import SwiftUI

/// The light premium-blue page background (ignores the safe area).
struct GradientScreen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack { Theme.backdrop.ignoresSafeArea(); content }
    }
}

/// A white card with a hairline blue border and a soft shadow.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        // Wrap in a stack: a multi-view builder would otherwise get each modifier
        // applied per child and render as several separate cards.
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1))
            .shadow(color: Theme.navy950.opacity(0.05), radius: 8, y: 3)
    }
}

/// Small stat tile (value + label) for dashboards.
struct StatTile: View {
    let value: String
    let label: String
    var icon: String? = nil
    var tint: Color = Theme.sky
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                if let icon { Image(systemName: icon).foregroundStyle(tint) }
                Text(value).font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                Text(label).font(.caption).foregroundStyle(Theme.mist)
            }
        }
    }
}

/// Status pill (leave/expense status colouring).
struct StatusPill: View {
    let status: String
    var body: some View {
        Text(status.capitalized)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .lineLimit(1)
            .fixedSize()
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
    }
    private var color: Color {
        switch status.uppercased() {
        case "APPROVED", "PAID": return Theme.success
        case "PENDING": return Theme.warning
        case "REJECTED": return Theme.danger
        case "CANCELLED": return Theme.mist
        default: return Theme.sky
        }
    }
}

/// A generic async-content container: shows a spinner, an error with retry, or content.
struct AsyncContent<T, Content: View>: View {
    @Binding var state: LoadState<T>
    let load: () async -> Void
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                VStack { Spacer(); ProgressView().tint(Theme.premier); Spacer() }
                    .frame(maxWidth: .infinity)
            case .failed(let message):
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Theme.mist)
                    Text(message).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent).tint(Theme.premier)
                }
                .padding(32).frame(maxWidth: .infinity)
            case .loaded(let value):
                content(value)
            }
        }
        .task { if case .idle = state { await load() } }
    }
}

enum LoadState<T> {
    case idle, loading, loaded(T), failed(String)
}

struct EmptyHint: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.title).foregroundStyle(Theme.royal300)
            Text(text).font(.subheadline).foregroundStyle(Theme.mist)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}
