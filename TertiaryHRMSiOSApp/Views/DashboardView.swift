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

                        // Accountants: claims waiting, then this month's bank income and expenses (web FinanceKpiRow).
                        if let f = s.financeKpis {
                            sectionTitle("Finance")
                            financeCard(f)
                        }

                        // Trainer Admins: the same three counts as the Trainers screen tiles (web TrainerKpiRow).
                        if let t = s.trainerKpis {
                            sectionTitle("Trainers")
                            HStack(spacing: 10) {
                                kpi("Trainers", t.total, "person.text.rectangle.fill", Theme.sky, id: "trainers") { TrainersView(aclp: .all) }
                                kpi("ACLP trainers", t.aclp, "checkmark.seal.fill", Theme.sky, id: "aclp") { TrainersView(aclp: .aclp) }
                                kpi("Non-ACLP trainers", t.nonAclp, "person.crop.circle", Theme.sky, id: "nonaclp") { TrainersView(aclp: .non) }
                            }
                        }

                        sectionTitle("Quick actions")
                        HStack(spacing: 12) {
                            quickAction("Clock in / out", "clock.badge.checkmark.fill", Theme.gold600) { ClockView() }
                            quickAction("Snap a claim", "camera.fill", .orange) { NewClaimView() }
                        }

                        if !s.isAdmin, let stats = s.leaveSummary, !stats.isEmpty {
                            // Staff / interns: the server's leave tiles (same as the web dashboard and the
                            // decision email), shown as given.
                            sectionTitle("My leave")
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(Array(stats.enumerated()), id: \.offset) { i, stat in
                                    leaveTile(stat, index: i)
                                }
                            }
                            sectionTitle("My balances")
                        } else {
                            sectionTitle("My balances")
                            HStack(spacing: 12) {
                                StatTile(value: fmt(s.alAvailable), label: "Annual leave", icon: "sun.max.fill", tint: Theme.sky)
                                StatTile(value: fmt(s.mcAvailable), label: "Medical leave", icon: "cross.case.fill", tint: .pink)
                            }
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

    /// Icon and colour of each leave tile by its position (the web StatsCards order: paid leave
    /// taken, annual leave balance, MC taken, no-pay leave taken).
    private static let leaveTileStyle: [(icon: String, tint: Color)] = [
        ("calendar.badge.checkmark", Theme.success), ("calendar", Theme.sky),
        ("stethoscope", Theme.danger), ("calendar.badge.minus", Theme.warning),
    ]

    private func leaveTile(_ stat: SummaryStat, index: Int) -> some View {
        let style = Self.leaveTileStyle[index % Self.leaveTileStyle.count]
        // Interns have no paid MC: their sick leave is No Pay Leave.
        let hint = stat.hint ?? (auth.isIntern && stat.label == "MC taken" ? "Sick leave is No Pay Leave" : nil)
        return NavigationLink(destination: LeaveView()) {
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: style.icon).foregroundStyle(style.tint).frame(height: 20)
                    Text(stat.value).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(stat.label).font(.caption).foregroundStyle(Theme.mist).lineLimit(1).minimumScaleFactor(0.8)
                    if let hint {
                        Text(hint).font(.caption2).foregroundStyle(Theme.mist).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.label)
        .accessibilityValue([stat.value, hint].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.leave.\(index)")
    }

    /// Accountants: pending claims, then this month's income and expenses with the year so far.
    private func financeCard(_ f: FinanceKpis) -> some View {
        let rows: [(id: String, icon: String, tint: Color, label: String, value: String, sub: String)] = [
            ("pending", "doc.text.fill", f.pendingClaims > 0 ? Theme.gold600 : Theme.sky, "Pending expense claims",
             "\(f.pendingClaims)",
             f.pendingClaims > 0 ? "\(Fmt.money(f.pendingClaimsAmount)) waiting for approval" : "Nothing waiting"),
            ("income", "arrow.up.right", Theme.success, "Income, \(f.monthLabel)", Fmt.money(f.incomeMonth),
             "\(Fmt.money(f.incomeYtd)) in \(String(f.year)) so far"),
            ("expenses", "arrow.down.right", Theme.danger, "Expenses, \(f.monthLabel)", Fmt.money(f.expensesMonth),
             "\(Fmt.money(f.expensesYtd)) in \(String(f.year)) so far"),
        ]
        return Card(padding: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                if i > 0 { Divider().padding(.leading, 52) }
                HStack(spacing: 12) {
                    Image(systemName: r.icon).foregroundStyle(r.tint).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text(r.sub).font(.caption).foregroundStyle(Theme.mist).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 8)
                    Text(r.value).font(.headline).monospacedDigit().foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.label)
                .accessibilityValue("\(r.value), \(r.sub)")
                .accessibilityIdentifier("home.finance.\(r.id)")
            }
        }
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
