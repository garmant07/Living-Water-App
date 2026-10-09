import Observation
import SwiftUI

/// The pages that open from the home page.
enum Page: String, Hashable {
    case globe, hub, scan, journey
}

/// Keeps track of which pages are open, so any screen can open another
/// or go back to the home page.
@Observable
final class Router {
    var path = NavigationPath()

    func open(_ page: Page) {
        path.append(page)
    }

    func goHome() {
        path = NavigationPath()
    }
}

// Where the app starts. It opens the home page. Every other page opens on
// top of it and has a back arrow in the top left corner.
@main
struct LivingWaterApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: Bindable(router).path) {
                HomeView()
                    .navigationDestination(for: Page.self) { page in
                        switch page {
                        case .globe: GlobeView()
                        case .hub: HubView()
                        case .scan: ScanView()
                        case .journey: JourneyView()
                        }
                    }
                    .navigationDestination(for: Community.self) { community in
                        CommunityStoryView(community: community)
                    }
                    .navigationDestination(for: Partner.self) { partner in
                        PartnerDetailView(partner: partner)
                    }
                    .navigationDestination(for: BottleRoute.self) { route in
                        BottleView(code: route.code)
                    }
            }
            .environment(router)
            .tint(Theme.brand)
            // The whole app is white text on blue, so system bars use their dark look.
            .preferredColorScheme(.dark)
            .onAppear {
                #if DEBUG
                // For testing: launch with "-startPage hub" to open straight on a page.
                if router.path.isEmpty,
                   let page = UserDefaults.standard.string(forKey: "startPage").flatMap(Page.init) {
                    router.open(page)
                }
                #endif
            }
        }
    }
}
