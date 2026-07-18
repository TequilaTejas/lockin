import AppKit

/// The prevention layer. A session-level, head-inserting CGEventTap that swallows
/// blocked shortcuts and stray clicks while locked. The callback does ZERO heavy
/// work (no AppleScript, no AX) — only table lookups and a cached region test.
final class EventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Snapshot state — written and read only on the main thread (the tap source
    // lives on the main run loop, so the callback also runs on main).
    var lockedPID: pid_t = 0
    var targetIsBrowser = false
    var settings: Settings

    /// Temporary second allowed app (the kitty input exception). 0 = none.
    var exceptionPID: pid_t = 0
    /// Browser locks only: supplies window/content rects for chrome-click
    /// filtering. Main-thread only, like the rest of the snapshot state.
    weak var chromeGuard: ChromeGuard?
    /// Fired on a bare Return while the exception is active — the "input
    /// submitted, snap me back" signal. Validation happens in the handler,
    /// not here.
    var onExceptionSubmit: (() -> Void)?

    private let regions = AllowedRegions()
    private var escDownSince: CFAbsoluteTime?

    /// Fired when Esc has been held for 5 s. Runs on the next main-loop turn.
    var onEmergencyUnlock: (() -> Void)?

    init(settings: Settings) { self.settings = settings }

    // MARK: Lifecycle

    /// Must be called on the main thread — the tap attaches to the main run loop.
    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.rightMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) |
            (CGEventMask(1) << 14) // NX_SYSDEFINED (Mission Control / Launchpad / media)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = src
    }

    func stop() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        if let tap = tap { CFMachPortInvalidate(tap) }
        tap = nil
        runLoopSource = nil
        escDownSince = nil
    }

    // MARK: Callback body

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The OS disables the tap after a slow callback or heavy user input.
        // Re-enable immediately or input stays swallowed.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Our own synthetic keystrokes (ChromeGuard's sidebar collapse) carry a
        // sentinel and must never be swallowed by the shortcut table.
        if event.getIntegerValueField(.eventSourceUserData) == ChromeGuard.sentinel {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Esc-hold emergency unlock. Esc ALWAYS passes through, and this lives
        // inside the callback itself so it can never be starved — the last-resort
        // escape from a wedged lock.
        if keyCode == 53 { // Esc
            if type == .keyDown, settings.emergencyEscEnabled {
                let now = CFAbsoluteTimeGetCurrent()
                if let since = escDownSince {
                    if now - since >= 5.0 {
                        escDownSince = nil
                        onEmergencyUnlock?() // scheduled after we return; we're on main
                    }
                } else {
                    escDownSince = now
                }
            } else if type == .keyUp {
                escDownSince = nil
            }
            return Unmanaged.passUnretained(event)
        }

        // NX_SYSDEFINED: allow media/brightness/volume/illumination, swallow other
        // system nav keys (Mission Control, Launchpad, Exposé) while locked.
        if type.rawValue == 14 {
            return shouldSwallowSystemDefined(event) ? nil : Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            let mods = normalize(event.flags)
            let sc = Shortcut(keyCode: keyCode, mods: mods)
            if exceptionPID != 0, mods.isEmpty, keyCode == 36 || keyCode == 76 {
                onExceptionSubmit?() // Return/Enter still passes through below
            }
            if BlockedShortcuts.always.contains(sc) { return nil }
            if targetIsBrowser, BlockedShortcuts.browserOnly.contains(sc) { return nil }
            if settings.blockSpotlight,
               sc == BlockedShortcuts.spotlight || sc == BlockedShortcuts.spotlightAlt { return nil }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return regions.allows(point: event.location, lockedPID: lockedPID, exceptionPID: exceptionPID,
                                  lockedWindowRect: chromeGuard?.windowRect,
                                  contentRect: chromeGuard?.contentRect)
                ? Unmanaged.passUnretained(event)
                : nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func normalize(_ flags: CGEventFlags) -> Mods {
        var m = Mods()
        if flags.contains(.maskCommand)   { m.insert(.cmd) }
        if flags.contains(.maskShift)     { m.insert(.shift) }
        if flags.contains(.maskControl)   { m.insert(.ctrl) }
        if flags.contains(.maskAlternate) { m.insert(.opt) }
        return m
    }

    private func shouldSwallowSystemDefined(_ event: CGEvent) -> Bool {
        guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else { return false }
        let keyCode = Int((ns.data1 & 0xFFFF0000) >> 16)
        // NX_KEYTYPE codes we always let through, even while locked.
        let allowed: Set<Int> = [0, 1, 2, 3, 4, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23]
        return !allowed.contains(keyCode)
    }
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
