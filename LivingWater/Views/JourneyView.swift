import MapKit
import SwiftUI

// The Journey tab: the communities this person's own bottles supported,
// their part in the bigger picture, and the badges they have earned.
struct JourneyView: View {
    let goToScan: () -> Void

    @State private var path = NavigationPath()
    @State private var bottleToRemove: SavedBottle?
    @State private var position: MapCameraPosition = .automatic

    private let store = DataStore.shared
    private let journey = JourneyStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    if journey.bottles.isEmpty {
                        emptyState
                    } else {
                        constellation
                        yourPart
                    }
                    badges
                    if !journey.bottles.isEmpty {
                        bottleList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Community.self) { community in
                CommunityStoryView(community: community)
            }
            .confirmationDialog(
                "Remove this bottle from your journey?",
                isPresented: Binding(
                    get: { bottleToRemove != nil },
                    set: { if !$0 { bottleToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove bottle", role: .destructive) {
                    if let bottleToRemove {
                        journey.remove(bottleToRemove.code)
                    }
                    bottleToRemove = nil
                }
                Button("Keep it", role: .cancel) { bottleToRemove = nil }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your journey")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)
            Text("The places your bottles have reached.")
                .font(.title3)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: Nothing saved yet

    private var emptyState: some View {
        Card {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Your journey starts with one bottle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text("Scan a bottle and save it. The community it supported will appear here as your first light.")
                .font(.body)
                .foregroundStyle(Theme.muted)
            Button("Scan a bottle", action: goToScan)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
    }

    // MARK: Your lights on the globe

    private var constellation: some View {
        let communities = journey.communities

        return VStack(alignment: .leading, spacing: 10) {
            Map(position: $position) {
                // Faint lines join the lights in the order they were saved.
                if communities.count > 1 {
                    MapPolyline(coordinates: communities.map(\.coordinate))
                        .stroke(.white.opacity(0.55), lineWidth: 1.5)
                }
                ForEach(communities) { community in
                    Annotation(community.name, coordinate: community.coordinate) {
                        Button {
                            path.append(community)
                        } label: {
                            GlowPoint(peopleServed: community.peopleServed, isSelected: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(community.name)
                        .accessibilityHint("Opens this community's story")
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .overlay {
                Theme.globeTint
                    .blendMode(.color)
                    .allowsHitTesting(false)
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            // Aim the globe at the lights, again whenever the set of lights changes.
            .task(id: communities.map(\.id)) {
                let camera = startCamera(for: communities)
                position = .camera(camera)
                // Apple's map only draws the lights once the view has moved,
                // so settle it with a tiny move.
                try? await Task.sleep(for: .seconds(1))
                position = .camera(camera.nudged)
            }

            Text("Drag to turn the globe. Tap a light to read its story.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    /// Looks at the middle of this person's communities from far away.
    private func startCamera(for communities: [Community]) -> MapCamera {
        let count = Double(max(communities.count, 1))
        let latitude = communities.reduce(0) { $0 + $1.latitude } / count
        let longitude = communities.reduce(0) { $0 + $1.longitude } / count
        return MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            distance: communities.count > 1 ? 24_000_000 : 9_000_000
        )
    }

    // MARK: Your part in the whole

    private var yourPart: some View {
        let totals = store.totals
        let communities = journey.communities
        let bottleCount = journey.bottles.count

        return Card {
            HStack {
                SectionHeading("Your part")
                Spacer()
                if totals.includesSampleData {
                    SampleBadge()
                }
            }

            Text("Your \(bottleCount) \(bottleCount == 1 ? "bottle is" : "bottles are") part of \(Format.number(store.company.bottlesSold)) bottles that have helped reach \(Format.number(totals.peopleServed)) people.")
                .font(.title3)
                .foregroundStyle(Theme.foreground)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                StatTile(label: bottleCount == 1 ? "Bottle saved" : "Bottles saved", value: Format.number(bottleCount))
                StatTile(label: "Communities", value: Format.number(communities.count))
                StatTile(label: "Ministries", value: Format.number(journey.value(for: .partners)))
                StatTile(label: "Countries", value: Format.number(Set(communities.map(\.country)).count))
            }
            .padding(.top, 4)
        }
    }

    // MARK: Badges

    private var badges: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Badges")

            ForEach(store.milestones(ofType: .personal)) { milestone in
                let current = journey.value(for: milestone.metric)
                let earned = current >= milestone.threshold

                Card {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: earned ? "checkmark.seal.fill" : "seal")
                            .font(.title)
                            .foregroundStyle(earned ? Theme.foreground : Theme.muted.opacity(0.7))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(milestone.title)
                                .font(.headline)
                                .foregroundStyle(Theme.foreground)

                            if earned {
                                Text(milestone.description)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            } else {
                                ProgressView(value: Double(current) / Double(milestone.threshold))
                                    .tint(Theme.brand)
                                    .accessibilityHidden(true)
                                Text("\(current) of \(milestone.threshold). \(milestone.threshold - current) to go.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(milestone.title), \(earned ? "earned" : "\(current) of \(milestone.threshold)")")
                }
            }
        }
    }

    // MARK: Saved bottles

    private var bottleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Your bottles")

            // Newest first.
            ForEach(journey.bottles.reversed(), id: \.code) { saved in
                if let community = store.community(forBottleCode: saved.code) {
                    HStack(alignment: .top, spacing: 0) {
                        NavigationLink(value: community) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(community.name)
                                    .font(.headline)
                                    .foregroundStyle(Theme.foreground)
                                    .multilineTextAlignment(.leading)
                                Text("through \(store.partner(id: community.partnerId)?.name ?? "")")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                                Text("Bottle \(saved.code) · saved \(saved.savedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this community's story")

                        Button {
                            bottleToRemove = saved
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Theme.muted)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Remove bottle \(saved.code)")
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 6)
                    .padding(.vertical, 14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
                }
            }

            Button("Scan another bottle", action: goToScan)
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
        }
    }
}

#Preview {
    JourneyView(goToScan: {})
}
