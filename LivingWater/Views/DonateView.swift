import SwiftUI

// Donate Directly, page 1: the list of ministry partners.
// Tapping one opens its page, where the donate button leads to Safari.
struct DonateView: View {
    @Environment(Router.self) private var router

    private let store = DataStore.shared
    private static var didPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Donate Directly")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .accessibilityAddTraits(.isHeader)
                    Text("Every one of our partners is putting clean water in the hands of people who need it. Give directly to the ministry that moves you.")
                        .font(.title3)
                        .foregroundStyle(Theme.muted)
                }

                VStack(spacing: 12) {
                    ForEach(store.partners) { partner in
                        NavigationLink(value: DonateRoute(partner: partner)) {
                            row(partner)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(partner.name). \(partner.tagline)")
                        .accessibilityHint("Opens \(partner.name)'s page")
                    }
                }

                Text("Living Water never takes or handles your gift. You give on the partner's own website.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            #if DEBUG
            // For testing: launch with "-previewDonate water-mission" to open a partner's page.
            if !Self.didPreview, let id = UserDefaults.standard.string(forKey: "previewDonate"),
               let partner = store.partner(id: id) {
                Self.didPreview = true
                router.path.append(DonateRoute(partner: partner))
            }
            #endif
        }
    }

    private func row(_ partner: Partner) -> some View {
        Card {
            HStack(alignment: .center, spacing: 14) {
                PartnerLogo(partner: partner, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(partner.name)
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                    Text(partner.tagline)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
        }
    }
}

// A partner's logo. Until a real logo is added to Assets, it shows the
// partner's initials in a circle.
struct PartnerLogo: View {
    let partner: Partner
    let size: CGFloat

    private var initials: String {
        partner.name
            .split(separator: " ")
            .filter { $0.first?.isUppercase == true }
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

    var body: some View {
        Group {
            if let logo = partner.logo, UIImage(named: logo) != nil {
                Image(logo)
                    .resizable()
                    .scaledToFit()
            } else {
                // PLACEHOLDER until the partner supplies a logo.
                Circle()
                    .fill(Theme.deep)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.34, weight: .bold))
                            .foregroundStyle(Theme.foreground)
                    )
                    .overlay(Circle().stroke(Theme.border))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        DonateView()
    }
    .environment(Router())
}
