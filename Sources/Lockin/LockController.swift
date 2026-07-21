import AppKit
import ApplicationServices
import Combine

struct LockTarget {
    let pid: pid_t
    let bundleID: String
    let appName: String
    let appElement: AXUIElement
    let windowElement: AXUIElement
    let browserKind: BrowserKind?
    var isBrowser: Bool { browserKind != nil }
}

enum LockState {
    case unlocked
    case locked(LockTarget)
}

/// The single owner of lock state. lock() captures the target and starts all
/// three layers; unlock(reason:) is the sole teardown path. Locked state is
/// never persisted — a fresh launch is always unlocked.
final class LockController: ObservableObject {
    @Published private(set) var state: LockState = .unlocked
    @Published private(set) var degradedNote: String?
    @Published private(set) var lockedTabTitle: String?
    @Published private(set) var lastUnlockReason: String?
    /// The kitty input exception: kitty is temporarily allowed over the lock
    /// so a Claude Code prompt can be answered. Ends on Return, on the user
    /// coming back to the locked app themselves, or after a safety timeout.
    @Published private(set) var kittyExceptionActive = false
    /// Commitment timer choice for the NEXT lock (minutes; nil = off). Set from
    /// the panel before locking; sticky across locks within a session.
    @Published var minLockChoiceMinutes: Int?
    /// When a timer is set: true = the lock releases itself at expiry;
    /// false = it stays locked and only the unlock ring becomes available.
    @Published var autoUnlockAtTimerEnd = false
    private(set) var minLockUntil: Date?
    private var autoUnlockWork: DispatchWorkItem?

    /// Non-nil while the hold-to-unlock path is blocked by the commitment
    /// timer. Emergency Esc-hold and system unlocks are unaffected.
    var unlockBlockedUntil: Date? {
        guard isLocked, let until = minLockUntil, until > Date() else { return nil }
        return until
    }
    @Published var settings: Settings {
        didSet {
            settings.save()
            eventTap.settings = settings
        }
    }

    private let eventTap: EventTap
    private var watchdog: FocusWatchdog?
    private var tabLock: TabLock?
    private var chromeGuard: ChromeGuard?
    private var exceptionTimeout: DispatchWorkItem?

    static let kittyBundleID = "net.kovidgoyal.kitty"

    var isLocked: Bool { if case .locked = state { return true } else { return false } }
    var lockedTarget: LockTarget? { if case let .locked(t) = state { return t } else { return nil } }

    init() {
        let loaded = Settings.load()
        settings = loaded
        eventTap = EventTap(settings: loaded)
        eventTap.onEmergencyUnlock = { [weak self] in
            self?.unlock(reason: "Emergency unlock — Esc held 5 s.")
        }
        eventTap.onExceptionSubmit = { [weak self] in
            guard let self, self.kittyExceptionActive,
                  NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.kittyBundleID
            else { return }
            // Let kitty receive the Return first, then pull focus home.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.endKittyException() }
        }
    }

    // MARK: Kitty input exception

