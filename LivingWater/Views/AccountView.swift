import SwiftUI

// The account page: sign in or create an account, and once signed in, your
// name, your orders, signing out and deleting the account.
struct AccountView: View {
    @State private var name = ""
    @State private var notice: (text: String, isProblem: Bool)?
    @State private var confirmingDelete = false
    @State private var isWorking = false

    private let auth = AuthStore.shared

    var body: some View {
        PageScroll {
            PageTitle("Account")

            if !Backend.isConfigured {
                Card {
                    Text("Accounts aren't switched on yet")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text("You can use everything else in the app without one.")
                        .foregroundStyle(Theme.muted)
                }
                // Still reachable for laying out the operator screens while building.
                if auth.isOperator { operatorLink }
            } else if auth.isSignedIn {
                signedIn
            } else {
                Text("Browsing is open to everyone. You only need an account to buy from the shop and see your orders.")
                    .foregroundStyle(Theme.muted)
                SignInForm(onSignedIn: {})
            }
        }
        .onAppear { name = auth.displayName }
        .onChange(of: auth.displayName) { _, new in name = new }
        .confirmationDialog(
            "Delete your account for good?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete my account", role: .destructive) { Task { await deleteAccount() } }
            Button("Keep my account", role: .cancel) {}
        } message: {
            Text("Your sign-in and personal details are removed and can't be brought back. Records of past orders are kept for our accounts, with your name, address and email removed.")
        }
    }

    @ViewBuilder
    private var signedIn: some View {
        Card {
            LabeledField(label: "Name", text: $name, contentType: .name, capitalization: .words)
            Text(auth.email ?? "")
                .foregroundStyle(Theme.muted)
            Button("Save name") {
                Task {
                    do {
                        try await auth.rename(to: name.trimmingCharacters(in: .whitespaces))
                        notice = ("Saved.", false)
                    } catch {
                        notice = (error.localizedDescription, true)
                    }
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(name == auth.displayName)
        }

        if let notice {
            Notice(text: notice.text, isProblem: notice.isProblem)
        }

        NavigationLink(value: AppRoute.orders) {
            row("My orders", icon: "shippingbox")
        }
        .buttonStyle(.plain)

        if auth.isOperator { operatorLink }

        Button("Sign out") { Task { await auth.signOut() } }
            .buttonStyle(SecondaryButtonStyle())

        Button {
            confirmingDelete = true
        } label: {
            if isWorking {
                ProgressView().tint(Theme.foreground)
            } else {
                Text("Delete account")
                    .font(.body.weight(.semibold))
                    .underline()
                    .foregroundStyle(Theme.foreground)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .disabled(isWorking)
    }

    private var operatorLink: some View {
        NavigationLink(value: AppRoute.operatorHome) {
            row("Operator dashboard", icon: "wrench.and.screwdriver")
        }
        .buttonStyle(.plain)
    }

    private func row(_ title: String, icon: String) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Theme.foreground)
        }
    }

    private func deleteAccount() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.deleteAccount()
        } catch {
            notice = (error.localizedDescription, true)
        }
    }
}

// The sign-in, create-account and forgot-password form.
struct SignInForm: View {
    let onSignedIn: () -> Void

    private enum Mode: String, CaseIterable {
        case signIn = "Sign in"
        case create = "Create account"
    }

    @State private var mode = Mode.signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var notice: (text: String, isProblem: Bool)?

    private let auth = AuthStore.shared

    private var canSubmit: Bool {
        email.contains("@") && password.count >= (mode == .create ? 8 : 1) && !isWorking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Sign in or create an account", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // TODO: add the "Sign in with Apple" button here once the paid Apple
            // Developer account exists. Apple requires it alongside email sign-in.

            if mode == .create {
                LabeledField(label: "Name", text: $name, contentType: .name, capitalization: .words)
            }
            LabeledField(label: "Email", text: $email, keyboard: .emailAddress, contentType: .username, capitalization: .never)
            LabeledField(
                label: mode == .create ? "Password (at least 8 characters)" : "Password",
                text: $password,
                isSecure: true,
                contentType: mode == .create ? .newPassword : .password,
                capitalization: .never
            )

            if let notice {
                Notice(text: notice.text, isProblem: notice.isProblem)
            }

            Button {
                Task { await submit() }
            } label: {
                if isWorking {
                    ProgressView().tint(Theme.background)
                } else {
                    Text(mode.rawValue)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)

            if mode == .signIn {
                Button("Forgot password?") { Task { await sendReset() } }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(minHeight: 44)
            }
        }
    }

