# SwiftUI Components

Reusable building blocks for native iOS apps in the house style. Reference `Theme` tokens (see
`hig-theming.md`), never raw `Color` literals.

## Quick-start: list card

The iOS twin of the Android `ItemListCard` — a tappable row with leading icon, title/subtitle,
and a chevron.

```swift
struct ItemListCard: View {
    let title: String
    let subtitle: String
    var symbol: String = "star.fill"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(Theme.accent.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
```

## Lists

- Use `List` for settings/grouped content (`.listStyle(.insetGrouped)`), or `ScrollView` +
  `LazyVStack` for custom card layouts.
- Long/dynamic data → `List`/`LazyVStack`, never a plain `VStack` (which builds every row eagerly).
- For grouped rounded cards, wrap a `VStack` of rows in
  `.background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))`.

## Buttons

- Primary action: `.buttonStyle(.borderedProminent).tint(Theme.accent)`.
- Use `Label("Title", systemImage:)` so the icon scales with Dynamic Type.
- Gate destructive/empty actions with `.disabled(...)`; add `.accessibilityLabel` to icon-only buttons.

## Forms & text input

- `TextField` for single-line; `TextEditor` for multi-line (add `.scrollContentBackground(.hidden)`
  on iOS 16+ to show a custom background, and overlay a placeholder `Text` when empty).
- Set `.textInputAutocapitalization`, `.keyboardType`, and `.submitLabel` appropriately.

## Surfaces & materials

- Prefer system materials for overlays: `.background(.regularMaterial)`.
- Standard corner radius for cards is 12–18pt with `.continuous` style for the squircle look.

## Previews

Always preview in light + dark and a large Dynamic Type size:

```swift
#Preview {
    ItemListCard(title: "Title", subtitle: "Subtitle") {}
        .padding()
        .preferredColorScheme(.dark)
}
```
