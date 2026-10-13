import Observation
import SwiftUI

/// The pages that open from the home page.
enum Page: String, Hashable {
    case globe, hub, scan, journey, donate, shop, community, account
}

/// Pages that need something handed to them, or that open from inside other pages.
enum AppRoute: Hashable {
    case product(ShopProduct)
    case cart
    case checkout
    case orders
    case order(Order)
    case operatorHome
    case operatorProducts
    case operatorOrders
    case operatorOrder(Order)
    case operatorMessages
    case operatorStories
    case operatorPartners
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
            VStack(spacing: 0) {
            NavigationStack(path: Bindable(router).path) {
                HomeView()
                    .navigationDestination(for: Page.self) { page in
                        switch page {
                        case .globe: GlobeView()
                        case .hub: HubView()
                        case .scan: ScanView()
                        case .journey: JourneyView()
                        case .donate: DonateView()
                        case .shop: ShopView()
                        case .community: CommunityView()
                        case .account: AccountView()
                        }
                    }
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .product(let product): ProductDetailView(product: product)
                        case .cart: CartView()
                        case .checkout: CheckoutView()
                        case .orders: OrdersView()
                        case .order(let order): OrderDetailView(order: order)
                        case .operatorHome: OperatorDashboardView()
                        case .operatorProducts: OperatorProductsView()
                        case .operatorOrders: OperatorOrdersView()
                        case .operatorOrder(let order): OperatorOrderView(order: order)
                        case .operatorMessages: OperatorMessagesView()
                        case .operatorStories: OperatorStoriesView()
                        case .operatorPartners: OperatorPartnersView()
                        }
                    }
                    .navigationDestination(for: Community.self) { community in
                        CommunityStoryView(community: community)
                    }
                    .navigationDestination(for: Partner.self) { partner in
                        PartnerDetailView(partner: partner)
                    }
                    .navigationDestination(for: DonateRoute.self) { route in
                        DonatePartnerView(partner: route.partner)
                    }
                    .navigationDestination(for: BottleRoute.self) { route in
                        BottleView(code: route.code)
                    }
            }
            // While an operator has Edit Mode on, a bar across the bottom says so.
            if CloudContent.shared.isEditing && AuthStore.shared.isOperator {
                EditModeBar()
            }
            }
            .background(Theme.background)
            .environment(router)
            // Links in confirmation and password-reset emails open the app here.
            .onOpenURL { link in
                Task { await AuthStore.shared.open(link) }
            }
            .sheet(isPresented: Bindable(AuthStore.shared).needsNewPassword) {
                NewPasswordSheet()
            }
            .alert(
                AuthStore.shared.linkNotice ?? "",
                isPresented: Binding(
                    get: { AuthStore.shared.linkNotice != nil },
                    set: { if !$0 { AuthStore.shared.linkNotice = nil } }
                )
            ) {
                Button("OK") {}
            }
            .tint(Theme.brand)
            // The whole app is white text on blue, so system bars use their dark look.
            .preferredColorScheme(.dark)
            // Keep track of who is signed in, and fetch the latest content.
            .task { await AuthStore.shared.start() }
            .task { await CloudContent.shared.load() }
            .onAppear {
                #if DEBUG
                // For testing: launch with "-startPage hub" to open straight on a page.
                if router.path.isEmpty,
                   let page = UserDefaults.standard.string(forKey: "startPage").flatMap(Page.init) {
                    router.open(page)
                }
                // For testing: "-startRoute cart", "product" or "operator".
                switch UserDefaults.standard.string(forKey: "startRoute") {
                case "cart": router.path.append(AppRoute.cart)
                case "product": router.path.append(AppRoute.product(ShopProduct.samples[1]))
                case "operator": router.path.append(AppRoute.operatorHome)
                case "operatorProducts": router.path.append(AppRoute.operatorProducts)
                case "operatorPartners": router.path.append(AppRoute.operatorPartners)
                default: break
                }
                // For testing: "-previewEditing YES" turns Edit Mode on (with -previewOperator YES).
                if UserDefaults.standard.bool(forKey: "previewEditing") { CloudContent.shared.isEditing = true }
                #endif
            }
        }
    }
}
