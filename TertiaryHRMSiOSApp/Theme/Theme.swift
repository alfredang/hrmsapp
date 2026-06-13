import SwiftUI

/// Premier Blue — the Tertiary HRMS brand palette.
/// A deep royal-blue identity: navy foundations rising to a vivid premier blue,
/// used consistently across the login frontend, buttons, and the brand header.
enum Theme {
    // MARK: Core blues
    /// Deep navy — backgrounds, gradient base.
    static let navy = Color(red: 0.039, green: 0.122, blue: 0.267)      // #0A1F44
    /// Premier blue — primary brand / accent.
    static let premier = Color(red: 0.114, green: 0.306, blue: 0.847)   // #1D4ED8
    /// Bright blue — gradient top / highlights.
    static let azure = Color(red: 0.231, green: 0.510, blue: 0.965)     // #3B82F6
    /// Soft sky — subtle accents on dark.
    static let sky = Color(red: 0.580, green: 0.772, blue: 0.992)       // #94C5FD

    // MARK: Neutrals
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.15)          // near-black text
    static let field = Color.white.opacity(0.12)
    static let fieldBorder = Color.white.opacity(0.22)

    // MARK: Gradients
    /// The signature Premier Blue backdrop (navy → premier → azure, top-leading to bottom-trailing).
    static let backdrop = LinearGradient(
        colors: [navy, premier, azure],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A flatter brand gradient for buttons and accents.
    static let accent = LinearGradient(
        colors: [azure, premier],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Metrics
    static let corner: CGFloat = 16
    static let controlHeight: CGFloat = 56   // ≥56pt touch targets (HIG)
}
