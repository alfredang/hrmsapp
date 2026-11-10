import SwiftUI

@main
struct TertiaryHRMSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.light)   // one light premium-blue theme (no dark mode)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await PushManager.shared.onForeground() } }
        }
    }
}
