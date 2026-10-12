import Foundation
import Supabase

// The app's connection to Supabase, the online service that holds accounts,
// content, products and orders.
//
// The address and keys come from Config/BackendConfig.plist, which is not
// saved to Git. Only PUBLIC values belong there: the Supabase project
// address, the Supabase "anon" key, and the Stripe "publishable" key.
// Secret keys (the Supabase service role key, the Stripe secret key) must
// never be put in the app; they live on the server only.

enum Backend {
    private static let settings: [String: String] = {
        guard let file = Bundle.main.url(forResource: "BackendConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: file),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return values.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }()

    /// nil until BackendConfig.plist is filled in. The app then carries on
    /// with the content built into it, and accounts and checkout stay off.
    static let client: SupabaseClient? = {
        guard let address = settings["SUPABASE_URL"],
              let key = settings["SUPABASE_ANON_KEY"], !key.isEmpty,
              let url = URL(string: address), url.scheme == "https", url.host() != nil
        else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    static var isConfigured: Bool { client != nil }

    /// Stripe's public key. nil until it is filled in.
    static var stripePublishableKey: String? {
        guard let key = settings["STRIPE_PUBLISHABLE_KEY"], key.hasPrefix("pk_") else { return nil }
        return key
    }

    /// The bucket that holds photos operators upload.
    static let imageBucket = "public-images"
}

/// A message that is safe to show a person: plain words, no error codes.
struct FriendlyError: LocalizedError {
    let message: String
    var errorDescription: String? { message }

    static let notConnected = FriendlyError(message: "This part of the app isn't switched on yet.")
}

/// Keeps the last-loaded content on the phone, so the app opens fast and
/// still shows something without a connection.
enum DiskCache {
    private static func file(_ name: String) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("cloud-\(name).json")
    }

    static func save<T: Encodable>(_ value: T, as name: String) {
        guard let file = file(name), let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: file, options: .atomic)
    }

    static func load<T: Decodable>(_ name: String) -> T? {
        guard let file = file(name), let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
