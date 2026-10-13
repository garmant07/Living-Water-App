import PhotosUI
import SwiftUI

// The operator's screens. Only accounts marked "operator" in the database
// can reach them, and the database itself refuses edits from anyone else.

// MARK: Dashboard

struct OperatorDashboardView: View {
    private let auth = AuthStore.shared

    var body: some View {
        PageScroll {
            PageTitle("Operator dashboard")
            OperatorBanner()

            if !auth.isOperator {
                Notice(text: "This area is for the Living Water team.")
            } else {
                if !Backend.isConfigured {
                    Notice(text: "Not connected yet, so these screens are empty and nothing can be saved.")
                }
                link("Shop products", "Add, edit, reorder, hide or delete", "bag", .operatorProducts)
                link("Orders", "See orders and add tracking links", "shippingbox", .operatorOrders)
                link("Home page verses", "The lines that rotate under the title", "text.quote", .operatorMessages)
                link("Community stories", "Write and publish stories", "person.3", .operatorStories)
            }
        }
    }

    private func link(_ title: String, _ detail: String, _ icon: String, _ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        Text(detail).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Theme.foreground)
            }
        }
        .buttonStyle(.plain)
    }
}

// A list page shared by the operator screens: banner, rows, a + button, and
// loading, empty and error states.
private struct OperatorList<Item: Identifiable & Hashable, Row: View>: View {
    let title: String
    let emptyText: String
    @Binding var items: [Item]
    @Binding var problem: String?
    let canReorder: Bool
    let onAdd: () -> Void
    let onMove: ([Item]) -> Void
    let onOpen: (Item) -> Void
    let load: () async -> Void
    let onDelete: (Item) async -> Void
    @ViewBuilder let row: (Item) -> Row

    @State private var hasLoaded = false
    @State private var deleting: Item?

