import Foundation
import SwiftUI

/// Force update (Alfred, 22 Nov 2026). The server says which version is live on the App Store
/// (`GET /api/public/app-version`, from Apple's public lookup, so it only moves once Apple has
/// released a version). An app older than that shows the blocking `UpdateRequiredView`. A 426 from
/// any HRMS call (an outdated app, `src/lib/mobile-app-version.ts` in the web repo) does the same.
/// A failed check never blocks.
@MainActor
final class UpdateGate: ObservableObject {
    static let shared = UpdateGate()

    /// Set when this app must be updated: where to send the person.
    @Published private(set) var storeURL: URL?
    @Published private(set) var liveVersion: String?

    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    static let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    static let defaultStoreURL = URL(string: "https://apps.apple.com/app/id6759821144")!

    /// -1, 0 or 1, comparing dotted numbers ("1.9" < "1.10"); mirrors the server's compareVersions.
    nonisolated static func compare(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let d = (i < pa.count ? pa[i] : 0) - (i < pb.count ? pb[i] : 0)
            if d != 0 { return d < 0 ? -1 : 1 }
        }
        return 0
    }

    /// Whether `version` must update to `live` (nil live = no forcing).
    nonisolated static func mustUpdate(version: String, live: String?) -> Bool {
        guard let live, !live.isEmpty else { return false }
        return compare(version, live) < 0
    }

    private struct Response: Decodable {
        struct Platform: Decodable { let liveVersion: String?; let storeUrl: String? }
        let ios: Platform?
    }

    /// Launch and every return to the foreground. Skipped in the screenshot preview.
    func check() async {
        if ProcessInfo.processInfo.arguments.contains("-uiPreview") {
            if ProcessInfo.processInfo.arguments.contains("-uiPreviewUpdateRequired") { require(nil, live: "9.9") }
            return
        }
        var req = URLRequest(url: AuthService.baseURL.appendingPathComponent("api/public/app-version"))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 10
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let r = try? JSONDecoder().decode(Response.self, from: data) else { return }
        if Self.mustUpdate(version: Self.appVersion, live: r.ios?.liveVersion) {
            require(r.ios?.storeUrl.flatMap(URL.init(string:)), live: r.ios?.liveVersion)
        } else {
            storeURL = nil
        }
    }

    /// The server answered 426: this app is too old.
    func require(_ url: URL?, live: String? = nil) {
        storeURL = url ?? Self.defaultStoreURL
        if let live { liveVersion = live }
    }
}

/// Full-screen, cannot be dismissed: the only way on is the App Store.
struct UpdateRequiredView: View {
    @ObservedObject var gate: UpdateGate
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 72)).foregroundStyle(Theme.royal600)
                    .accessibilityHidden(true)
                Text("Update required").font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("update.title")
                Text("A new version of TIA HRMS\(gate.liveVersion.map { " (\($0))" } ?? "") is available. Please update to continue.")
                    .font(.body).foregroundStyle(Theme.mist).multilineTextAlignment(.center)
                Text("You have version \(UpdateGate.appVersion).")
                    .font(.footnote).foregroundStyle(Theme.mist)
                Spacer()
                Button {
                    openURL(gate.storeURL ?? UpdateGate.defaultStoreURL)
                } label: {
                    Label("Update now", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(Theme.royal600)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("update.button")
            }
            .padding(28)
        }
    }
}
