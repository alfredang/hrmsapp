import SwiftUI

@main
struct TertiaryHRMSApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.light)   // one light premium-blue theme (no dark mode)
        }
    }
}
