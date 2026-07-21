import AppKit
import SwiftUI

/// Borderless, non-activating panel floating at status-bar level over every
/// Space and full-screen app. It never steals focus from the locked window, so
/// its buttons work on the first click without activating Lockin.
final class FloatingPanel: NSPanel {
    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { true }
}

/// Shows the status panel under the menu bar item and resizes it to fit the
/// content of whichever state is showing, keeping the top edge anchored.
final class StatusPanelController {
    private let controller: LockController
    private var panel: FloatingPanel?
    private var anchorTop: CGFloat = 0
    private var anchorMidX: CGFloat = 0

    init(controller: LockController) { self.controller = controller }

    var isShowing: Bool { panel != nil }

    func toggle(from button: NSStatusBarButton) {
        if panel != nil { hide() } else { show(from: button) }
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func show(from button: NSStatusBarButton) {
        if let win = button.window {
            let btnRect = win.convertToScreen(button.convert(button.bounds, to: nil))
            anchorTop = btnRect.minY - 8
            anchorMidX = btnRect.midX
        }
        let p = FloatingPanel(size: NSSize(width: PanelMetrics.width, height: 300))
        p.contentView = NSHostingView(rootView: StatusPanelView(
            controller: controller,
            onClose: { [weak self] in self?.hide() },
            onResize: { [weak self] size in self?.resize(to: size) }
        ))
        panel = p
        resize(to: CGSize(width: PanelMetrics.width, height: 300))
        p.orderFrontRegardless()
    }

    private func resize(to size: CGSize) {
        guard let p = panel, size.width > 1, size.height > 1 else { return }
        p.setFrame(NSRect(x: anchorMidX - size.width / 2, y: anchorTop - size.height,
                          width: size.width, height: size.height), display: true)
    }
}

enum PanelMetrics {
    static let width: CGFloat = 296
    static let corner: CGFloat = 24
    static let pad: CGFloat = 16
}

/// Always-dark token set, matched to the reference: near-black ground,
/// elevated tiles, one glowing orange accent, white pill CTA.
enum Ink {
    static let ground = Color(red: 0.055, green: 0.058, blue: 0.07)
    static let tile = Color.white.opacity(0.07)
    static let tilePressed = Color.white.opacity(0.12)
    static let group = Color.white.opacity(0.05)
    static let hairline = Color.white.opacity(0.07)
    static let text = Color.white
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.32)
    static let accent = Color.orange
}

private struct PanelSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct StatusPanelView: View {
    @ObservedObject var controller: LockController
    let onClose: () -> Void
    let onResize: (CGSize) -> Void

    var body: some View {
        Group {
            if controller.isLocked {
                LockedView(controller: controller, onClose: onClose)
            } else {
                UnlockedView(controller: controller, onClose: onClose)
            }
        }
        .frame(width: PanelMetrics.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous)
            .fill(Ink.ground))
        .overlay(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous)
            .strokeBorder(Ink.hairline))
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous))
        .environment(\.colorScheme, .dark)
        .background(GeometryReader { g in
            Color.clear.preference(key: PanelSizeKey.self, value: g.size)
        })
        .onPreferenceChange(PanelSizeKey.self, perform: onResize)
    }
}

// MARK: - Target row

private struct TargetRow: View {
    let icon: NSImage?
    let name: String
    let subtitle: String
    var subtitleLines = 1

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.tile)
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 30, height: 30)
                } else {
                    Phos.appWindow.color(Ink.secondary).frame(width: 22, height: 22)
                }
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.text)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(subtitleLines)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Unlocked

private struct UnlockedView: View {
    @ObservedObject var controller: LockController
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !Permissions.isTrusted {
                permissionBlock
                    .padding(.top, PanelMetrics.pad)
            } else if let front = controller.frontmostLockable() {
                TargetRow(
                    icon: front.icon,
                    name: front.name,
                    subtitle: front.isBrowser ? "Window and active tab get pinned"
                                              : "This window gets pinned"
                )
                .padding(.top, PanelMetrics.pad)

                timerTiles
                    .padding(.top, 14)

                settingsGroup
                    .padding(.top, 12)

                Button {
                    controller.lock()
                    onClose()
                } label: {
                    Text("Lock This Window")
                }
                .buttonStyle(PillCTAStyle())
                .padding(.top, 16)
            } else {
                Text("Bring the window you want to lock to the front, then open this menu again.")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                    .padding(.top, PanelMetrics.pad)
            }

            if let reason = controller.lastUnlockReason {
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(Ink.tertiary)
                    .padding(.top, 10)
            }

