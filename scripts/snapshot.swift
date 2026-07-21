import SwiftUI
import AppKit

@main
struct PanelTest {
    @MainActor
    static func main() {
        func snap(_ name: String, _ setup: (LockController) -> Void) {
            let c = LockController()
            setup(c)
            let v = StatusPanelView(controller: c, onClose: {}, onResize: { _ in })
                .padding(12)
                .background(Color(red: 0.93, green: 0.93, blue: 0.94))
            let r = ImageRenderer(content: v)
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else { print("FAIL \(name)"); return }
            try! png.write(to: URL(fileURLWithPath: "panel-\(name).png"))
            print("OK \(name)")
        }
        snap("unlocked") { _ in }
        snap("unlocked-timer") { $0.minLockChoiceMinutes = 30 }
        snap("locked") { $0.previewLock(browser: true, tabTitle: "The Ultimate Framework to Ace the Whiteboard Challenge — Medium", minutes: nil, auto: false) }
        snap("locked-countdown") { $0.previewLock(browser: true, tabTitle: "The Ultimate Framework to Ace the Whiteboard Challenge — Medium", minutes: 30, auto: false) }
    }
}
