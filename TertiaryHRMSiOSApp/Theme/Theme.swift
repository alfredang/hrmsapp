import SwiftUI

/// TIA HRMS "premium blue" brand palette (BRAND.md, 9 Nov 2026).
/// One light theme (Alfred, 10 Nov 2026): a soft blue-white surface, navy text, royal-blue
/// primary, and gold as the single, sparing warm accent. There is no dark mode — the app
/// forces `.preferredColorScheme(.light)` at the root, matching the web app.
enum Theme {
    // MARK: Brand tokens
    /// navy-950 — primary text, headings.
    static let navy950 = Color(hex: 0x0D1638)
    /// navy-800 — gradient middle, headers.
    static let navy800 = Color(hex: 0x1A2F86)
    /// royal-600 — primary buttons, links, active tab, tint.
    static let royal600 = Color(hex: 0x2F5BE6)
    /// royal-500 — top of the button gradient.
    static let royal500 = Color(hex: 0x3D6BF0)
    /// royal-300 — light blue for soft fills.
    static let royal300 = Color(hex: 0x8FB0FF)
    /// mist-100 — pale blue for chips, selected rows and tinted surfaces.
    static let mist100 = Color(hex: 0xC9D8FF)
    /// gold-400 — the single warm accent: accreditation badges, highlights. Use sparingly.
    static let gold = Color(hex: 0xF5B83D)
    /// gold-600 — gold pressed / gradient end.
    static let gold600 = Color(hex: 0xD9921C)

    // MARK: Semantic aliases (every screen reads these)
    static let navy = navy950
    static let premier = royal600
    static let azure = royal500
    /// Primary interactive colour on the light surface (links, icons, tint).
    static let sky = royal600
    /// Primary text.
    static let ink = navy950
    /// Secondary text / metadata (navy-blue grey, AA on white).
    static let mist = Color(hex: 0x4D5B8C)

    /// Opaque bar colour (tab + nav bars) — white.
    static let barUIColor = UIColor.white
    static let barTitleUIColor = UIColor(red: 0x0D / 255, green: 0x16 / 255, blue: 0x38 / 255, alpha: 1)

    // MARK: Surfaces
    /// Page background base colour.
    static let surface = Color(hex: 0xF3F6FD)
    /// Cards and grouped sections.
    static let card = Color.white
    static let cardBorder = Color(hex: 0x2F5BE6).opacity(0.10)
    static let field = Color.white
    static let fieldBorder = Color(hex: 0x0D1638).opacity(0.14)

    // MARK: Status colours (darkened so text stays readable on white)
    static let success = Color(hex: 0x15803D)
    static let warning = Color(hex: 0xB45309)
    static let danger = Color(hex: 0xC2271D)

    // MARK: Gradients
    /// The page backdrop: a very light blue-white wash.
    static let backdrop = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xF8FAFF), location: 0),
            .init(color: Color(hex: 0xF1F5FE), location: 0.55),
            .init(color: Color(hex: 0xE6EDFD), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// The brand gradient (navy-950 → navy-800 → royal-600, 160°) — the brand mark only.
    static let brand = LinearGradient(
        stops: [
            .init(color: navy950, location: 0),
            .init(color: navy800, location: 0.5),
            .init(color: royal600, location: 1),
        ],
        startPoint: UnitPoint(x: 0.32, y: 0),
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
