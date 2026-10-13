import SwiftUI

// Donate Directly, page 2: one partner, with a button that opens the
// partner's own donation page in Safari. The app never takes a payment
// and never sees what anyone gives.
struct DonatePartnerView: View {
    let partner: Partner

    @Environment(\.openURL) private var openURL

    /// Only real web links are opened. Anything else is treated as missing.
    private func webURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", url.host() != nil else { return nil }
        return url
    }

    private var donateURL: URL? { webURL(partner.donateUrl) }
    private var websiteURL: URL? { webURL(partner.website) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                titleBlock
                donateBlock
                aboutSection
                factsCard
                if let feature = partner.featureStory {
                    Card {
                        SectionHeading(feature.title)
                        Text(feature.body)
                            .font(.body)
                            .lineSpacing(4)
                            .foregroundStyle(Theme.foreground)
                    }
                }
                faithSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            PartnerLogo(partner: partner, size: 84)
            Text(partner.name)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)
            Text(partner.tagline)
                .font(.title3)
                .foregroundStyle(Theme.muted)
            EditShortcut(title: "Edit partners", route: .operatorPartners)
        }
    }

    /// The donate button, what will happen when it is tapped, and the plain website link.
    private var donateBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let donateURL {
                Button {
                    // A web link opens in the Safari app, outside this app.
                    openURL(donateURL)
                } label: {
                    Label("Donate on \(partner.name)'s Website", systemImage: "arrow.up.right")
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Donate to \(partner.name), opens Safari")

                Text("You'll be taken to \(partner.name)'s secure website to give.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                Text("The donation link for \(partner.name) isn't available right now.")
                    .font(.body)
                    .foregroundStyle(Theme.foreground)
            }

            if let websiteURL {
                Button {
                    openURL(websiteURL)
                } label: {
                    Text("Visit website")
                        .font(.body.weight(.semibold))
                        .underline()
                        .foregroundStyle(Theme.foreground)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Visit \(partner.name)'s website, opens Safari")
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("About")
            Text(partner.about)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)
        }
    }

    private var factsCard: some View {
        Card {
            SectionHeading("Key facts")
            ForEach(partner.keyFacts, id: \.self) { fact in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Text(fact)
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                }
            }
            if let published = partner.headlineStats.first {
                Divider().overlay(Theme.border)
                Text("Figures as published by \(partner.name), \(Format.month(published.asOf)).")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var faithSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("Their calling")
            Text(partner.faithStatement)
                .font(.body.italic())
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)
        }
    }
}

#Preview {
    NavigationStack {
        DonatePartnerView(partner: DataStore.shared.partners[0])
    }
}
