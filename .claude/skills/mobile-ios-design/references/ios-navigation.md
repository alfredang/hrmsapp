# iOS Navigation (SwiftUI)

Patterns for structuring navigation in a native SwiftUI app, plus the **full reference
implementation** of the Tertiary Infotech Academy house-style **bottom-tab nav with Feedback + About**.

## Picking a container

- **`TabView`** — top-level, peer destinations (Home / Feedback / About). The default for the
  house style. Make it the app root: `WindowGroup { MainTabView() }`.
- **`NavigationStack`** — push/pop hierarchy within a tab. Use `navigationDestination(for:)` with
  a typed path for data-driven navigation.
- **`NavigationSplitView`** — sidebar + detail on iPad / large widths; collapses to a stack on
  iPhone.
- **`.sheet` / `.fullScreenCover`** — modal, self-contained tasks (compose, settings).

### iOS version note
The `Tab("…", systemImage:)` initializer is **iOS 18+**. For deployment targets below iOS 18,
use the classic API:

```swift
TabView {
    SomeView().tabItem { Label("Home", systemImage: "house.fill") }
}
```

Apply `.tint(Theme.accent)` for the selected-tab color, and `.preferredColorScheme(.dark)` only
if the whole app is dark-themed.

## Reference implementation: Feedback + About bottom nav

### MainTabView.swift
```swift
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
        .tint(Theme.accent)
    }
}
```

### FeedbackView.swift — Title + Message → WhatsApp
```swift
struct FeedbackView: View {
    private let whatsAppNumber = "6588666375"        // +65 8866 6375, country code, no "+"/spaces
    @State private var title = ""
    @State private var message = ""

    private var canSend: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Feedback").font(.largeTitle.bold())
                TextField("Title", text: $title)
                ZStack(alignment: .topLeading) {
                    if message.isEmpty { Text("Your message…").foregroundStyle(.secondary) }
                    TextEditor(text: $message)
                        .scrollContentBackground(.hidden)      // iOS 16+: show custom background
                        .frame(minHeight: 160)
                }
                Button(action: send) {
                    Label("Send via WhatsApp", systemImage: "paperplane.fill")
                }
                .disabled(!canSend)
            }
            .padding(22)
        }
    }

    private func send() {
        var body = ""
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { body += "*\(t)*\n" }
        body += m
        var comps = URLComponents()
        comps.scheme = "https"; comps.host = "wa.me"; comps.path = "/\(whatsAppNumber)"
        comps.queryItems = [URLQueryItem(name: "text", value: body)]   // percent-encodes correctly
        if let url = comps.url { UIApplication.shared.open(url) }
    }
}
```

### AboutView.swift — app card, developer + link, version
```swift
struct AboutView: View {
    private let developerURL = URL(string: "https://www.tertiaryinfotech.com")!
    private var versionString: String {
        let i = Bundle.main.infoDictionary
        let s = i?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = i?["CFBundleVersion"] as? String ?? "1"
        return "\(s) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("About").font(.largeTitle.bold())

                // App card
                VStack(alignment: .leading, spacing: 10) {
                    Text("<App name>").font(.title3.bold())
                    Text("<One-paragraph description of what the app does.>")
                        .foregroundStyle(.secondary)
                }

                // Developer card (label + building row + globe link row)
                Text("DEVELOPER").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Label("Tertiary Infotech Academy Pte Ltd", systemImage: "building.2.fill")
                        .padding(.vertical, 14)
                    Divider()
                    Link(destination: developerURL) {
                        Label("tertiaryinfotech.com", systemImage: "globe")
                    }
                    .padding(.vertical, 14)
                }

                // Optional Data-source card here (required for government data) — same Link row pattern.

                // Version row
                HStack { Text("Version"); Spacer(); Text(versionString).foregroundStyle(.secondary) }
            }
            .padding(22)
        }
    }
}
```

Wrap each card group in a rounded surface to match the grouped-card look:
`.background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))`.

## Conventions

- WhatsApp number is **6588666375** (Singapore, country code included, no `+`/spaces).
- Always build the `wa.me` URL with **`URLComponents`/`URLQueryItem`** — it percent-encodes the
  title/message (newlines, `*`, emoji) correctly; string concatenation breaks on those.
- Open WhatsApp and external links with `UIApplication.shared.open(url)`; use `Link(destination:)`
  for inline website rows. No URL schemes to allow-list (`wa.me` + `https`).
- The About **Data source** card is mandatory when the app shows government/official data
  (LTA DataMall, data.gov.sg, OneMap, etc.) — it doubles as the App Store Review attribution.
- For a turn-key drop-in of exactly this Feedback/About pair, use the `ios-feedback-about` skill.
