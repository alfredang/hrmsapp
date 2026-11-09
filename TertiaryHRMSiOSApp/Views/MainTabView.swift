import SwiftUI

/// The signed-in app shell. Five tabs cover the HR modules (Accounting is
/// intentionally excluded). Each tab is its own navigation stack on the
/// Premier Blue surface.
struct MainTabView: View {
    @EnvironmentObject private var auth: AuthViewModel

    init() {
        // White tab + nav bars with a hairline shadow on the light premium-blue surface.
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = Theme.barUIColor
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = Theme.barUIColor
        nav.titleTextAttributes = [.foregroundColor: Theme.barTitleUIColor]
        nav.largeTitleTextAttributes = [.foregroundColor: Theme.barTitleUIColor]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            NavigationStack { LeaveView() }
                .tabItem { Label("Leave", systemImage: "calendar.badge.clock") }.tag(1)
            NavigationStack { TeamCalendarView() }
                .tabItem { Label("Calendar", systemImage: "calendar") }.tag(2)
            NavigationStack { TeamView() }
                .tabItem { Label("Team", systemImage: "person.2.fill") }.tag(3)
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }.tag(4)
        }
        .tint(Theme.sky)
        .fullScreenCover(isPresented: $showPreviewScreen) {
            if Self.previewOpen == "applyleave" {
                ApplyLeaveView(types: PreviewData.leave.types, balances: PreviewData.leave.balances,
                               isIntern: auth.isIntern)
                    .preferredColorScheme(.light)
            } else {
            NavigationStack {
                switch Self.previewOpen {
                case "clock": ClockView()
                case "claim": NewClaimView()
                case "approvals": ApprovalsView()
                case "calendar": TeamCalendarView()
                case "interns", "timesheet": TimesheetAdminView()
                case "mytimesheet": MyTimesheetView()
                case "timeoff": TimeOffView()
                case "feedback": FeedbackView()
                case "about": AboutView()
                case "leavesummary": LeaveSummaryView()
                case "records": EmployeeRecordsView(employee: PreviewData.employees.employees[0])
                case "leave": LeaveView()
                case "payslips": PayslipsView()
                case "expenses": ExpensesView()
                case "more": MoreView()
                case "trainers": TrainersView()
                case "trainer": TrainerProfileView(trainerId: PreviewData.trainerList[0].id,
                                                   name: PreviewData.trainerList[0].name)
                default: EmptyView()
                }
            }
            .preferredColorScheme(.light)
            }
        }
    }

    // Screenshot/preview capture only (`-uiPreviewOpen clock|claim`), like `-uiPreview`:
    // deep-opens a feature screen so it can be screenshotted without UI automation.
    @State private var showPreviewScreen = MainTabView.previewOpen != nil
    /// Selected tab; `-uiPreview -uiPreviewTab N` (capture only) starts on tab N.
    @State private var tab: Int = {
        let a = ProcessInfo.processInfo.arguments
        guard a.contains("-uiPreview"), let i = a.firstIndex(of: "-uiPreviewTab"), i + 1 < a.count else { return 0 }
        return Int(a[i + 1]) ?? 0
    }()
    private static let previewOpen: String? = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-uiPreviewOpen"), i + 1 < a.count,
              a.contains("-uiPreview") else { return nil }
        return a[i + 1]
    }()
}
