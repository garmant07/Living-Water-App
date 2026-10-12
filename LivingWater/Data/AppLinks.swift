import Foundation

// Web addresses the app opens that aren't partner data, in one place.
enum AppLinks {
    // TODO: add the real Privacy Policy address before launch
    private static let privacyPolicyAddress = ""
    // TODO: add the real Terms of Sale and Refund Policy address before launch
    private static let termsAddress = ""

    static var privacyPolicy: URL? { webURL(privacyPolicyAddress) }
    static var terms: URL? { webURL(termsAddress) }

    /// Only proper secure web links count. A mistyped address gives nil,
    /// so a typo can never crash the app.
    static func webURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host() != nil else { return nil }
        return url
    }
}
