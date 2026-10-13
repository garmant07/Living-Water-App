import SwiftUI

// The Privacy Policy, shown inside the app.
//
// DRAFT: written to match what the app actually collects, but not yet read
// by a lawyer. Before launch: have it reviewed, fill in the contact email and
// the date below, and publish the same words at a web address for Apple.

enum PrivacyPolicy {
    // TODO: the email address customers should write to about their data.
    static let contactEmail = ""
    // TODO: the date this policy takes effect, e.g. "January 1, 2027".
    static let effectiveDate = ""

    struct Section: Identifiable {
        let title: String
        let paragraphs: [String]
        var points: [String] = []
        var id: String { title }
    }

    static let summary = [
        "We collect only what we need to run your account and send your orders.",
        "Your card details go straight to Stripe. We never see or store them.",
        "Your camera and location are used on your phone only. Neither is saved or sent to us.",
        "We don't sell your information, show ads, or track you across other apps.",
        "You can delete your account at any time from the Account page.",
    ]

    static let sections = [
        Section(
            title: "Who we are",
            paragraphs: [
                "Living Water Co. sells bottled water and uses what it earns to help bring clean water to communities in need. This policy explains what information the Living Water app collects, why, and the choices you have.",
                "You can browse the whole app without an account. An account is only needed to buy from the shop and see your orders.",
            ]
        ),
        Section(
            title: "What we collect",
            paragraphs: ["We collect information only when you give it to us:"],
            points: [
                "Account: your email address, the name you choose, and a password. Your password is stored in a scrambled form that we cannot read.",
                "Orders: the name, shipping address, email and (if you add one) phone number for each order, along with what you bought and what you paid.",
                "Saved bottles: if you are signed in, the codes of the bottles you save and when you saved them, so your journey follows you to a new phone.",
            ]
        ),
        Section(
            title: "What stays on your phone",
            paragraphs: ["Some things never leave your phone and are never sent to us:"],
            points: [
                "Camera: used only to read the QR code on a bottle. No photos or video are saved or sent.",
                "Location: if you allow it, your approximate location is used only to sort the clean water work nearest to you. It is not saved or sent.",
                "Your cart, and any bottles you save while signed out.",
            ]
        ),
        Section(
            title: "Payments",
            paragraphs: [
                "Payments are handled by Stripe. When you pay, your card details go directly from your phone to Stripe. They never pass through our systems and we never see or store them.",
                "Stripe also collects some information about your phone and the payment to help prevent fraud. Stripe's own privacy policy explains how it uses that information.",
            ]
        ),
        Section(
            title: "How we use your information",
            paragraphs: ["We use your information to:"],
            points: [
                "Create and look after your account.",
                "Take payment for, pack, ship and track your orders.",
                "Answer you when you get in touch.",
                "Keep the records the law requires of a business, such as records of sales.",
            ]
        ),
        Section(
            title: "Who we share it with",
            paragraphs: [
                "We do not sell your information, and we do not share it for advertising. We share it only with the companies that help us run the app and deliver your order:",
            ],
            points: [
                "Supabase, which stores accounts, orders and the app's content for us.",
                "Stripe, which processes payments.",
                "The shipping carrier, which receives your name and address so it can deliver your order.",
            ]
        ),
        Section(
            title: "Donations",
            paragraphs: [
                "When you choose to donate, the app opens our ministry partner's own website in Safari. Living Water Co. does not take or handle your gift and does not receive any information you give the partner. The partner's own privacy policy applies there.",
            ]
        ),
        Section(
            title: "No ads, no tracking",
            paragraphs: [
                "The app contains no advertising and no advertising trackers. We do not follow what you do in other apps or on other websites.",
            ]
        ),
        Section(
            title: "Keeping and deleting your information",
            paragraphs: [
                "We keep your account information for as long as you have an account.",
                "You can delete your account at any time: open the Account page and tap Delete account. Your sign-in, your name and your saved bottles are removed for good. Records of past orders are kept for our accounts, with your name, address, email and phone number removed so they can no longer be tied to you.",
                "You can also ask us for a copy of your information, or ask us to correct it, by writing to us.",
            ]
        ),
        Section(
            title: "Keeping it safe",
            paragraphs: [
                "Information travels between your phone and our systems over an encrypted connection. Each person can see only their own account and orders. Order details can be seen by the Living Water Co. team members who pack and ship orders. No system is perfectly secure, but we work to protect what you trust us with.",
            ]
        ),
        Section(
            title: "Children",
            paragraphs: [
                "The app is not directed to children under 13, and we do not knowingly collect information from them. If you believe a child has given us information, write to us and we will remove it.",
            ]
        ),
        Section(
            title: "Where your information is kept",
            paragraphs: [
                "Living Water Co. is based in the United States, and we ship within the United States. Your information is stored and handled by the companies named above, in the United States or in other countries where they operate.",
            ]
        ),
        Section(
            title: "Changes to this policy",
            paragraphs: [
                "If we change this policy, the new version will appear here with a new date.",
            ]
        ),
    ]
}

struct PrivacyPolicyView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 8) {
                PageTitle("Privacy Policy")
                Text(PrivacyPolicy.effectiveDate.isEmpty
                    ? "Draft. Not yet in effect."
                    : "In effect from \(PrivacyPolicy.effectiveDate)")
                    .foregroundStyle(Theme.muted)
            }

            Card {
                SectionHeading("In short")
                ForEach(PrivacyPolicy.summary, id: \.self) { point in
                    bullet(point)
                }
            }

            ForEach(PrivacyPolicy.sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(section.title)
                    ForEach(section.paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .lineSpacing(4)
                            .foregroundStyle(Theme.foreground)
                    }
                    ForEach(section.points, id: \.self) { point in
                        bullet(point)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionHeading("Contact us")
                if let link = URL(string: "mailto:\(PrivacyPolicy.contactEmail)"), !PrivacyPolicy.contactEmail.isEmpty {
                    Text("Questions about this policy or your information? Write to us.")
                        .foregroundStyle(Theme.foreground)
                    Button(PrivacyPolicy.contactEmail) { openURL(link) }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .frame(minHeight: 44)
                } else {
                    // PLACEHOLDER until the contact email is added above.
                    Text("Our contact details will be added here before the app launches.")
                        .foregroundStyle(Theme.foreground)
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.footnote)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(text)
                .lineSpacing(4)
                .foregroundStyle(Theme.foreground)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
