import SwiftUI

/// Home tab — a snapshot pulled from /api/mobile/summary.
struct DashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var state: LoadState<DashboardSummary> = .idle
    /// Approvers: ACTIVE staff and interns for the Home tiles (the Team list, which holds active
    /// people only, as the web's workforce snapshot). nil until loaded, or on an older server
    /// without the intern flag: the two tiles are then left out.
    @State private var headcount: (staff: Int, interns: Int)?
    /// Approvers: what is waiting, by type. nil until loaded (the tile then uses the summary counts).
    @State private var pending: PendingApprovals?
    @State private var refreshingPending = false
    /// The leave form opened from the balance card, with the types loaded at tap time.
    @State private var applySheet: ApplySheet?
    @State private var openingApply: String?
    @State private var applyError: String?

    private struct ApplySheet: Identifiable {
        let id = UUID()
        let types: [LeaveType]
        let balances: [LeaveBalance]
        let code: String
    }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { s in
                if auth.isTrainerView { trainerAdminHome(s) } else {
                // Admin layout only in the approver's own view; View As previews another role.
                let admin = s.isAdmin && auth.showsAdmin
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        greeting(s)
                        if auth.availableViews.count > 1 { viewAsRow }

                        // Each role gets its own Home (Alfred, 22 Nov 2026), in the order that role
                        // uses it most: interns / accountants who clock in see the punch first, staff
                        // see their leave and MC balances with the two apply buttons, admins the
                        // workforce overview.
                        if auth.showsMustClockIn { HomeClockCard(preview: auth.isRolePreview) }

                        if admin {
                            // The web dashboard's three KPI tiles: active staff, active interns, pending approvals.
                            sectionTitle("Overview")
                            HStack(spacing: 10) {
                                if let h = headcount {
                                    kpi("Full-time staff", h.staff, "person.2.fill", Theme.sky, id: "staff") { TeamView(group: .staff) }
                                    kpi("Interns", h.interns, "graduationcap.fill", Theme.sky, id: "interns") { TeamView(group: .interns) }
                                }
                                let waiting = pending?.total ?? (s.pendingLeaves + s.pendingClaims)
                                kpi("Pending approvals", waiting, "tray.full.fill",
                                    waiting > 0 ? Theme.gold600 : Theme.sky, id: "pending") { ApprovalsView() }
                            }
                            if let pending {
                                HStack {
                                    sectionTitle("Waiting for approval")
                                    Spacer()
                                    Button {
                                        Task { await refreshPending() }
                                    } label: {
                                        HStack(spacing: 4) {
                                            if refreshingPending { ProgressView().scaleEffect(0.7) }
                                            else { Image(systemName: "arrow.clockwise") }
                                            Text("Refresh")
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.sky)
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                    }
                                    .disabled(refreshingPending)
                                    .accessibilityIdentifier("home.pending.refresh")
                                }
                                pendingCard(pending)
                            }
                        }

                        // Accountants: claims waiting, then this month's bank income and expenses (web FinanceKpiRow).
                        if let f = s.financeKpis {
                            sectionTitle("Finance")
                            financeCard(f, canApprove: s.isAdmin)
                        }

                        // Everyone but admins: leave and MC left, and the two forms one tap away.
                        // Accountants have no leave or MC (Alfred, 22 Nov 2026).
                        if !admin && !auth.showsAccountant { balanceCard(s) }

                        // Trainer Admins: the same three counts as the Trainers screen tiles (web TrainerKpiRow).
                        // Trainer counts: Trainer Admins who are not approvers. Admins see them in the
                        // Trainer Admin view, not on the admin Home (Alfred, 22 Nov 2026).
                        if let t = s.trainerKpis, !admin, !auth.isRolePreview {
                            sectionTitle("Trainer Admin")
                            TrainerHomeSearch()
                            HStack(spacing: 10) {
                                kpi("Trainers", t.total, "person.text.rectangle.fill", Theme.sky, id: "trainers") { TrainersView(aclp: .all) }
                                kpi("ACLP trainers", t.aclp, "checkmark.seal.fill", Theme.sky, id: "aclp") { TrainersView(aclp: .aclp) }
                                kpi("Non-ACLP trainers", t.nonAclp, "person.crop.circle", Theme.sky, id: "nonaclp") { TrainersView(aclp: .non) }
                            }
                        }

                        // Accountants: finance only, no quick actions (Alfred, 22 Nov 2026).
                        if !auth.showsAccountant { quickActions(isAdmin: admin) }

                        if !admin, !auth.showsAccountant, let stats = s.leaveSummary, !stats.isEmpty {
                            // Staff / interns: the server's leave tiles (same as the web dashboard and the
                            // decision email), shown as given.
                            sectionTitle("My leave this year")
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(Array(stats.enumerated()), id: \.offset) { i, stat in
                                    leaveTile(stat, index: i)
                                }
                            }
                        }
                        // Admins: no personal balances on Home (Alfred, 22 Nov 2026); their own leave is in the Leave tab.
                        if !admin && !auth.showsAccountant {
                            HStack(spacing: 12) {
                                StatTile(value: fmt(s.otRemaining), label: "OT leave", icon: "clock.arrow.circlepath", tint: .teal)
                                StatTile(value: Fmt.money(s.expenseYtd), label: "Expenses YTD", icon: "creditcard.fill", tint: .green)
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
                }
            }
        }
        .brandBar(bell: true)
        .sheet(item: $applySheet, onDismiss: { Task { await load() } }) { sheet in
            ApplyLeaveView(types: sheet.types, balances: sheet.balances, isIntern: auth.isIntern,
                           initialTypeCode: sheet.code)
        }
        .alert("Could not open the form", isPresented: Binding(get: { applyError != nil },
                                                               set: { if !$0 { applyError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(applyError ?? "") }
        .task { await NotificationStore.shared.refresh() }
        .onChange(of: auth.viewAs) { _ in Task { await load() } }
        .onReceive(NotificationCenter.default.publisher(for: .hrmsForeground)) { _ in Task { await load() } }
    }

    /// Home in the Trainer Admin view (web dashboard in view mode "trainer"): the trainer KPI row
    /// only, plus a way into the directory. No leave, finance, admin or quick-action sections.
    private func trainerAdminHome(_ s: DashboardSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trainer Admin").font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("home.trainerAdmin.title")
                        Text(s.name ?? auth.user?.displayName ?? "")
                            .font(.subheadline).foregroundStyle(Theme.mist)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // The switcher right under the name (Alfred, 22 Nov 2026), as on the other Homes.
                if auth.availableViews.count > 1 { viewAsRow }
                // Search every trainer by name, skill, certification or course (Alfred, 22 Nov 2026).
                TrainerHomeSearch()
                if let t = s.trainerKpis {
                    HStack(spacing: 10) {
                        kpi("Trainers", t.total, "person.text.rectangle.fill", Theme.sky, id: "trainers") { TrainersView(aclp: .all) }
                        kpi("ACLP trainers", t.aclp, "checkmark.seal.fill", Theme.sky, id: "aclp") { TrainersView(aclp: .aclp) }
                        kpi("Non-ACLP trainers", t.nonAclp, "person.crop.circle", Theme.sky, id: "nonaclp") { TrainersView(aclp: .non) }
                    }
                }
                NavigationLink(destination: TrainersView()) {
                    Card(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.text.rectangle.fill").font(.title3).foregroundStyle(Theme.sky)
                            Text("Open trainer directory").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
                        }
                    }
                }
                .accessibilityIdentifier("home.trainerAdmin.directory")
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await load() }
    }

    /// View As on Home (approvers and Trainer Admins): switch to another role's screens to check them.
    private var viewAsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewAsMenu(id: "home.viewAs")
            if auth.isRolePreview {
                Text("Previewing the \(auth.viewAs.title(isApprover: true)) screens. Forms still use your own account; clocking in is off.")
                    .font(.caption).foregroundStyle(Theme.mist)
                    .padding(.horizontal, 6)
                    .accessibilityIdentifier("home.viewAs.note")
            }
        }
    }

    /// Welcome card; a tap opens My Profile. The name spans the full width on one line (shrinking
    /// for a long name); the chevron sits beside "Welcome back" so it takes no width from the name.
    private func greeting(_ s: DashboardSummary) -> some View {
        NavigationLink(destination: ProfileView()) {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Welcome back").font(.subheadline).foregroundStyle(Theme.ink.opacity(0.75))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
                    }
                    Text(s.name ?? auth.user?.displayName ?? "Employee")
                        .font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("home.name")
                    HStack(spacing: 10) {
                        Text(s.role?.capitalized ?? "")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.chipFill.opacity(0.55)).clipShape(Capsule()).foregroundStyle(Theme.chipInk)
                        Label("My Profile", systemImage: "person.crop.circle")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.sky)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.profile")
    }

    /// Quick actions follow the role, as on the web dashboard (`QuickActions`). Approvers get the
    /// admin actions; everyone else their own (leave and MC are on the balance card above).
    /// Clock in / out is never a quick action: people who must clock in have `HomeClockCard` at
    /// the top, and admins and staff do not clock in (Alfred, 22 Nov 2026).
    @ViewBuilder
    private func quickActions(isAdmin: Bool) -> some View {
        sectionTitle("Quick actions")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if isAdmin {
                quickAction("Approvals", "checkmark.circle.fill", Theme.success, id: "approvals") { ApprovalsView() }
                quickAction("Leave & MC", "cross.case.fill", .pink, id: "leavemc") { LeaveSummaryView() }
                quickAction("Timesheet", "person.badge.clock.fill", .teal, id: "timesheet") { TimesheetAdminView() }
                quickAction("Calendar", "calendar", Theme.sky, id: "calendar") { TeamCalendarView() }
            } else if auth.showsIntern {
                quickAction("My timesheet", "tablecells", .teal, id: "mytimesheet") { MyTimesheetView() }
                quickAction("Request time off", "hourglass", .orange, id: "timeoff") { TimeOffView() }
                quickAction("Snap a claim", "camera.fill", .green, id: "claim") { NewClaimView() }
                quickAction("Calendar", "calendar", Theme.sky, id: "calendar") { TeamCalendarView() }
            } else if auth.showsMustClockIn {
                // Accountants who clock in (web accountant view: claims first, then their timesheet).
                quickAction("Snap a claim", "camera.fill", .green, id: "claim") { NewClaimView() }
                quickAction("Expense claims", "creditcard.fill", .orange, id: "expenses") { ExpensesView() }
                quickAction("My timesheet", "tablecells", .teal, id: "mytimesheet") { MyTimesheetView() }
                quickAction("Off In Lieu", "calendar.badge.plus", Theme.sky, id: "offinlieu") { WeeklyTimesheetView() }
            } else {
                quickAction("Request time off", "hourglass", .orange, id: "timeoff") { TimeOffView() }
                quickAction("Snap a claim", "camera.fill", .green, id: "claim") { NewClaimView() }
                quickAction("Off In Lieu", "calendar.badge.plus", .teal, id: "offinlieu") { WeeklyTimesheetView() }
                quickAction("Payslips", "doc.text.fill", Theme.sky, id: "payslips") { PayslipsView() }
            }
        }
    }

    /// Staff, interns and accountants: annual leave and MC left (from the summary), with Apply for
    /// leave / Apply for MC opening the form preset to that type. Interns have no paid MC; their
    /// MC goes in as No Pay Leave with the photo kept (the form handles the switch).
    private func balanceCard(_ s: DashboardSummary) -> some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    balance(fmt(s.alAvailable), "Annual leave left", "sun.max.fill", Theme.sky, id: "al")
                    if auth.showsIntern {
                        balance("No pay", "Sick leave (MC)", "cross.case.fill", .pink, id: "mc")
                    } else {
                        balance(fmt(s.mcAvailable), "MC left", "cross.case.fill", .pink, id: "mc")
                    }
                }
                HStack(spacing: 10) {
                    applyButton("Apply for leave", "calendar.badge.plus", code: "AL", filled: true)
                    applyButton("Apply for MC", "cross.case.fill", code: "MC", filled: false)
                }
            }
        }
    }

    private func balance(_ value: String, _ label: String, _ icon: String, _ tint: Color, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                .labelStyle(TintedIconLabel(tint: tint))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.largeTitle.weight(.bold)).monospacedDigit().foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if value != "—" && value != "No pay" {
                    Text("days").font(.subheadline).foregroundStyle(Theme.mist)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value == "—" || value == "No pay" ? value : "\(value) days")
        .accessibilityIdentifier("home.balance.\(id)")
    }

    private func applyButton(_ title: String, _ icon: String, code: String, filled: Bool) -> some View {
        Button {
            Task { await openApply(code) }
        } label: {
            HStack(spacing: 6) {
                if openingApply == code { ProgressView().tint(filled ? .white : Theme.sky) }
                else { Image(systemName: icon) }
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(filled ? Color.white : Theme.sky)
            .background(filled ? Theme.royal600 : Theme.field)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.sky.opacity(filled ? 0 : 0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(openingApply != nil)
        .accessibilityIdentifier("home.apply.\(code)")
    }

    private func openApply(_ code: String) async {
        openingApply = code
        defer { openingApply = nil }
        do {
            let data = try await HRMSAPI.shared.leave()
            applySheet = ApplySheet(types: data.types, balances: data.balances, code: code)
        } catch {
            applyError = (error as? LocalizedError)?.errorDescription ?? "Please try again."
        }
    }

    private func quickAction<D: View>(_ title: String, _ icon: String, _ tint: Color, id: String,
                                      @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink(destination: dest()) {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: icon).foregroundStyle(tint)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("home.action.\(id)")
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
        let hint = stat.hint ?? (auth.showsIntern && stat.label == "MC taken" ? "Sick leave is No Pay Leave" : nil)
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

    /// Approvers: leave, MC, time off, claims and No Pay Leave paybacks waiting (→ Approvals); no
    /// missed punches on Home (23 Nov 2026). Feeds are best-effort: a failed one counts as 0, a failed
    /// approvals feed leaves the section out.
    private func loadPending() async {
        async let a = try? HRMSAPI.shared.approvals()
        async let t = try? HRMSAPI.shared.allTimeOff()
        // A failed or cancelled refresh keeps the last numbers: dropping them made the whole
        // section vanish (Alfred, 23 Nov 2026). Only a first load that fails leaves it out.
        guard let approvals = await a else { return }
        pending = PendingApprovals(approvals: approvals, timeOff: await t ?? [])
    }

    /// The section's Refresh button: the approval counts and the notices (badge) together.
    private func refreshPending() async {
        refreshingPending = true
        async let notices: Void = NotificationStore.shared.refresh()
        await loadPending()
        _ = await notices
        refreshingPending = false
    }

    private func pendingCard(_ p: PendingApprovals) -> some View {
        let rows: [(id: String, label: String, icon: String, tint: Color, count: Int)] = [
            ("leave", "Leave", "calendar.badge.clock", Theme.sky, p.leave),
            ("mc", "MC", "cross.case.fill", .pink, p.mc),
            ("timeoff", "Time off", "hourglass", .orange, p.timeOff),
            ("claims", "Expense claims", "creditcard.fill", .green, p.claims),
            ("payback", "Payback", "arrow.uturn.backward.circle.fill", .purple, p.paybacks),
        ]
        return Card(padding: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                if i > 0 { Divider().padding(.leading, 52) }
                NavigationLink {
                    ApprovalsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: r.icon).foregroundStyle(r.tint).frame(width: 24)
                        Text(r.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text("\(r.count)").font(.headline).monospacedDigit()
                            .foregroundStyle(r.count > 0 ? Theme.gold600 : Theme.mist)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.label)
                .accessibilityValue("\(r.count) waiting")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("home.pending.\(r.id)")
            }
        }
    }

    /// Accountants: pending claims, then this month's income and expenses with the year so far.
    /// Every row opens its detail (Alfred, 22 Nov 2026); pending claims open Approvals for approvers
    /// only (the server refuses anyone else).
    private func financeCard(_ f: FinanceKpis, canApprove: Bool) -> some View {
        let count = { (n: Int?, noun: String) in n.map { "\($0) \(noun)\($0 == 1 ? "" : "s") · " } ?? "" }
        var rows: [(id: String, icon: String, tint: Color, label: String, value: String, sub: String)] = [
            ("pending", "doc.text.fill", f.pendingClaims > 0 ? Theme.gold600 : Theme.sky, "Pending expense claims",
             "\(f.pendingClaims)",
             f.pendingClaims > 0 ? "\(Fmt.money(f.pendingClaimsAmount)) waiting for approval" : "Nothing waiting"),
            ("income", "arrow.up.right", Theme.success, "Income, \(f.monthLabel)", Fmt.money(f.incomeMonth),
             count(f.incomeCountMonth, "credit") + "\(Fmt.money(f.incomeYtd)) in \(String(f.year))"),
            ("expenses", "arrow.down.right", Theme.danger, "Expenses, \(f.monthLabel)", Fmt.money(f.expensesMonth),
             count(f.expenseCountMonth, "debit") + "\(Fmt.money(f.expensesYtd)) in \(String(f.year))"),
        ]
        if let n = f.statementImports {
            rows.append(("statements", "doc.richtext.fill", Theme.sky, "Bank statements", "\(n)",
                         f.statementLatestDate.map { "Imported up to \(Fmt.date($0))" } ?? "None imported yet"))
        }
        if f.statementImports != nil || f.reconciliation != nil {
            if let r = f.reconciliation {
                rows.append(("reconciliation", "scale.3d", r.toReview > 0 ? Theme.gold600 : Theme.success,
                             "Bank reconciliation", r.toReview > 0 ? "\(r.toReview) to review" : "All clear",
                             "\(Fmt.date(r.periodStart)) – \(Fmt.date(r.periodEnd)) · \(r.matched) matched"
                             + (r.status.uppercased() == "COMPLETED" ? "" : " · \(r.status.capitalized)")))
            } else {
                rows.append(("reconciliation", "scale.3d", Theme.mist, "Bank reconciliation", "Not run",
                             "Run it on the web: Accounting → Reconciliation"))
            }
        }
        return Card(padding: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                if i > 0 { Divider().padding(.leading, 52) }
                let tappable = r.id != "pending" || canApprove
                NavigationLink { financeDetail(r.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: r.icon).foregroundStyle(r.tint).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                            Text(r.sub).font(.caption).foregroundStyle(Theme.mist).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 8)
                        Text(r.value).font(.headline).monospacedDigit().foregroundStyle(Theme.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        if tappable {
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!tappable)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.label)
                .accessibilityValue("\(r.value), \(r.sub)")
                .accessibilityAddTraits(tappable ? .isButton : [])
                .accessibilityIdentifier("home.finance.\(r.id)")
            }
        }
    }

    /// The screen behind a Finance card row.
    @ViewBuilder
    private func financeDetail(_ id: String) -> some View {
        switch id {
        case "income": BankTransactionsView(direction: .credit)
        case "expenses": BankTransactionsView(direction: .debit)
        case "statements": BankStatementsView()
        case "reconciliation": ReconciliationView()
        default: ApprovalsView()
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
        // Keep Home on screen while refreshing (foreground, View As): blanking it also reset the
        // screens pushed from it, such as My Profile with its Edit sheet.
        if case .loaded = state {} else { state = .loading }
        do {
            let s = try await HRMSAPI.shared.summary(view: auth.isRolePreview ? auth.viewAs.rawValue : nil)
            auth.applyTrainerCapability(s.showsTrainers)
            state = .loaded(s)
            // Active staff and interns (approvers only); a failure only hides the two tiles.
            if s.isAdmin, auth.showsAdmin { await loadPending() }
            if s.isAdmin, auth.showsAdmin, let list = try? await HRMSAPI.shared.employees().employees,
               EmployeeGroup.isAvailable(list) {
                headcount = (EmployeeGroup.staff.filter(list).count, EmployeeGroup.interns.filter(list).count)
            }
        }
        catch { if case .loaded = state { return }; state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}

/// A label whose icon takes its own tint while the title keeps the label's colour.
private struct TintedIconLabel: LabelStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) { configuration.icon.foregroundStyle(tint); configuration.title }
    }
}

/// Home, for people who must clock in (interns, accountants without an approver role): today's
/// punch and a one-tap Clock in / Clock out, right under the greeting. History lives in ClockView.
struct HomeClockCard: View {
    /// An approver previewing the intern / accountant Home: the card shows, but cannot punch.
    var preview = false
    @State private var today: AttendancePunch?
    @State private var loaded = false
    @State private var punching = false
    @State private var error: String?

    private var clockedIn: Date? { today?.clockOut == nil ? Fmt.dateObj(today?.clockIn) : nil }
    private var done: Bool { today?.clockIn != nil && today?.clockOut != nil }

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: clockedIn != nil ? "clock.fill" : done ? "checkmark.circle.fill" : "sunrise.fill")
                        .font(.title2).foregroundStyle(clockedIn != nil ? Theme.success : done ? Theme.sky : Theme.gold600)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today").font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                        if let since = clockedIn {
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Text("Clocked in \(Self.time(since))" + (Self.elapsed(since, ctx.date).map { " · \($0)" } ?? ""))
                                    .font(.headline).monospacedDigit().foregroundStyle(Theme.ink)
                            }
                        } else if done {
                            Text("\(Self.time(Fmt.dateObj(today?.clockIn))) – \(Self.time(Fmt.dateObj(today?.clockOut)))"
                                 + (today?.hours.map { String(format: " · %.1f h", $0) } ?? ""))
                                .font(.headline).monospacedDigit().foregroundStyle(Theme.ink)
                        } else {
                            Text(loaded ? "Not clocked in yet" : "Loading…").font(.headline).foregroundStyle(Theme.ink)
                        }
                    }
                    Spacer(minLength: 0)
                    NavigationLink(destination: ClockView()) {
                        Text("History").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.sky)
                    }
                    .accessibilityIdentifier("home.clock.history")
                }
                if !done {
                    Button { Task { await punch() } } label: {
                        HStack(spacing: 8) {
                            if punching { ProgressView().tint(.white) }
                            else { Image(systemName: clockedIn != nil ? "stop.circle.fill" : "arrow.right.circle.fill") }
                            Text(clockedIn != nil ? "Clock out" : "Clock in")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(clockedIn != nil ? Theme.danger : Theme.royal600)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(punching || !loaded || preview)
                    .opacity(preview ? 0.5 : 1)
                    .accessibilityIdentifier("home.clock.punch")
                }
                if let error { StatusBanner(kind: .error, text: error) }
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .hrmsForeground)) { _ in Task { await load() } }
    }

    private func load() async {
        if let r = try? await HRMSAPI.shared.attendance() { today = r.today }
        loaded = true
    }

    private func punch() async {
        guard !punching else { return }
        error = nil
        punching = true
        defer { punching = false }
        do {
            try await HRMSAPI.shared.clock(clockedIn != nil ? .clockOut : .clockIn)
            await load()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? (error as NSError).localizedDescription
        }
    }

    static func time(_ d: Date?) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: d)
    }

    /// Time since clock-in; nil past 24 h (an open punch from an earlier day is not "working now").
    static func elapsed(_ from: Date, _ now: Date) -> String? {
        let m = max(0, Int(now.timeIntervalSince(from)) / 60)
        guard m < 24 * 60 else { return nil }
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
}

/// View As menu (Home and More): the person's own view, the role previews (approvers) and the
/// Trainer Admin view (TRAINER_ADMIN). Accessibility value = the current view's title.
struct ViewAsMenu: View {
    @EnvironmentObject private var auth: AuthViewModel
    let id: String

    var body: some View {
        let current = auth.viewAs.title(isApprover: auth.isApprover)
        Menu {
            ForEach(auth.availableViews) { v in
                Button { auth.viewAs = v } label: {
                    Label(v.title(isApprover: auth.isApprover), systemImage: auth.viewAs == v ? "checkmark" : v.icon)
                }
                .accessibilityIdentifier("viewAs.\(v.rawValue)")
            }
        } label: {
            Card(padding: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "eye.fill").foregroundStyle(Theme.sky)
                    Text("View as").font(.subheadline).foregroundStyle(Theme.mist)
                    Spacer(minLength: 8)
                    Text(current).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Theme.mist)
                }
            }
        }
        .accessibilityIdentifier(id)
        .accessibilityLabel("View as")
        .accessibilityValue(current)
    }
}
