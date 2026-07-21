import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = LockController()

    private var statusItem: NSStatusItem!
    private var panelController: StatusPanelController!
    private var cancellables = Set<AnyCancellable>()
    private var titleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = StatusPanelController(controller: controller)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.statusIcon(locked: false)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        // Reflect lock state in the menu bar icon and remaining-time label.
        controller.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                let locked: Bool = { if case .locked = state { return true } else { return false } }()
                self?.statusItem.button?.image = Self.statusIcon(locked: locked)
                self?.refreshStatusTitle()
            }
            .store(in: &cancellables)

        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in self?.refreshStatusTitle() }
        RunLoop.main.add(t, forMode: .common)
        titleTimer = t
    }

    /// While a commitment timer runs, the menu bar shows the minutes left next
    /// to the lock — the state is readable without opening the panel.
    private func refreshStatusTitle() {
        guard let button = statusItem.button else { return }
        if controller.isLocked, let until = controller.minLockUntil, until > Date() {
            let mins = max(1, Int(ceil(until.timeIntervalSinceNow / 60)))
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.imagePosition = .imageLeading
            button.title = " \(mins)m"
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    /// Phosphor icons rasterized for the status item. Unlocked: black render
    /// marked template so the menu bar tints it natively. Locked: orange baked
    /// into the bitmap — menu bar tinting of template images is unreliable, so
    /// color never relies on it.
    private static func statusIcon(locked: Bool) -> NSImage? {
        MainActor.assumeIsolated {
            let icon = locked
                ? Phos.lockSimpleFill.color(.orange)
                : Phos.lockSimpleOpenBold.color(.black)
            let renderer = ImageRenderer(content: icon.frame(width: 16, height: 16))
            renderer.scale = 2
            guard let img = renderer.nsImage else { return nil }
            img.isTemplate = !locked
            img.accessibilityDescription = locked ? "Lockin — locked" : "Lockin — unlocked"
            return img
        }
    }

    // lockin://kitty-input — pinged by the Claude Code Notification hook when a
    // session inside kitty is waiting on the user. Only meaningful while locked.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "lockin" && url.host == "kitty-input" {
            controller.beginKittyException()
        }
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        panelController.toggle(from: button)
    }

    // Don't let a stray Quit end a live lock — unlock through the panel first
    // (or hold Esc 5 s). kill -9 always still works as the hard failsafe.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        controller.isLocked ? .terminateCancel : .terminateNow
    }
}
