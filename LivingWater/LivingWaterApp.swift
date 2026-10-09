import SwiftUI

// Where the app starts. It shows the bottom tab bar, opening on the globe.
@main
struct LivingWaterApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Globe", systemImage: "globe") {
                    GlobeView()
                }
                Tab("Hub", systemImage: "drop") {
                    HomeView()
                }
            }
            .tint(Theme.brand)
        }
    }
}
