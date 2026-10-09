import SwiftUI

// One community's full story: who is doing the work, what has been done,
// what is still left to do, and the latest news from the field.
struct CommunityStoryView: View {
    let community: Community

    private let store = DataStore.shared

    private var partner: Partner? { store.partner(id: community.partnerId) }
    private var updates: [StoryUpdate] { store.stories(forCommunity: community.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PhotoView(photo: community.heroPhoto)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                titleBlock
                progressCard
                factsCard
                storySection
                if let scripture = community.scripture {
                    scriptureBlock(scripture)
                }
                if let partner {
                    partnerCard(partner)
                }
                updatesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .navigationTitle(community.country)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(community.name)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)

            Text("\(community.country) · \(community.region)")
                .font(.title3)
                .foregroundStyle(Theme.muted)

            HStack(spacing: 8) {
                chip(community.status.label)
                if community.isSample {
                    SampleBadge()
                }
            }
            .padding(.top, 2)
        }
    }

    /// Accomplished vs. still to do, always shown together.
    private var progressCard: some View {
        card {
            sectionHeading(community.status == .completed ? "What was given" : "How far along")
            ProgressSummary(progress: store.progress(for: community))
        }
    }

    private var factsCard: some View {
        card {
            fact("People served", Format.number(community.peopleServed))
            Divider().overlay(Theme.border)
            fact("Kind of work", community.solutionType.label)
            Divider().overlay(Theme.border)
            fact(community.status == .planned ? "Planned start" : "Started", Format.date(community.startDate))
            if let completed = community.completedDate {
                Divider().overlay(Theme.border)
                fact("Completed", Format.date(completed))
            }
        }
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("The story")
            Text(community.story)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)
        }
    }

    private func scriptureBlock(_ scripture: Scripture) -> some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("“\(scripture.text)”")
                    .font(.title3)
                    .foregroundStyle(Theme.foreground)
                Text(scripture.reference)
                    .font(.body)
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Names the ministry and what it does, so the work has a face.
    private func partnerCard(_ partner: Partner) -> some View {
        card {
            Text("The ministry doing the work")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text(partner.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)
            Text(partner.description)
                .font(.body)
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

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("From the field")

            if updates.isEmpty {
                Text("No updates yet. News from this community will appear here.")
                    .font(.body)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(updates) { update in
                    card {
                        HStack {
                            Text(Format.date(update.date))
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            if update.isSample {
                                SampleBadge()
                            }
                        }
                        Text(update.title)
                            .font(.headline)
                            .foregroundStyle(Theme.foreground)
                        Text(update.body)
                            .font(.body)
                            .foregroundStyle(Theme.foreground)
                    }
                }
            }
        }
    }

    // MARK: Small building blocks

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.title2.weight(.semibold))
            .foregroundStyle(Theme.foreground)
            .accessibilityAddTraits(.isHeader)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(Theme.foreground.opacity(0.6)))
    }
}

extension ProjectStatus {
    /// How the status reads on screen.
    var label: String {
        switch self {
        case .planned: "Planned"
        case .inProgress: "In progress"
        case .completed: "Completed"
        }
    }
}

extension SolutionType {
    /// How the kind of work reads on screen.
    var label: String {
        switch self {
        case .well: "Well"
        case .treatmentSystem: "Water treatment system"
        case .filters: "Water filters"
        case .sanitation: "Sanitation and hygiene"
        case .disasterResponse: "Disaster response"
        }
    }
}

#Preview {
    NavigationStack {
        CommunityStoryView(community: DataStore.shared.communities[3])
    }
}
