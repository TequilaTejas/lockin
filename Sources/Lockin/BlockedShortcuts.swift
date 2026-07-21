import Foundation

/// Normalized modifier set — only the four we care about, stripped of
/// device-specific bits (caps lock, fn, numeric pad, left/right variants).
struct Mods: OptionSet, Hashable {
    let rawValue: Int
    static let cmd   = Mods(rawValue: 1 << 0)
    static let shift = Mods(rawValue: 1 << 1)
    static let ctrl  = Mods(rawValue: 1 << 2)
    static let opt   = Mods(rawValue: 1 << 3)
}

struct Shortcut: Hashable {
    let keyCode: Int64
    let mods: Mods
}

/// Virtual key codes (kVK_*). Only the ones we block.
private enum K {
    static let tab: Int64 = 48
    static let backtick: Int64 = 50
    static let q: Int64 = 12
    static let w: Int64 = 13
    static let n: Int64 = 45
    static let m: Int64 = 46
    static let h: Int64 = 4
    static let t: Int64 = 17
    static let a: Int64 = 0
    static let d: Int64 = 2
    static let s: Int64 = 1
    static let l: Int64 = 37
    static let o: Int64 = 31
    static let k: Int64 = 40
    static let space: Int64 = 49
    static let f11: Int64 = 103
    // Dedicated top-row keys on Apple keyboards arrive as plain keyDowns,
    // not NX_SYSDEFINED.
    static let missionControl: Int64 = 160
    static let launchpad: Int64 = 131
    static let appExpose: Int64 = 130
    static let left: Int64 = 123
    static let right: Int64 = 124
    static let down: Int64 = 125
    static let up: Int64 = 126
    static let leftBracket: Int64 = 33
    static let rightBracket: Int64 = 30
    // number row 1...9
    static let digits: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
}

enum BlockedShortcuts {
    /// Blocked no matter what app is frontmost.
    static let always: Set<Shortcut> = {
        var s = Set<Shortcut>()
        // App switching
        s.insert(Shortcut(keyCode: K.tab, mods: [.cmd]))
        s.insert(Shortcut(keyCode: K.tab, mods: [.cmd, .shift]))
        s.insert(Shortcut(keyCode: K.backtick, mods: [.cmd]))
        s.insert(Shortcut(keyCode: K.backtick, mods: [.cmd, .shift]))
        // Quit / close the only allowed surface (+ shift/opt variants).
        // Ctrl+Cmd+Q (lock screen) carries ctrl, so it never matches these.
        for m: Mods in [[.cmd], [.cmd, .shift], [.cmd, .opt]] {
            s.insert(Shortcut(keyCode: K.q, mods: m))
            s.insert(Shortcut(keyCode: K.w, mods: m))
        }
        // New window (+ shift/opt variants).
        for m: Mods in [[.cmd], [.cmd, .shift], [.cmd, .opt]] {
            s.insert(Shortcut(keyCode: K.n, mods: m))
        }
        // Minimize / hide.
        s.insert(Shortcut(keyCode: K.m, mods: [.cmd]))
        s.insert(Shortcut(keyCode: K.m, mods: [.cmd, .opt])) // minimize all
        s.insert(Shortcut(keyCode: K.h, mods: [.cmd]))
        s.insert(Shortcut(keyCode: K.h, mods: [.cmd, .opt])) // hide others
        // Spaces / Mission Control via Ctrl+arrows.
        for k in [K.left, K.right, K.up, K.down] {
            s.insert(Shortcut(keyCode: k, mods: [.ctrl]))
            s.insert(Shortcut(keyCode: k, mods: [.ctrl, .shift]))
        }
        // Show desktop / Mission Control / Launchpad / App Exposé keys.
        for k in [K.f11, K.missionControl, K.launchpad, K.appExpose] {
            s.insert(Shortcut(keyCode: k, mods: []))
            s.insert(Shortcut(keyCode: k, mods: [.ctrl]))
        }
        return s
    }()

    /// Blocked only when the locked target is a browser.
    static let browserOnly: Set<Shortcut> = {
        var s = Set<Shortcut>()
        s.insert(Shortcut(keyCode: K.t, mods: [.cmd]))            // new tab
        s.insert(Shortcut(keyCode: K.t, mods: [.cmd, .shift]))    // reopen tab
        s.insert(Shortcut(keyCode: K.t, mods: [.cmd, .opt]))      // new tab (some)
        for k in K.digits {                                       // jump to tab N
            s.insert(Shortcut(keyCode: k, mods: [.cmd]))
        }
        s.insert(Shortcut(keyCode: K.tab, mods: [.ctrl]))         // next tab
        s.insert(Shortcut(keyCode: K.tab, mods: [.ctrl, .shift])) // prev tab
        s.insert(Shortcut(keyCode: K.rightBracket, mods: [.cmd, .shift])) // next tab
        s.insert(Shortcut(keyCode: K.leftBracket, mods: [.cmd, .shift]))  // prev tab
        s.insert(Shortcut(keyCode: K.left, mods: [.cmd, .opt]))   // prev tab (Chrome)
        s.insert(Shortcut(keyCode: K.right, mods: [.cmd, .opt]))  // next tab (Chrome)
        s.insert(Shortcut(keyCode: K.a, mods: [.cmd, .shift]))    // search tabs
        s.insert(Shortcut(keyCode: K.d, mods: [.cmd, .shift]))    // bookmark all / dupe
        s.insert(Shortcut(keyCode: K.s, mods: [.cmd]))            // Dia/Arc sidebar toggle
        s.insert(Shortcut(keyCode: K.l, mods: [.cmd]))            // address bar / command bar
        s.insert(Shortcut(keyCode: K.l, mods: [.cmd, .shift]))    // Safari sidebar
        s.insert(Shortcut(keyCode: K.o, mods: [.cmd]))            // open file → navigation
        s.insert(Shortcut(keyCode: K.k, mods: [.cmd]))            // address-bar search
        return s
    }()

    /// Spotlight is separate so it can be toggled off in settings.
    static let spotlight = Shortcut(keyCode: K.space, mods: [.cmd])
    static let spotlightAlt = Shortcut(keyCode: K.space, mods: [.cmd, .opt])
}
