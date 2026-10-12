import SwiftUI

/// A web page waiting to be shown in the in-app browser.
private struct BrowserPage: Identifiable {
    let url: URL
    var id: URL { url }
}

// The Shop page: every product as a photo with its name. Tapping one opens
// that product's page on the website, in the in-app browser, where it is
// bought. The app itself never handles a cart or a payment.
struct ShopView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var products: [Product] = []
    @State private var browserPage: BrowserPage?

    private static var didPreview = false

    /// Two columns, or one when the phone's text size is set large.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: dynamicTypeSize >= .xxLarge ? 1 : 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shop")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .accessibilityAddTraits(.isHeader)
                    Text("Every purchase helps bring clean water to communities in need.")
                        .font(.title3)
                        .foregroundStyle(Theme.muted)
                }

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(products) { product in
                        Button {
                            open(product.productURL)
                        } label: {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spokenLabel(for: product))
                    }
                }

                Button("View full store") {
                    browserPage = AppLinks.shop.map(BrowserPage.init)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Opens the Living Water store")

                Text("You'll buy on the Living Water Co. website. The app never takes a payment.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            products = await ProductCatalog.load()
            #if DEBUG
            // For testing: launch with "-previewProduct sample-1" to open a product's page.
            if !Self.didPreview, let id = UserDefaults.standard.string(forKey: "previewProduct"),
               let product = products.first(where: { $0.id == id }) {
                Self.didPreview = true
                open(product.productURL)
            }
            #endif
        }
        // Closing the browser lands back here, at the same place in the grid.
        .fullScreenCover(item: $browserPage) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
    }

    /// Opens a web address in the in-app browser. A bad address does nothing.
    private func open(_ address: String) {
        browserPage = AppLinks.webURL(address).map(BrowserPage.init)
    }

    private func spokenLabel(for product: Product) -> String {
        [product.name, product.badge, product.price, "opens product page"]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// One product: its photo, then its name, and its price if there is one.
private struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A clear 4:5 box sets the shape; the photo fills it and is trimmed to fit.
            Color.clear
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .overlay { photo }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
                .overlay(alignment: .topLeading) {
                    if let badge = product.badge {
                        Text(badge)
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

            if let price = product.price {
                Text(price)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
            }
            if product.isSample {
                SampleBadge()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var photo: some View {
        if let name = product.imageName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
        } else if let url = product.imageURL.flatMap(AppLinks.webURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallback
                default:
                    // Still loading: a plain panel in the app's blue.
                    Theme.widget
                }
            }
        } else {
            fallback
        }
    }

    /// Shown when there is no photo or it fails to load. Never a broken image.
    private var fallback: some View {
        Theme.widget
            .overlay {
                Image(systemName: "drop")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.foreground.opacity(0.85))
            }
    }
}

#Preview {
    NavigationStack {
        ShopView()
    }
}
