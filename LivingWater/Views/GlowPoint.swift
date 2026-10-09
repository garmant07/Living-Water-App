import SwiftUI

// One glowing light on the globe. Bigger lights mean more people served.
struct GlowPoint: View {
    let peopleServed: Int
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    /// 10 points for the smallest projects up to 20 for the largest.
    private var coreSize: CGFloat {
        let scaled = Double(peopleServed).squareRoot() / 65 * 10
        return CGFloat(min(max(10 + scaled, 10), 20))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.glow.opacity(0.35))
                .frame(width: coreSize * 2.4, height: coreSize * 2.4)
                .blur(radius: 4)
                .scaleEffect(isPulsing ? 1.25 : 1)

            Circle()
                .fill(.white)
                .frame(width: coreSize, height: coreSize)
                .shadow(color: Theme.glow, radius: 6)

            if isSelected {
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: coreSize + 14, height: coreSize + 14)
            }
        }
        // 44 points is the smallest comfortable target for a thumb.
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
