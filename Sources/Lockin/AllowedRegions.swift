import AppKit

/// Decides whether a mouse-down at a point should be allowed while locked.
/// CGEvent.location and CGWindowList bounds are both in top-left global display
/// coordinates, so they compare directly with no conversion.
/// Is this pid a system UI process (TCC permission prompts, SecurityAgent,
/// screenshot UI…)? Their dialogs sit at the modal-panel layer (8), NOT the
/// high status layers, so they must be trusted by owner, not by layer.
enum SystemProcess {
    private static var cache: [pid_t: Bool] = [:]

    static func isSystem(_ pid: pid_t) -> Bool {
        if let hit = cache[pid] { return hit }
        var buf = [CChar](repeating: 0, count: 4096)
        var system = false
        if proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 {
            let path = String(cString: buf)
            system = path.hasPrefix("/System/") || path.hasPrefix("/usr/libexec/")
        }
        if cache.count > 256 { cache.removeAll() }
        cache[pid] = system
        return system
    }
}

final class AllowedRegions {
    private struct WinInfo { let pid: pid_t; let layer: Int; let bounds: CGRect }

    private let ourPID = getpid()
    private var cache: [WinInfo] = []
    private var cacheTime: CFAbsoluteTime = 0

    func allows(point cg: CGPoint, lockedPID: pid_t, exceptionPID: pid_t = 0,
                lockedWindowRect: CGRect? = nil, contentRect: CGRect? = nil) -> Bool {
        // DEAD-MAN RULE: the menu bar is ALWAYS clickable, checked BEFORE we touch
        // any cache or window list. This is what guarantees the status item and
        // hold-to-unlock stay reachable no matter what else goes wrong.
        if isInMenuBar(cg) { return true }

        let now = CFAbsoluteTimeGetCurrent()
        if now - cacheTime > 0.25 {
            refreshCache()
            cacheTime = now
        }

        // Window list is front-to-back; the first window containing the point is
        // the one that would receive the click. Its ownership decides.
        for w in cache where w.bounds.contains(cg) {
            if w.pid == lockedPID {
                // Browser chrome defence: clicks on the locked browser window
                // itself are only allowed inside the web content area — the URL
                // bar, tab strip, and sidebar are all mouse paths to navigation.
                // Applies only when the hit window IS the locked window (fuzzy
                // bounds match), so the browser's own sheets, file pickers, and
                // JS dialogs — separate windows — stay fully clickable.
                if let winRect = lockedWindowRect, let content = contentRect,
                   approxEqual(w.bounds, winRect),
                   !content.insetBy(dx: -2, dy: -2).contains(cg) {
                    return false
                }
                return true
            }
            return w.pid == ourPID || w.layer >= 25
                || (exceptionPID != 0 && w.pid == exceptionPID)
                || SystemProcess.isSystem(w.pid)
        }
        return false // desktop / Dock / no owning window → swallow
    }

    private func approxEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 2 && abs(a.minY - b.minY) < 2
            && abs(a.width - b.width) < 2 && abs(a.height - b.height) < 2
    }

    private func isInMenuBar(_ cg: CGPoint) -> Bool {
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                ?? NSScreen.screens.first else { return false }
        let cocoa = CGPoint(x: cg.x, y: primary.frame.maxY - cg.y) // top-left → bottom-left
        for screen in NSScreen.screens {
            let f = screen.frame
            let vf = screen.visibleFrame
            if cocoa.x >= f.minX, cocoa.x <= f.maxX, cocoa.y >= vf.maxY, cocoa.y <= f.maxY {
                return true
            }
        }
        return false
    }

    private func refreshCache() {
        var result: [WinInfo] = []
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard let pidNum = w[kCGWindowOwnerPID as String] as? Int,
                      let layer = w[kCGWindowLayer as String] as? Int,
                      let boundsDict = w[kCGWindowBounds as String] as? NSDictionary,
                      let rect = CGRect(dictionaryRepresentation: boundsDict)
                else { continue }
                // Skip fully transparent overlays (input monitors, screen FX):
                // first-window-wins would let one sitting above the locked
                // window eat every click.
                if let alpha = w[kCGWindowAlpha as String] as? Double, alpha <= 0 { continue }
                result.append(WinInfo(pid: pid_t(pidNum), layer: layer, bounds: rect))
            }
        }
        cache = result
    }
}
