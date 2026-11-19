import SwiftUI

/// TIA HRMS "premium blue" brand palette (BRAND.md, 9 Nov 2026).
/// Light (Alfred, 10 Nov 2026): a soft blue-white surface, navy text, royal-blue primary, and
/// gold as the single, sparing warm accent. Dark (19 Nov 2026) matches the web app's dark:
/// near-black page, slate cards, near-white text. The semantic tokens below are dynamic
/// colours, so every screen follows the Appearance setting (`Appearance.swift`) with no
/// per-view code. Brand tokens (navy / royal / gold) are fixed: use them for fills and for
/// text that sits on a fixed fill (navy on gold, white on royal).
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
    /// Primary interactive colour on the page surface (links, icons, tint).
    static let sky = Color(light: 0x2F5BE6, dark: 0x8FB0FF)
    /// Primary text.
    static let ink = Color(light: 0x0D1638, dark: 0xF9FAFB)
    /// Secondary text / metadata (AA on the card in both appearances).
    static let mist = Color(light: 0x4D5B8C, dark: 0x9CA3AF)
    /// Text on a `chipFill` chip.
    static let chipInk = Color(light: 0x1A2F86, dark: 0xC9D8FF)
    /// Pale tinted chip / selected-row fill.
    static let chipFill = Color(light: 0xC9D8FF, dark: 0x24356F)

    /// Opaque bar colour (tab + nav bars).
    static let barUIColor = UIColor(light: 0xFFFFFF, dark: 0x0B1220)
    static let barTitleUIColor = UIColor(light: 0x0D1638, dark: 0xF9FAFB)

    // MARK: Surfaces
    /// Page background base colour.
    static let surface = Color(light: 0xF3F6FD, dark: 0x030712)
    /// Cards and grouped sections.
    static let card = Color(light: 0xFFFFFF, dark: 0x111827)
    /// Alternate (zebra) row on a card.
    static let cardStripe = Color(light: 0xF5F8FF, dark: 0x0D1424)
    static let cardBorder = Color(light: 0x2F5BE6, dark: 0xFFFFFF).opacity(0.10)
    static let field = Color(light: 0xFFFFFF, dark: 0x1F2937)
    static let fieldBorder = Color(light: 0x0D1638, dark: 0xFFFFFF).opacity(0.14)

    // MARK: Status colours (dark on white cards, light on dark cards; AA in both)
    static let success = Color(light: 0x15803D, dark: 0x4ADE80)
    static let warning = Color(light: 0xB45309, dark: 0xFBBF24)
    static let danger = Color(light: 0xC2271D, dark: 0xF87171)

    // MARK: Gradients
    /// The page backdrop: a very light blue-white wash (light) or a near-black wash (dark).
    static let backdrop = LinearGradient(
        stops: [
            .init(color: Color(light: 0xF8FAFF, dark: 0x030712), location: 0),
            .init(color: Color(light: 0xF1F5FE, dark: 0x050A18), location: 0.55),
            .init(color: Color(light: 0xE6EDFD, dark: 0x0A1226), location: 1),
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

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// A colour that follows the current appearance (light / dark).
    convenience init(light: UInt32, dark: UInt32) {
        self.init { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}

extension Color {
    /// A colour that follows the current appearance (light / dark).
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor(light: light, dark: dark))
    }
}
