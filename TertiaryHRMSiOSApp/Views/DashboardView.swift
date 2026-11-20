import SwiftUI

/// Home tab — a snapshot pulled from /api/mobile/summary.
struct DashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var state: LoadState<DashboardSummary> = .idle
    /// Approvers: active staff and interns for the Home tiles (from Analytics). nil until
    /// loaded, or when the server cannot give them: the two tiles are then left out.
    @State private var headcount: (staff: Int, interns: Int)?

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { s in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        greeting(s)

                        if s.isAdmin {
                            // The web dashboard's three KPI tiles: staff, interns, pending approvals.
                            sectionTitle("Overview")
                            HStack(spacing: 10) {
                                if let h = headcount {
                                    kpi("Full-time staff", h.staff, "person.2.fill", Theme.sky, id: "staff") { TeamView(group: .staff) }
                                    kpi("Interns", h.interns, "graduationcap.fill", Theme.sky, id: "interns") { TeamView(group: .interns) }
                                }
                                let pending = s.pendingLeaves + s.pendingClaims
                                kpi("Pending approvals", pending, "tray.full.fill",
                                    pending > 0 ? Theme.gold600 : Theme.sky, id: "pending") { ApprovalsView() }
                            }
                            NavigationLink(destination: AnalyticsView()) {
                                Card(padding: 14) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "chart.bar.xaxis").font(.title3).foregroundStyle(Theme.sky)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Analytics").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                            Text("Revenue, leave and headcount, last 12 months")
                                                .font(.caption).foregroundStyle(Theme.mist).lineLimit(1).minimumScaleFactor(0.85)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
                                    }
                                }
                            }
                            .accessibilityIdentifier("home.analytics")
                        }

                        sectionTitle("Quick actions")
                        HStack(spacing: 12) {
                            quickAction("Clock in / out", "clock.badge.checkmark.fill", Theme.gold600) { ClockView() }
                            quickAction("Snap a claim", "camera.fill", .orange) { NewClaimView() }
                        }

                        sectionTitle("My balances")
                        HStack(spacing: 12) {
                            StatTile(value: fmt(s.alAvailable), label: "Annual leave", icon: "sun.max.fill", tint: Theme.sky)
                            StatTile(value: fmt(s.mcAvailable), label: "Medical leave", icon: "cross.case.fill", tint: .pink)
                        }
                        HStack(spacing: 12) {
                            StatTile(value: fmt(s.otRemaining), label: "OT leave", icon: "clock.arrow.circlepath", tint: .teal)
                            StatTile(value: Fmt.money(s.expenseYtd), label: "Expenses YTD", icon: "creditcard.fill", tint: .green)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar(bell: true)
        .task { await NotificationStore.shared.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .hrmsForeground)) { _ in Task { await load() } }
    }

    private func greeting(_ s: DashboardSummary) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back").font(.subheadline).foregroundStyle(Theme.ink.opacity(0.75))
                Text(s.name ?? auth.user?.displayName ?? "Employee")
                    .font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                Text(s.role?.capitalized ?? "")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.chipFill.opacity(0.55)).clipShape(Capsule()).foregroundStyle(Theme.chipInk)
            }
        }
    }

    private func quickAction<D: View>(_ title: String, _ icon: String, _ tint: Color,
                                      @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink(destination: dest()) {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: icon).foregroundStyle(tint)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                }
            }
        }
    }

    /// One admin KPI tile; a tap opens its list.
    private func kpi<D: View>(_ label: String, _ value: Int, _ icon: String, _ tint: Color, id: String,
                              @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink(destination: dest()) {
            Card(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: icon).foregroundStyle(tint).frame(height: 22)
                    Text("\(value)").font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(Theme.ink)
                    Text(label).font(.caption).foregroundStyle(Theme.mist).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.kpi.\(id)")
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private func load() async {
        state = .loading
        do {
            let s = try await HRMSAPI.shared.summary()
            auth.canManageTrainers = s.showsTrainers
            state = .loaded(s)
            // Staff and intern counts come with Analytics (approvers only); a failure only hides the tiles.
            if s.isAdmin, let counts = try? await HRMSAPI.shared.analytics().activeCounts { headcount = counts }
        }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
