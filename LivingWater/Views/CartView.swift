import SwiftUI
import StripePaymentSheet

// The cart: what's in it, how many of each, and the way on to checkout.
struct CartView: View {
    @Environment(Router.self) private var router
    @State private var showingSignIn = false

    private let cart = CartStore.shared
    private let auth = AuthStore.shared

    var body: some View {
        PageScroll {
            PageTitle("Your cart")

            if cart.lines.isEmpty {
                Card {
                    Text("Your cart is empty")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text("Add something from the shop and it will appear here.")
                        .foregroundStyle(Theme.muted)
                }
            } else {
                ForEach(cart.lines) { line in
                    Card {
                        HStack(alignment: .top, spacing: 14) {
                            RemotePhoto(address: line.product.imageUrls.first)
                                .frame(width: 72, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.product.name)
                                    .font(.headline)
                                    .foregroundStyle(Theme.foreground)
                                Text(Format.price(cents: line.product.priceCents))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Stepper(value: Binding(
                            get: { line.quantity },
                            set: { cart.setQuantity($0, for: line.id) }
                        ), in: 0...99) {
                            Text("Quantity: \(line.quantity)")
                                .foregroundStyle(Theme.foreground)
                        }
                        .frame(minHeight: 44)
                        Button("Remove", role: .destructive) { cart.setQuantity(0, for: line.id) }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Remove \(line.product.name)")
                    }
                }

                Card {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(Format.price(cents: cart.subtotalCents)).fontWeight(.semibold)
                    }
                    .font(.title3)
                    .foregroundStyle(Theme.foreground)
                    Text("Shipping and any tax are worked out at checkout.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }

                if !Backend.isConfigured {
                    Notice(text: "Checkout isn't switched on yet. You can fill the cart, but you can't pay.")
                } else {
                    Button(auth.isSignedIn ? "Check out" : "Sign in to check out") {
                        if auth.isSignedIn {
                            router.path.append(AppRoute.checkout)
                        } else {
                            showingSignIn = true
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        // Signing in happens on a sheet, so the cart is still here afterwards.
        .sheet(isPresented: $showingSignIn) {
            NavigationStack {
                PageScroll {
                    PageTitle("Sign in to check out")
                    SignInForm(onSignedIn: { showingSignIn = false })
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showingSignIn = false }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// Checkout: the shipping address, then Stripe's payment sheet. The server
// decides the prices and the total; the app only shows what it is told.
struct CheckoutView: View {
    @Environment(Router.self) private var router

    @State private var address = CheckoutRequest.Address()
    @State private var email = ""
    @State private var phone = ""
    @State private var isWorking = false
    @State private var problem: String?
    @State private var quote: CheckoutResponse?
    @State private var paymentSheet: PaymentSheet?
    @State private var showingPayment = false
    @State private var isPaid = false

    private let cart = CartStore.shared
    private let auth = AuthStore.shared

    private var addressIsComplete: Bool {
        ![address.name, address.line1, address.city, address.state, address.postalCode, email]
            .contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        PageScroll {
            if isPaid, let quote {
                confirmation(quote)
            } else {
                form
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(isPaid)
        .onAppear {
            if email.isEmpty { email = auth.email ?? "" }
            if address.name.isEmpty { address.name = auth.displayName }
        }
        .background {
            if let paymentSheet {
                Color.clear.paymentSheet(isPresented: $showingPayment, paymentSheet: paymentSheet, onCompletion: finish)
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        PageTitle("Checkout")

        Card {
            SectionHeading("Ship to")
            LabeledField(label: "Full name", text: $address.name, contentType: .name, capitalization: .words)
            LabeledField(label: "Address", text: $address.line1, contentType: .streetAddressLine1, capitalization: .words)
            LabeledField(label: "Apartment, suite (optional)", text: $address.line2, contentType: .streetAddressLine2, capitalization: .words)
            LabeledField(label: "City", text: $address.city, contentType: .addressCity, capitalization: .words)
            LabeledField(label: "State", text: $address.state, contentType: .addressState, capitalization: .characters)
            LabeledField(label: "ZIP code", text: $address.postalCode, keyboard: .numbersAndPunctuation, contentType: .postalCode)
            Text("We ship within the United States.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }

        Card {
            SectionHeading("Contact")
            LabeledField(label: "Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress, capitalization: .never)
            LabeledField(label: "Phone (optional)", text: $phone, keyboard: .phonePad, contentType: .telephoneNumber)
        }

        Card {
            HStack {
                Text("Subtotal")
                Spacer()
                Text(Format.price(cents: cart.subtotalCents)).fontWeight(.semibold)
            }
            .foregroundStyle(Theme.foreground)
            Text("You'll see shipping, tax and the final total before you pay.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }

        if let problem {
            Notice(text: problem)
        }

        Button {
            Task { await startPayment() }
        } label: {
            if isWorking {
                ProgressView().tint(Theme.background)
            } else {
                Text("Continue to payment")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!addressIsComplete || isWorking || cart.lines.isEmpty)

        policyLinks
    }

    private var policyLinks: some View {
        // PLACEHOLDER until the policies are written and their addresses added to AppLinks.
        VStack(alignment: .leading, spacing: 0) {
            if let terms = AppLinks.terms {
                Link("Terms of Sale and Refund Policy", destination: terms).frame(minHeight: 44)
            }
            if let privacy = AppLinks.privacyPolicy {
                Link("Privacy Policy", destination: privacy).frame(minHeight: 44)
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.foreground)
    }

    /// Asks the server to price the order, then shows Stripe's payment sheet.
    private func startPayment() async {
        guard let key = Backend.stripePublishableKey else {
            problem = "Payments aren't switched on yet."
            return
        }
        isWorking = true
        problem = nil
        defer { isWorking = false }

        let request = CheckoutRequest(
            items: cart.lines.map { .init(productId: $0.product.id, quantity: $0.quantity) },
            shipping: address,
            contactEmail: email.trimmingCharacters(in: .whitespaces),
            contactPhone: phone.isEmpty ? nil : phone
        )
        do {
            let response = try await OrdersService.startCheckout(request)
            STPAPIClient.shared.publishableKey = key
            var settings = PaymentSheet.Configuration()
            settings.merchantDisplayName = "Living Water Co."
            // TODO: switch on Apple Pay here once the paid Apple Developer account
            // and a merchant ID exist: settings.applePay = .init(merchantId:merchantCountryCode:)
            quote = response
            paymentSheet = PaymentSheet(paymentIntentClientSecret: response.clientSecret, configuration: settings)
            showingPayment = true
        } catch {
            problem = error.localizedDescription
        }
    }

    private func finish(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            cart.clear()
            isPaid = true
        case .canceled:
            problem = "Payment wasn't completed. Nothing was charged."
        case .failed:
            problem = "The payment didn't go through. Nothing was charged. Please try again or use another card."
        }
    }

    @ViewBuilder
    private func confirmation(_ quote: CheckoutResponse) -> some View {
        Image(systemName: "checkmark.circle")
            .font(.system(size: 64))
            .foregroundStyle(Theme.foreground)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .accessibilityHidden(true)
        PageTitle("Thank you")
        Text("Order #\(String(quote.orderNumber))")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.foreground)
        Card {
            totalRow("Subtotal", quote.subtotalCents)
            totalRow("Shipping", quote.shippingCents)
            totalRow("Tax", quote.taxCents)
            Divider().overlay(Theme.border)
            totalRow("Total", quote.totalCents).fontWeight(.semibold)
        }
        Text("We'll let you know when it ships. You can follow this order under your account.")
            .foregroundStyle(Theme.foreground)
        Button("Done") { router.goHome() }
            .buttonStyle(PrimaryButtonStyle())
    }

    private func totalRow(_ label: String, _ cents: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(Format.price(cents: cents))
        }
        .foregroundStyle(Theme.foreground)
    }
}
