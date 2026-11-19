import SwiftUI
import UIKit

/// The Appearance setting (My Profile → Appearance): Light, Dark or System.
/// Saved on this device only (UserDefaults); nothing saved means System, except the accounts in
/// `lightDefaultEmails`, which start on Light. Same rule as the web app (`src/lib/appearance.ts`).
enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return .unspecified
        }
    }

    /// These accounts start on Light instead of System; they can still change it.
    static let lightDefaultEmails: Set<String> = ["angch@tertiaryinfotech.com", "tansc@tertiaryinfotech.com"]

    static func defaultFor(email: String?) -> Appearance {
        guard let email else { return .system }
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lightDefaultEmails.contains(key) ? .light : .system
    }
}

/// Holds the saved choice and applies it to every window, so sheets, alerts and system
/// controls follow it too (more reliable than `.preferredColorScheme`, which does not always
/// return to System inside a presented sheet).
@MainActor
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()
    static let storageKey = "hrms_appearance"

    @Published private(set) var selection: Appearance

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.storageKey).flatMap(Appearance.init(rawValue:)) ?? .system
    }

    /// True once the person (or the account default) has saved a choice on this device.
    var hasSavedChoice: Bool {
        defaults.string(forKey: Self.storageKey).flatMap(Appearance.init(rawValue:)) != nil
    }

    func select(_ appearance: Appearance) {
        selection = appearance
        defaults.set(appearance.rawValue, forKey: Self.storageKey)
        apply()
    }

    /// After sign-in: give the account its starting appearance when nothing is saved yet.
    func applyAccountDefault(email: String?) {
        guard !hasSavedChoice else { return }
        let start = Appearance.defaultFor(email: email)
        if start != .system { select(start) }
    }

    /// Push the choice to every window of the app.
    func apply() {
        let style = selection.interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.overrideUserInterfaceStyle != style {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

/// The Appearance card on My Profile.
struct AppearanceCard: View {
    @ObservedObject private var store = AppearanceStore.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance").font(.headline).foregroundStyle(Theme.ink)
                Text("System follows your iPhone's light or dark setting. Your choice is saved on this device.")
                    .font(.footnote).foregroundStyle(Theme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ForEach(Appearance.allCases) { option in
                        let selected = store.selection == option
                        Button { store.select(option) } label: {
                            Label(option.label, systemImage: option.icon)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .foregroundStyle(selected ? Color.white : Theme.ink)
                                .background {
                                    if selected { Theme.accent } else { Theme.ink.opacity(0.08) }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selected ? Color.clear : Theme.ink.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                if store.selection == .system {
                    Text("Your iPhone is currently set to \(colorScheme == .dark ? "dark" : "light").")
                        .font(.caption).foregroundStyle(Theme.mist)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}
