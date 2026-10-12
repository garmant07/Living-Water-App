import Foundation
import Supabase

// Everything an operator can change: products, home page verses and
// community stories. The database refuses these calls from anyone whose
// account isn't an operator, so this file is not what keeps content safe.

enum OperatorService {
    private static var now: String { ISO8601DateFormatter().string(from: Date()) }

    private static func run(_ failure: String, _ work: (SupabaseClient) async throws -> Void) async throws {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            try await work(client)
        } catch {
            throw FriendlyError(message: failure)
        }
    }

    private static func fetch<T: Decodable>(_ table: String, orderedBy column: String, ascending: Bool = true) async throws -> [T] {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            return try await client.from(table).select().order(column, ascending: ascending).execute().value
        } catch {
            throw FriendlyError(message: "We couldn't load that. Pull down to try again.")
        }
    }

    // MARK: Products

    static func allProducts() async throws -> [ShopProduct] {
        try await fetch("products", orderedBy: "sort_order")
    }

    private struct ProductWrite: Encodable {
        let product: ShopProduct
        let updatedBy: UUID?
        let updatedAt: String

        enum Keys: String, CodingKey {
            case id, name, description, currency, badge
            case priceCents = "price_cents"
            case imageUrls = "image_urls"
            case stockQuantity = "stock_quantity"
            case isActive = "is_active"
            case sortOrder = "sort_order"
            case updatedBy = "updated_by"
            case updatedAt = "updated_at"
        }

        func encode(to encoder: Encoder) throws {
            var fields = encoder.container(keyedBy: Keys.self)
            try fields.encode(product.id, forKey: .id)
            try fields.encode(product.name, forKey: .name)
            try fields.encode(product.description, forKey: .description)
            try fields.encode(product.currency, forKey: .currency)
            try fields.encode(product.badge, forKey: .badge)
            try fields.encode(product.priceCents, forKey: .priceCents)
            try fields.encode(product.imageUrls, forKey: .imageUrls)
            // Written even when empty, so "not tracked" can be saved.
            try fields.encode(product.stockQuantity, forKey: .stockQuantity)
            try fields.encode(product.isActive, forKey: .isActive)
            try fields.encode(product.sortOrder, forKey: .sortOrder)
            try fields.encode(updatedBy, forKey: .updatedBy)
            try fields.encode(updatedAt, forKey: .updatedAt)
        }
    }

    static func save(_ product: ShopProduct, by userID: UUID?) async throws {
        try await run("The product didn't save. Check your connection and try again.") { client in
            try await client.from("products")
                .upsert(ProductWrite(product: product, updatedBy: userID, updatedAt: now))
                .execute()
        }
    }

    static func deleteProduct(_ id: UUID) async throws {
        try await run("The product couldn't be deleted. Please try again.") { client in
            try await client.from("products").delete().eq("id", value: id.uuidString).execute()
        }
    }

    /// Saves a new order for the products after dragging.
    static func saveOrder(of products: [ShopProduct]) async throws {
        try await run("The new order didn't save. Please try again.") { client in
            for (index, product) in products.enumerated() where product.sortOrder != index {
                try await client.from("products").update(["sort_order": index]).eq("id", value: product.id.uuidString).execute()
            }
        }
    }

    // MARK: Home page verses

    static func allMessages() async throws -> [CloudMessage] {
        try await fetch("home_messages", orderedBy: "sort_order")
    }

    static func save(_ message: CloudMessage) async throws {
        try await run("The message didn't save. Please try again.") { client in
            try await client.from("home_messages").upsert(message).execute()
        }
    }

    static func deleteMessage(_ id: UUID) async throws {
        try await run("The message couldn't be deleted. Please try again.") { client in
            try await client.from("home_messages").delete().eq("id", value: id.uuidString).execute()
        }
    }

    // MARK: Community stories

    static func allStories() async throws -> [CommunityStory] {
        try await fetch("community_stories", orderedBy: "published_at", ascending: false)
    }

    static func save(_ story: CommunityStory) async throws {
        try await run("The story didn't save. Please try again.") { client in
            try await client.from("community_stories").upsert(story).execute()
        }
    }

    static func deleteStory(_ id: UUID) async throws {
        try await run("The story couldn't be deleted. Please try again.") { client in
            try await client.from("community_stories").delete().eq("id", value: id.uuidString).execute()
        }
    }
}
