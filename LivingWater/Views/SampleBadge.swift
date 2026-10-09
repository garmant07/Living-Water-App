import SwiftUI

// A small label shown wherever invented placeholder numbers appear,
// so sample data is never mistaken for real impact.
struct SampleBadge: View {
    var body: some View {
        Text("Sample data")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.sampleForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.sampleBackground, in: Capsule())
    }
}
