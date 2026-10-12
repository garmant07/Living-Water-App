import Foundation

// The shapes of the records kept online. Each matches a table in
// supabase/schema.sql. The names on the right of each CodingKeys line are
// the column names in the database.

struct Profile: Codable, Hashable {
    let id: UUID
    var displayName: String?
    /// "user" or "operator". Can only be changed in the Supabase dashboard.
    let role: String

    enum CodingKeys: String, CodingKey {
        case id, role
        case displayName = "display_name"
    }
}

struct ShopProduct: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var description: String
    var priceCents: Int
    var currency: String
    var imageUrls: [String]
    /// A small label such as "New". Empty means no label.
    var badge: String
    /// nil means stock isn't tracked. 0 means sold out.
    var stockQuantity: Int?
    /// false hides the product from customers without deleting it.
    var isActive: Bool
    var sortOrder: Int
    /// true = built into the app for testing, not a real product.
    var isSample = false

    enum CodingKeys: String, CodingKey {
        case id, name, description, currency, badge
        case priceCents = "price_cents"
        case imageUrls = "image_urls"
        case stockQuantity = "stock_quantity"
        case isActive = "is_active"
        case sortOrder = "sort_order"
    }

    var isSoldOut: Bool { stockQuantity == 0 }

    /// SAMPLE products shown only while the app isn't connected to Supabase.
    static let samples: [ShopProduct] = ["one", "two", "three"].enumerated().map { index, word in
        ShopProduct(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index + 1)")!,
            name: "Sample product \(word)",
            description: "A sample product, here so the shop can be tried before real products are added.",
            priceCents: [2499, 3499, 1999][index],
            currency: "usd",
            imageUrls: [],
            badge: index == 1 ? "New" : "",
            stockQuantity: nil,
            isActive: true,
            sortOrder: index,
            isSample: true
        )
    }
}

struct OrderItem: Codable, Identifiable, Hashable {
    let id: UUID
    let productName: String
    let unitPriceCents: Int
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case productName = "product_name"
        case unitPriceCents = "unit_price_cents"
    }
}

struct Order: Codable, Identifiable, Hashable {
    let id: UUID
    let orderNumber: Int
    var status: String
    let subtotalCents: Int
    let shippingCents: Int
    let taxCents: Int
    let totalCents: Int
    let shippingName: String?
    let shippingLine1: String?
    let shippingLine2: String?
    let shippingCity: String?
    let shippingState: String?
    let shippingPostalCode: String?
    let shippingCountry: String?
    let contactEmail: String?
    var shippingCarrier: String?
    var trackingUrl: String?
    let createdAt: Date
    let items: [OrderItem]?

    enum CodingKeys: String, CodingKey {
        case id, status
        case orderNumber = "order_number"
        case subtotalCents = "subtotal_cents"
        case shippingCents = "shipping_cents"
        case taxCents = "tax_cents"
        case totalCents = "total_cents"
        case shippingName = "shipping_name"
        case shippingLine1 = "shipping_line1"
        case shippingLine2 = "shipping_line2"
        case shippingCity = "shipping_city"
        case shippingState = "shipping_state"
        case shippingPostalCode = "shipping_postal_code"
        case shippingCountry = "shipping_country"
        case contactEmail = "contact_email"
        case shippingCarrier = "shipping_carrier"
        case trackingUrl = "tracking_url"
        case createdAt = "created_at"
        case items = "order_items"
    }

    /// How the status reads on screen.
    var statusLabel: String {
        switch status {
        case "pending_payment": "Waiting for payment"
        case "paid": "Paid"
        case "shipped": "Shipped"
        case "delivered": "Delivered"
        case "cancelled": "Cancelled"
        case "refunded": "Refunded"
        default: status.capitalized
        }
    }

    var addressLines: [String] {
        [
            shippingName,
            shippingLine1,
            shippingLine2,
            [shippingCity, shippingState, shippingPostalCode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "),
            shippingCountry,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
    }
}

struct CommunityStory: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var imageUrl: String?
    var location: String?
    var isPublished: Bool
    var publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, body, location
        case imageUrl = "image_url"
        case isPublished = "is_published"
        case publishedAt = "published_at"
    }
}

/// A home page verse, slogan or mission statement, as stored online.
struct CloudMessage: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: String
    var text: String
    var reference: String?
    var sortOrder: Int
    var isPublished: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, text, reference
        case sortOrder = "sort_order"
        case isPublished = "is_published"
    }

    var asHomeMessage: HomeMessage {
        HomeMessage(kind: HomeMessage.Kind(rawValue: kind) ?? .slogan, text: text, reference: reference)
    }
}