    var kittyAvailable: Bool {
        guard let t = lockedTarget, t.bundleID != Self.kittyBundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: Self.kittyBundleID).isEmpty
    }

    func beginKittyException() {
        guard isLocked, !kittyExceptionActive,
              lockedTarget?.bundleID != Self.kittyBundleID,
              let kitty = NSRunningApplication.runningApplications(withBundleIdentifier: Self.kittyBundleID).first
        else { return }

        kittyExceptionActive = true
        eventTap.exceptionPID = kitty.processIdentifier
        watchdog?.extraAllowedPID = kitty.processIdentifier

        kitty.activate()
        let el = AXUIElementCreateApplication(kitty.processIdentifier)
        AXUIElementSetAttributeValue(el, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        // Safety net: an unanswered prompt shouldn't hold the door open forever.
        let work = DispatchWorkItem { [weak self] in self?.endKittyException() }
        exceptionTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: work)
    }

    /// Ends the exception and snaps focus back to the locked window.
    func endKittyException() {
        guard clearKittyException() else { return }
        watchdog?.snapBackNow()
    }

    /// Clears exception state without moving focus (the user already came back).
    @discardableResult
    private func clearKittyException() -> Bool {
        guard kittyExceptionActive else { return false }
        kittyExceptionActive = false
        exceptionTimeout?.cancel()
        exceptionTimeout = nil
        eventTap.exceptionPID = 0
        watchdog?.extraAllowedPID = nil
        return true
    }

    /// The frontmost app we'd lock (nil if it's us or nothing).
    func frontmostLockable() -> (name: String, icon: NSImage?, isBrowser: Bool)? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != getpid() else { return nil }
        let name = front.localizedName ?? front.bundleIdentifier ?? "App"
        let browser = front.bundleIdentifier.flatMap(BrowserKind.from(bundleID:)) != nil
        return (name, front.icon, browser)
    }

    var lockedAppIcon: NSImage? {
        lockedTarget.flatMap { NSRunningApplication(processIdentifier: $0.pid)?.icon }
    }

    // MARK: Lock

    func lock() {
        guard !isLocked, Permissions.isTrusted else { return }
        guard let front = NSWorkspace.shared.frontmostApplication,
              let bundleID = front.bundleIdentifier,
              front.processIdentifier != getpid(),
              bundleID != Bundle.main.bundleIdentifier else { return } // never lock Lockin itself

        let pid = front.processIdentifier
        let appEl = AXUIElementCreateApplication(pid)
        var winValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &winValue) == .success,
              let wv = winValue, CFGetTypeID(wv) == AXUIElementGetTypeID() else { return }
        let winEl = wv as! AXUIElement

        let kind = BrowserKind.from(bundleID: bundleID)
        let target = LockTarget(
            pid: pid, bundleID: bundleID, appName: front.localizedName ?? bundleID,
            appElement: appEl, windowElement: winEl, browserKind: kind
        )

        degradedNote = nil
        lockedTabTitle = nil
        lastUnlockReason = nil
        minLockUntil = minLockChoiceMinutes.map { Date().addingTimeInterval(Double($0) * 60) }
        if let until = minLockUntil, autoUnlockAtTimerEnd {
            let work = DispatchWorkItem { [weak self] in self?.unlock(reason: "Timed lock ended.") }
            autoUnlockWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + until.timeIntervalSinceNow, execute: work)
        }

        // PREVENTION
        eventTap.settings = settings
        eventTap.lockedPID = pid
        eventTap.targetIsBrowser = target.isBrowser
        eventTap.start()

        // Browser chrome defence (browsers only)
        if kind != nil {
            let cg = ChromeGuard(target: target)
            cg.start()
            chromeGuard = cg
            eventTap.chromeGuard = cg
        }

        // CURE — tab lock (browsers only)
        if let kind = kind {
            let tl = TabLock(bundleID: bundleID, kind: kind)
            tl.onDegraded = { [weak self] reason in self?.degradedNote = reason }
            tl.onAutomationDenied = { [weak self] in self?.handleAutomationDenied() }
            tl.onTitle = { [weak self] title in self?.lockedTabTitle = title }
            tl.start()
            tabLock = tl
        }

        // CURE — focus watchdog
        let wd = FocusWatchdog(
            target: target, debounceMs: settings.debounceMs,
            onUnlock: { [weak self] reason in self?.unlock(reason: reason) },
            onRevertTab: { [weak self] in self?.tabLock?.revertNow() },
            onRepin: { [weak self] newWin in
                self?.tabLock?.recapture()
                self?.chromeGuard?.updateWindow(newWin)
            }
        )
        wd.onTargetRefocused = { [weak self] in self?.clearKittyException() }
        wd.start()
        watchdog = wd

        state = .locked(target)
    }

    // MARK: Unlock (sole teardown path)

    func unlock(reason: String? = nil) {
        guard isLocked else { return }
        clearKittyException()
        eventTap.stop()
        eventTap.lockedPID = 0
        eventTap.targetIsBrowser = false
        watchdog?.stop(); watchdog = nil
        tabLock?.stop(); tabLock = nil
        chromeGuard?.stop(); chromeGuard = nil
        eventTap.chromeGuard = nil
        lockedTabTitle = nil
        minLockUntil = nil
        autoUnlockWork?.cancel()
        autoUnlockWork = nil
        lastUnlockReason = reason
        state = .unlocked
    }

#if LOCKIN_PREVIEW
    /// Snapshot-harness only: force UI states without touching AX or the tap.
    func previewLock(browser: Bool, tabTitle: String?, minutes: Int?, auto: Bool) {
        let el = AXUIElementCreateApplication(getpid())
        let t = LockTarget(
            pid: pid_t(getpid()),
            bundleID: browser ? "company.thebrowser.dia" : "com.apple.TextEdit",
            appName: browser ? "Dia" : "TextEdit",
            appElement: el, windowElement: el,
            browserKind: browser ? .dia : nil
        )
        lockedTabTitle = tabTitle
        minLockChoiceMinutes = minutes
        autoUnlockAtTimerEnd = auto
        minLockUntil = minutes.map { Date().addingTimeInterval(Double($0) * 60 - 133) }
        state = .locked(t)
    }
#endif

    private func handleAutomationDenied() {
        degradedNote = "Automation is off — Lockin can't steer tabs. Enable it in System Settings ▸ Privacy ▸ Automation."
    }
}
