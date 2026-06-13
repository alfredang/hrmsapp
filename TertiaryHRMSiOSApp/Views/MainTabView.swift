import SwiftUI

/// The signed-in app shell. Four tabs cover the HR modules (Accounting is
/// intentionally excluded). Each tab is its own navigation stack on the
/// Premier Blue surface.
struct MainTabView: View {
    init() {
        // Dark, translucent tab + nav bars to sit on the Premier Blue backdrop.
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.04, green: 0.10, blue: 0.22, alpha: 1)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 0.04, green: 0.10, blue: 0.22, alpha: 1)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { LeaveView() }
                .tabItem { Label("Leave", systemImage: "calendar.badge.clock") }
            NavigationStack { TeamView() }
                .tabItem { Label("Team", systemImage: "person.2.fill") }
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
        }
        .tint(Theme.sky)
    }
}
