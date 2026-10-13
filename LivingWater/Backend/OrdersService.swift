import Foundation
import Supabase

// Reading orders, starting a payment, and (for operators) updating shipping.

/// What the app sends to start a purchase. Note there are no prices here:
/// the server looks them up itself.
struct CheckoutRequest: Encodable {
    struct Item: Encodable {
        /// Sent in lowercase, the way the database writes ids. Swift writes
        /// them in capitals, and the server compares them letter for letter.
        let productId: String
        let quantity: Int
        enum CodingKeys: String, CodingKey {
            case quantity
            case productId = "product_id"
        }
    }

    struct Address: Encodable {
        var name = ""
        var line1 = ""
        var line2 = ""
        var city = ""
        var state = ""
        var postalCode = ""
        var country = "US"
        enum CodingKeys: String, CodingKey {
            case name, line1, line2, city, state, country
            case postalCode = "postal_code"
        }
    }

    let items: [Item]
    let shipping: Address
    let contactEmail: String
    let contactPhone: String?

    enum CodingKeys: String, CodingKey {
        case items, shipping
        case contactEmail = "contact_email"
        case contactPhone = "contact_phone"
    }
}

/// What the server sends back: the totals it worked out, and the key the
/// payment sheet needs.
struct CheckoutResponse: Decodable, Hashable {
    let clientSecret: String
    let orderNumber: Int
    let subtotalCents: Int
    let shippingCents: Int
    let taxCents: Int
    let totalCents: Int

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case orderNumber = "order_number"
        case subtotalCents = "subtotal_cents"
        case shippingCents = "shipping_cents"
        case taxCents = "tax_cents"
        case totalCents = "total_cents"
    }
}

enum OrdersService {
    static let carriers = ["USPS", "UPS", "FedEx", "DHL", "Other"]

    static func startCheckout(_ request: CheckoutRequest) async throws -> CheckoutResponse {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            return try await client.functions.invoke("create-payment", options: FunctionInvokeOptions(body: request))
        } catch FunctionsError.httpError(_, let data) {
            // The server writes its own plain-language message; show that.
            struct Problem: Decodable { let error: String }
            let message = (try? JSONDecoder().decode(Problem.self, from: data))?.error
            throw FriendlyError(message: message ?? "We couldn't start your order. Please try again.")
        } catch {
            throw FriendlyError(message: "We couldn't reach the shop. Check your connection and try again.")
        }
    }

    /// The signed-in person's own orders, newest first.
    static func mine(userID: UUID) async throws -> [Order] {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            return try await client.from("orders")
                .select("*, order_items(*)")
                .eq("user_id", value: userID.uuidString)
                .neq("status", value: "pending_payment")
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw FriendlyError(message: "We couldn't load your orders. Pull down to try again.")
        }
    }

    /// Every order. The database only allows this for operators.
    static func all(status: String?) async throws -> [Order] {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            var query = client.from("orders").select("*, order_items(*)")
            if let status {
                query = query.eq("status", value: status)
            } else {
                query = query.neq("status", value: "pending_payment")
            }
            return try await query.order("created_at", ascending: false).execute().value
        } catch {
            throw FriendlyError(message: "We couldn't load the orders. Pull down to try again.")
        }
    }

    /// Operator only: change an order's status, carrier or tracking link.
    static func update(_ id: UUID, status: String? = nil, carrier: String? = nil, trackingURL: String? = nil, markShippedNow: Bool = false) async throws {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        var fields: [String: String] = [:]
        if let status { fields["status"] = status }
        if let carrier { fields["shipping_carrier"] = carrier }
        if let trackingURL { fields["tracking_url"] = trackingURL }
        if markShippedNow { fields["shipped_at"] = ISO8601DateFormatter().string(from: Date()) }
        do {
            try await client.from("orders").update(fields).eq("id", value: id.uuidString).execute()
        } catch {
            throw FriendlyError(message: "The order didn't save. Check your connection and try again.")
        }
    }
}
