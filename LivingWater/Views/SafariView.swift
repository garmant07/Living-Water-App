import SafariServices
import SwiftUI

// Apple's in-app browser, wrapped so SwiftUI can show it. It opens a web
// page on top of the app with Safari's own "Done" button to come back.
// Reusable: give it any web address.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        // The browser's bar shrinks out of the way while scrolling.
        configuration.barCollapsingEnabled = true

        let browser = SFSafariViewController(url: url, configuration: configuration)
        // The Done button and icons: white on a dark bar, the app's blue on a light one.
        browser.preferredControlTintColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : UIColor(Theme.background)
        }
        return browser
    }

    func updateUIViewController(_ browser: SFSafariViewController, context: Context) {}
}
