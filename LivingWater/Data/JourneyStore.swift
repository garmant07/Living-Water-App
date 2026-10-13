import Foundation
import Observation

// Remembers which bottles this person has saved. They are kept on the
// phone. When someone is signed in, JourneySync also keeps a copy in their
// account so the Journey follows them to a new phone.

struct SavedBottle: Codable, Hashable {
    let code: String
    let savedAt: Date
}

@Observable
final class JourneyStore {
    static let shared = JourneyStore()

    private(set) var bottles: [SavedBottle] = []

    private let storageKey = "journey.savedBottles"
    /// Codes the signed-in account is known to hold. This is how the phone can
    /// tell a bottle removed on another phone from one not yet uploaded.
    private let syncedKey = "journey.syncedCodes"
    private var syncedCodes: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: syncedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: syncedKey) }
    }

    private init() {
        #if DEBUG
        // For testing: launch with "-journeyPreview LW-MW-0001,LW-ET-0001" to
        // see a journey with those bottles, without saving anything.
        if let codes = UserDefaults.standard.string(forKey: "journeyPreview") {
            bottles = codes.split(separator: ",").map { SavedBottle(code: String($0), savedAt: Date()) }
            return
        }
        #endif
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([SavedBottle].self, from: data) else { return }
        bottles = saved
    }

    /// The communities these bottles supported, each one once, oldest first.
    var communities: [Community] {
        var seen = Set<String>()
        return bottles
            .compactMap { DataStore.shared.community(forBottleCode: $0.code) }
            .filter { seen.insert($0.id).inserted }
    }

    /// How far this person has come on what a personal milestone counts.
    func value(for metric: Milestone.Metric) -> Int {
        switch metric {
        case .bottlesScanned: bottles.count
        case .communities: communities.count
        case .partners: Set(communities.map(\.partnerId)).count
        case .peopleServed: communities.reduce(0) { $0 + $1.peopleServed }
        }
    }

    func isSaved(_ code: String) -> Bool {
        bottles.contains { $0.code == code }
    }

    func save(_ code: String) {
        guard !isSaved(code) else { return }
        let bottle = SavedBottle(code: code, savedAt: Date())
        bottles.append(bottle)
        persist()
        Task { @MainActor in JourneySync.saved(bottle) }
    }

    func remove(_ code: String) {
        bottles.removeAll { $0.code == code }
        syncedCodes.remove(code)
        persist()
        Task { @MainActor in JourneySync.removed(code) }
    }

    // MARK: Keeping in step with the account

    /// Combines what the account holds with what is on this phone, and
    /// returns the bottles the account still needs to be sent.
    func merge(online: [CloudBottle]) -> [SavedBottle] {
        let onlineCodes = Set(online.map(\.code))
        let known = syncedCodes

        // In the account before, but not now: it was removed on another phone.
        var merged = bottles.filter { onlineCodes.contains($0.code) || !known.contains($0.code) }
        // In the account, but not on this phone yet.
        let here = Set(merged.map(\.code))
        merged += online.filter { !here.contains($0.code) }.map { SavedBottle(code: $0.code, savedAt: $0.savedAt) }
        merged.sort { $0.savedAt < $1.savedAt }

        if merged != bottles {
            bottles = merged
            persist()
        }
        syncedCodes = onlineCodes
        return merged.filter { !onlineCodes.contains($0.code) }
    }

    func markSynced(_ codes: [String]) {
        syncedCodes.formUnion(codes)
    }

    /// Called on signing out. The bottles stay on the phone; they are simply
    /// no longer tied to an account.
    func forgetAccount() {
        syncedCodes = []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bottles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
