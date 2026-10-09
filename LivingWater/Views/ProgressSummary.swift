import SwiftUI

// A progress bar with the honest sentence under it:
// what has been raised, what the goal is, and what is still to go.
struct ProgressSummary: View {
    let progress: Progress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress.fraction)
                .tint(Theme.brand)
                .background(Theme.progressTrack, in: Capsule())
                .scaleEffect(x: 1, y: 2.5, anchor: .center)
                .accessibilityHidden(true)

            Group {
                if progress.isComplete {
                    Text("\(Text(Format.currency(progress.raised)).bold()) raised. \(Text("Goal reached.").bold())")
                } else {
                    Text("\(Text(Format.currency(progress.raised)).bold()) raised of \(Format.currency(progress.goal)). \(Text("\(Format.currency(progress.remaining)) still to go.").bold())")
                }
            }
            .font(.body)
            .foregroundStyle(Theme.foreground)
        }
        .accessibilityElement(children: .combine)
    }
}
