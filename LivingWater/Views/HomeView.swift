import SwiftUI

// The home screen: the brand, the totals so far, the three ministries,
// and a verse. Every number comes from DataStore.
struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbIsLarge = false

    private let store = DataStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                header
                totalsCard
                partnersSection
                verse
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(spacing: 24) {
            // Stand-in for the interactive globe, which arrives in step 2.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.glow, Theme.accent, Theme.brand, Theme.brandStrong],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 160, height: 160)
                .shadow(color: Theme.glow.opacity(0.55), radius: 30)
                .scaleEffect(orbIsLarge ? 1.04 : 1)
                .accessibilityHidden(true)
                .onAppear {
                    // Respect people who ask their phone for less motion.
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        orbIsLarge = true
                    }
                }

            VStack(spacing: 12) {
                // PLACEHOLDER wordmark until the real logo is supplied.
                Text("Living Water Co.")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Theme.brandStrong)
                    .accessibilityAddTraits(.isHeader)

                Text("Every bottle helps bring clean water to a community in need. See where it's reaching, and how far there is still to go.")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var totalsCard: some View {
        let totals = store.totals

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Together so far")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if totals.includesSampleData {
                    SampleBadge()
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                alignment: .leading,
                spacing: 16
            ) {
                stat("People reached", Format.number(totals.peopleServed))
                stat("Communities", Format.number(totals.communities))
                stat("Countries", Format.number(totals.countries))
                stat("Bottles sold", Format.number(store.company.bottlesSold))
            }

            ProgressSummary(progress: totals.progress)
        }
        .foregroundStyle(Theme.foreground)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.brandStrong)
            Text(label)
                .font(.body)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var partnersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The ministries doing the work")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)

            ForEach(store.partners) { partner in
                VStack(alignment: .leading, spacing: 4) {
                    Text(partner.name)
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                    Text("\(partner.countries.count) countries · since \(String(partner.founded))")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var verse: some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("“Whoever drinks the water I give them will never thirst.”")
                    .font(.title3)
                    .foregroundStyle(Theme.foreground)
                Text("John 4:14")
                    .font(.body)
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView()
}
