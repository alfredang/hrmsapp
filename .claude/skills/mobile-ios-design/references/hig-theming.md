# HIG Theming, SF Symbols & Accessibility

How to theme a SwiftUI app for automatic dark mode, consistent branding, and accessibility,
following Apple's Human Interface Guidelines.

## Central Theme tokens

Put every brand color in one place and reference it everywhere. This is the single most
important rule — raw `Color(red:…)` literals scattered in views are what break dark mode.

```swift
enum Theme {
    static let accent = Color("Accent")          // brand/selected color
    static let card   = Color("Card")            // grouped-card surface
    static let bg      = Color("Background")
    // Define each in Assets.xcassets with a Light + Dark appearance variant.
}
```

- Back each token with an **Asset Catalog color set** that has both Light and Dark variants, so
  the system swaps them automatically.
- For text/foreground, prefer semantic styles (`.foregroundStyle(.primary/.secondary/.tertiary)`)
  and only reach for `Theme.accent` on branded elements (tab tint, primary buttons, links).
- Apply the accent app-wide via `.tint(Theme.accent)` on the root `TabView`/`NavigationStack`.

## Dark mode

- Don't hardcode black/white. Use semantic colors and the asset-catalog variants above.
- Test both: `#Preview { ContentView().preferredColorScheme(.dark) }`.
- Only set `.preferredColorScheme(.dark)` globally if the app is intentionally always-dark.

## SF Symbols

- Use `Image(systemName:)` / `Label(_:systemImage:)` for all iconography — they scale with
  Dynamic Type and inherit foreground color and weight.
- Match symbol weight to adjacent text (`.font(.title3)` etc.); tint with `.foregroundStyle`.
- Prefer `.fill` variants for tab-bar and primary glyphs (e.g. `house.fill`, `info.circle.fill`).

## Typography & Dynamic Type

- Use text styles (`.largeTitle`, `.title3`, `.body`, `.caption`) — never fixed point sizes.
- Large navigation titles for top-level screens; sentence-case labels.
- Test at the largest accessibility size; ensure nothing truncates or overlaps.

## Layout rhythm (HIG)

- Respect safe areas; use `safeAreaInset` for floating bars instead of magic padding.
- System spacing and ~16–22pt screen padding; group related controls into rounded cards.
- Minimum **44×44pt** hit target for every interactive control.

## Accessibility

- Add `.accessibilityLabel` to icon-only controls; combine decorative + label with
  `.accessibilityElement(children: .combine)`.
- Don't rely on color alone to convey state — pair with text or an icon.
- Maintain WCAG-style contrast; verify with the Accessibility Inspector.
- Support VoiceOver focus order by structuring views logically (it follows view order).
