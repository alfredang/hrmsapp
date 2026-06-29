---
name: mobile-ios-design
description: Master SwiftUI and Apple Human Interface Guidelines patterns for building native iOS apps. Use when designing iOS interfaces, implementing SwiftUI UI, adding navigation (TabView / NavigationStack), theming, or following Apple's HIG. Includes the Tertiary Infotech Academy house-style bottom-tab nav with Feedback + About tabs.
license: MIT
metadata:
  version: "1.0.0"
---

# iOS Mobile Design

Master SwiftUI and the Apple Human Interface Guidelines (HIG) to build modern, adaptive iOS
applications that feel native on iPhone and iPad. This is the iOS twin of the
`mobile-android-design` skill.

## When to Use This Skill

- Designing iOS app interfaces following the Human Interface Guidelines
- Building SwiftUI views, layouts, and reusable components
- Implementing iOS navigation patterns (`TabView`, `NavigationStack`, sheets)
- Adding a **bottom-tab navigation with Feedback + About tabs** (house style — see below)
- Creating adaptive layouts for iPhone and iPad (size classes, `NavigationSplitView`)
- Theming with semantic colors, SF Symbols, Dynamic Type, and dark mode
- Building accessible iOS interfaces (VoiceOver, contrast, hit targets)

## Core Concepts

- **SwiftUI-first, declarative.** Describe UI as a function of state; hoist state with
  `@State` / `@Binding` / `@Observable` (or `ObservableObject` pre-iOS 17). Keep views small
  and composable.
- **Semantic over literal.** Use system materials and a central `Theme` of color tokens, never
  raw `Color(red:…)` scattered inline — this is what gives automatic dark-mode support.
- **SF Symbols** for iconography (`Image(systemName:)` / `Label`) — they scale with Dynamic Type
  and adapt to weight and color automatically.
- **HIG layout rhythm.** Respect safe areas, use system spacing, 44×44pt minimum hit targets,
  grouped rounded-card surfaces, and large navigation titles for top-level screens.

Deeper material is split into `references/` to keep this body small:
- `references/swiftui-components.md` — cards, lists, forms, buttons, the quick-start component.
- `references/ios-navigation.md` — `TabView`, `NavigationStack`, and the **full Feedback + About
  bottom-nav reference implementation**.
- `references/hig-theming.md` — `Theme` tokens, dark mode, SF Symbols, Dynamic Type, accessibility.

## Bottom-tab navigation with Feedback + About (house style)

Add a root `TabView` with the app's content as the first tab, plus **Feedback** and **About**
tabs in the Tertiary Infotech Academy house style. (Full code: `references/ios-navigation.md`.)

- **Feedback tab:** `Title` + `Message` fields and a **Send via WhatsApp** button that opens
  `https://wa.me/6588666375?text=<title + message>`. Build the URL with `URLComponents` /
  `URLQueryItem` (never string-concatenation) so the text is percent-encoded correctly. The
  `wa.me` https link works whether or not WhatsApp is installed — no `LSApplicationQueriesSchemes`.
- **About tab:** an app card (name + description), a **Developer** card ("Tertiary Infotech
  Academy Pte Ltd" + `tertiaryinfotech.com` link), an optional **Data source** card (mandatory
  when surfacing government/official data — doubles as App Review attribution), and a **Version**
  row read from `Bundle.main.infoDictionary` (`CFBundleShortVersionString` + `CFBundleVersion`).

```swift
// MainTabView.swift — make this the root: WindowGroup { MainTabView() }
struct MainTabView: View {
    var body: some View {
        TabView {
            ContentScreen()                                   // your existing first tab
                .tabItem { Label("Home", systemImage: "house.fill") }
            FeedbackView()
                .tabItem { Label("Feedback", systemImage: "bubble.left.and.bubble.right.fill") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
        }
        .tint(Theme.accent)            // selected-tab color from the central Theme
    }
}
```

On a **deployment target < iOS 18** use the classic `.tabItem { Label(...) }` API (the
`Tab("…", systemImage:)` initializer is iOS 18+). The Feedback `TextEditor` needs
`.scrollContentBackground(.hidden)` to show a custom background (iOS 16+).

## Best Practices

1. **Use a central `Theme`**: reference color tokens (`Theme.accent`, `Theme.card`), never raw
   `Color` literals — guarantees consistent dark mode.
2. **Semantic colors & materials**: prefer `.background(.regularMaterial)` and system colors so
   contrast adapts automatically.
3. **SF Symbols + `Label`**: pair an icon with text; symbols scale with Dynamic Type.
4. **Dynamic Type**: use text styles (`.body`, `.title3`) not fixed point sizes; test at XXL.
5. **Hit targets**: minimum 44×44pt for every interactive control.
6. **Safe areas**: respect them; only ignore deliberately for full-bleed backgrounds.
7. **State hoisting**: lift state to make views reusable and previewable.
8. **`#Preview`**: add previews in light + dark and a large Dynamic Type size.
9. **Adaptive**: use size classes / `NavigationSplitView` for iPad instead of hardcoding widths.

## Common Issues

- **No dark mode**: caused by raw `Color` literals — route everything through `Theme`.
- **Tab init won't compile**: `Tab(_:systemImage:)` is iOS 18+; below that use `.tabItem`.
- **`TextEditor` shows default background**: add `.scrollContentBackground(.hidden)`.
- **Broken WhatsApp/links text**: build URLs with `URLComponents`, not string concatenation.
- **Janky long lists**: use `List`/`LazyVStack`, not a plain `VStack` in a `ScrollView`.
- **VoiceOver gaps**: add `.accessibilityLabel` to icon-only buttons; group related elements.
- **Layout fights safe area**: prefer `safeAreaInset`/`padding` over magic numbers.

## Verify

If the project is XcodeGen-based, run `xcodegen generate`, then a Debug build
(`xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' build`)
before shipping. Pair with `ios-feedback-about` for a turn-key Feedback/About drop-in.
