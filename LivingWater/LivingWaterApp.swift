import SwiftUI

// Where the app starts. It shows the bottom tab bar, opening on the globe.
@main
struct LivingWaterApp: App {
    // For testing: launch with "-startTab hub" to open on the Hub.
    @State private var tab = UserDefaults.standard.string(forKey: "startTab") ?? "globe"

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                Tab("Globe", systemImage: "globe", value: "globe") {
                    GlobeView()
                }
                Tab("Hub", systemImage: "drop", value: "hub") {
                    HomeView()
                }
            }
            .tint(Theme.brand)
            // The whole app is white text on blue, so system bars use their dark look.
            .preferredColorScheme(.dark)
        }
    }
}
