import SwiftUI

// What a bottle did: the community and ministry that purchase supported.
// An unknown code gets a friendly page pointing to the Hub instead.
struct BottleView: View {
    let code: String

    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router

    private let store = DataStore.shared
    private let journey = JourneyStore.shared

    var body: some View {
        ScrollView {
            Group {
                if let bottle = store.bottle(code: code),
                   let community = store.community(id: bottle.communityId) {
                    found(bottle: bottle, community: community)
                } else {
                    unknown
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .navigationTitle("Your bottle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    // MARK: A bottle we know

    private func found(bottle: BottleCode, community: Community) -> some View {
        let partner = store.partner(id: community.partnerId)

        return VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This bottle helped bring clean water to")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
                Text(community.name)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .accessibilityAddTraits(.isHeader)
                if let partner {
                    Text("through \(partner.name)")
                        .font(.title3)
                        .foregroundStyle(Theme.foreground)
                }
                if community.isSample || bottle.isSample {
                    SampleBadge()
                        .padding(.top, 2)
                }
            }

            PhotoView(photo: community.heroPhoto)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            saveButton(code: bottle.code)

            Card {
                SectionHeading(community.status == .completed ? "What was given" : "How far along")
                ProgressSummary(progress: store.progress(for: community))
                Divider().overlay(Theme.border)
                Text("\(Format.number(community.peopleServed)) people served · \(community.solutionType.label)")
                    .font(.body)
                    .foregroundStyle(Theme.foreground)
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionHeading("Where it is")
                MiniMap(community: community)
                Text("\(community.country) · \(community.region)")
                    .font(.body)
                    .foregroundStyle(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionHeading("The story")
                Text(community.story)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(Theme.foreground)
                NavigationLink(value: community) {
                    Text("Read the full story")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
            }

            if let partner {
                Card {
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
                }
            }

            Text("Bottle \(bottle.code) · Batch \(bottle.batch) · Produced \(Format.date(bottle.dateProduced))")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private func saveButton(code: String) -> some View {
        if journey.isSaved(code) {
            Label("Saved to What you've done", systemImage: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
        } else {
            Button {
                journey.save(code)
            } label: {
                Label("Save this bottle", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: A code we don't know

    private var unknown: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "drop")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            Text("We couldn't find that bottle")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)

            Text("The code \"\(code)\" didn't match one of ours. It may have been mistyped, or the bottle may be newer than this version of the app.")
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)

            Text("Every bottle still helps. You can still see everything we're doing together.")
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Theme.muted)

            Button("See what we've done") {
                router.goHome()
                router.open(.hub)
            }
                .buttonStyle(PrimaryButtonStyle())
            Button("Try another code") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.top, 24)
    }
}

// A small still globe showing where one community is.
private struct MiniMap: View {
    let community: Community

    var body: some View {
        FlatGlobe(
            communities: [community],
            selectedID: community.id,
            interactive: false,
            camera: .constant(GlobeCamera(longitude: community.longitude, latitude: community.latitude, zoom: 1.6))
        )
        .frame(height: 200)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
        .accessibilityElement()
        .accessibilityLabel("Globe showing \(community.name) in \(community.country)")
    }
}

#Preview {
    NavigationStack {
        BottleView(code: "LW-MW-0001")
            .environment(Router())
    }
}
