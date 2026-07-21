import AppKit
import ApplicationServices

/// The cure layer. Whatever slips past the event tap (notification clicks,
/// trackpad gestures, page JS window.open) gets chased back: activate the app,
/// raise the locked window, re-pin the tab. Debounced, with a loop guard so a
/// stubborn modal can never turn into a snap-back storm.
final class FocusWatchdog {
    private let target: LockTarget
    private let debounceMs: Int
    private let onUnlock: (String) -> Void
    private let onRevertTab: () -> Void
    private let onRepin: (AXUIElement) -> Void

    /// Temporary second allowed app (the kitty input exception) — activations
    /// of this pid don't trigger snap-back.
    var extraAllowedPID: pid_t?
    /// Fired when the locked app itself comes back to front (used to end the
    /// exception when the user returns on their own).
    var onTargetRefocused: (() -> Void)?

    private var observer: AXObserver?
    private var currentWindow: AXUIElement
    private var wsTokens: [NSObjectProtocol] = []

    private var snapWork: DispatchWorkItem?
    private var snapTimestamps: [CFAbsoluteTime] = []
    private var backoffUntil: CFAbsoluteTime = 0

    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

    init(target: LockTarget,
         debounceMs: Int,
         onUnlock: @escaping (String) -> Void,
         onRevertTab: @escaping () -> Void,
         onRepin: @escaping (AXUIElement) -> Void) {
        self.target = target
        self.debounceMs = debounceMs
        self.onUnlock = onUnlock
        self.onRevertTab = onRevertTab
        self.onRepin = onRepin
        self.currentWindow = target.windowElement
    }

    // MARK: Lifecycle

    func start() {
        let wc = NSWorkspace.shared.notificationCenter
        wsTokens.append(wc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                       object: nil, queue: .main) { [weak self] note in
            self?.handleActivate(note)
        })
        wsTokens.append(wc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                       object: nil, queue: .main) { [weak self] note in
            self?.handleTerminate(note)
        })

        var obs: AXObserver?
        if AXObserverCreate(target.pid, axObserverCallback, &obs) == .success, let obs = obs {
            observer = obs
            AXObserverAddNotification(obs, target.appElement, kAXFocusedWindowChangedNotification as CFString, refcon)
            AXObserverAddNotification(obs, currentWindow, kAXUIElementDestroyedNotification as CFString, refcon)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
    }

    func stop() {
        let wc = NSWorkspace.shared.notificationCenter
        wsTokens.forEach { wc.removeObserver($0) }
        wsTokens.removeAll()
        snapWork?.cancel()
        if let obs = observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
            AXObserverRemoveNotification(obs, target.appElement, kAXFocusedWindowChangedNotification as CFString)
            AXObserverRemoveNotification(obs, currentWindow, kAXUIElementDestroyedNotification as CFString)
        }
        observer = nil
    }

    // MARK: NSWorkspace

    private func handleActivate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        if pid == target.pid { onTargetRefocused?(); return }
        if pid == getpid() || pid == extraAllowedPID { return }
        if SystemProcess.isSystem(pid) { return } // don't fight permission prompts
        scheduleSnapBack()
    }

    private func handleTerminate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.processIdentifier == target.pid {
            onUnlock("The locked app quit.")
        }
    }

    // MARK: AX

    fileprivate func handleAX(notification: String) {
        if notification == (kAXUIElementDestroyedNotification as String) {
            handleWindowDestroyed()
        } else if notification == (kAXFocusedWindowChangedNotification as String) {
            handleFocusChanged()
        }
    }

    private func handleFocusChanged() {
        guard let newWin = focusedWindow(of: target.appElement) else { return }
        if CFEqual(newWin, currentWindow) { return }
        // Let legitimate sheets / dialogs / modals take focus without a fight;
        // focus returns to the locked window when they close.
        let allowed: Set<String> = ["AXSheet", "AXDialog", "AXSystemDialog", "AXSystemDialogSubrole"]
        let subrole = stringAttr(newWin, kAXSubroleAttribute as String)
        let role = stringAttr(newWin, kAXRoleAttribute as String)
        if boolAttr(newWin, kAXModalAttribute as String)
            || (subrole.map(allowed.contains) ?? false)
            || (role.map(allowed.contains) ?? false) {
            return
        }
        scheduleSnapBack()
    }

    private func handleWindowDestroyed() {
        if let newWin = focusedWindow(of: target.appElement) {
            if let obs = observer {
                AXObserverRemoveNotification(obs, currentWindow, kAXUIElementDestroyedNotification as CFString)
                currentWindow = newWin
                AXObserverAddNotification(obs, currentWindow, kAXUIElementDestroyedNotification as CFString, refcon)
            }
            onRepin(newWin) // re-capture the tab on the app's new frontmost window
            scheduleSnapBack()
        } else {
            onUnlock("The locked window closed.")
        }
    }

    // MARK: Snap-back

    /// Immediate, undebounced snap-back (ending the kitty exception).
    func snapBackNow() {
        snapWork?.cancel()
        performSnapBack()
    }

    private func scheduleSnapBack() {
        if CFAbsoluteTimeGetCurrent() < backoffUntil { return }
        snapWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.performSnapBack() }
        snapWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(debounceMs) / 1000.0, execute: work)
    }

    private func performSnapBack() {
        // Loop guard: more than 3 snap-backs in 2 s means we're fighting something
        // real (a modal we misjudged) — back off 5 s instead of thrashing.
        let now = CFAbsoluteTimeGetCurrent()
        snapTimestamps = snapTimestamps.filter { now - $0 < 2.0 }
        if snapTimestamps.count >= 3 {
            backoffUntil = now + 5.0
            snapTimestamps.removeAll()
            return
        }
        snapTimestamps.append(now)

        // Cooperative activation (macOS 14+) can refuse activate() from a
        // background process, so also force frontmost through AX — trusted
        // apps bypass the cooperation rules there.
        NSRunningApplication(processIdentifier: target.pid)?.activate()
        AXUIElementSetAttributeValue(target.appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(currentWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(currentWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        onRevertTab()
    }

    // MARK: AX helpers

    private func focusedWindow(of app: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    private func stringAttr(_ el: AXUIElement, _ attr: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func boolAttr(_ el: AXUIElement, _ attr: String) -> Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }
}

private let axObserverCallback: AXObserverCallback = { _, _, notification, refcon in
    guard let refcon = refcon else { return }
    let wd = Unmanaged<FocusWatchdog>.fromOpaque(refcon).takeUnretainedValue()
    wd.handleAX(notification: notification as String)
}
