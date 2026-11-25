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
            } else if !auth.showsAccountant && !auth.showsAdmin {
                // Accountants have no leave or MC (Alfred, 22 Nov 2026): no Leave tab.
                // Admins have no Leave tab either (Alfred, 25 Nov 2026): leave management stays on
                // Home ("Leave & MC") and More → Leave Management. Staff, interns and an approver
                // previewing those roles keep their own leave with Apply.
                NavigationStack { LeaveView() }
                    .tabItem { Label("Leave", systemImage: "calendar.badge.clock") }.tag(1)
            }
            if auth.isTrainerView {
                // Trainer Admin view: no calendar (Alfred, 22 Nov 2026).
            } else if auth.showsAccountant && !auth.showsAdmin {
                // Accountants: the month's bank income in Calendar's place (Alfred, 22 Nov 2026).
                NavigationStack { BankTransactionsView(direction: .credit) }
                    .tabItem { Label("Income", systemImage: "chart.line.uptrend.xyaxis") }.tag(2)
            } else {
                NavigationStack { TeamCalendarView() }
                    .tabItem { Label("Calendar", systemImage: "calendar") }.tag(2)
            }
            // Only admins see the full team; everyone else gets the SOPs here (Alfred, 22 Nov 2026).
            if auth.showsAdmin {
                NavigationStack { TeamView() }
                    .tabItem { Label("Team", systemImage: "person.2.fill") }.tag(3)
            } else if auth.showsAccountant {
                // Accountants: the month's bank expenses (Alfred, 22 Nov 2026); SOP stays in More.
                NavigationStack { BankTransactionsView(direction: .debit) }
                    .tabItem { Label("Expenses", systemImage: "creditcard.fill") }.tag(3)
            } else if !auth.isTrainerView {
                NavigationStack { SopListView() }
                    .tabItem { Label("SOP", systemImage: "book.fill") }.tag(3)
            }
            // Admins: SOP after Team; Trainer Admin view: SOP after Trainers (Alfred, 25 Nov 2026).
            if auth.showsAdmin || auth.isTrainerView {
                NavigationStack { SopListView() }
                    .tabItem { Label("SOP", systemImage: "book.fill") }.tag(Self.sopTab)
            }
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }.tag(4)
        }
        .tint(Theme.sky)
        // Switching View As lands on the directory (the web opens /trainers) or back on Home.
        .onChange(of: auth.viewAs) { v in tab = v == .trainerAdmin && auth.canManageTrainers ? Self.trainersTab : 0 }
        .onChange(of: auth.isTrainerView) { on in
            if !on && (tab == Self.trainersTab || (tab == Self.sopTab && !auth.showsAdmin)) { tab = 0 }
        }
        // The selected tab can vanish when the admin view turns on (Leave) or off (the extra SOP tab).
        .onChange(of: auth.showsAdmin) { admin in
            if (admin && tab == 1) || (!admin && tab == Self.sopTab && !auth.isTrainerView) { tab = 0 }
        }
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
                case "notifications": NotificationsView()
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
                case "sop": SopListView()
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
    /// Tag of the SOP tab that admins (after Team) and the Trainer Admin view (after Trainers) get.
    /// Staff and interns have SOP in tag 3's place.
    static let sopTab = 6

    /// Route a tapped push (its web `link`) to a tab or a sheet, then clear it.
    private func openPendingLink() {
        guard let link = push.pendingLink else { return }
        push.pendingLink = nil
        switch PushRoute.from(link: link, isAdmin: isAdmin, mustClockIn: auth.mustClockIn) {
        case .tab(let i) where (auth.isTrainerView && (1...3).contains(i)) || (auth.showsAccountant && (i == 1 || i == 2))
                                || (auth.showsAdmin && i == 1):
            pushSheet = .tab(i)   // a hidden tab (Trainer Admin view: Leave / Team; accountants: Leave / Calendar; admins: Leave) opens as a sheet
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
        case .tab(1): if auth.showsAdmin { LeaveSummaryView() } else { LeaveView() }
        case .tab(2): TeamCalendarView()   // accountants: Calendar is not a tab
        case .tab(3):
            if auth.showsAdmin { TeamView() }
            else if auth.showsAccountant { BankTransactionsView(direction: .debit) }
            else { SopListView() }
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
