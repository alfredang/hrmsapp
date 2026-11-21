import SwiftUI

/// The signed-in app shell. Five tabs cover the HR modules (Accounting is
/// intentionally excluded). Each tab is its own navigation stack on the
/// Premier Blue surface.
struct MainTabView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var push = PushManager.shared
    /// A screen opened from a tapped push / notification (`PushRoute`), shown as a sheet.
    @State private var pushSheet: PushRoute?

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
            // Trainer Admin view (More → View As): Home, Trainers, Calendar, More; no Leave / Team.
            if auth.isTrainerView {
                NavigationStack { TrainersView() }
                    .tabItem { Label("Trainers", systemImage: "person.text.rectangle.fill") }.tag(Self.trainersTab)
            } else {
                NavigationStack { LeaveView() }
                    .tabItem { Label("Leave", systemImage: "calendar.badge.clock") }.tag(1)
            }
            NavigationStack { TeamCalendarView() }
                .tabItem { Label("Calendar", systemImage: "calendar") }.tag(2)
            if !auth.isTrainerView {
                NavigationStack { TeamView() }
                    .tabItem { Label("Team", systemImage: "person.2.fill") }.tag(3)
            }
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }.tag(4)
        }
        .tint(Theme.sky)
        // Switching View As lands on the directory (the web opens /trainers) or back on Home.
        .onChange(of: auth.viewAs) { v in tab = v == .trainerAdmin && auth.canManageTrainers ? Self.trainersTab : 0 }
        .onChange(of: auth.isTrainerView) { on in if !on && tab == Self.trainersTab { tab = 0 } }
        .onChange(of: push.pendingLink) { _ in openPendingLink() }
        .onAppear { openPendingLink() }   // cold start from a tapped push
        .sheet(item: $pushSheet) { route in
            NavigationStack { pushScreen(route) }
        }
        .fullScreenCover(isPresented: $showPreviewScreen) {
            if Self.previewOpen == "applyleave" {
                ApplyLeaveView(types: PreviewData.leave.types, balances: PreviewData.leave.balances,
                               isIntern: auth.isIntern)
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
                case "profile": ProfileView()
                case "trainers": TrainersView()
                case "trainercontacts": TrainerContactsView()
                case "trainer": TrainerProfileView(trainerId: PreviewData.trainerList[0].id,
                                                   name: PreviewData.trainerList[0].name)
                default: EmptyView()
                }
            }
            }
        }
    }

    private var isAdmin: Bool { ["ADMIN", "HR", "MANAGER"].contains(auth.user?.primaryRole.uppercased() ?? "") }
    /// Tag of the Trainers tab, shown only in the Trainer Admin view.
    static let trainersTab = 5

    /// Route a tapped push (its web `link`) to a tab or a sheet, then clear it.
    private func openPendingLink() {
        guard let link = push.pendingLink else { return }
        push.pendingLink = nil
        switch PushRoute.from(link: link, isAdmin: isAdmin, mustClockIn: auth.mustClockIn) {
        case .tab(let i) where auth.isTrainerView && (i == 1 || i == 3):
            pushSheet = .tab(i)   // Leave / Team are hidden in the Trainer Admin view: open as a sheet
        case .tab(let i): pushSheet = nil; tab = i
        case let route: pushSheet = route
        }
    }

    @ViewBuilder private func pushScreen(_ route: PushRoute) -> some View {
        switch route {
        case .approvals: ApprovalsView()
        case .clock: ClockView()
        case .expenses: ExpensesView()
        case .timeOff: TimeOffView()
        case .adminTimesheet: TimesheetAdminView()
        case .myTimesheet: MyTimesheetView()
        case .tab(1): LeaveView()
        case .tab(3): TeamView()
        case .notifications, .tab: NotificationsView()
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
