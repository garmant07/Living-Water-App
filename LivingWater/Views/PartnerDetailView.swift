import SwiftUI

// One ministry's page: who they are, what they do, their published figures
// with sources, and the communities Living Water has funded through them.
struct PartnerDetailView: View {
    let partner: Partner

    private let store = DataStore.shared

    private var communities: [Community] { store.communities(forPartner: partner.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                titleBlock
                if let feature = partner.featureStory {
                    featureCard(feature)
                }
                workCard
                publishedCard
                fundedSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .navigationTitle(partner.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(partner.name)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)

            Text(foundedLine)
                .font(.title3)
                .foregroundStyle(Theme.muted)

            Text(partner.description)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)

            Text(partner.faithStatement)
                .font(.body.italic())
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)

            if let url = URL(string: partner.website) {
                Link(destination: url) {
                    Label("Visit \(partner.name)", systemImage: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .foregroundStyle(Theme.brand)
            }
        }
    }

    private var foundedLine: String {
        if let headquarters = partner.headquarters {
            "Founded \(String(partner.founded)) · \(headquarters)"
        } else {
            "Founded \(String(partner.founded))"
        }
    }

    private func featureCard(_ feature: FeatureStory) -> some View {
        Card {
            SectionHeading(feature.title)
            Text(feature.body)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)
        }
    }

    private var workCard: some View {
        Card {
            SectionHeading("What they do")
            ForEach(partner.work, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Text(item)
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                }
            }
            Divider().overlay(Theme.border)
            Text("Where: \(partner.countries.joined(separator: ", "))")
                .font(.body)
                .foregroundStyle(Theme.muted)
        }
    }

    /// Real figures. Each one comes from the partner and says when it was published.
    private var publishedCard: some View {
        Card {
            SectionHeading("Published figures")

            ForEach(partner.headlineStats, id: \.label) { stat in
                SourcedStatRow(stat: stat)
            }

            if let note = partner.statsNote {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            if let first = partner.headlineStats.first, let url = URL(string: first.sourceUrl) {
                Divider().overlay(Theme.border)
                Link(destination: url) {
                    Label("Source: \(url.host() ?? first.sourceUrl), as of \(Format.month(first.asOf))", systemImage: "arrow.up.right")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 44)
                }
                .foregroundStyle(Theme.brand)
            }
        }
    }

    private var fundedSection: some View {
        let funded = store.totals(forPartner: partner.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading("Through Living Water")
                Spacer()
                if funded.includesSampleData {
                    SampleBadge()
                }
            }

            Card {
                Text("\(Format.number(funded.peopleServed)) people in \(funded.communities) communities across \(funded.countries) countries")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                ProgressSummary(progress: funded.progress)
            }

            ForEach(communities) { community in
                NavigationLink(value: community) {
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            Text(community.name)
                                .font(.headline)
                                .foregroundStyle(Theme.foreground)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                                .accessibilityHidden(true)
                        }
                        Text("\(community.status.label) · \(Format.number(community.peopleServed)) people served")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                        ProgressSummary(progress: store.progress(for: community))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this community's story")
            }
        }
    }
}

#Preview {
    NavigationStack {
        PartnerDetailView(partner: DataStore.shared.partners[0])
    }
}
