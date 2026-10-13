import Combine
import SwiftUI

// The home page. "Living Water" across the top, the Earth beneath it, and the
// Donate Directly across the page, four more cards in two rows, and the
// scan button fixed at the bottom.
// Tapping the Earth opens the globe page.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var camera = GlobeCamera(longitude: 25, latitude: 8)
    /// The verse, slogan or mission statement showing right now.
    @State private var message: HomeMessage?
    @State private var messageChangedAt = Date.distantPast
    /// How far the cards have been scrolled up.
    @State private var scrollOffset: CGFloat = 0
    /// The height of the title, verse and Earth together.
    @State private var backHeight: CGFloat = 0
    /// The height of the verse, which is how far the Earth can rise.
    @State private var messageHeight: CGFloat = 0
    @State private var scrollPosition = ScrollPosition()

    private let store = DataStore.shared
    private let journey = JourneyStore.shared
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    /// Degrees of turn per tick. About one full turn every two minutes.
    private static let degreesPerTick = 0.1
    /// How visible the verse stays once it has faded: 0.35 is about a third.
    private static let verseRestingOpacity = 0.35
    /// How far to scroll before the verse has finished fading.
    private static let fadeDistance: CGFloat = 48
    /// How much the Earth dims when the cards cover it: 0.35 leaves it 65% visible.
    private static let coveredDimming = 0.35
    /// How far the cards slide over the Earth before it has dimmed fully.
    private static let dimDistance: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            let globeHeight = max(geometry.size.height * 0.40, 230)

            // The title sits above everything else, so the cards can never
            // scroll over it.
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

            ZStack(alignment: .top) {
                // The back layer: the verse grows lighter, and the Earth rises
                // to the title and then stays there.
                VStack(spacing: 12) {
                    // The verse stays where it is and grows lighter as the
                    // cards are scrolled up. It never disappears completely.
                    messageArea
                        .opacity(1 - (1 - Self.verseRestingOpacity) * min(max(scrollOffset / Self.fadeDistance, 0), 1))
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { messageHeight = $0 }

                    FlatGlobe(
                        communities: store.communities,
                        interactive: false,
                        camera: .constant(camera)
                    )
                    .frame(height: globeHeight)
                    // As the verse fades, the Earth rises into its place, and
                    // stops once it sits just under the title.
                    .offset(y: -min(max(scrollOffset, 0), messageHeight + 12))
                    // Once the cards start sliding over the Earth, it dims a little.
                    // A wash of the page color does the dimming, so the verse
                    // behind the Earth never shows through it.
                    .overlay {
                        Circle()
                            .fill(Theme.background)
                            .padding(2)
                            .opacity(Self.coveredDimming * min(max((scrollOffset - (messageHeight + 12)) / Self.dimDistance, 0), 1))
                            .offset(y: -min(max(scrollOffset, 0), messageHeight + 12))
                            .allowsHitTesting(false)
                    }
                    .accessibilityHidden(true)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { backHeight = $0 }

                // The front layer scrolls: an empty space the size of the back
                // layer, then the cards, which slide up in front of the Earth.
                ScrollView {
                    VStack(spacing: 12) {
                        Color.clear
                            .frame(height: max(backHeight - globeHeight, 0))

                        // The see-through space over the Earth is the button
                        // that opens the globe page.
                        Button {
                            router.open(.globe)
                        } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(height: globeHeight)
                        .padding(.top, -12)
                        .accessibilityLabel("The Earth, showing \(store.communities.count) communities")
                        .accessibilityHint("Opens the globe")

                        doors
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollPosition($scrollPosition)
                .onScrollGeometryChange(for: CGFloat.self) { scroll in
                    scroll.contentOffset.y + scroll.contentInsets.top
                } action: { _, offset in
                    scrollOffset = offset
                }
            }
            }
        }
        // The scan button stays fixed at the very bottom.
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    router.open(.scan)
                } label: {
                    Label("Scan a bottle", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())

                // The way in to signing in, orders and (for the team) the operator tools.
                Button {
                    router.open(.account)
                } label: {
                    Image(systemName: "person")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .frame(width: 50, height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.foreground.opacity(0.7), lineWidth: 1.5))
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityLabel("Account")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.background)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        // A fresh message each time the home page is returned to...
        .onAppear(perform: showNextMessage)
        .task {
            #if DEBUG
            // For testing: launch with "-homeScroll 80" to open scrolled that far.
            let wanted = UserDefaults.standard.double(forKey: "homeScroll")
            if wanted > 0 {
                try? await Task.sleep(for: .seconds(1))
                scrollPosition.scrollTo(y: wanted)
            }
            #endif
        }
        // ...and each time the app is opened again.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, router.path.isEmpty {
                showNextMessage()
            }
        }
        .onReceive(clock) { _ in
            // The Earth turns slowly unless the phone asks for less motion,
            // and only while the home page is the one showing.
            guard !reduceMotion, router.path.isEmpty else { return }
            camera.longitude = wrapDegrees(camera.longitude + Self.degreesPerTick)
        }
    }

    // MARK: The message under the title

    private var messageArea: some View {
        VStack(spacing: 4) {
            if let message {
                Text(message.kind == .scripture ? "\u{201C}\(message.text)\u{201D}" : message.text)
                    .font(message.kind == .scripture ? .callout.italic() : .callout.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(usesLargeText ? 8 : 3)
                    .minimumScaleFactor(0.75)
                if let reference = message.reference {
                    Text(reference)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.horizontal, 24)
        // A fixed height, so the page doesn't shift when the message changes.
        .frame(maxWidth: .infinity)
        .frame(minHeight: 76)
        .accessibilityElement(children: .combine)
    }

    /// Picks a different message from the one showing.
    private func showNextMessage() {
        // Opening the app triggers this twice in a row; once is enough.
        guard Date().timeIntervalSince(messageChangedAt) > 1 else { return }
        // Verses edited by the team online win; otherwise the built-in ones.
        let all = CloudContent.shared.homeMessages ?? store.homeMessages
        let others = all.filter { $0 != message }
        message = others.randomElement() ?? all.first
        messageChangedAt = Date()
    }

    // MARK: The cards below the Earth

    /// true when the phone's text size is set large enough that three
    /// cards side by side would cut words off.
    private var usesLargeText: Bool { dynamicTypeSize >= .xxLarge }

    /// Donate Directly runs across the page, with the other four cards in
    /// two rows of two below it. With large text they all stack.
    @ViewBuilder
    private var doors: some View {
        VStack(spacing: 10) {
            EditShortcut(title: "Edit the verses", route: .operatorMessages)
            donateDoor
            if usesLargeText {
                hubDoor
                journeyDoor
                communityDoor
                shopDoor
            } else {
                HStack(alignment: .top, spacing: 10) {
                    hubDoor
                    journeyDoor
                }
                HStack(alignment: .top, spacing: 10) {
                    communityDoor
                    shopDoor
                }
            }
        }
    }

    private var communityDoor: some View {
        doorCard(
            title: "Community",
            headline: nil,
            detail: nil,
            showsSample: false,
            spokenLabel: "Community, coming soon",
            action: { router.open(.community) }
        ) {
            Image(systemName: "person.3")
                .font(.system(size: 46))
                .foregroundStyle(Theme.foreground)
        }
    }

    private var shopDoor: some View {
        doorCard(
            title: "Shop",
            headline: nil,
            detail: nil,
            showsSample: false,
            action: { router.open(.shop) }
        ) {
            Image(systemName: "bag")
                .font(.system(size: 58))
                .foregroundStyle(Theme.foreground)
        }
    }

    /// Only the title and the picture.
    private var hubDoor: some View {
        doorCard(
            title: "What we've done",
            headline: nil,
            detail: nil,
            showsSample: false,
            action: { router.open(.hub) }
        ) {
            Image(systemName: "drop")
                .font(.system(size: 58))
                .foregroundStyle(Theme.foreground)
        }
    }

    /// Only the title and the picture.
    private var journeyDoor: some View {
        let progress = store.levelProgress(bottles: journey.bottles.count)

        return doorCard(
            title: "What you've done",
            headline: nil,
            detail: nil,
            showsSample: false,
            action: { router.open(.journey) }
        ) {
            // The biggest thing filled so far, or an empty glass before the first bottle.
            VesselView(kind: progress.current?.vessel ?? .glass, fill: progress.current == nil ? 0 : 1, lineWidth: 3.5)
                .frame(width: 70, height: 70)
        }
    }

    /// A full-width card with only the bold title and, beneath it, the big
    /// heart. It is just tall enough for those two.
    private var donateDoor: some View {
        Button {
            router.open(.donate)
        } label: {
            VStack(spacing: 6) {
                Text("Donate Directly")
                    .font(.headline.weight(.bold))
                Image(systemName: "heart")
                    .font(.system(size: 58))
                    .frame(height: 76)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Theme.foreground)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Theme.widget, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Donate Directly")
    }

    /// A card: the title in bold at the top, its picture big in the middle,
    /// and a line or two underneath.
    private func doorCard<Picture: View>(
        title: String,
        headline: String?,
        detail: String?,
        showsSample: Bool,
        spokenLabel: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder picture: () -> Picture
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(2)
                picture()
                    .frame(height: 76)
                    .accessibilityHidden(true)
                if let headline {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                }
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                }
                if showsSample {
                    SampleBadge()
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(12)
            .background(Theme.widget, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel ?? title)
        .accessibilityHint("Opens \(title)")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
}
