import CoreLocation
import SwiftUI
import UIKit

/// The two ways to look at the globe page.
enum FrontDoorMode: String {
    case global
    case nearYou
}

// The Global / Near you switch shown at the top of the globe page.
struct FrontDoorPicker: View {
    @Binding var mode: FrontDoorMode

    var body: some View {
        Picker("View", selection: $mode.animation(.easeInOut(duration: 0.25))) {
            Text("Global").tag(FrontDoorMode.global)
            Text("Near you").tag(FrontDoorMode.nearYou)
        }
        .pickerStyle(.segmented)
    }
}

// The work and stories closest to this person. Sharing a location is never
// required: they can pick a part of the world instead, or go back to Global.
struct NearYouView: View {
    @Binding var mode: FrontDoorMode

    /// Remembers the choice between launches. The location itself is never saved.
    @AppStorage("nearYou.useLocation") private var useLocation = false
    @AppStorage("nearYou.region") private var regionName = ""
    @State private var location = LocationProvider()

    private let store = DataStore.shared
    private static let howMany = 5

    private var region: WorldRegion? {
        WorldRegion.all.first { $0.name == regionName }
    }

    /// The point everything is measured from, once there is one.
    private var origin: CLLocationCoordinate2D? {
        if useLocation {
            if case .found(let coordinate) = location.status { return coordinate }
            return nil
        }
        return region?.coordinate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let origin {
                    placeRow
                    results(from: origin)
                } else if useLocation {
                    locationProgress
                } else {
                    chooser
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .onAppear {
            if useLocation, case .idle = location.status {
                location.request()
            }
        }
    }

    // MARK: Before a place is chosen

    private var chooser: some View {
        Card {
            Image(systemName: "location.circle")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("See the work closest to you")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text("Share your location or pick a part of the world. Your location is only used on this phone to sort this list. It is never saved or sent anywhere.")
                .font(.body)
                .foregroundStyle(Theme.muted)

            Button("Use my location", action: startUsingLocation)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
            regionMenu {
                Text("Choose a region instead")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.foreground.opacity(0.7), lineWidth: 1.5))
                    .contentShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    /// Shown while waiting for the phone, or when the phone said no.
    @ViewBuilder
    private var locationProgress: some View {
        switch location.status {
        case .idle, .asking, .found:
            Card {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Theme.foreground)
                    Text("Finding where you are…")
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                }
            }
        case .denied:
            locationProblem(
                title: "Location is switched off",
                message: "You can turn it on for Living Water in Settings, or pick a part of the world instead.",
                showSettings: true
            )
        case .failed:
            locationProblem(
                title: "We couldn't find where you are",
                message: "You can try again, or pick a part of the world instead.",
                showSettings: false
            )
        }
    }

    private func locationProblem(title: String, message: String, showSettings: Bool) -> some View {
        Card {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.muted)

            if showSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(url) }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Try again") { location.request() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            regionMenu {
                Text("Choose a region instead")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.foreground.opacity(0.7), lineWidth: 1.5))
                    .contentShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: Choosing and changing the place

    private func regionMenu<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Menu {
            Button("Use my location", systemImage: "location", action: startUsingLocation)
            Section("Or pick a part of the world") {
                ForEach(WorldRegion.all) { region in
                    Button(region.name) {
                        useLocation = false
                        regionName = region.name
                    }
                }
            }
            if useLocation || region != nil {
                Section {
                    Button("Forget my choice", systemImage: "xmark", role: .destructive) {
                        useLocation = false
                        regionName = ""
                    }
                }
            }
        } label: {
            label()
        }
    }

    private func startUsingLocation() {
        regionName = ""
        useLocation = true
        location.request()
    }

    private var placeRow: some View {
        HStack {
            Label(useLocation ? "Closest to your location" : "Closest to \(regionName)", systemImage: useLocation ? "location.fill" : "mappin.and.ellipse")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Spacer()
            regionMenu {
                Text("Change")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    // MARK: The closest work and stories

    private func results(from origin: CLLocationCoordinate2D) -> some View {
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let nearest = store.communities
            .map { (community: $0, meters: here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))) }
            .sorted { $0.meters < $1.meters }
        let closest = Array(nearest.prefix(Self.howMany))
        let closestIds = closest.map(\.community.id)
        // Stories from those same communities, nearest community first.
        let stories = store.stories
            .filter { closestIds.contains($0.communityId) }
            .sorted { (closestIds.firstIndex(of: $0.communityId) ?? 0) < (closestIds.firstIndex(of: $1.communityId) ?? 0) }

        return VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading("Closest work")

                ForEach(closest, id: \.community.id) { entry in
                    NavigationLink(value: entry.community) {
                        communityCard(entry.community, meters: entry.meters)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this community's story")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeading("Stories from nearby")

                if stories.isEmpty {
                    Text("No updates yet from the communities closest to you.")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(stories) { story in
                        if let community = store.community(id: story.communityId) {
                            NavigationLink(value: community) {
                                StoryCard(story: story, community: community)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens this community's story")
                        }
                    }
                }
            }

            Button("See everywhere on the globe") {
                withAnimation(.easeInOut(duration: 0.25)) { mode = .global }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func communityCard(_ community: Community, meters: CLLocationDistance) -> some View {
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
            Text("\(store.partner(id: community.partnerId)?.name ?? "") · \(Format.number(community.peopleServed)) people served")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.leading)
            // A real distance only makes sense from a real location.
            if useLocation {
                Text("About \(Format.distance(meters)) away")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                Text(community.status.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(Theme.foreground.opacity(0.6)))
                if community.isSample {
                    SampleBadge()
                }
            }
            ProgressSummary(progress: store.progress(for: community))
        }
    }
}