            footer
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, PanelMetrics.pad)
    }

    private var timerTiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stay locked for")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.secondary)
            HStack(spacing: 6) {
                tile(label: "Off", caption: "timer", value: 0)
                tile(label: "10", caption: "min", value: 10)
                tile(label: "20", caption: "min", value: 20)
                tile(label: "30", caption: "min", value: 30)
                tile(label: "60", caption: "min", value: 60)
            }
        }
    }

    private func tile(label: String, caption: String, value: Int) -> some View {
        let selected = (controller.minLockChoiceMinutes ?? 0) == value
        return Button {
            controller.minLockChoiceMinutes = value == 0 ? nil : value
        } label: {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Color.black : Ink.text)
                Text(caption)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(selected ? Color.black.opacity(0.6) : Ink.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? Ink.accent : Ink.tile))
            .shadow(color: selected ? Ink.accent.opacity(0.45) : .clear, radius: 9)
        }
        .buttonStyle(.plain)
    }

    private var settingsGroup: some View {
        VStack(spacing: 0) {
            if controller.minLockChoiceMinutes != nil {
                row("Auto-unlock when time's up") {
                    MiniSwitch(isOn: $controller.autoUnlockAtTimerEnd)
                }
                Rectangle().fill(Ink.hairline).frame(height: 1)
                    .padding(.leading, 14)
            }
            row("Block Spotlight while locked") {
                MiniSwitch(isOn: $controller.settings.blockSpotlight)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.group))
    }

    private func row(_ label: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Ink.text)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private var permissionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Phos.warningFill.color(Ink.accent).frame(width: 13, height: 13)
                Text("Accessibility permission needed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.text)
            }
            Text("Lockin blocks shortcuts and clicks through the Accessibility API. Grant it, then reopen this menu.")
                .font(.system(size: 11))
                .foregroundStyle(Ink.secondary)
            Button("Open System Settings…") {
                Permissions.promptForAccessibility()
                Permissions.openAccessibilitySettings()
            }
            .buttonStyle(TileButtonStyle())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.group))
    }

    private var footer: some View {
        HStack {
            Button("Quit Lockin") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Ink.tertiary)
            Spacer()
            Text("Hold Esc 5s to force-unlock")
                .font(.system(size: 10))
                .foregroundStyle(Ink.tertiary)
        }
    }
}

// MARK: - Locked

private struct LockedView: View {
    @ObservedObject var controller: LockController
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let t = controller.lockedTarget {
                    TargetRow(
                        icon: controller.lockedAppIcon,
                        name: t.appName,
                        subtitle: t.isBrowser
                            ? (controller.lockedTabTitle ?? "Pinned to the active tab")
                            : "Pinned to this window",
                        subtitleLines: 2
                    )
                }
            }
            .padding(.top, PanelMetrics.pad)
            .overlay(alignment: .topTrailing) {
                // The glowing accent: locked state announces itself.
                Phos.lockFill.color(Ink.accent)
                    .frame(width: 14, height: 14)
                    .shadow(color: Ink.accent.opacity(0.8), radius: 7)
                    .padding(.top, PanelMetrics.pad + 2)
            }

            unlockArea
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

            if let note = controller.degradedNote {
                HStack(alignment: .top, spacing: 6) {
                    Phos.warning.color(Ink.secondary).frame(width: 11, height: 11)
                        .padding(.top, 1)
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(Ink.secondary)
                }
                .padding(.top, 14)
            }

            if controller.kittyExceptionActive {
                Text("kitty is up — Return snaps you back")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            } else if controller.kittyAvailable {
                Button {
                    controller.beginKittyException()
                    onClose()
                } label: {
                    HStack(spacing: 7) {
                        Phos.terminalWindow.color(Ink.text).frame(width: 13, height: 13)
                        Text("Answer kitty")
                    }
                }
                .buttonStyle(TileButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            }

            Text("Hold Esc 5 s for emergency unlock")
                .font(.system(size: 10))
                .foregroundStyle(Ink.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, PanelMetrics.pad)
    }

    private var unlockArea: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let until = controller.unlockBlockedUntil {
                VStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(remaining(until: until, now: context.date))
                            .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Ink.text)
                        Text(controller.autoUnlockAtTimerEnd ? "until auto-unlock" : "until unlock opens")
                            .font(.system(size: 11))
                            .foregroundStyle(Ink.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(Ink.accent)
                                .frame(width: geo.size.width * remainingFraction(until: until, now: context.date))
                                .shadow(color: Ink.accent.opacity(0.6), radius: 5)
                        }
                    }
                    .frame(height: 4)
                }
            } else {
                VStack(spacing: 8) {
                    HoldToUnlockView(duration: controller.settings.holdSeconds) {
                        controller.unlock()
                        onClose()
                    }
                    Text("Hold to unlock")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                }
            }
        }
    }

    private func remaining(until: Date, now: Date) -> String {
        let s = max(0, Int(until.timeIntervalSince(now).rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func remainingFraction(until: Date, now: Date) -> Double {
        let total = Double(controller.minLockChoiceMinutes ?? 0) * 60
        guard total > 0 else { return 0 }
        return min(1, max(0, until.timeIntervalSince(now) / total))
    }
}

// MARK: - Controls

private struct MiniSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.2)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? Ink.accent : Color.white.opacity(0.14))
                .frame(width: 34, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                        .padding(2.5)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct PillCTAStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.82 : 1)))
            .contentShape(Capsule())
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Ink.text)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(configuration.isPressed ? Ink.tilePressed : Ink.tile))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
