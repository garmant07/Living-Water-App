import Foundation

// The one place every screen asks for data.
// Screens never read the JSON files themselves. When the data later moves to
// a server or CMS, only this file has to change.

/// Accomplished vs. still to do, for one project or for everything together.
struct Progress: Hashable {
    let raised: Int
    let goal: Int

    /// Dollars still to go. Never below zero.
    var remaining: Int { max(goal - raised, 0) }

    /// 0 to 1, for progress bars.
    var fraction: Double {
        goal > 0 ? min(Double(raised) / Double(goal), 1) : 0
    }

    /// 0 to 100, whole number.
    var percent: Int { Int((fraction * 100).rounded()) }

    var isComplete: Bool { goal > 0 && remaining == 0 }
}

struct Totals: Hashable {
    let peopleServed: Int
    let communities: Int
    let communitiesCompleted: Int
    let countries: Int
    let progress: Progress
    /// true when any number in these totals comes from sample data.
    let includesSampleData: Bool
}

final class DataStore {
    static let shared = DataStore()

    let partners: [Partner]
    let communities: [Community]
    let company: CompanyTotals
    private let allStories: [StoryUpdate]
    private let bottles: [BottleCode]
    private let allMilestones: [Milestone]

    private init() {
        partners = Self.load("partners")
        communities = Self.load("communities")
        allStories = Self.load("stories")
        bottles = Self.load("bottles")
        allMilestones = Self.load("milestones")
        company = Self.load("company")
    }

    /// Reads one JSON file from the app. A typo in a data file stops the app
    /// here with a message naming the file, so it is caught while building.
    private static func load<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            fatalError("Missing data file: \(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Could not read \(name).json: \(error)")
        }
    }

    // MARK: Partners

    func partner(id: String) -> Partner? {
        partners.first { $0.id == id }
    }

    // MARK: Communities

    func community(id: String) -> Community? {
        communities.first { $0.id == id }
    }

    func communities(forPartner partnerId: String) -> [Community] {
        communities.filter { $0.partnerId == partnerId }
    }

    func communities(inCountry country: String) -> [Community] {
        let wanted = country.trimmingCharacters(in: .whitespaces).lowercased()
        return communities.filter { $0.country.lowercased() == wanted }
    }

    /// Every country that has at least one community, A to Z.
    var countries: [String] {
        Set(communities.map(\.country)).sorted()
    }

    // MARK: Progress and totals

    func progress(for community: Community) -> Progress {
        Progress(raised: community.raisedAmount, goal: community.goalAmount)
    }

    /// The big-picture numbers for the whole app.
    var totals: Totals {
        let base = totals(for: communities)
        return Totals(
            peopleServed: base.peopleServed,
            communities: base.communities,
            communitiesCompleted: base.communitiesCompleted,
            countries: base.countries,
            progress: base.progress,
            includesSampleData: base.includesSampleData || company.isSample
        )
    }

    /// The same numbers, for one partner's communities only.
    func totals(forPartner partnerId: String) -> Totals {
        totals(for: communities(forPartner: partnerId))
    }

    private func totals(for list: [Community]) -> Totals {
        Totals(
            peopleServed: list.reduce(0) { $0 + $1.peopleServed },
            communities: list.count,
            communitiesCompleted: list.filter { $0.status == .completed }.count,
            countries: Set(list.map(\.country)).count,
            progress: Progress(
                raised: list.reduce(0) { $0 + $1.raisedAmount },
                goal: list.reduce(0) { $0 + $1.goalAmount }
            ),
            includesSampleData: list.contains { $0.isSample }
        )
    }

    // MARK: Stories

    /// All field updates, newest first.
    var stories: [StoryUpdate] {
        allStories.sorted { $0.date > $1.date }
    }

    func stories(forCommunity communityId: String) -> [StoryUpdate] {
        stories.filter { $0.communityId == communityId }
    }

    // MARK: Bottles

    /// Tidies a typed or scanned code so " lw-mw-0001 " matches "LW-MW-0001".
    func normalizeBottleCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    func bottle(code: String) -> BottleCode? {
        let wanted = normalizeBottleCode(code)
        return bottles.first { $0.code == wanted }
    }

    /// The community a bottle supported, or nil for an unknown code.
    func community(forBottleCode code: String) -> Community? {
        bottle(code: code).flatMap { community(id: $0.communityId) }
    }

    // MARK: Milestones

    func milestones(ofType type: Milestone.Kind? = nil) -> [Milestone] {
        guard let type else { return allMilestones }
        return allMilestones.filter { $0.type == type }
    }

    /// Where everyone together stands today on what a shared milestone counts.
    /// nil for personal milestones, which depend on one person's own bottles.
    func sharedValue(for metric: Milestone.Metric) -> Int? {
        switch metric {
        case .peopleServed: totals.peopleServed
        case .communities: totals.communities
        case .partners: partners.count
        case .bottlesScanned: nil
        }
    }
}

// MARK: Formatting

enum Format {
    /// 18400 -> "$18,400"
    static func currency(_ amount: Int) -> String {
        amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    /// 52000 -> "52,000"
    static func number(_ value: Int) -> String {
        value.formatted(.number)
    }

    /// "2026-10" -> "October 2026"
    static func month(_ isoMonth: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: isoMonth) else { return isoMonth }
        var style = Date.FormatStyle().month(.wide).year()
        style.timeZone = TimeZone(identifier: "UTC")!
        return date.formatted(style)
    }

    /// "2026-09-28" -> "September 28, 2026"
    static func date(_ isoDate: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDate) else { return isoDate }
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.timeZone = TimeZone(identifier: "UTC")!
        return date.formatted(style)
    }
}
