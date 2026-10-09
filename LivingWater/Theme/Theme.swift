import SwiftUI
import UIKit

// BRAND COLORS — PLACEHOLDERS
// The real Living Water Co. colors, fonts, and logo are still to be confirmed
// with the founders. Change the values here and the whole app updates.
// Each color has a light-mode and a dark-mode value.

enum Theme {
    /// Warm off-white page background
    static let background = Color(light: 0xF8F5EE, dark: 0x061A28)
    /// Cards
    static let surface = Color(light: 0xFFFFFF, dark: 0x0C2A3D)
    /// Main text: deep ocean
    static let foreground = Color(light: 0x0B2A3F, dark: 0xEEF6F8)
    /// Secondary text
    static let muted = Color(light: 0x4D6577, dark: 0xA3BCC9)
    static let border = Color(light: 0xD9E2E6, dark: 0x1C4259)
    /// Ocean blue: buttons and links
    static let brand = Color(light: 0x0A6C8F, dark: 0x2BB8CF)
    /// Deep ocean: headings and big numbers
    static let brandStrong = Color(light: 0x0B3D5C, dark: 0x8FE3EE)
    /// Clear aqua
    static let accent = Color(light: 0x12A5B8, dark: 0x5FD9E6)
    /// Soft glow for globe points
    static let glow = Color(light: 0x5FD9E6, dark: 0x8FF0F8)
    /// The "still to do" part of a progress bar
    static let progressTrack = Color(light: 0xDBE7EA, dark: 0x1C4259)
    /// "Sample data" badge
    static let sampleBackground = Color(light: 0xFFF3D6, dark: 0x4A3600)
    static let sampleForeground = Color(light: 0x6B4A00, dark: 0xFFE3A1)
}

private extension Color {
    /// Builds a color from two hex values, e.g. Color(light: 0xF8F5EE, dark: 0x061A28).
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
