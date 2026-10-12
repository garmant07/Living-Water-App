import SwiftUI

// Small shared pieces used by the account, checkout and operator screens.

// A text box with its label above it.
struct LabeledField: View {
    let label: String
    @Binding var text: String
    var prompt = ""
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .sentences
    var multiline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Group {
                if isSecure {
                    SecureField(label, text: $text, prompt: promptText)
                } else if multiline {
                    TextField(label, text: $text, prompt: promptText, axis: .vertical)
                        .lineLimit(3...10)
                } else {
                    TextField(label, text: $text, prompt: promptText)
                }
            }
            .font(.body)
            .foregroundStyle(Theme.foreground)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(keyboard != .default || isSecure)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 50)
            .background(Theme.deep, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
            .accessibilityLabel(label)
        }
    }

    private var promptText: Text? {
        prompt.isEmpty ? nil : Text(prompt).foregroundStyle(Theme.muted.opacity(0.6))
    }
}

// A short message in a panel: a problem, or a confirmation that something saved.
struct Notice: View {
    let text: String
    var isProblem = true

    var body: some View {
        Label(text, systemImage: isProblem ? "exclamationmark.circle" : "checkmark.circle")
            .font(.subheadline)
            .foregroundStyle(Theme.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.deep, in: RoundedRectangle(cornerRadius: 14))
    }
}

// Shown across the top of every operator screen, so it is always clear that
// changes made here are live for every customer.
struct OperatorBanner: View {
    var body: some View {
        Label("Operator tools. Changes here are live for everyone.", systemImage: "wrench.and.screwdriver")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
    }
}

// The usual page frame: scrolling content on the app's blue.
struct PageScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PageTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(Theme.foreground)
            .accessibilityAddTraits(.isHeader)
    }
}

// A photo from the web. A plain blue panel shows while it loads, and a water
// drop if there is no photo or it fails. Never a broken image.
struct RemotePhoto: View {
    let address: String?

    var body: some View {
        if let url = address.flatMap(AppLinks.webURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    fallback
                default:
                    Theme.widget
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Theme.widget.overlay {
            Image(systemName: "drop")
                .font(.system(size: 40))
                .foregroundStyle(Theme.foreground.opacity(0.85))
        }
    }
}
