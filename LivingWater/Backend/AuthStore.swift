import Foundation
import Observation
import Supabase

// Who is signed in, and whether they are an operator.
// The role comes from the database and is only used to decide which buttons
// to show. The real protection is in the database's own rules, which refuse
// edits from anyone who isn't an operator no matter what the app does.

@MainActor
@Observable
final class AuthStore {
    static let shared = AuthStore()

    private(set) var userID: UUID?
    private(set) var email: String?
    private(set) var profile: Profile?

    var isSignedIn: Bool { userID != nil }

    var isOperator: Bool {
        #if DEBUG
        // For testing the operator screens' layout: launch with "-previewOperator YES".
        // This only shows the screens; the database still refuses any edit.
        if UserDefaults.standard.bool(forKey: "previewOperator") { return true }
        #endif
        return profile?.role == "operator"
    }

    var displayName: String { profile?.displayName ?? "" }

    /// true after someone taps the link in a password-reset email. The app
    /// then asks them for a new password.
    var needsNewPassword = false
    /// A short message to show after an emailed link opens the app.
    var linkNotice: String?

    /// Where emailed links send people: back into this app. The address must
    /// also be allowed in Supabase (Authentication > URL Configuration >
    /// Redirect URLs: livingwater://**). Until it is, the links fall back to
    /// Supabase's default page and the app carries on as before.
    private static let confirmLink = URL(string: "livingwater://auth/confirm")!
    private static let resetLink = URL(string: "livingwater://auth/reset")!

    private init() {}

    /// Keeps this store in step with Supabase for as long as the app runs.
    func start() async {
        guard let client = Backend.client else { return }
        for await change in client.auth.authStateChanges {
            let user = change.session?.user
            userID = user?.id
            email = user?.email
            if let user {
                await loadProfile(for: user.id)
                if change.event == .initialSession || change.event == .signedIn {
                    await JourneySync.refresh(for: user.id)
                }
            } else {
                profile = nil
                if change.event == .signedOut {
                    CloudContent.shared.isEditing = false
                    JourneyStore.shared.forgetAccount()
                }
            }
        }
    }

    /// Handles a link from a confirmation or password-reset email.
    func open(_ link: URL) async {
        guard let client = Backend.client, link.scheme == "livingwater", link.host() == "auth" else { return }
        let isReset = link.path().hasPrefix("/reset")
        do {
            try await client.auth.session(from: link)
            if isReset {
                needsNewPassword = true
            } else {
                linkNotice = "Your email is confirmed and you're signed in."
            }
        } catch {
            // The link was opened on a different phone from the one that asked
            // for it, or it has already been used.
            linkNotice = isReset
                ? "That reset link has expired or was already used. Ask for a new one from the sign-in page."
                : "Your email is confirmed. Sign in with your email and password."
        }
    }

    func setNewPassword(_ password: String) async throws {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            try await client.auth.update(user: UserAttributes(password: password))
            needsNewPassword = false
        } catch {
            throw FriendlyError(message: "We couldn't save the new password. Use at least 8 characters and try again.")
        }
    }

    private func loadProfile(for id: UUID) async {
        guard let client = Backend.client else { return }
        profile = try? await client.from("profiles").select().eq("id", value: id.uuidString).single().execute().value
    }

    func signIn(email: String, password: String) async throws {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            try await client.auth.signIn(email: email, password: password)
        } catch {
            throw FriendlyError(message: "That email and password didn't match. Check them and try again. If you just signed up, confirm your email first.")
        }
    }

    /// Returns true when the person must confirm their email before signing in.
    func signUp(name: String, email: String, password: String) async throws -> Bool {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(name)],
                redirectTo: Self.confirmLink
            )
            return response.session == nil
        } catch {
            throw FriendlyError(message: "We couldn't create the account. Check the email address, and use a password of at least 8 characters.")
        }
    }

    func sendPasswordReset(to email: String) async throws {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            try await client.auth.resetPasswordForEmail(email, redirectTo: Self.resetLink)
        } catch {
            throw FriendlyError(message: "We couldn't send the reset email. Check the address and try again.")
        }
    }

    func rename(to name: String) async throws {
        guard let client = Backend.client, let userID else { throw FriendlyError.notConnected }
        do {
            try await client.from("profiles").update(["display_name": name]).eq("id", value: userID.uuidString).execute()
            await loadProfile(for: userID)
        } catch {
            throw FriendlyError(message: "We couldn't save your name. Please try again.")
        }
    }

    func signOut() async {
        try? await Backend.client?.auth.signOut()
    }

    /// Deletes the account and personal details for good. See
    /// supabase/functions/delete-account for exactly what is removed.
    func deleteAccount() async throws {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            // On Supabase this function's web address is "clever-handler" (the name
            // the editor made up when it was uploaded). Its code is
            // supabase/functions/delete-account. If it is ever uploaded again under
            // the address "delete-account", change the name here to match.
            try await client.functions.invoke("clever-handler")
        } catch {
            throw FriendlyError(message: "We couldn't delete the account just now. Please try again.")
        }
        try? await client.auth.signOut(scope: .local)
    }
}
