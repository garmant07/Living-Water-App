import Combine
import SwiftUI

// The home page. "Living Water" across the top, the Earth beneath it, and the
// ways in to the Community Hub, the Personal Journey and the bottle scanner.
// Tapping the Earth opens the globe page.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camera = GlobeCamera(longitude: 25, latitude: 8)

    private let store = DataStore.shared
    private let journey = JourneyStore.shared
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    /// Degrees of turn per tick. About one full turn every two minutes.
    private static let degreesPerTick = 0.1

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                // PLACEHOLDER wordmark until the real logo is supplied.
                // The size shrinks just enough to fit the screen's width.
                Text("Living Water")
                    .font(.system(size: 120, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .accessibilityAddTraits(.isHeader)

                earth
                    .frame(height: geometry.size.height * 0.46)

                HStack(alignment: .top, spacing: 12) {
                    hubDoor
                    journeyDoor
                }
                .padding(.horizontal, 16)

                Button {
                    router.open(.scan)
                } label: {
                    Label("Scan a bottle", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(clock) { _ in
            // The Earth turns slowly unless the phone asks for less motion,
            // and only while the home page is the one showing.
            guard !reduceMotion, router.path.isEmpty else { return }
            camera.longitude = wrapDegrees(camera.longitude + Self.degreesPerTick)
        }
    }

    /// The Earth is one big button here. Spinning and tapping dots happen on the globe page.
    private var earth: some View {
        FlatGlobe(
            communities: store.communities,
            interactive: false,
            camera: .constant(camera)
        )
        .overlay {
            Button {
                router.open(.globe)
            } label: {
                Color.clear.contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("The Earth, showing \(store.communities.count) communities")
            .accessibilityHint("Opens the globe")
        }
    }

    // MARK: The cards below the Earth

    private var hubDoor: some View {
        let totals = store.totals

        return doorCard(
            title: "Community Hub",
            headline: "\(Format.number(totals.peopleServed)) people reached",
            detail: "\(Format.currency(totals.progress.remaining)) still to go",
            showsSample: totals.includesSampleData,
            action: { router.open(.hub) }
        ) {
            Image(systemName: "drop")
                .font(.title)
                .foregroundStyle(Theme.foreground)
                .frame(height: 44)
        }
    }

    private var journeyDoor: some View {
        let progress = store.levelProgress(bottles: journey.bottles.count)

        return doorCard(
            title: "Personal Journey",
            headline: progress.current.map { "Level \($0.level) · \($0.name)" } ?? "Level 0",
            detail: progress.bottles == 0
                ? "Scan a bottle to fill your glass"
                : "\(Format.number(progress.bottles)) \(progress.bottles == 1 ? "bottle" : "bottles") · \(Format.volume(progress.liters))",
            showsSample: false,
            action: { router.open(.journey) }
        ) {
            // The biggest thing filled so far, or an empty glass before the first bottle.
            VesselView(kind: progress.current?.vessel ?? .glass, fill: progress.current == nil ? 0 : 1, lineWidth: 2.5)
                .frame(width: 44, height: 44)
        }
    }

    /// A card: the title on top, then its picture, then two lines.
    private func doorCard<Picture: View>(
        title: String,
        headline: String,
        detail: String,
        showsSample: Bool,
        action: @escaping () -> Void,
        @ViewBuilder picture: () -> Picture
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .accessibilityHidden(true)
                }
                picture()
                    .accessibilityHidden(true)
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
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
            .background(Theme.widget, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
}