    var body: some View {
        List {
            Section {
                PageTitle(title)
                OperatorBanner()
                if let problem {
                    Notice(text: problem)
                } else if hasLoaded && items.isEmpty {
                    Text(emptyText).foregroundStyle(Theme.muted)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

            Section {
                ForEach(items) { item in
                    HStack(spacing: 4) {
                        Button { onOpen(item) } label: {
                            row(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        Button { deleting = item } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Delete")
                    }
                    // Lets the row hold two separate buttons instead of one big one.
                    .buttonStyle(.borderless)
                    .listRowBackground(Theme.surface)
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                    onMove(items)
                }
                .moveDisabled(!canReorder)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canReorder {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) { Image(systemName: "plus") }
                    .accessibilityLabel("Add")
            }
        }
        .confirmationDialog(
            "Delete this for good?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { item in
            Button("Delete", role: .destructive) {
                Task { await onDelete(item) }
            }
            Button("Keep it", role: .cancel) {}
        }
        .refreshable { await load() }
        .task {
            await load()
            hasLoaded = true
        }
    }
}

// The frame around every edit form: Cancel and Save at the top, a warning
// before throwing away changes, and Delete at the bottom.
private struct EditSheet<Content: View>: View {
    let title: String
    let hasChanges: Bool
    let canSave: Bool
    let canDelete: Bool
    let save: () async throws -> Void
    let delete: () async throws -> Void
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var problem: String?
    @State private var confirmingDiscard = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            PageScroll {
                OperatorBanner()
                content
                if let problem {
                    Notice(text: problem)
                }
                if canDelete {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isWorking)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { perform(save) }
                        .disabled(!canSave || !hasChanges || isWorking)
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .confirmationDialog("Delete this for good?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { perform(delete) }
                Button("Keep it", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .preferredColorScheme(.dark)
    }

    private func perform(_ work: @escaping () async throws -> Void) {
        isWorking = true
        problem = nil
        Task {
            do {
                try await work()
                dismiss()
            } catch {
                problem = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// Picks photos, shrinks and uploads them, and hands back their web addresses.
private struct PhotoUploader: View {
    let folder: String
    let limit: Int
    @Binding var addresses: [String]

    @State private var picked: [PhotosPickerItem] = []
    @State private var progress: String?
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(limit == 1 ? "Photo" : "Photos (up to \(limit))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)

            ForEach(Array(addresses.enumerated()), id: \.element) { index, address in
                HStack(spacing: 12) {
                    RemotePhoto(address: address)
                        .frame(width: 64, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text(index == 0 && limit > 1 ? "Main photo" : "Photo \(index + 1)")
                        .foregroundStyle(Theme.foreground)
                    Spacer()
                    if index > 0 {
                        Button { addresses.swapAt(index, index - 1) } label: {
                            Image(systemName: "arrow.up").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Move photo \(index + 1) earlier")
                    }
                    Button { addresses.remove(at: index) } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Remove photo \(index + 1)")
                }
                .foregroundStyle(Theme.foreground)
            }

            if let progress {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.foreground)
                    Text(progress).foregroundStyle(Theme.foreground)
                }
            } else if addresses.count < limit {
                PhotosPicker(selection: $picked, maxSelectionCount: limit - addresses.count, matching: .images) {
                    Label("Add photo", systemImage: "photo.badge.plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            if let problem {
                Notice(text: problem)
            }
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task { await upload(items) }
        }
    }

    private func upload(_ items: [PhotosPickerItem]) async {
        problem = nil
        for (index, item) in items.enumerated() {
            progress = "Uploading \(index + 1) of \(items.count)…"
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                addresses.append(try await ImageUploader.upload(data, folder: folder))
            } catch {
                problem = error.localizedDescription
            }
        }
        progress = nil
        picked = []
    }
}

// MARK: Products

struct OperatorProductsView: View {
    @State private var products: [ShopProduct] = []
    @State private var problem: String?
    @State private var editing: ShopProduct?

    var body: some View {
        OperatorList(
            title: "Shop products",
            emptyText: "No products yet. Tap + to add the first one.",
            items: $products,
            problem: $problem,
            canReorder: true,
            onAdd: {
                editing = ShopProduct(
                    id: UUID(), name: "", description: "", priceCents: 0, currency: "usd", imageUrls: [],
                    badge: "", stockQuantity: nil, isActive: false, sortOrder: products.count
                )
            },
            onMove: { moved in
                Task {
                    do { try await OperatorService.saveOrder(of: moved) } catch { problem = error.localizedDescription }
                    await load()
                }
            },
            onOpen: { editing = $0 },
            load: load,
            onDelete: { item in
                do {
                    try await OperatorService.deleteProduct(item.id)
                } catch {
                    problem = error.localizedDescription
                }
                await load()
            }
        ) { product in
            HStack(spacing: 12) {
                RemotePhoto(address: product.imageUrls.first)
                    .frame(width: 48, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name).font(.headline)
                    Text("\(Format.price(cents: product.priceCents)) · \(product.isActive ? "Showing in shop" : "Hidden")")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            .foregroundStyle(Theme.foreground)
        }
        .sheet(item: $editing) { product in
            ProductForm(product: product, isNew: !products.contains { $0.id == product.id }, onDone: load)
        }
    }

    private func load() async {
        do {
            products = try await OperatorService.allProducts()
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }
}

private struct ProductForm: View {
    let original: ShopProduct
    let isNew: Bool
    let onDone: () async -> Void

    @State private var product: ShopProduct
    @State private var price: String
    @State private var stock: String

    init(product: ShopProduct, isNew: Bool, onDone: @escaping () async -> Void) {
        original = product
        self.isNew = isNew
        self.onDone = onDone
        _product = State(initialValue: product)
        _price = State(initialValue: product.priceCents == 0 ? "" : String(format: "%.2f", Double(product.priceCents) / 100))
        _stock = State(initialValue: product.stockQuantity.map(String.init) ?? "")
    }

    /// The typed price as cents, or nil if it isn't a sensible amount.
    private var priceCents: Int? {
        guard let amount = Double(price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)),
              amount >= 0.5, amount < 100_000 else { return nil }
        return Int((amount * 100).rounded())
    }

    private var edited: ShopProduct {
        var copy = product
        copy.priceCents = priceCents ?? 0
        copy.stockQuantity = Int(stock.trimmingCharacters(in: .whitespaces))
        return copy
    }

    var body: some View {
        EditSheet(
            title: isNew ? "New product" : "Edit product",
            hasChanges: isNew || edited != original,
            canSave: !product.name.trimmingCharacters(in: .whitespaces).isEmpty && priceCents != nil,
            canDelete: !isNew,
            save: {
                try await OperatorService.save(edited, by: AuthStore.shared.userID)
                await onDone()
            },
            delete: {
                try await OperatorService.deleteProduct(original.id)
                await onDone()
            }
        ) {
            LabeledField(label: "Name", text: $product.name, capitalization: .words)
            LabeledField(label: "Description", text: $product.description, multiline: true)
            LabeledField(label: "Price in dollars", text: $price, prompt: "24.99", keyboard: .decimalPad)
            if !price.isEmpty && priceCents == nil {
                Notice(text: "Type the price as a number, such as 24.99. The smallest price is 0.50.")
            }
            LabeledField(label: "Badge (optional)", text: $product.badge, prompt: "New")
            LabeledField(label: "Number in stock (leave empty if you don't track it)", text: $stock, keyboard: .numberPad)
            Toggle("Show in the shop", isOn: $product.isActive)
                .foregroundStyle(Theme.foreground)
                .frame(minHeight: 44)
            PhotoUploader(folder: "products", limit: 5, addresses: $product.imageUrls)
        }
    }
}

// MARK: Home page verses

struct OperatorMessagesView: View {
    @State private var messages: [CloudMessage] = []
    @State private var problem: String?
    @State private var editing: CloudMessage?

    var body: some View {
        OperatorList(
            title: "Home page verses",
            emptyText: "Nothing here yet, so the app shows its built-in verses. Tap + to add one.",
            items: $messages,
            problem: $problem,
            canReorder: false,
            onAdd: {
                editing = CloudMessage(id: UUID(), kind: "scripture", text: "", reference: nil, sortOrder: messages.count, isPublished: true)
            },
            onMove: { _ in },
            onOpen: { editing = $0 },
            load: load,
            onDelete: { item in
                do {
                    try await OperatorService.deleteMessage(item.id)
                    await CloudContent.shared.loadMessages()
                } catch {
                    problem = error.localizedDescription
                }
                await load()
            }
        ) { message in
            VStack(alignment: .leading, spacing: 2) {
                Text(message.text).lineLimit(2)
                Text([message.reference, message.isPublished ? nil : "Hidden"].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.foreground)
        }
        .sheet(item: $editing) { message in
            MessageForm(original: message, isNew: !messages.contains { $0.id == message.id }, onDone: load)
        }
    }

    private func load() async {
        do {
            messages = try await OperatorService.allMessages()
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }
}

private struct MessageForm: View {
    let original: CloudMessage
    let isNew: Bool
    let onDone: () async -> Void

    @State private var message: CloudMessage
    @State private var reference: String

    init(original: CloudMessage, isNew: Bool, onDone: @escaping () async -> Void) {
        self.original = original
        self.isNew = isNew
        self.onDone = onDone
        _message = State(initialValue: original)
        _reference = State(initialValue: original.reference ?? "")
    }

    private var edited: CloudMessage {
        var copy = message
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        copy.reference = trimmed.isEmpty ? nil : trimmed
        return copy
    }

    var body: some View {
        EditSheet(
            title: isNew ? "New message" : "Edit message",
            hasChanges: isNew || edited != original,
            canSave: !message.text.trimmingCharacters(in: .whitespaces).isEmpty,
            canDelete: !isNew,
            save: {
                try await OperatorService.save(edited)
                await CloudContent.shared.loadMessages()
                await onDone()
            },
            delete: {
                try await OperatorService.deleteMessage(original.id)
                await CloudContent.shared.loadMessages()
                await onDone()
            }
        ) {
            Picker("Kind", selection: $message.kind) {
                Text("Scripture").tag("scripture")
                Text("Slogan").tag("slogan")
                Text("Mission").tag("mission")
            }
            .pickerStyle(.segmented)
            LabeledField(label: "Text", text: $message.text, multiline: true)
            Text("\(message.text.count) characters. About 140 fit on the home page.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            if message.kind == "scripture" {
                LabeledField(label: "Reference", text: $reference, prompt: "John 4:14 (KJV)", capitalization: .words)
            }
            Toggle("Show on the home page", isOn: $message.isPublished)
                .foregroundStyle(Theme.foreground)
                .frame(minHeight: 44)

            // How it will look on the home page.
            Card {
                Text("Preview").font(.subheadline).foregroundStyle(Theme.muted)
                Text(message.kind == "scripture" ? "\u{201C}\(message.text)\u{201D}" : message.text)
                    .font(message.kind == "scripture" ? .callout.italic() : .callout.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                if message.kind == "scripture", !reference.isEmpty {
                    Text(reference).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

// MARK: Community stories

struct OperatorStoriesView: View {
    @State private var stories: [CommunityStory] = []
    @State private var problem: String?
    @State private var editing: CommunityStory?

    var body: some View {
        OperatorList(
            title: "Community stories",
            emptyText: "No stories yet. Tap + to write the first one.",
            items: $stories,
            problem: $problem,
            canReorder: false,
            onAdd: {
                editing = CommunityStory(id: UUID(), title: "", body: "", imageUrl: nil, location: nil, isPublished: false, publishedAt: Date())
            },
            onMove: { _ in },
            onOpen: { editing = $0 },
            load: load,
            onDelete: { item in
                do {
                    try await OperatorService.deleteStory(item.id)
                    await CloudContent.shared.loadStories()
                } catch {
                    problem = error.localizedDescription
                }
                await load()
            }
        ) { story in
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title).font(.headline)
                Text("\(story.publishedAt.formatted(date: .abbreviated, time: .omitted)) · \(story.isPublished ? "Published" : "Draft")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.foreground)
        }
        .sheet(item: $editing) { story in
            StoryForm(original: story, isNew: !stories.contains { $0.id == story.id }, onDone: load)
        }
    }

    private func load() async {
        do {
            stories = try await OperatorService.allStories()
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }
}

private struct StoryForm: View {
    let original: CommunityStory
    let isNew: Bool
    let onDone: () async -> Void

    @State private var story: CommunityStory
    @State private var location: String
    @State private var photos: [String]

    init(original: CommunityStory, isNew: Bool, onDone: @escaping () async -> Void) {
        self.original = original
        self.isNew = isNew
        self.onDone = onDone
        _story = State(initialValue: original)
        _location = State(initialValue: original.location ?? "")
        _photos = State(initialValue: original.imageUrl.map { [$0] } ?? [])
    }

    private var edited: CommunityStory {
        var copy = story
        let trimmed = location.trimmingCharacters(in: .whitespaces)
        copy.location = trimmed.isEmpty ? nil : trimmed
        copy.imageUrl = photos.first
        return copy
    }

    var body: some View {
        EditSheet(
            title: isNew ? "New story" : "Edit story",
            hasChanges: isNew || edited != original,
            canSave: !story.title.trimmingCharacters(in: .whitespaces).isEmpty,
            canDelete: !isNew,
            save: {
                try await OperatorService.save(edited)
                await CloudContent.shared.loadStories()
                await onDone()
            },
            delete: {
                try await OperatorService.deleteStory(original.id)
                await CloudContent.shared.loadStories()
                await onDone()
            }
        ) {
            LabeledField(label: "Title", text: $story.title)
            LabeledField(label: "Where (optional)", text: $location, prompt: "Malawi", capitalization: .words)
            LabeledField(label: "Story", text: $story.body, multiline: true)
            PhotoUploader(folder: "stories", limit: 1, addresses: $photos)
            Toggle("Published (visible to everyone)", isOn: $story.isPublished)
                .foregroundStyle(Theme.foreground)
                .frame(minHeight: 44)
        }
    }
}

// MARK: Orders

struct OperatorOrdersView: View {
    @State private var orders: [Order] = []
    @State private var filter = "all"
    @State private var problem: String?
    @State private var hasLoaded = false

    var body: some View {
        PageScroll {
            PageTitle("Orders")
            OperatorBanner()

            Picker("Show", selection: $filter) {
                Text("All").tag("all")
                Text("Paid").tag("paid")
                Text("Shipped").tag("shipped")
                Text("Delivered").tag("delivered")
                Text("Cancelled").tag("cancelled")
            }
            .pickerStyle(.menu)
            .tint(Theme.foreground)
            .frame(minHeight: 44)

            if let problem {
                Notice(text: problem)
            } else if hasLoaded && orders.isEmpty {
                Text("No orders here.").foregroundStyle(Theme.muted)
            }

            ForEach(orders) { order in
                NavigationLink(value: AppRoute.operatorOrder(order)) {
                    OrderRow(order: order)
                }
                .buttonStyle(.plain)
            }
        }
        .refreshable { await load() }
        .task(id: filter) { await load() }
    }

    private func load() async {
        do {
            orders = try await OrdersService.all(status: filter == "all" ? nil : filter)
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
        hasLoaded = true
    }
}

struct OperatorOrderView: View {
    @State private var order: Order
    @State private var carrier: String
    @State private var tracking: String
    @State private var notice: (text: String, isProblem: Bool)?
    @State private var confirmingCancel = false

    init(order: Order) {
        _order = State(initialValue: order)
        _carrier = State(initialValue: order.shippingCarrier ?? OrdersService.carriers[0])
        _tracking = State(initialValue: order.trackingUrl ?? "")
    }

    private var trackingIsValid: Bool { AppLinks.webURL(tracking) != nil }

    var body: some View {
        PageScroll {
            PageTitle("Order #\(String(order.orderNumber))")
            OperatorBanner()
            Text("\(order.createdAt.formatted(date: .long, time: .shortened)) · \(order.statusLabel)")
                .foregroundStyle(Theme.muted)

            OrderSummary(order: order)

            if let email = order.contactEmail {
                Card {
                    SectionHeading("Contact")
                    Text(email).foregroundStyle(Theme.foreground).textSelection(.enabled)
                }
            }

            Card {
                SectionHeading("Shipping")
                Picker("Carrier", selection: $carrier) {
                    ForEach(OrdersService.carriers, id: \.self) { Text($0).tag($0) }
                }
                .tint(Theme.foreground)
                .frame(minHeight: 44)
                LabeledField(label: "Tracking link", text: $tracking, prompt: "https://…", keyboard: .URL, capitalization: .never)
                if !tracking.isEmpty && !trackingIsValid {
                    Notice(text: "That isn't a full web link. It should start with https://")
                }

                if order.status == "paid" {
                    Button("Save link and mark as shipped") {
                        change(status: "shipped", shippedNow: true, done: "Marked as shipped. The customer now sees Track package.")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!trackingIsValid)
                } else if order.status == "shipped" {
                    Button("Save tracking link") { change(status: nil, shippedNow: false, done: "Tracking link saved.") }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(!trackingIsValid)
                    Button("Mark as delivered") { change(status: "delivered", shippedNow: false, done: "Marked as delivered.") }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }

            if let notice {
                Notice(text: notice.text, isProblem: notice.isProblem)
            }

            if order.status == "paid" || order.status == "shipped" {
                Button("Cancel this order") { confirmingCancel = true }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("Cancel this order?", isPresented: $confirmingCancel, titleVisibility: .visible) {
            Button("Cancel the order", role: .destructive) {
                change(status: "cancelled", shippedNow: false, done: "Order cancelled. Remember to refund it in Stripe.")
            }
            Button("Keep the order", role: .cancel) {}
        } message: {
            Text("This only marks the order as cancelled. It does not return the money. Refund the payment in the Stripe dashboard.")
        }
    }

    private func change(status: String?, shippedNow: Bool, done: String) {
        Task {
            do {
                try await OrdersService.update(
                    order.id,
                    status: status,
                    carrier: trackingIsValid ? carrier : nil,
                    trackingURL: trackingIsValid ? tracking.trimmingCharacters(in: .whitespaces) : nil,
                    markShippedNow: shippedNow
                )
                if let status { order.status = status }
                notice = (done, false)
            } catch {
                notice = (error.localizedDescription, true)
            }
        }
    }
}
