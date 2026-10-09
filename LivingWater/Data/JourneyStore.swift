import Foundation
import Observation

// Remembers which bottles this person has saved. Everything stays on the
// phone; nothing is sent anywhere. Accounts that sync across devices can
// replace the saving and loading here later.

struct SavedBottle: Codable, Hashable {
    let code: String
    let savedAt: Date
}

@Observable
final class JourneyStore {
    static let shared = JourneyStore()

    private(set) var bottles: [SavedBottle] = []

    private let storageKey = "journey.savedBottles"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([SavedBottle].self, from: data) else { return }
        bottles = saved
    }

    func isSaved(_ code: String) -> Bool {
        bottles.contains { $0.code == code }
    }

    func save(_ code: String) {
        guard !isSaved(code) else { return }
        bottles.append(SavedBottle(code: code, savedAt: Date()))
        persist()
    }

    func remove(_ code: String) {
        bottles.removeAll { $0.code == code }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bottles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
