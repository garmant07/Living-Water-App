import Foundation
import Observation

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

@Observable
final class DataStore {
    static let shared = DataStore()

    /// The partners as shown: the built-in ones, with any edits the team has
    /// made online laid over the top.
    private(set) var partners: [Partner]
    /// The partners exactly as built into the app.
    private let builtInPartners: [Partner]
    let communities: [Community]
    let company: CompanyTotals
    private let allStories: [StoryUpdate]
    private let bottles: [BottleCode]
    private let allMilestones: [Milestone]
    /// The Personal Journey levels, smallest first.
    let levels: [JourneyLevel]
    /// The verses, slogans and mission statements that take turns on the home page.
    let homeMessages: [HomeMessage]
    /// The short invitations that take turns at the top of the globe page.
    let globeMessages: [String]

    private init() {
        builtInPartners = Self.load("partners")
        partners = builtInPartners
        communities = Self.load("communities")
        allStories = Self.load("stories")
        bottles = Self.load("bottles")
        allMilestones = Self.load("milestones")
        company = Self.load("company")
        homeMessages = Self.load("messages")
        globeMessages = Self.load("globeMessages")
        let loadedLevels: [JourneyLevel] = Self.load("levels")
        levels = loadedLevels.sorted { $0.liters < $1.liters }
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

    /// Lays the team's online edits over the built-in partners. A field left
    /// empty online keeps its built-in wording, so nothing can go blank.
    func apply(_ edits: [CloudPartner]) {
        partners = builtInPartners.map { original in
            guard let edit = edits.first(where: { $0.id == original.id }) else { return original }
            var partner = original
            func filled(_ text: String) -> String? {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            partner.name = filled(edit.name) ?? original.name
            partner.tagline = filled(edit.tagline) ?? original.tagline
            partner.about = filled(edit.about) ?? original.about
            partner.faithStatement = filled(edit.faithNote) ?? original.faithStatement
            partner.website = filled(edit.websiteUrl) ?? original.website
            let facts = edit.keyFacts.compactMap(filled)
            if !facts.isEmpty { partner.keyFacts = facts }
            if let donate = filled(edit.donateUrl), donate != original.donateUrl {
                // The team typed a donation page themselves, so it counts as checked.
                partner.donateUrl = donate
                partner.donateUrlConfirmed = true
            }
            partner.logoUrl = edit.logoUrl.flatMap(filled)
            return partner
        }
    }

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
    /// Long dashes that a keyboard may swap in are turned back into hyphens.
    func normalizeBottleCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
    }

    /// Pulls the bottle code out of whatever a QR code contained: either a
    /// link ending in /b/LW-MW-0001 or just the code by itself.
    func bottleCode(fromScanned text: String) -> String {
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme != nil,
           let marker = url.pathComponents.lastIndex(of: "b"),
           marker + 1 < url.pathComponents.count {
            return normalizeBottleCode(url.pathComponents[marker + 1])
        }
        return normalizeBottleCode(text)
    }

    func bottle(code: String) -> BottleCode? {
        let wanted = normalizeBottleCode(code)
        return bottles.first { $0.code == wanted }
    }

    /// The community a bottle supported, or nil for an unknown code.
    func community(forBottleCode code: String) -> Community? {
        bottle(code: code).flatMap { community(id: $0.communityId) }
    }

    // MARK: Personal Journey levels

    /// How many scanned bottles it takes to fill a level.
    func bottlesNeeded(for level: JourneyLevel) -> Int {
        max(Int((level.liters / company.litersPerBottle).rounded(.up)), 1)
    }

    /// Works out the level reached, and the one being filled, for a number of bottles.
    func levelProgress(bottles: Int) -> LevelProgress {
        let liters = Double(bottles) * company.litersPerBottle
        let current = levels.last { bottlesNeeded(for: $0) <= bottles }
        let next = levels.first { bottlesNeeded(for: $0) > bottles }
        return LevelProgress(
            bottles: bottles,
            liters: liters,
            current: current,
            next: next,
            bottlesToNext: next.map { bottlesNeeded(for: $0) - bottles } ?? 0,
            fill: next.map { min(liters / $0.liters, 1) } ?? 1
        )
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

    /// 2499 cents -> "$24.99"
    static func price(cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }

    /// 52000 -> "52,000"
    static func number(_ value: Int) -> String {
        value.formatted(.number)
    }

    /// 1_932_000 meters -> "1,200 miles" or "1,900 kilometers", whichever the
    /// phone's region uses, rounded so it reads as an estimate.
    static func distance(_ meters: Double) -> String {
        let usesMiles = Locale.current.measurementSystem != .metric
        let amount = meters / (usesMiles ? 1609.344 : 1000)
        let step: Double = amount >= 1000 ? 100 : (amount >= 100 ? 10 : 1)
        let rounded = Int((amount / step).rounded() * step)
        let unit = usesMiles ? (rounded == 1 ? "mile" : "miles") : (rounded == 1 ? "kilometer" : "kilometers")
        return "\(number(rounded)) \(unit)"
    }

    /// 150 litres -> "40 gallons" or "150 litres", whichever the phone's
    /// region uses. Small amounts read in fluid ounces or millilitres.
    static func volume(_ liters: Double) -> String {
        func tidy(_ amount: Double) -> String {
            // Two meaningful digits is plenty: 39.6 -> 40, 660,430 -> 660,000.
            guard amount >= 100 else {
                return amount < 10 && amount != amount.rounded()
                    ? amount.formatted(.number.precision(.fractionLength(1)))
                    : number(Int(amount.rounded()))
            }
            let step = pow(10, (log10(amount)).rounded(.down) - 1)
            return number(Int((amount / step).rounded() * step))
        }
        if Locale.current.measurementSystem == .metric {
            return liters < 1 ? "\(tidy(liters * 1000)) ml" : "\(tidy(liters)) \(liters == 1 ? "litre" : "litres")"
        }
        let gallons = liters / 3.785411784
        return gallons < 1 ? "\(tidy(liters * 33.8140227)) fl oz" : "\(tidy(gallons)) \(tidy(gallons) == "1" ? "gallon" : "gallons")"
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
