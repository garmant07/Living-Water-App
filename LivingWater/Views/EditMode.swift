import SwiftUI

// Edit Mode: lets an operator change the app's words from the pages
// themselves. Pencils appear next to anything that can be changed. Customers
// never see any of this, and the database refuses a save from anyone who
// isn't an operator.

/// true while a signed-in operator has Edit Mode switched on.
@MainActor
private var isEditingNow: Bool {
    CloudContent.shared.isEditing && AuthStore.shared.isOperator
}

// The bar across the bottom of every page while Edit Mode is on.
struct EditModeBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Label("Edit Mode. Tap a pencil to change it.", systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Done") { CloudContent.shared.isEditing = false }
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .overlay(Capsule().stroke(Theme.background, lineWidth: 1.5))
                .accessibilityLabel("Turn off Edit Mode")
        }
        .foregroundStyle(Theme.background)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.accent)
    }
}

// A piece of page text the team can reword. It shows their wording when
// there is some, and the built-in wording otherwise.
struct EditableText: View {
    let key: String
    let fallback: String
    /// What the edit page calls this text, e.g. "Shop introduction".
    let name: String

    @State private var isOpen = false
    private let content = CloudContent.shared

    var body: some View {
        let text = content.text(key, fallback: fallback)
        if isEditingNow {
            HStack(alignment: .top, spacing: 4) {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { isOpen = true } label: {
                    PencilBadge()
                }
                .accessibilityLabel("Edit \(name)")
            }
            .sheet(isPresented: $isOpen) {
                TextBlockForm(key: key, name: name, original: text, fallback: fallback)
            }
        } else {
            Text(text)
        }
    }
}

// A button, shown only in Edit Mode, that jumps to one of the operator's
// editing pages: "Edit products" on the Shop, for example.
struct EditShortcut: View {
    let title: String
    let route: AppRoute

    @Environment(Router.self) private var router

    var body: some View {
        if isEditingNow {
            Button {
                router.path.append(route)
            } label: {
                Label(title, systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Theme.accent, in: Capsule())
            }
        }
    }
}

private struct PencilBadge: View {
    var body: some View {
        Image(systemName: "pencil")
            .font(.body.weight(.bold))
            .foregroundStyle(Theme.background)
            .frame(width: 32, height: 32)
            .background(Theme.accent, in: Circle())
            .frame(width: 44, height: 44)
    }
}

// The page for rewording one piece of text.
private struct TextBlockForm: View {
    let key: String
    let name: String
    let original: String
    let fallback: String

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isWorking = false
    @State private var problem: String?

    init(key: String, name: String, original: String, fallback: String) {
        self.key = key
        self.name = name
        self.original = original
        self.fallback = fallback
        _text = State(initialValue: original)
    }

    var body: some View {
        NavigationStack {
            PageScroll {
                OperatorBanner()
                LabeledField(label: name, text: $text, multiline: true)
                Text("Leave the box empty to go back to the original wording:")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                Text(fallback)
                    .font(.footnote.italic())
                    .foregroundStyle(Theme.muted)
                if let problem {
                    Notice(text: problem)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit text")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text == original || isWorking)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        isWorking = true
        problem = nil
        Task {
            do {
                try await OperatorService.saveText(text.trimmingCharacters(in: .whitespacesAndNewlines), key: key)
                await CloudContent.shared.loadBlocks()
                dismiss()
            } catch {
                problem = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// Asks for a new password after someone taps the link in a reset email.
struct NewPasswordSheet: View {
    @State private var password = ""
    @State private var isWorking = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            PageScroll {
                PageTitle("Choose a new password")
                LabeledField(
                    label: "New password (at least 8 characters)",
                    text: $password,
                    isSecure: true,
                    contentType: .newPassword,
                    capitalization: .never
                )
                if let problem {
                    Notice(text: problem)
                }
                Button {
                    save()
                } label: {
                    if isWorking {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("Save password")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(password.count < 8 || isWorking)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { AuthStore.shared.needsNewPassword = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        isWorking = true
        problem = nil
        Task {
            do {
                try await AuthStore.shared.setNewPassword(password)
            } catch {
                problem = error.localizedDescription
            }
            isWorking = false
        }
    }
}
