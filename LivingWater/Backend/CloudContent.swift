import Foundation
import Observation
import Supabase
import UIKit

// Content that operators can change without a new app version: the home page
// verses, the community stories, the partners' wording and short page texts. Loaded when the app opens and remembered
// on the phone. Until Supabase is connected, the app's built-in content is used.

@MainActor
@Observable
final class CloudContent {
    static let shared = CloudContent()

    /// nil means "use the verses built into the app".
    private(set) var homeMessages: [HomeMessage]?
    private(set) var stories: [CommunityStory] = []
    private(set) var storiesFailed = false
    /// Short page texts the team has changed, by key. See `text(_:fallback:)`.
    private(set) var blocks: [String: String] = [:]

    /// On while an operator is changing the app's words from the pages
    /// themselves. It only shows the pencils; the database decides who can save.
    var isEditing = false

    private init() {
        guard Backend.isConfigured else { return }
        if let saved: [ContentBlock] = DiskCache.load("blocks") {
            blocks = Dictionary(saved.map { ($0.key, $0.text) }, uniquingKeysWith: { $1 })
        }
        if let saved: [CloudPartner] = DiskCache.load("partners") {
            DataStore.shared.apply(saved)
        }
        if let saved: [CloudMessage] = DiskCache.load("messages"), !saved.isEmpty {
            homeMessages = saved.map(\.asHomeMessage)
        }
        stories = DiskCache.load("stories") ?? []
    }

    func load() async {
        await loadMessages()
        await loadStories()
        await loadBlocks()
        await loadPartners()
    }

    /// The team's wording for a piece of page text, or the built-in wording
    /// when they haven't changed it.
    func text(_ key: String, fallback: String) -> String {
        guard let text = blocks[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return fallback
        }
        return text
    }

    func loadBlocks() async {
        guard let client = Backend.client else { return }
        if let rows: [ContentBlock] = try? await client.from("content_blocks").select("key, text").execute().value {
            blocks = Dictionary(rows.map { ($0.key, $0.text) }, uniquingKeysWith: { $1 })
            DiskCache.save(rows, as: "blocks")
        }
    }

    func loadPartners() async {
        guard let client = Backend.client else { return }
        if let rows: [CloudPartner] = try? await client.from("partners").select().execute().value {
            DataStore.shared.apply(rows)
            DiskCache.save(rows, as: "partners")
        }
    }

    func loadMessages() async {
        guard let client = Backend.client else { return }
        if let rows: [CloudMessage] = try? await client.from("home_messages")
            .select()
            .eq("is_published", value: true)
            .order("sort_order")
            .execute()
            .value, !rows.isEmpty {
            homeMessages = rows.map(\.asHomeMessage)
            DiskCache.save(rows, as: "messages")
        }
    }

    func loadStories() async {
        guard let client = Backend.client else { return }
        do {
            let rows: [CommunityStory] = try await client.from("community_stories")
                .select()
                .eq("is_published", value: true)
                .order("published_at", ascending: false)
                .execute()
                .value
            stories = rows
            storiesFailed = false
            DiskCache.save(rows, as: "stories")
        } catch {
            storiesFailed = stories.isEmpty
        }
    }
}

/// Shrinks a photo and uploads it. Only operators are allowed to; the
/// storage rules refuse anyone else.
enum ImageUploader {
    /// Returns the photo's public web address.
    static func upload(_ original: Data, folder: String) async throws -> String {
        guard let client = Backend.client else { throw FriendlyError.notConnected }
        guard let image = UIImage(data: original) else {
            throw FriendlyError(message: "That photo couldn't be read. Try a different one.")
        }

        // No bigger than 2000 points on its long edge, saved as an 80% JPEG.
        let longEdge = max(image.size.width, image.size.height)
        let scale = min(2000 / max(longEdge, 1), 1)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
            throw FriendlyError(message: "That photo couldn't be prepared. Try a different one.")
        }

        let path = "\(folder)/\(UUID().uuidString).jpg"
        do {
            try await client.storage.from(Backend.imageBucket)
                .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
            return try client.storage.from(Backend.imageBucket).getPublicURL(path: path).absoluteString
        } catch {
            throw FriendlyError(message: "The photo didn't upload. Check your connection and try again.")
        }
    }
}
