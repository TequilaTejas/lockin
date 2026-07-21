import AppKit
import ApplicationServices

/// Browser-only mouse defence. Tracks the locked window's frame and its web
/// content area (AXWebArea) so the event tap can swallow clicks on browser
/// chrome — URL bar, tab strip, sidebar — which are all mouse paths to tab
/// switching or typed navigation. Also collapses the Dia/Arc sidebar once at
/// lock time. All state is written and read on the main thread.
final class ChromeGuard {
    /// Marks our own synthetic key events so the tap passes them through.
    static let sentinel: Int64 = 0x414E4348 // "ANCH"

    private let target: LockTarget
    private var windowEl: AXUIElement
    private var webArea: AXUIElement?
    private var timer: Timer?

    private(set) var windowRect: CGRect?
    private(set) var contentRect: CGRect?

    init(target: LockTarget) {
        self.target = target
        self.windowEl = target.windowElement
    }

    func start() {
        tick()
        maybeCollapseSidebar()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called when the watchdog re-pins to a new window.
    func updateWindow(_ newWindow: AXUIElement) {
        windowEl = newWindow
        webArea = nil
        contentRect = nil
        tick()
    }

    private func tick() {
        windowRect = Self.frame(of: windowEl)
        if webArea == nil { webArea = Self.findWebArea(in: windowEl) }
        if let wa = webArea {
            if let r = Self.frame(of: wa) {
                contentRect = r
            } else {
                // Navigation replaced the web area — re-find on the next tick.
                webArea = nil
                contentRect = nil
            }
        }
    }

    // MARK: Sidebar collapse (Dia / Arc)

    private func maybeCollapseSidebar() {
        guard target.browserKind == .dia || target.browserKind == .arc else { return }
        // Wait for the first content measurement, then use the content offset
        // as the open-sidebar signal — never blind-toggle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, let win = self.windowRect, let content = self.contentRect else { return }
            guard content.minX - win.minX > 80 else { return }
            self.sendCmdS()
        }
    }

    private func sendCmdS() {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: 1, keyDown: down) else { continue }
            e.flags = .maskCommand
            e.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)
            e.postToPid(target.pid)
        }
    }

    // MARK: AX helpers

    private static func frame(of el: AXUIElement) -> CGRect? {
        var posV: AnyObject?, sizeV: AnyObject?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posV) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeV) == .success
        else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(posV as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sizeV as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    /// Bounded DFS for the largest AXWebArea. Runs once per lock/navigation,
    /// never per event.
    private static func findWebArea(in root: AXUIElement) -> AXUIElement? {
        var best: (el: AXUIElement, area: CGFloat)?
        var stack: [(AXUIElement, Int)] = [(root, 0)]
        var visited = 0
        while let (el, depth) = stack.popLast() {
            visited += 1
            if visited > 400 { break }
            var roleV: AnyObject?
            AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleV)
            if (roleV as? String) == "AXWebArea" {
                if let f = frame(of: el) {
                    let area = f.width * f.height
                    if best == nil || area > best!.area { best = (el, area) }
                }
                continue
            }
            if depth >= 12 { continue }
            var kidsV: AnyObject?
            if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &kidsV) == .success,
               let kids = kidsV as? [AXUIElement] {
                for k in kids { stack.append((k, depth + 1)) }
            }
        }
        return best?.el
    }
}
