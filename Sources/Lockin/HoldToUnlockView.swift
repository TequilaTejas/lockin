import SwiftUI

/// Press-and-hold unlock. A DragGesture with zero minimum distance tracks the
/// press; a 60 Hz tick fills the ring. Releasing early resets to zero — you have
/// to mean it.
struct HoldToUnlockView: View {
    let duration: Double
    let onComplete: () -> Void

    @State private var pressing = false
    @State private var progress: Double = 0

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(pressing ? 0.12 : 0.06))
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            (pressing ? Phos.lockOpenFill : Phos.lockFill)
                .color(.orange)
                .frame(width: 24, height: 24)
        }
        .frame(width: 58, height: 58)
        .scaleEffect(pressing ? 0.94 : 1)
        .animation(.spring(duration: 0.25), value: pressing)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in pressing = false; progress = 0 }
        )
        .onReceive(tick) { _ in
            guard pressing else { return }
            progress = min(1, progress + (1.0 / 60.0) / max(duration, 0.1))
            if progress >= 1 {
                pressing = false
                progress = 0
                onComplete()
            }
        }
        .animation(.linear(duration: 1.0 / 60.0), value: progress)
    }
}
