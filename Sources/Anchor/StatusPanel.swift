import AppKit
import SwiftUI

/// Borderless, non-activating panel floating at status-bar level over every
/// Space and full-screen app. It never steals focus from the locked window, so
/// its buttons work on the first click without activating Anchor.
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
    static let width: CGFloat = 312
    static let corner: CGFloat = 16
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
        // Solid & quiet: opaque adaptive ground, hairline edge — no materials.
        .background(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7)))
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.corner, style: .continuous))
        .background(GeometryReader { g in
            Color.clear.preference(key: PanelSizeKey.self, value: g.size)
        })
        .onPreferenceChange(PanelSizeKey.self, perform: onResize)
    }
}

// MARK: - Unlocked

private struct UnlockedView: View {
    @ObservedObject var controller: LockController
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(
                icon: Phos.lockSimpleOpenBold,
                iconStyle: .subtle,
                title: "Anchor",
                subtitle: Permissions.isTrusted ? "Ready to lock" : "Needs permission"
            )

            VStack(alignment: .leading, spacing: 12) {
                if !Permissions.isTrusted {
                    permissionCard
                } else if let front = controller.frontmostLockable() {
                    targetCard(front)
                    timerSection
                    Button {
                        controller.lock()
                        onClose()
                    } label: {
                        Label {
                            Text("Lock This Window")
                        } icon: {
                            Phos.lockSimpleFill.color(.white).frame(width: 14, height: 14)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Text("Bring the window you want to lock to the front, then open this menu again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(cardShape)
                }

                if let reason = controller.lastUnlockReason {
                    Label {
                        Text(reason)
                    } icon: {
                        Phos.info.color(.secondary).frame(width: 12, height: 12)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)

            Divider().padding(.top, 14)
            HStack {
                Button("Quit Anchor") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Hold Esc 5 s to force-unlock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06)))
    }

    private func targetCard(_ front: (name: String, icon: NSImage?, isBrowser: Bool)) -> some View {
        HStack(spacing: 10) {
            if let icon = front.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 30, height: 30)
            } else {
                Phos.appWindow
                    .color(.secondary)
                    .frame(width: 24, height: 24)
                    .frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(front.name)
                    .font(.system(size: 13, weight: .medium))
                Text(front.isBrowser ? "Window and active tab will be pinned"
                                     : "This window will be pinned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(cardShape)
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No unlocking for")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: minLockBinding) {
                Text("Off").tag(0)
                Text("10 m").tag(10)
                Text("20 m").tag(20)
                Text("30 m").tag(30)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if controller.minLockChoiceMinutes != nil {
                HStack {
                    Text("Auto-unlock when time's up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $controller.autoUnlockAtTimerEnd)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Accessibility permission needed")
            } icon: {
                Phos.warningFill.color(.orange).frame(width: 13, height: 13)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.orange)
            Text("Anchor blocks shortcuts and clicks through the Accessibility API. Grant it, then reopen this menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                Permissions.promptForAccessibility()
                Permissions.openAccessibilitySettings()
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))))
    }

    private var minLockBinding: Binding<Int> {
        Binding(
            get: { controller.minLockChoiceMinutes ?? 0 },
            set: { controller.minLockChoiceMinutes = $0 == 0 ? nil : $0 }
        )
    }
}

// MARK: - Locked

private struct LockedView: View {
    @ObservedObject var controller: LockController
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(
                icon: Phos.lockSimpleFill,
                iconStyle: .solid,
                title: "Locked",
                subtitle: controller.lockedTarget?.appName ?? ""
            )

            VStack(alignment: .leading, spacing: 12) {
                if let t = controller.lockedTarget {
                    HStack(spacing: 10) {
                        if let icon = controller.lockedAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.appName)
                                .font(.system(size: 13, weight: .medium))
                            if t.isBrowser {
                                Text(controller.lockedTabTitle ?? "Pinned to the active tab")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            } else {
                                Text("Pinned to this window")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06))))
                }

                if let note = controller.degradedNote {
                    Label {
                        Text(note)
                    } icon: {
                        Phos.warning.color(.secondary).frame(width: 12, height: 12)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if controller.kittyExceptionActive {
                    Label {
                        Text("kitty is up — Return snaps you back")
                    } icon: {
                        Phos.terminalWindow.color(.secondary).frame(width: 13, height: 13)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if controller.kittyAvailable {
                    Button {
                        controller.beginKittyException()
                        onClose()
                    } label: {
                        Label {
                            Text("Answer kitty")
                        } icon: {
                            Phos.terminalWindow.color(.primary).frame(width: 13, height: 13)
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)
                }

                unlockArea
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)

            Text("Hold Esc 5 s for emergency unlock")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 10)
        }
    }

    private var unlockArea: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let until = controller.unlockBlockedUntil {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: remainingFraction(until: until, now: context.date))
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Phos.hourglassMediumFill
                            .color(.orange)
                            .frame(width: 20, height: 20)
                    }
                    .frame(width: 58, height: 58)
                    Text(remaining(until: until, now: context.date))
                        .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    Text(controller.autoUnlockAtTimerEnd ? "until auto-unlock" : "until unlock opens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 6) {
                    HoldToUnlockView(duration: controller.settings.holdSeconds) {
                        controller.unlock()
                        onClose()
                    }
                    Text("Hold to unlock")
                        .font(.caption)
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

// MARK: - Shared header

private struct PanelHeader: View {
    enum Style { case subtle, solid }

    let icon: PhosIcon
    let iconStyle: Style
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            // Orange belongs to the locked state only; the ready state is neutral.
            ZStack {
                Circle().fill(iconStyle == .solid ? Color.orange : Color.primary.opacity(0.06))
                icon.color(iconStyle == .solid ? Color.white : Color.secondary)
                    .frame(width: 14, height: 14)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }
}
