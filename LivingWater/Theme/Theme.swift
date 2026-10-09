import SwiftUI

// BRAND COLORS — PLACEHOLDERS
// A minimalist soft-blue look with white text. The real Living Water Co.
// colors, fonts, and logo are still to be confirmed with the founders.
// Change the values here and the whole app updates.
// The blues are deep enough for white text to stay easy to read.

enum Theme {
    /// Soft blue page background
    static let background = Color(hex: 0x3A72AB)
    /// Cards: a slightly deeper blue
    static let surface = Color(hex: 0x316499)
    /// The deepest blue, for badges and photo placeholders
    static let deep = Color(hex: 0x28557F)
    /// Main text
    static let foreground = Color.white
    /// Secondary text: white, softened a touch
    static let muted = Color(hex: 0xE3EEF8)
    static let border = Color.white.opacity(0.22)
    /// Buttons, links, and the filled part of a progress bar
    static let brand = Color.white
    /// Headings and big numbers
    static let brandStrong = Color.white
    /// Pale blue for small accents
    static let accent = Color(hex: 0xBFDDF5)
    /// Soft glow for globe points
    static let glow = Color(hex: 0xD6ECFF)
    /// The globe is flat color with no shading: one blue for sea, one for land
    static let globeSea = Color(hex: 0x2B5C91)
    static let globeLand = Color(hex: 0x4A82BC)
    /// Coastlines and the edge of the globe
    static let globeOutline = Color.white
    /// The "still to do" part of a progress bar
    static let progressTrack = Color.white.opacity(0.25)
    /// "Sample data" badge
    static let sampleBackground = deep
    static let sampleForeground = Color.white
}

private extension Color {
    /// Builds a color from a hex value, e.g. Color(hex: 0x3A72AB).
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
