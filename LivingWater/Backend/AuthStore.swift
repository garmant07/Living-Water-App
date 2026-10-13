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
            } else {
                profile = nil
            }
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
                data: ["display_name": .string(name)]
            )
            return response.session == nil
        } catch {
            throw FriendlyError(message: "We couldn't create the account. Check the email address, and use a password of at least 8 characters.")
        }
    }

    func sendPasswordReset(to email: String) async throws {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        do {
            try await client.auth.resetPasswordForEmail(email)
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
