import Foundation

// Every web address the app opens that isn't partner data, in one place.
enum AppLinks {
    // TODO: replace with exact shop page URL
    private static let shopAddress = "https://livingwaterco.com"

    /// The online store. nil if the address above is ever mistyped, so a
    /// typo can never crash the app.
    static var shop: URL? { webURL(shopAddress) }

    /// Only proper secure web links count.
    static func webURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", url.host() != nil else { return nil }
        return url
    }
}
