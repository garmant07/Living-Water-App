import SwiftUI

// The shared "coming soon" look used by pages that aren't built yet:
// a title, a big icon, and a short message.
struct ComingSoonView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(Theme.muted)
                }

                Image(systemName: icon)
                    .font(.system(size: 96))
                    .foregroundStyle(Theme.foreground)
                    .padding(.vertical, 32)
                    .accessibilityHidden(true)

                Text("Coming soon. We're building something good here.")
                    .font(.title3)
                    .foregroundStyle(Theme.foreground)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}
