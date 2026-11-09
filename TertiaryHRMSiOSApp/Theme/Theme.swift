import SwiftUI

/// TIA HRMS "premium blue" brand palette (BRAND.md, 9 Nov 2026).
/// Navy foundations rising to royal blue, with gold as the single, sparing warm accent.
/// The app runs on a dark branded surface, so `royal300` is the primary on dark and
/// `royal600` the primary for fills / light-mode tint (AccentColor asset).
enum Theme {
    // MARK: Brand tokens
    /// navy-950 — darkest background, top of gradients, bars.
    static let navy950 = Color(hex: 0x0D1638)
    /// navy-800 — gradient middle, headers.
    static let navy800 = Color(hex: 0x1A2F86)
    /// royal-600 — gradient end, primary buttons (light-mode primary).
    static let royal600 = Color(hex: 0x2F5BE6)
    /// royal-500 — hover / pressed-light, top of the button gradient.
    static let royal500 = Color(hex: 0x3D6BF0)
    /// royal-300 — primary on dark backgrounds (links, tint, active tab).
    static let royal300 = Color(hex: 0x8FB0FF)
    /// mist-100 — secondary text on blue.
    static let mist = Color(hex: 0xC9D8FF)
    /// gold-400 — the single warm accent: badges, highlights. Use sparingly.
    static let gold = Color(hex: 0xF5B83D)
    /// gold-600 — gold pressed / gradient end.
    static let gold600 = Color(hex: 0xD9921C)

    // MARK: Semantic aliases (kept so every screen picks up the palette)
    static let navy = navy950
    static let premier = royal600
    static let azure = royal500
    static let sky = royal300

    /// Opaque bar colour (tab + nav bars) — navy-950.
    static let barUIColor = UIColor(red: 0x0D / 255, green: 0x16 / 255, blue: 0x38 / 255, alpha: 1)

    // MARK: Neutrals
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.15)          // near-black text
    static let field = Color.white.opacity(0.12)
    static let fieldBorder = Color.white.opacity(0.22)

    // MARK: Gradients
    /// The brand backdrop: linear 160°, navy-950 → navy-800 (50%) → royal-600.
    static let backdrop = LinearGradient(
        stops: [
            .init(color: navy950, location: 0),
            .init(color: navy800, location: 0.5),
            .init(color: royal600, location: 1),
        ],
        startPoint: UnitPoint(x: 0.32, y: 0),   // 160° ≈ top, slightly left → bottom, slightly right
        endPoint: UnitPoint(x: 0.68, y: 1)
    )

    /// Buttons and accents (royal-500 → royal-600).
    static let accent = LinearGradient(
        colors: [royal500, royal600],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Metrics
    static let corner: CGFloat = 16
    static let controlHeight: CGFloat = 56   // ≥56pt touch targets (HIG)
}

extension Color {
    /// `Color(hex: 0x2F5BE6)` — sRGB from a 24-bit hex literal.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
