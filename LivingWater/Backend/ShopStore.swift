import Foundation
import Observation
import Supabase

// The products customers can buy, loaded from Supabase and remembered on the
// phone. Prices shown here are for display; the server works out the real
// total at checkout.

@MainActor
@Observable
final class ShopStore {
    static let shared = ShopStore()

    private(set) var products: [ShopProduct] = []
    private(set) var isLoading = false
    /// true when nothing could be loaded and there is nothing saved to show.
    private(set) var loadFailed = false

    private init() {
        if Backend.isConfigured, let saved: [ShopProduct] = DiskCache.load("products") {
            products = saved
        }
    }

    func load() async {
        guard let client = Backend.client else {
            // Not connected yet: show the built-in samples.
            products = ShopProduct.samples
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [ShopProduct] = try await client.from("products")
                .select()
                .eq("is_active", value: true)
                .order("sort_order")
                .execute()
                .value
            products = rows
            loadFailed = false
            DiskCache.save(rows, as: "products")
            CartStore.shared.matchToShop(rows)
        } catch {
            loadFailed = products.isEmpty
        }
    }
}

/// One product in the cart, with how many.
struct CartLine: Codable, Identifiable, Hashable {
    var product: ShopProduct
    var quantity: Int
    var id: UUID { product.id }
}

// The cart. It is saved on the phone, so it survives closing the app.
@MainActor
@Observable
final class CartStore {
    static let shared = CartStore()

    private(set) var lines: [CartLine] = []
    /// Items the last tidy-up took out because they are no longer for sale.
    var removedNames: [String] = []
    private let storageKey = "cart.lines"

    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
    var subtotalCents: Int { lines.reduce(0) { $0 + $1.product.priceCents * $1.quantity } }

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([CartLine].self, from: data) {
            lines = saved
        }
        #if DEBUG
        // For testing: launch with "-previewCart YES" to start with something in the cart.
        if UserDefaults.standard.bool(forKey: "previewCart"), lines.isEmpty {
            lines = [CartLine(product: ShopProduct.samples[0], quantity: 2), CartLine(product: ShopProduct.samples[1], quantity: 1)]
        }
        #endif
    }

    func add(_ product: ShopProduct, quantity: Int) {
        if let index = lines.firstIndex(where: { $0.id == product.id }) {
            lines[index].quantity = min(lines[index].quantity + quantity, 99)
        } else {
            lines.append(CartLine(product: product, quantity: quantity))
        }
        save()
    }

    func setQuantity(_ quantity: Int, for id: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        if quantity <= 0 {
            lines.remove(at: index)
        } else {
            lines[index].quantity = min(quantity, 99)
        }
        save()
    }

    /// Brings the cart in line with what the shop sells right now: anything no
    /// longer for sale is taken out, and names and prices are refreshed.
    /// Returns nothing; `removedNames` says what was taken out.
    func matchToShop(_ products: [ShopProduct]) {
        var kept: [CartLine] = []
        var removed: [String] = []
        for line in lines {
            if let current = products.first(where: { $0.id == line.id }), !current.isSoldOut {
                kept.append(CartLine(product: current, quantity: line.quantity))
            } else {
                removed.append(line.product.name)
            }
        }
        guard kept != lines else { return }
        lines = kept
        removedNames = removed
        save()
    }

    func clear() {
        lines = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(lines) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
