import SwiftUI

@main
struct TertiaryHRMSApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.dark)   // the Premier Blue frontend is a dark, branded surface
        }
    }
}
