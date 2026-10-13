import SwiftUI

// The Shop: every product as a photo with its name and price. Customers
// browse, add to the cart and pay inside the app.
struct ShopView: View {
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let shop = ShopStore.shared
    private let cart = CartStore.shared

    /// Two columns, or one when the phone's text size is set large.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: dynamicTypeSize >= .xxLarge ? 1 : 2)
    }

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 8) {
                PageTitle("Shop")
                EditableText(
                    key: "shop_intro",
                    fallback: "Every purchase helps bring clean water to communities in need.",
                    name: "Shop introduction"
                )
                .font(.title3)
                .foregroundStyle(Theme.muted)
                EditShortcut(title: "Edit products", route: .operatorProducts)
            }

            if shop.products.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(shop.products) { product in
                        NavigationLink(value: AppRoute.product(product)) {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spokenLabel(for: product))
                    }
                }
            }
        }
        .refreshable { await shop.load() }
        .task { await shop.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.cart) {
                    Image(systemName: "cart")
                        .overlay(alignment: .topTrailing) {
                            if cart.itemCount > 0 {
                                Text("\(cart.itemCount)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.background)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Theme.brand, in: Capsule())
                                    .offset(x: 12, y: -10)
                            }
                        }
                }
                .accessibilityLabel("Cart, \(cart.itemCount) \(cart.itemCount == 1 ? "item" : "items")")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if shop.isLoading {
            ProgressView().tint(Theme.foreground).frame(maxWidth: .infinity).padding(.top, 40)
        } else if shop.loadFailed {
            Card {
                Text("We couldn't load the shop")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Text("Check your connection and try again.")
                    .foregroundStyle(Theme.muted)
                Button("Try again") { Task { await shop.load() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else {
            Card {
                Text("Nothing in the shop yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                Text("Products will appear here soon.")
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func spokenLabel(for product: ShopProduct) -> String {
        [product.name, product.badge.isEmpty ? nil : product.badge, Format.price(cents: product.priceCents), product.isSoldOut ? "sold out" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// One product in the grid: its photo, then its name and price.
private struct ProductCard: View {
    let product: ShopProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A clear 4:5 box sets the shape; the photo fills it and is trimmed to fit.
            Color.clear
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .overlay { RemotePhoto(address: product.imageUrls.first) }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
                .overlay(alignment: .topLeading) {
                    if product.isSoldOut || !product.badge.isEmpty {
                        Text(product.isSoldOut ? "Sold out" : product.badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.brand, in: Capsule())
                            .padding(10)
                    }
                }

            Text(product.name)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(Format.price(cents: product.priceCents))
                .font(.subheadline)
                .foregroundStyle(Theme.foreground)
            if product.isSample {
                SampleBadge()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// One product's own page: photos to swipe through, the details, and Add to cart.
struct ProductDetailView: View {
    let product: ShopProduct

    @Environment(Router.self) private var router
    @State private var quantity = 1
    @State private var justAdded = false

    private let cart = CartStore.shared

    var body: some View {
        PageScroll {
            gallery

            VStack(alignment: .leading, spacing: 8) {
                PageTitle(product.name)
                Text(Format.price(cents: product.priceCents))
                    .font(.title2)
                    .foregroundStyle(Theme.foreground)
                if product.isSample {
                    SampleBadge()
                }
            }

            if !product.description.isEmpty {
                Text(product.description)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(Theme.foreground)
            }

            if product.isSoldOut {
                Notice(text: "This is sold out for now.")
            } else {
                Stepper(value: $quantity, in: 1...min(product.stockQuantity ?? 20, 20)) {
                    Text("Quantity: \(quantity)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                }
                .frame(minHeight: 44)

                Button {
                    cart.add(product, quantity: quantity)
                    justAdded = true
                } label: {
                    Label("Add to cart", systemImage: "cart.badge.plus")
                }
                .buttonStyle(PrimaryButtonStyle())

                if justAdded {
                    Notice(text: "Added to your cart.", isProblem: false)
                    Button("View cart") { router.path.append(AppRoute.cart) }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }

            Text("Your purchase helps fund clean water through our ministry partners.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    private var gallery: some View {
        let photos: [String?] = product.imageUrls.isEmpty ? [nil] : product.imageUrls

        return TabView {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, address in
                RemotePhoto(address: address)
                    .accessibilityLabel("\(product.name), photo \(index + 1) of \(photos.count)")
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border))
    }
}
