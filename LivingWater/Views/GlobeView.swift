import Combine
import SwiftUI

// The globe page, opened by tapping the Earth on the home page. Spin it,
// pinch it, tap a dot to meet a community. The Global / Near you switch at
// the top swaps the globe for the work closest to this person.
struct GlobeView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    private let store = DataStore.shared
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    private static var didPreview = false
    /// The last invitation shown, so the next one is different.
    private static var lastMessage: String?

    /// The invitation showing above the globe.
    @State private var message = ""

    /// The whole Earth, centered on Africa.
    private static let startCamera = GlobeCamera(longitude: 25, latitude: 8)
    /// How close the globe moves in when a community is chosen.
    private static let selectedZoom = 1.8
    /// Degrees of turn per tick. About one full turn every two minutes.
    private static let degreesPerTick = 0.1
    /// Seconds of stillness before the globe starts turning again.
    private static let idleSeconds: TimeInterval = 10

    var body: some View {
        ZStack {
            // The globe stays alive underneath so it is ready to come back.
            globePage
                .accessibilityHidden(mode == .nearYou)
            if mode == .nearYou {
                NearYouView(mode: $mode)
                    .transition(.opacity)
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                FrontDoorPicker(mode: $mode)
                    .frame(width: 210)
            }
            if mode == .global {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingList = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .accessibilityLabel("Show all communities as a list")
                }
            }
        }
        .onReceive(clock) { _ in tick() }
        .sheet(isPresented: $showingList) {
            CommunityListView { community in
                select(community)
            }
        }
        .onAppear {
            // A different invitation each time the page is opened.
            let others = store.globeMessages.filter { $0 != Self.lastMessage }
            message = others.randomElement() ?? store.globeMessages.first ?? ""
            Self.lastMessage = message

            #if DEBUG
            // For testing: launch with "-previewCommunity wm-malawi-1" to open on a card,
            // or "-previewStory wm-malawi-1" to open on a story page.
            guard !Self.didPreview else { return }
            Self.didPreview = true
            let defaults = UserDefaults.standard
            if let id = defaults.string(forKey: "previewCommunity"),
               let community = store.community(id: id) {
                select(community)
            }
            if let id = defaults.string(forKey: "previewStory"),
               let community = store.community(id: id) {
                select(community)
                router.path.append(community)
            }
            #endif
        }
    }

    /// With large text the words need more room than one screen has, so the
    /// page scrolls and the globe keeps a fixed height.
    @ViewBuilder
    private var globePage: some View {
        if dynamicTypeSize >= .xxLarge {
            ScrollView {
                globeContent(globeHeight: 300)
            }
        } else {
            globeContent(globeHeight: nil)
        }
    }

    private func globeContent(globeHeight: CGFloat?) -> some View {
        VStack(spacing: 0) {
            Text(message)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                // Room for two lines, so the globe doesn't shift when the words change.
                .frame(maxWidth: .infinity)
                .frame(minHeight: 64)
                .accessibilityAddTraits(.isHeader)

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
            .frame(height: globeHeight)
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

            // The words below take the room they need, even with large text;
            // the globe uses whatever is left.
            lowerPart
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 190, alignment: .top)
        }
    }

    // MARK: Below the globe

    @ViewBuilder
    private var lowerPart: some View {
        if let selected {
            CommunityPreviewCard(
                community: selected,
                partner: store.partner(id: selected.partnerId),
                onOpen: { router.path.append(selected) },
                onClose: { close() }
            )
            .transition(.opacity)
        } else {
            VStack(spacing: 6) {
                Text("\(store.communities.count) communities")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Text("Drag to spin, pinch to zoom, and tap a dot to meet a community.")
                    .font(.body)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            .transition(.opacity)
        }
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
        guard !reduceMotion, mode == .global, selected == nil, !showingList else { return }

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
    NavigationStack {
        GlobeView()
    }
    .environment(Router())
}
