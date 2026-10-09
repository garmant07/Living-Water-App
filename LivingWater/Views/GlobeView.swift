import Combine
import MapKit
import SwiftUI

// The front door: a globe you can spin and pinch, with a glowing light for
// every community. Tapping a light shows a small card about that community.
struct GlobeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var position: MapCameraPosition = .camera(GlobeView.startCamera)
    /// Where the globe is looking right now.
    @State private var camera = GlobeView.startCamera
    @State private var isRotating = true
    @State private var lastTouched = Date.distantPast
    @State private var selected: Community?
    @State private var showingList = false
    /// The story pages opened on top of the globe.
    @State private var path: [Community] = []

    private let store = DataStore.shared
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    /// Far enough away to see the whole Earth, centered on Africa.
    private static let startCamera = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 8, longitude: 25),
        distance: 24_000_000
    )
    /// How close the globe moves in when a community is chosen (meters).
    private static let selectedDistance: Double = 7_000_000
    /// Degrees of turn per tick. About one full turn every two minutes.
    private static let degreesPerTick = 0.1
    /// The globe only turns by itself when zoomed out at least this far (meters).
    private static let turningDistance: Double = 15_000_000
    /// Seconds of stillness before the globe starts turning again.
    private static let idleSeconds: TimeInterval = 10

    var body: some View {
        NavigationStack(path: $path) {
            globe
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Community.self) { community in
                    CommunityStoryView(community: community)
                }
        }
    }

    private var globe: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(store.communities) { community in
                Annotation(community.name, coordinate: community.coordinate) {
                    Button {
                        select(community)
                    } label: {
                        GlowPoint(
                            peopleServed: community.peopleServed,
                            isSelected: selected == community
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(community.name), \(Format.number(community.peopleServed)) people served"
                    )
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        // Wash the Earth in soft blue to match the rest of the app.
        .overlay {
            Theme.globeTint
                .blendMode(.color)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            // Only listen while the person is in control, so the slow turn
            // below doesn't argue with itself.
            guard !isRotating else { return }
            camera = context.camera
            lastTouched = Date()
        }
        .onReceive(clock) { _ in turn() }
        .safeAreaInset(edge: .top) { header }
        .safeAreaInset(edge: .bottom) {
            if let selected {
                CommunityPreviewCard(
                    community: selected,
                    partner: store.partner(id: selected.partnerId),
                    onOpen: { path.append(selected) },
                    onClose: { close() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingList) {
            CommunityListView { community in
                select(community)
            }
        }
        .task {
            // With Reduce Motion on the globe never turns, so give it the
            // one small move the lights need in order to appear.
            guard reduceMotion else { return }
            try? await Task.sleep(for: .seconds(1))
            if selected == nil, !position.positionedByUser {
                position = .camera(camera.nudged)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // PLACEHOLDER wordmark until the real logo is supplied.
                Text("Living Water Co.")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("\(store.communities.count) communities. Tap a light.")
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 4)

            Spacer()

            Button {
                showingList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Show all communities as a list")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Runs 30 times a second. Turns the globe a little when nobody is using it.
    private func turn() {
        // Respect people who ask their phone for less motion.
        guard !reduceMotion, selected == nil, !showingList, path.isEmpty else { return }

        if isRotating {
            // The moment a finger moves the globe, hand over control.
            if position.positionedByUser {
                isRotating = false
                lastTouched = Date()
                return
            }
            var longitude = camera.centerCoordinate.longitude + Self.degreesPerTick
            if longitude > 180 { longitude -= 360 }
            camera = MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: camera.centerCoordinate.latitude,
                    longitude: longitude
                ),
                distance: camera.distance
            )
            position = .camera(camera)
        } else if Date().timeIntervalSince(lastTouched) > Self.idleSeconds,
                  camera.distance >= Self.turningDistance {
            // Left alone for a while and still zoomed out: start turning again.
            isRotating = true
        }
    }

    private func select(_ community: Community) {
        isRotating = false
        camera = MapCamera(
            centerCoordinate: community.coordinate,
            distance: Self.selectedDistance
        )
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.2)) {
            selected = community
            position = .camera(camera)
        }
    }

    private func close() {
        lastTouched = Date()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            selected = nil
        }
    }
}

extension Community {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension MapCamera {
    /// The same view moved a hair's width. Apple's map only draws custom
    /// points once the view has moved, so still maps use this to settle.
    var nudged: MapCamera {
        MapCamera(centerCoordinate: centerCoordinate, distance: distance * 1.02)
    }
}

#Preview {
    GlobeView()
}
