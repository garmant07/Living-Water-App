import Foundation

// The products shown on the Shop page. This is the one file to edit when
// adding, changing or removing a product.
//
// To add a real product:
//   1. Open the product on livingwaterco.com in Safari.
//   2. Copy the page address. That is productURL.
//   3. Save the product photo and drag it into Assets in Xcode, then put
//      its name in imageName. (Or copy the photo's web link into imageURL.)
//   4. Copy the product name exactly as it appears.
//   5. Set isSample to false.

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    /// A web link to the product photo. Use this OR imageName.
    var imageURL: String? = nil
    /// The name of a photo added to Assets in Xcode. Use this OR imageURL.
    var imageName: String? = nil
    /// The exact product page on livingwaterco.com.
    let productURL: String
    /// Shown only if provided, e.g. "$24.99".
    var price: String? = nil
    /// A small label such as "New" or "Best Seller". Optional.
    var badge: String? = nil
    /// true = made up for building the app. Shown with a "Sample data" badge.
    var isSample = false
}

enum ProductCatalog {
    /// The Shop page asks for products here. If products later come from the
    /// website automatically, only this function changes; the page stays the same.
    static func load() async -> [Product] {
        manualProducts
    }

    static let manualProducts: [Product] = [
        // TODO: replace with real product name, photo, and product page link
        Product(
            id: "sample-1",
            name: "Sample product one",
            productURL: "https://livingwaterco.com",
            isSample: true
        ),
        // TODO: replace with real product name, photo, and product page link
        Product(
            id: "sample-2",
            name: "Sample product two",
            productURL: "https://livingwaterco.com",
            badge: "New",
            isSample: true
        ),
        // TODO: replace with real product name, photo, and product page link
        Product(
            id: "sample-3",
            name: "Sample product three",
            productURL: "https://livingwaterco.com",
            isSample: true
        ),
    ]
}