    private func submit() async {
        isWorking = true
        notice = nil
        defer { isWorking = false }
        let address = email.trimmingCharacters(in: .whitespaces)
        do {
            if mode == .create {
                let mustConfirm = try await auth.signUp(name: name.trimmingCharacters(in: .whitespaces), email: address, password: password)
                if mustConfirm {
                    notice = ("Check your email and tap the link to confirm, then sign in here.", false)
                    mode = .signIn
                    return
                }
            } else {
                try await auth.signIn(email: address, password: password)
            }
            onSignedIn()
        } catch {
            notice = (error.localizedDescription, true)
        }
    }

    private func sendReset() async {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard address.contains("@") else {
            notice = ("Type your email above first, then tap Forgot password.", true)
            return
        }
        do {
            try await auth.sendPasswordReset(to: address)
            notice = ("If that address has an account, a reset email is on its way.", false)
        } catch {
            notice = (error.localizedDescription, true)
        }
    }
}

// MARK: Orders (customer)

/// A web page waiting to be shown in the in-app browser.
struct BrowserPage: Identifiable {
    let url: URL
    var id: URL { url }
}

// The signed-in person's orders, newest first.
struct OrdersView: View {
    @State private var orders: [Order] = []
    @State private var problem: String?
    @State private var hasLoaded = false

    private let auth = AuthStore.shared

    var body: some View {
        PageScroll {
            PageTitle("My orders")

            if let problem {
                Notice(text: problem)
            } else if !hasLoaded {
                ProgressView().tint(Theme.foreground).frame(maxWidth: .infinity)
            } else if orders.isEmpty {
                Text("You haven't ordered anything yet.")
                    .foregroundStyle(Theme.muted)
            }

            ForEach(orders) { order in
                NavigationLink(value: AppRoute.order(order)) {
                    OrderRow(order: order)
                }
                .buttonStyle(.plain)
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        guard let userID = auth.userID else { return }
        do {
            orders = try await OrdersService.mine(userID: userID)
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
        hasLoaded = true
    }
}

struct OrderRow: View {
    let order: Order

    var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Order #\(String(order.orderNumber))")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Theme.foreground)
            Text("\(order.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(Format.price(cents: order.totalCents)) · \(order.statusLabel)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

// The items, totals and address of one order. Shared by the customer's order
// page and the operator's.
struct OrderSummary: View {
    let order: Order

    var body: some View {
        Card {
            SectionHeading("Items")
            ForEach(order.items ?? []) { item in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(item.quantity) × \(item.productName)")
                    Spacer()
                    Text(Format.price(cents: item.unitPriceCents * item.quantity))
                }
                .foregroundStyle(Theme.foreground)
            }
            Divider().overlay(Theme.border)
            line("Subtotal", order.subtotalCents)
            line("Shipping", order.shippingCents)
            line("Tax", order.taxCents)
            line("Total", order.totalCents).fontWeight(.semibold)
        }

        if !order.addressLines.isEmpty {
            Card {
                SectionHeading("Ship to")
                ForEach(order.addressLines, id: \.self) { Text($0).foregroundStyle(Theme.foreground) }
            }
        }
    }

    private func line(_ label: String, _ cents: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(Format.price(cents: cents))
        }
        .foregroundStyle(Theme.foreground)
    }
}

// One order, as the customer sees it: where it's up to, and Track package
// once an operator has added the tracking link.
struct OrderDetailView: View {
    let order: Order

    @State private var browserPage: BrowserPage?

    private let steps = ["paid", "shipped", "delivered"]

    var body: some View {
        PageScroll {
            PageTitle("Order #\(String(order.orderNumber))")
            Text(order.createdAt.formatted(date: .long, time: .omitted))
                .foregroundStyle(Theme.muted)

            Card {
                SectionHeading(order.statusLabel)
                if steps.contains(order.status) {
                    let reached = steps.firstIndex(of: order.status) ?? 0
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        Label(step.capitalized, systemImage: index <= reached ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index <= reached ? Theme.foreground : Theme.muted.opacity(0.7))
                    }
                }

                if let url = order.trackingUrl.flatMap(AppLinks.webURL) {
                    if let carrier = order.shippingCarrier, !carrier.isEmpty {
                        Text("Shipped with \(carrier)")
                            .foregroundStyle(Theme.muted)
                    }
                    Button {
                        browserPage = BrowserPage(url: url)
                    } label: {
                        Label("Track package", systemImage: "shippingbox")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if order.status == "paid" {
                    Text("We'll add a tracking link here when it ships.")
                        .foregroundStyle(Theme.muted)
                }
            }

            OrderSummary(order: order)
        }
        .fullScreenCover(item: $browserPage) { page in
            SafariView(url: page.url).ignoresSafeArea()
        }
    }
}
