import AppKit
import ApplicationServices

enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompts for Accessibility on first use. Returns current trust immediately;
    /// the system shows its grant dialog asynchronously.
    @discardableResult
    static func promptForAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    /// Polls once a second until the app becomes trusted, then fires once.
    static func pollUntilTrusted(_ onGranted: @escaping () -> Void) {
        if isTrusted { onGranted(); return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { t in
            if isTrusted { t.invalidate(); onGranted() }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func open(_ s: String) {
        if let url = URL(string: s) { NSWorkspace.shared.open(url) }
    }
}
