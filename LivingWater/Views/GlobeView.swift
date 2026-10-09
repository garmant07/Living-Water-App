import Combine
import SwiftUI

// The front page. The globe sits at the top and takes about two thirds of the
// screen; below it are the ways in to the Community Hub and the Journey.
// Tapping a dot swaps that lower part for a card about the community.
struct GlobeView: View {
    let goToHub: () -> Void
    let goToJourney: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camera = GlobeView.startCamera
    /// Where the globe is gliding to after a dot or list row is chosen.
    @State private var flyTarget: GlobeCamera?
    @State private var isRotating = true
    @State private var lastTouched = Date.distantPast
    @State private var selected: Community?
    @State private var showingList = false
    /// Global shows the globe; Near you shows the work closest to this person.
    /// For testing: launch with "-frontDoor nearYou" to open on Near you.
    @State private var mode = FrontDoorMode(rawValue: UserDefaults.standard.string(forKey: "frontDoor") ?? "") ?? .global
    /// The story pages opened on top of the front page.
    @State private var path: [Community] = []

    private let store = DataStore.shared
    private let journey = JourneyStore.shared
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    /// The whole Earth, centered on Africa.
    private static let startCamera = GlobeCamera(longitude: 25, latitude: 8)
    /// How close the globe moves in when a community is chosen.
    private static let selectedZoom = 1.8
    /// Degrees of turn per tick. About one full turn every two minutes.
    private static let degreesPerTick = 0.1
    /// Seconds of stillness before the globe starts turning again.
    private static let idleSeconds: TimeInterval = 10
    /// The share of the screen given to the title and globe together.
    private static let globeShare = 0.66

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // The globe stays alive underneath so it is ready to come back.
                frontPage
                    .accessibilityHidden(mode == .nearYou)
                if mode == .nearYou {
                    NearYouView(mode: $mode)
                        .transition(.opacity)
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Community.self) { community in
                CommunityStoryView(community: community)
            }
        }
    }

    private var frontPage: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    header
                    FlatGlobe(
                        communities: store.communities,
                        selectedID: selected?.id,
                        camera: $camera,
                        onTouch: {
                            isRotating = false
                            flyTarget = nil
                            lastTouched = Date()
                        },
                        onSelect: select
                    )
                    // When zoomed in, the globe fades out softly at the top
                    // and bottom instead of ending in a hard line.
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(camera.zoom > 1.02 ? 0 : 1), location: 0),
                                .init(color: .black, location: 0.07),
                                .init(color: .black, location: 0.93),
                                .init(color: .black.opacity(camera.zoom > 1.02 ? 0 : 1), location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: geometry.size.height * Self.globeShare)

                lowerPart
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .onReceive(clock) { _ in tick() }
        .sheet(isPresented: $showingList) {
            CommunityListView { community in
                select(community)
            }
        }
        .onAppear {
            #if DEBUG
            // For testing: launch with "-previewCommunity wm-malawi-1" to open on a card,
            // or "-previewStory wm-malawi-1" to open on a story page.
            let defaults = UserDefaults.standard
            if let id = defaults.string(forKey: "previewCommunity"),
               let community = store.community(id: id) {
                select(community)
            }
            if path.isEmpty, let id = defaults.string(forKey: "previewStory"),
               let community = store.community(id: id) {
                select(community)
                path.append(community)
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    // PLACEHOLDER wordmark until the real logo is supplied.
                    Text("Living Water Co.")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("\(store.communities.count) communities. Tap a dot.")
                        .font(.subheadline)
                }
                .foregroundStyle(Theme.foreground)

                Spacer()

                Button {
                    showingList = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .frame(width: 44, height: 44)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.border))
                }
                .accessibilityLabel("Show all communities as a list")
            }

            FrontDoorPicker(mode: $mode)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Below the globe

    @ViewBuilder
    private var lowerPart: some View {
        if let selected {
            CommunityPreviewCard(
                community: selected,
                partner: store.partner(id: selected.partnerId),
                onOpen: { path.append(selected) },
                onClose: { close() }
            )
            .transition(.opacity)
        } else {
            HStack(alignment: .top, spacing: 12) {
                hubDoor
                journeyDoor
            }
            .transition(.opacity)
        }
    }

    private var hubDoor: some View {
        let totals = store.totals

        return doorCard(
            icon: "drop",
            title: "Community Hub",
            headline: "\(Format.number(totals.peopleServed)) people reached",
            detail: "\(Format.currency(totals.progress.remaining)) still to go",
            showsSample: totals.includesSampleData,
            action: goToHub
        )
    }

    private var journeyDoor: some View {
        let count = journey.bottles.count

        return doorCard(
            icon: "sparkles",
            title: "Your journey",
            headline: count == 0 ? "No bottles yet" : "\(count) \(count == 1 ? "bottle" : "bottles") saved",
            detail: count == 0 ? "Scan one to begin" : "\(journey.communities.count) \(journey.communities.count == 1 ? "community" : "communities") reached",
            showsSample: false,
            action: goToJourney
        )
    }

    private func doorCard(
        icon: String,
        title: String,
        headline: String,
        detail: String,
        showsSample: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                if showsSample {
                    SampleBadge()
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
    }

    // MARK: Turning and gliding

    /// Runs 30 times a second.
    private func tick() {
        // Glide toward a chosen community, quickly at first and then settling.
        if let target = flyTarget {
            let longitudeGap = wrapDegrees(target.longitude - camera.longitude)
            let latitudeGap = target.latitude - camera.latitude
            let zoomGap = target.zoom - camera.zoom
            if abs(longitudeGap) < 0.05, abs(latitudeGap) < 0.05, abs(zoomGap) < 0.005 {
                camera = target
                flyTarget = nil
            } else {
                camera.longitude = wrapDegrees(camera.longitude + longitudeGap * 0.16)
                camera.latitude += latitudeGap * 0.16
                camera.zoom += zoomGap * 0.16
            }
            return
        }

        // Respect people who ask their phone for less motion.
        guard !reduceMotion, mode == .global, selected == nil, !showingList, path.isEmpty else { return }

        if isRotating {
            camera.longitude = wrapDegrees(camera.longitude + Self.degreesPerTick)
        } else if Date().timeIntervalSince(lastTouched) > Self.idleSeconds {
            // Left alone for a while: start turning again.
            isRotating = true
        }
    }

    private func select(_ community: Community) {
        isRotating = false
        let target = GlobeCamera(
            longitude: community.longitude,
            latitude: community.latitude,
            zoom: max(camera.zoom, Self.selectedZoom)
        )
        if reduceMotion {
            camera = target
            selected = community
        } else {
            flyTarget = target
            withAnimation(.easeInOut(duration: 0.3)) {
                selected = community
            }
        }
    }

    private func close() {
        lastTouched = Date()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            selected = nil
        }
    }
}

#Preview {
    GlobeView(goToHub: {}, goToJourney: {})
}
