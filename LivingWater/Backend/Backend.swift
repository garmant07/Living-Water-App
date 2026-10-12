import Foundation
import Supabase

// The app's connection to Supabase, the online service that holds accounts,
// content, products and orders.
//
// The address and key come from Config/BackendConfig.plist, which is not
// saved to Git. Only PUBLIC values belong there: the project address and the
// "anon" key. Secret keys (the Supabase service role key, the Stripe secret
// key) must never be put in the app; they live on the server only.

enum Backend {
    /// nil until BackendConfig.plist is filled in. The app then carries on
    /// with the content built into it.
    static let client: SupabaseClient? = {
        guard let file = Bundle.main.url(forResource: "BackendConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: file),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let address = values["SUPABASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let key = values["SUPABASE_ANON_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              let url = URL(string: address), url.scheme == "https", url.host() != nil
        else { return nil }

        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    static var isConfigured: Bool { client != nil }
}
