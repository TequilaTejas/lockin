import AppKit

/// Keeps a locked browser pinned to its active tab. Captures identity at lock
/// time, then polls at 500 ms *only while the locked browser is frontmost* and
/// reverts on deviation. All AppleScript runs off the main/event-tap thread.
final class TabLock {
    let bundleID: String
    let kind: BrowserKind

    private var identity: TabIdentity?
    private(set) var degraded = false
    private(set) var degradedReason: String?
    private(set) var tabTitle: String?
    private var automationDeniedSurfaced = false

    private let queue = DispatchQueue(label: "com.tejasdua.lockin.applescript")
    private var timer: Timer?
    private var busy = false

    /// Fired once when macOS reports Automation (Apple Events) is denied (-1743).
    var onAutomationDenied: (() -> Void)?
    /// Fired when we fall back to window-only lock (with a user-facing reason).
    var onDegraded: ((String) -> Void)?
    /// Fired when a tab title becomes available (for the status panel).
    var onTitle: ((String) -> Void)?

    init(bundleID: String, kind: BrowserKind) {
        self.bundleID = bundleID
        self.kind = kind
    }

    // MARK: Lifecycle

    /// Async capture with degraded tolerance — never blocks the lock, never crashes.
    func start() {
        captureIdentity()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Re-read the active tab after the watchdog re-pins to a new window.
    func recapture() {
        guard !degraded else { return }
        captureIdentity()
    }

    // MARK: Capture

    private func captureIdentity() {
        let src = BrowserScripts.capture(bundleID: bundleID, kind: kind)
        queue.async { [weak self] in
            let res = BrowserScripts.run(src)
            DispatchQueue.main.async { self?.applyCapture(res) }
        }
    }

    private func applyCapture(_ res: ScriptResult) {
        guard res.ok, let value = res.value else {
            if res.automationDenied { surfaceAutomationDenied() }
            degrade(reason: "Couldn't read the active tab — holding the window only.")
            return
        }
        switch kind {
        case .chromium, .arc:
            let parts = value.components(separatedBy: "|")
            guard parts.count == 2, !parts[0].isEmpty else {
                degrade(reason: "Couldn't read the active tab — holding the window only."); return
            }
            identity = kind == .arc
                ? .arc(tabID: parts[0], windowID: parts[1])
                : .chromium(tabID: parts[0], windowID: parts[1])
        case .safari:
            let parts = value.components(separatedBy: "|")
            guard parts.count >= 2, let idx = Int(parts[0]) else {
                degrade(reason: "Couldn't read the active tab — holding the window only."); return
            }
            identity = .safari(index: idx, lastKnownURL: parts.dropFirst().joined(separator: "|"))
        case .dia:
            guard !value.isEmpty else {
                degrade(reason: "Couldn't read the active tab — holding the window only."); return
            }
            identity = .dia(uuid: value)
        }
        fetchTitle()
    }

    // MARK: Poll

    private func tick() {
        guard !busy, let stored = identity else { return }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID else { return }
        busy = true
        let src = BrowserScripts.check(bundleID: bundleID, kind: kind)
        queue.async { [weak self] in
            let res = BrowserScripts.run(src)
            DispatchQueue.main.async { self?.handleCheck(res, stored: stored) }
        }
    }

    private func handleCheck(_ res: ScriptResult, stored: TabIdentity) {
        defer { busy = false }
        guard res.ok, let value = res.value else {
            if res.automationDenied { surfaceAutomationDenied() }
            return // transient (no window, mid-launch) — retry next tick
        }
        switch (kind, stored) {
        case let (.chromium, .chromium(tabID, _)), let (.arc, .arc(tabID, _)):
            let cur = value.components(separatedBy: "|").first ?? ""
            if cur != tabID { revert(stored) }
        case let (.safari, .safari(storedIdx, _)):
            let parts = value.components(separatedBy: "|")
            guard parts.count >= 2, let idx = Int(parts[0]) else { return }
            let curURL = parts.dropFirst().joined(separator: "|")
            if idx == storedIdx {
                identity = .safari(index: storedIdx, lastKnownURL: curURL) // same-tab nav is legal
            } else {
                revert(stored)
            }
        case let (.dia, .dia(uuid)):
            if value != uuid { revert(stored) }
        default:
            break
        }
    }

    /// Called by the watchdog after a window snap-back so the tab is re-pinned too.
    func revertNow() {
        guard let stored = identity else { return }
        revert(stored)
    }

    private func revert(_ stored: TabIdentity) {
        guard let src = BrowserScripts.revert(bundleID: bundleID, kind: kind, identity: stored) else { return }
        queue.async { [weak self] in
            let res = BrowserScripts.run(src)
            guard !res.ok else { return }
            DispatchQueue.main.async {
                if res.automationDenied { self?.surfaceAutomationDenied() }
                else { self?.degradeIfFragile() } // Arc/Dia: revert error → window-only
            }
        }
    }

    // MARK: Title

    private func fetchTitle() {
        let prop = kind == .safari ? "name of current tab" : "title of active tab"
        let src = "with timeout of 3 seconds\ntell application id \"\(bundleID)\" to return \(prop) of front window\nend timeout"
        queue.async { [weak self] in
            let res = BrowserScripts.run(src)
            guard res.ok, let title = res.value, !title.isEmpty else { return }
            DispatchQueue.main.async {
                self?.tabTitle = title
                self?.onTitle?(title)
            }
        }
    }

    // MARK: Degraded / errors

    private func degrade(reason: String) {
        guard !degraded else { return }
        degraded = true
        identity = nil
        degradedReason = reason
        onDegraded?(reason)
    }

    private func degradeIfFragile() {
        guard kind == .arc || kind == .dia else { return }
        degrade(reason: "Tab revert isn't supported here — holding the window only.")
    }

    private func surfaceAutomationDenied() {
        guard !automationDeniedSurfaced else { return }
        automationDeniedSurfaced = true
        onAutomationDenied?()
    }
}
