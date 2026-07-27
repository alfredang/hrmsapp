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
                if Self.previewScreenKey != nil {
                    NavigationStack { Self.previewScreen }.transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.phase)
        .task { await auth.bootstrap() }
    }

    /// Screenshot-only deep link: when launched with `-uiPreview -uiPreviewScreen <key>`,
    /// render a single module directly so App Store captures are deterministic. Only ever
    /// active alongside `-uiPreview`, so it never affects a real install.
    private static var previewScreenKey: String? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiPreview"),
              let i = args.firstIndex(of: "-uiPreviewScreen"), i + 1 < args.count
        else { return nil }
        return args[i + 1]
    }

    @ViewBuilder private static var previewScreen: some View {
        switch previewScreenKey {
        case "leave":     LeaveView()
        case "team":      TeamView()
        case "payslips":  PayslipsView()
        case "expenses":  ExpensesView()
        case "calendar":  CalendarListView()
        case "timesheet": WeeklyTimesheetView()
        case "timeoff":   TimeOffView()
        case "clock":     ClockView()
        case "profile":   ProfileView()
        default:          DashboardView()
        }
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
