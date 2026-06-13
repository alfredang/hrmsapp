import SwiftUI

/// Routes between a brief launch state, the login frontend, and the signed-in home.
struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()

            switch auth.phase {
            case .loading:
                LaunchView()
            case .signedOut:
                LoginView()
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.phase)
        .task { await auth.bootstrap() }
    }
}

/// Branded splash shown while restoring any existing session.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: 22) {
            BrandHeader()
            ProgressView().tint(.white)
        }
    }
}
