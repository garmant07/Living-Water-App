import SwiftUI

// The Community Hub: the big picture. What has been done together, what is
// still left to do, who is doing the work, and the latest news from the field.
struct HubView: View {
    @State private var path = NavigationPath()

    private let store = DataStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        header
                        totalsSection
                        milestonesSection.id("milestones")
                        partnersSection.id("partners")
                        storiesSection.id("stories")
                        verse
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .onAppear {
                    #if DEBUG
                    // For testing: "-hubSection stories" jumps to a section,
                    // "-previewPartner water-mission" opens a ministry page.
                    let defaults = UserDefaults.standard
                    if let section = defaults.string(forKey: "hubSection") {
                        scroller.scrollTo(section, anchor: .top)
                    }
                    if path.isEmpty, let id = defaults.string(forKey: "previewPartner"),
                       let partner = store.partner(id: id) {
                        path.append(partner)
                    }
                    #endif
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Community.self) { community in
                CommunityStoryView(community: community)
            }
            .navigationDestination(for: Partner.self) { partner in
                PartnerDetailView(partner: partner)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Community Hub")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)
            Text("What we've done together, and how far there is still to go.")
                .font(.title3)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: Totals

    private var totalsSection: some View {
        let totals = store.totals

        return Card {
            HStack {
                SectionHeading("Together so far")
                Spacer()
                if totals.includesSampleData {
                    SampleBadge()
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                StatTile(label: "People reached", value: Format.number(totals.peopleServed))
                StatTile(label: "Communities funded", value: Format.number(totals.communities))
                StatTile(label: "Countries", value: Format.number(totals.countries))
                StatTile(label: "Ministry partners", value: Format.number(store.partners.count))
                StatTile(label: "Bottles sold", value: Format.number(store.company.bottlesSold))
                StatTile(label: "Dollars given", value: Format.currency(totals.progress.raised))
            }
            .padding(.vertical, 4)

            Divider().overlay(Theme.border)

            Text("Still to do")
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            ProgressSummary(progress: totals.progress)
            Text("\(totals.communitiesCompleted) of \(totals.communities) communities are complete. \(totals.communities - totals.communitiesCompleted) are still waiting or under way.")
                .font(.body)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Milestones we share")

            ForEach(store.milestones(ofType: .global)) { milestone in
                Card {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: milestone.achievedDate == nil ? "circle.dashed" : "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.foreground)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(milestone.title)
                                .font(.headline)
                                .foregroundStyle(Theme.foreground)

                            if let achieved = milestone.achievedDate {
                                Text("Reached \(Format.date(achieved))")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            } else if let current = store.sharedValue(for: milestone.metric) {
                                let remaining = max(milestone.threshold - current, 0)
                                ProgressView(value: min(Double(current) / Double(milestone.threshold), 1))
                                    .tint(Theme.brand)
                                    .accessibilityHidden(true)
                                Text("\(Format.number(current)) of \(Format.number(milestone.threshold)). \(Format.number(remaining)) to go.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }

                            if milestone.isSample {
                                SampleBadge()
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Partners

    private var partnersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("The ministries doing the work")

            ForEach(store.partners) { partner in
                NavigationLink(value: partner) {
                    partnerCard(partner)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this ministry's page")
            }
        }
    }

    private func partnerCard(_ partner: Partner) -> some View {
        let funded = store.totals(forPartner: partner.id)

        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text(partner.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
            Text(partner.description)
                .font(.body)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)

            Divider().overlay(Theme.border)

            // Real figures, published by the partner.
            Text("Published by \(partner.name)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            ForEach(partner.headlineStats.prefix(3), id: \.label) { stat in
                SourcedStatRow(stat: stat)
            }
            if let note = partner.statsNote {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
            }

            Divider().overlay(Theme.border)

            // What Living Water bottles have funded through this partner.
            HStack {
                Text("Through Living Water")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if funded.includesSampleData {
                    SampleBadge()
                }
            }
            Text("\(Format.number(funded.peopleServed)) people in \(funded.communities) communities across \(funded.countries) countries")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)
            ProgressSummary(progress: funded.progress)
        }
    }

    // MARK: Stories

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("From the field")

            ForEach(store.stories) { story in
                if let community = store.community(id: story.communityId) {
                    NavigationLink(value: community) {
                        storyCard(story, community: community)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this community's story")
                }
            }
        }
    }

    private func storyCard(_ story: StoryUpdate, community: Community) -> some View {
        Card {
            if let photo = story.photo {
                PhotoView(photo: photo)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            HStack {
                Text(Format.date(story.date))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if story.isSample {
                    SampleBadge()
                }
            }
            Text(story.title)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)
            Text(story.body)
                .font(.body)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)
            HStack(spacing: 4) {
                Text("\(community.country) · \(store.partner(id: community.partnerId)?.name ?? "")")
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.foreground)
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
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HubView()
}
