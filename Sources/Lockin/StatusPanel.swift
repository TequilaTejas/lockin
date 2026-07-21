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
    static let width: CGFloat = 288
    static let corner: CGFloat = 14
    static let pad: CGFloat = 16
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
            .fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.09)))
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous))
        .background(GeometryReader { g in
            Color.clear.preference(key: PanelSizeKey.self, value: g.size)
        })
        .onPreferenceChange(PanelSizeKey.self, perform: onResize)
    }
}

// MARK: - Overline

private struct Overline: View {
    var locked = false

    var body: some View {
        HStack {
            Text("LOCKIN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.tertiary)
            Spacer()
            if locked {
                HStack(spacing: 4) {
                    Phos.lockFill.color(.orange).frame(width: 10, height: 10)
                    Text("LOCKED")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Target row

private struct TargetRow: View {
    let icon: NSImage?
    let name: String
    let subtitle: String
    var subtitleLines = 1

    var body: some View {
        HStack(spacing: 11) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 36, height: 36)
            } else {
                Phos.appWindow.color(.secondary)
                    .frame(width: 26, height: 26)
                    .frame(width: 36, height: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
            Overline()
                .padding(.top, 14)

            if !Permissions.isTrusted {
                permissionBlock
                    .padding(.top, 14)
            } else if let front = controller.frontmostLockable() {
                TargetRow(
                    icon: front.icon,
                    name: front.name,
                    subtitle: front.isBrowser ? "Window and active tab get pinned"
                                              : "This window gets pinned"
                )
                .padding(.top, 14)

                timerSection
                    .padding(.top, 18)

                Button {
                    controller.lock()
                    onClose()
                } label: {
                    Text("Lock This Window")
                }
                .buttonStyle(FlatProminentButtonStyle())
                .padding(.top, 18)
            } else {
                Text("Bring the window you want to lock to the front, then open this menu again.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
            }

            if let reason = controller.lastUnlockReason {
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }

            footer
                .padding(.top, 16)
        }
        .padding(.horizontal, PanelMetrics.pad)
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stay locked for")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ChipPicker(selection: $controller.minLockChoiceMinutes)

            if controller.minLockChoiceMinutes != nil {
                HStack {
                    Text("Auto-unlock when time's up")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    MiniSwitch(isOn: $controller.autoUnlockAtTimerEnd)
                }
                .padding(.top, 2)
            }
        }
    }

    private var permissionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Phos.warningFill.color(.orange).frame(width: 12, height: 12)
                Text("Accessibility permission needed")
                    .font(.system(size: 12, weight: .semibold))
            }
            Text("Lockin blocks shortcuts and clicks through the Accessibility API. Grant it, then reopen this menu.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Open System Settings…") {
                Permissions.promptForAccessibility()
                Permissions.openAccessibilitySettings()
            }
            .buttonStyle(QuietButtonStyle())
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Quit Lockin") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Hold Esc 5s to force-unlock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
        }
    }
}

// MARK: - Locked

private struct LockedView: View {
    @ObservedObject var controller: LockController
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Overline(locked: true)
                .padding(.top, 14)

            if let t = controller.lockedTarget {
                TargetRow(
                    icon: controller.lockedAppIcon,
                    name: t.appName,
                    subtitle: t.isBrowser
                        ? (controller.lockedTabTitle ?? "Pinned to the active tab")
                        : "Pinned to this window",
                    subtitleLines: 2
                )
                .padding(.top, 14)
            }

            unlockArea
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            if let note = controller.degradedNote {
                HStack(alignment: .top, spacing: 6) {
                    Phos.warning.color(.secondary).frame(width: 11, height: 11)
                        .padding(.top, 1)
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 14)
            }

            if controller.kittyExceptionActive {
                Text("kitty is up — Return snaps you back")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            } else if controller.kittyAvailable {
                Button {
                    controller.beginKittyException()
                    onClose()
                } label: {
                    HStack(spacing: 6) {
                        Phos.terminalWindow.color(.primary).frame(width: 12, height: 12)
                        Text("Answer kitty")
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
            }

            Text("Hold Esc 5 s for emergency unlock")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, PanelMetrics.pad)
    }

    private var unlockArea: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let until = controller.unlockBlockedUntil {
                VStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Text(remaining(until: until, now: context.date))
                            .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                            .kerning(0.5)
                        Text(controller.autoUnlockAtTimerEnd ? "until auto-unlock" : "until unlock opens")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule().fill(Color.orange)
                                .frame(width: geo.size.width * remainingFraction(until: until, now: context.date))
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
                        .foregroundStyle(.secondary)
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

private struct ChipPicker: View {
    @Binding var selection: Int?
    private let options: [(String, Int)] = [("Off", 0), ("10m", 10), ("20m", 20), ("30m", 30), ("60m", 60)]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(options, id: \.1) { label, value in
                chip(label, value)
            }
        }
    }

    private func chip(_ label: String, _ value: Int) -> some View {
        let selected = (selection ?? 0) == value
        return Button {
            selection = value == 0 ? nil : value
        } label: {
            Text(label)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color(nsColor: .windowBackgroundColor) : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 25)
                .background(
                    Capsule().fill(selected ? Color.primary : Color.primary.opacity(0.055))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MiniSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.2)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? Color.primary : Color.primary.opacity(0.15))
                .frame(width: 32, height: 19)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .padding(2.5)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct FlatProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.orange.opacity(configuration.isPressed ? 0.8 : 1)))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.055)))
            .contentShape(Capsule())
    }
}
