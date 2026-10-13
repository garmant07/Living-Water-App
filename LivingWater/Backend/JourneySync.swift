import Foundation
import Supabase

// Keeps a signed-in person's saved bottles in their account, so the Journey
// follows them to a new phone. Without an account nothing changes: bottles
// stay on the phone only.
//
// Needs the saved_bottles table from supabase/schema.sql. Until that exists,
// every call here quietly does nothing and the Journey works as before.

@MainActor
enum JourneySync {
    private static let journey = JourneyStore.shared

    private struct Upload: Encodable {
        let userID: String
        let code: String
        let savedAt: String

        enum CodingKeys: String, CodingKey {
            case code
            case userID = "user_id"
            case savedAt = "saved_at"
        }

        init(_ bottle: SavedBottle, for userID: UUID) {
            self.userID = userID.uuidString.lowercased()
            code = bottle.code
            savedAt = ISO8601DateFormatter().string(from: bottle.savedAt)
        }
    }

    /// Brings the phone and the account into step. Called when someone signs
    /// in and each time the app opens while signed in.
    static func refresh(for userID: UUID) async {
        guard let client = Backend.client else { return }
        guard let online: [CloudBottle] = try? await client.from("saved_bottles")
            .select("code, saved_at")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        else { return }

        // Bottles saved on this phone that the account hasn't seen yet go up.
        let toUpload = journey.merge(online: online)
        guard !toUpload.isEmpty else { return }
        let uploaded = (try? await client.from("saved_bottles")
            .upsert(toUpload.map { Upload($0, for: userID) }, onConflict: "user_id,code")
            .execute()) != nil
        if uploaded { journey.markSynced(toUpload.map(\.code)) }
    }

    static func saved(_ bottle: SavedBottle) {
        guard let client = Backend.client, let userID = AuthStore.shared.userID else { return }
        Task {
            let uploaded = (try? await client.from("saved_bottles")
                .upsert(Upload(bottle, for: userID), onConflict: "user_id,code")
                .execute()) != nil
            if uploaded { journey.markSynced([bottle.code]) }
        }
    }

    static func removed(_ code: String) {
        guard let client = Backend.client, let userID = AuthStore.shared.userID else { return }
        Task {
            _ = try? await client.from("saved_bottles")
                .delete()
                .eq("user_id", value: userID.uuidString)
                .eq("code", value: code)
                .execute()
        }
    }
}
