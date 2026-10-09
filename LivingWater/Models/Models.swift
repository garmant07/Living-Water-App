import Foundation

// The shapes of every kind of record in the app.
// Each one matches a JSON file in the Data folder. Because they are plain
// Codable types, the same shapes can later be loaded from a server or CMS.

/// A photo plus the words VoiceOver reads in its place.
struct Photo: Codable, Hashable {
    /// The image's name in Assets. "placeholder" until real photos arrive.
    let src: String
    let alt: String
}

/// A published figure. Real statistics must always say where they came from.
struct SourcedStat: Codable, Hashable {
    let label: String
    /// How the figure is shown, e.g. "8M+"
    let display: String
    /// The plain number, when one exists, for sorting and math.
    let value: Double?
    let sourceUrl: String
    /// When the figure was published or last checked (YYYY-MM).
    let asOf: String
}

struct FeatureStory: Codable, Hashable {
    let title: String
    let body: String
}

struct Partner: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let website: String
    let founded: Int
    let headquarters: String?
    let description: String
    let faithStatement: String
    /// The logo's name in Assets. nil until the partner supplies one.
    let logo: String?
    let countries: [String]
    /// What the partner does on the ground.
    let work: [String]
    /// Published figures. May be empty when a partner hasn't published any.
    let headlineStats: [SourcedStat]
    /// A plain note shown when figures are missing, so the gap is honest.
    let statsNote: String?
    /// An optional longer story to feature in the app.
    let featureStory: FeatureStory?
}

enum ProjectStatus: String, Codable {
    case planned
    case inProgress = "in progress"
    case completed
}

enum SolutionType: String, Codable {
    case well
    case treatmentSystem = "treatment system"
    case filters
    case sanitation
    case disasterResponse = "disaster response"
}

struct Scripture: Codable, Hashable {
    let reference: String
    let text: String
}

struct Community: Codable, Identifiable, Hashable {
    let id: String
    let partnerId: String
    let name: String
    let country: String
    let region: String
    let latitude: Double
    let longitude: Double
    let status: ProjectStatus
    let solutionType: SolutionType
    let peopleServed: Int
    /// US dollars
    let goalAmount: Int
    /// US dollars
    let raisedAmount: Int
    let startDate: String
    let completedDate: String?
    let heroPhoto: Photo
    let gallery: [Photo]
    let story: String
    let scripture: Scripture?
    /// true = invented for building the app. Shown with a "Sample data" badge.
    let isSample: Bool
}

struct StoryUpdate: Codable, Identifiable, Hashable {
    let id: String
    let communityId: String
    let date: String
    let title: String
    let body: String
    let photo: Photo?
    let isSample: Bool
}

struct BottleCode: Codable, Hashable {
    /// The code printed in the bottle's QR code, e.g. LW-MW-0001
    let code: String
    let communityId: String
    let batch: String
    let dateProduced: String
    let isSample: Bool
}

struct Milestone: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case global
        case personal
    }

    /// What is being counted to reach this milestone.
    enum Metric: String, Codable {
        case peopleServed
        case communities
        case bottlesScanned
        case partners
    }

    let id: String
    let title: String
    let description: String
    let type: Kind
    let metric: Metric
    let threshold: Int
    let achievedDate: String?
    let isSample: Bool
}

/// Company-wide figures that don't belong to any one project.
struct CompanyTotals: Codable, Hashable {
    let bottlesSold: Int
    /// How much water one scanned bottle counts for on the Personal Journey.
    /// PLACEHOLDER: 0.5 is the water inside a half-litre bottle.
    let litersPerBottle: Double
    let asOf: String
    let isSample: Bool
}

/// The simple outline a level is drawn with.
enum VesselKind: String, Codable {
    case glass, jug, bucket, tub, tank, pool
}

/// One step on the Personal Journey, from a glass up to an Olympic pool.
struct JourneyLevel: Codable, Identifiable, Hashable {
    let level: Int
    let name: String
    /// How the level reads inside a sentence, e.g. "a bathtub".
    let short: String
    /// How much water fills it.
    let liters: Double
    let vessel: VesselKind
    let note: String

    var id: Int { level }
}

/// Where someone stands on the Personal Journey for a number of bottles.
struct LevelProgress {
    let bottles: Int
    let liters: Double
    /// The biggest thing filled so far. nil before the first bottle.
    let current: JourneyLevel?
    /// The thing being filled now. nil once the Olympic pool is full.
    let next: JourneyLevel?
    let bottlesToNext: Int
    /// How full the thing being filled is, 0 to 1.
    let fill: Double
}
