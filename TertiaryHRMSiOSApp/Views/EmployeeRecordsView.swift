import SwiftUI

/// Approver drill-down from the Team tab: one person's clock-in history, MC
/// history and leave history. Reading another employee's records is
/// enforced server-side (403 unless approver or self).
struct EmployeeRecordsView: View {
    let employee: Employee
    @State private var state: LoadState<EmployeeRecords> = .idle

    /// How many rows each section previews before "See all".
    private let previewCount = 3

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header(data.employee)

                        // The month's Annual Leave, No Pay Leave, MC and Payback, with a month
                        // filter, for working out the pay (Alfred, 26 Nov 2026).
                        PayMonthSection(employeeId: employee.id)

                        // Each tile opens its full history.
                        if let balances = data.balances, !balances.isEmpty {
                            balanceTiles(data, balances)
                        } else {
                            legacyTiles(data)
                        }

                        if data.showsClock(listIntern: employee.intern) {
                            clockSection(data)
                        }
                        leaveSection(title: "MC history", icon: "cross.case",
                                     empty: "No medical leave on record.", rows: data.medical, name: data.employee.name)
                        leaveSection(title: "Leave history", icon: "calendar",
                                     empty: "No leave on record.", rows: data.otherLeave, name: data.employee.name)
                        if let paybacks = data.paybacks {
                            historySection(title: "Payback history", icon: "arrow.uturn.backward.circle",
                                           empty: "No paybacks on record.", rows: paybacks, id: "records.paybacks") {
                                PaybackHistoryListView(name: data.employee.name, rows: paybacks)
                            } row: { PaybackRow(payback: $0) }
                        }
                        if let claims = data.claims {
                            historySection(title: "Expense claim history", icon: "creditcard",
                                           empty: "No expense claims on record.", rows: claims, id: "records.claims") {
                                ClaimHistoryListView(name: data.employee.name, rows: claims)
                            } row: { ExpenseClaimRow(claim: $0) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
    }

    private func header(_ e: RecordsEmployee) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(e.name).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                Text([e.position, e.department].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.75))
                Text([e.employeeCode, e.employmentType?.replacingOccurrences(of: "_", with: " ").capitalized]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.sky)
            }
        }
    }

    // MARK: KPI tiles

    /// Annual Leave, MC and No Pay Leave: "5 taken" and "7/12 balance" (Alfred, 25 Nov 2026).
    private func balanceTiles(_ data: EmployeeRecords, _ balances: [RecordsBalance]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(balances) { b in
                NavigationLink {
                    LeaveHistoryListView(title: "\(b.name) history", name: data.employee.name,
                                         rows: data.requests(for: b), empty: "No \(b.name) on record.")
                } label: {
                    BalanceTile(balance: b)
                }
                .accessibilityIdentifier("records.balance.\(b.code)")
            }
        }
        .buttonStyle(.plain)
    }

    /// Older server (no balances): days clocked, MC days and leave days.
    private func legacyTiles(_ data: EmployeeRecords) -> some View {
        HStack(spacing: 10) {
            if data.showsClock(listIntern: employee.intern) {
                NavigationLink {
                    ClockHistoryView(name: data.employee.name, attendance: data.attendance)
                } label: {
                    StatTile(value: "\(data.attendance.daysWorked)", label: "Days clocked",
                             icon: "clock.fill", tint: .teal)
                }
            }
            NavigationLink {
                LeaveHistoryListView(title: "MC history", name: data.employee.name,
                                     rows: data.medical, empty: "No medical leave on record.")
            } label: {
                StatTile(value: approvedDays(data.medical), label: "MC days",
                         icon: "cross.case.fill", tint: .pink)
            }
            NavigationLink {
                LeaveHistoryListView(title: "Leave history", name: data.employee.name,
                                     rows: data.otherLeave, empty: "No leave on record.")
            } label: {
                StatTile(value: approvedDays(data.otherLeave), label: "Leave days",
                         icon: "airplane", tint: Theme.sky)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Clock-in history

    private func clockSection(_ data: EmployeeRecords) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Clock-in history", icon: "clock")
            NavigationLink {
                ClockHistoryView(name: data.employee.name, attendance: data.attendance)
            } label: {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        if data.attendance.days.isEmpty {
                            Text("No clock-ins on record.")
                                .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                        } else {
                            ForEach(data.attendance.days.prefix(previewCount)) { PunchLine(day: $0) }
                        }
                        Divider().overlay(Theme.ink.opacity(0.15))
                        HStack {
                            Text(String(format: "%.1f h total", data.attendance.totalHours))
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.success)
                            Spacer()
                            Text("See all clock in/out").font(.caption.weight(.semibold)).foregroundStyle(Theme.sky)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.sky)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: MC / leave history

    @ViewBuilder
    private func leaveSection(title: String, icon: String, empty: String,
                              rows: [LeaveRequest], name: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(title, icon: icon)
                Spacer()
                if rows.count > previewCount {
                    NavigationLink {
                        LeaveHistoryListView(title: title, name: name, rows: rows, empty: empty)
                    } label: {
                        Text("See all \(rows.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.sky)
                    }
                }
            }
            if rows.isEmpty {
                Card { Text(empty).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7)) }
            } else {
                ForEach(rows.prefix(previewCount)) { LeaveRequestRow(request: $0) }
            }
        }
    }

    /// A history section: up to three rows, then "See all" for the full list.
    @ViewBuilder
    private func historySection<Item: Identifiable, Full: View, RowView: View>(
        title: String, icon: String, empty: String, rows: [Item], id: String,
        @ViewBuilder full: @escaping () -> Full, @ViewBuilder row: @escaping (Item) -> RowView
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(title, icon: icon)
                Spacer()
                if rows.count > previewCount {
                    NavigationLink { full() } label: {
                        Text("See all \(rows.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.sky)
                    }
                }
            }
            if rows.isEmpty {
                Card { Text(empty).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7)) }
            } else {
                ForEach(rows.prefix(previewCount)) { row($0) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
    }

    /// Approved days only — pending/rejected requests weren't taken.
    private func approvedDays(_ rows: [LeaveRequest]) -> String {
        let total = rows.filter { $0.status.uppercased() == "APPROVED" }.reduce(0) { $0 + $1.days }
        return total.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", total) : String(format: "%.1f", total)
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.employeeRecords(id: employee.id)) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load records.") }
    }
}

/// "Month for pay": a month filter and four cards for that month — Annual Leave, No Pay Leave,
/// MC ("No Pay MC" for interns, "Paid MC" for staff) and Payback (Alfred, 26 Nov 2026: "easier for us to
/// compute the payout"). Hidden on an older server that has no `pay-month` endpoint.
struct PayMonthSection: View {
    let employeeId: String
    @State private var month = AttendanceMonth.current()
    @State private var data: PayMonthSummary?
    @State private var unavailable = false

    var body: some View {
        if !unavailable {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Label("Month for pay", systemImage: "calendar.badge.clock")
                        .font(.headline).foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    Button { month = AttendanceMonth.shift(month, by: -1) } label: {
                        Image(systemName: "chevron.left").padding(6)
                    }
                    .accessibilityLabel("Previous month")
                    .accessibilityIdentifier("records.payMonth.previous")
                    Text(AttendanceMonth.label(month))
                        .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("records.payMonth.month")
                    Button { month = AttendanceMonth.shift(month, by: 1) } label: {
                        Image(systemName: "chevron.right").padding(6)
                    }
                    .accessibilityLabel("Next month")
                    .accessibilityIdentifier("records.payMonth.next")
                }
                .foregroundStyle(Theme.sky)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(data?.tiles ?? placeholders) { t in
                        Card {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: t.color)).frame(width: 9, height: 9)
                                    Text(t.label).font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                }
                                Text(data == nil ? "—" : t.value)
                                    .font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(Theme.ink)
                                Text(t.hint).font(.caption2).foregroundStyle(Theme.mist).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("records.payMonth.\(t.label)")
                    }
                }
                .opacity(data?.month == month ? 1 : 0.5)
            }
            .task(id: month) { await load() }
        }
    }

    private var placeholders: [PayMonthSummary.Tile] {
        ["Annual Leave", "No Pay Leave", "MC", "Payback"].map { .init(label: $0, value: "—", hint: " ", color: 0x6B7280) }
    }

    private func load() async {
        do {
            let d = try await HRMSAPI.shared.payMonth(employeeId: employeeId, month: month)
            if d.month == month || data == nil { data = d }
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            // An older server (404) or no access: leave the section out rather than show an error.
            if data == nil { unavailable = true }
        }
    }
}

/// One balance KPI: the leave name, days taken, and the balance out of the allowance.
struct BalanceTile: View {
    let balance: RecordsBalance

    private var icon: String {
        switch balance.kind {
        case .mc: return "cross.case.fill"
        case .npl: return "banknote"
        default: return "airplane"
        }
    }
    private var tint: Color {
        switch balance.kind {
        case .mc: return .pink
        case .npl: return Theme.warning
        default: return Theme.sky
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Label(balance.kind == .al ? "Leave" : balance.name, systemImage: icon)
                    .font(.caption.weight(.semibold)).foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(RecordsBalance.days(balance.taken))
                    .font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(Theme.ink)
                Text("taken").font(.caption).foregroundStyle(Theme.mist)
                Divider().overlay(Theme.ink.opacity(0.12))
                Text("\(RecordsBalance.days(balance.available))/\(RecordsBalance.days(balance.allowance))")
                    .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.success)
                Text("balance").font(.caption).foregroundStyle(Theme.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(balance.name): \(balance.takenText), \(balance.balanceText)")
    }
}

/// Every clock in / out on record for one person, grouped by month with
/// each month's total hours.
struct ClockHistoryView: View {
    let name: String
    let attendance: RecordsAttendance

    private var months: [(month: String, days: [AttendanceDay])] {
        // `days` arrives newest first, so grouping preserves that order.
        var order: [String] = []
        var groups: [String: [AttendanceDay]] = [:]
        for d in attendance.days {
            let m = String(d.date.prefix(7))
            if groups[m] == nil { order.append(m) }
            groups[m, default: []].append(d)
        }
        return order.map { ($0, groups[$0]!) }
    }

    var body: some View {
        GradientScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("\(name) · Clock in/out history")
                        .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                    HStack(spacing: 12) {
                        StatTile(value: String(format: "%.1f h", attendance.totalHours),
                                 label: "Total hours", icon: "sum", tint: .teal)
                        StatTile(value: "\(attendance.daysWorked)",
                                 label: "Days worked", icon: "calendar.badge.checkmark", tint: Theme.sky)
                    }
                    if attendance.days.isEmpty {
                        EmptyHint(icon: "clock.badge.questionmark", text: "No clock-ins on record.")
                    }
                    ForEach(months, id: \.month) { group in
                        HStack {
                            Text(AttendanceMonth.label(group.month))
                                .font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
                            Spacer()
                            Text(String(format: "%.2f h · %d day%@",
                                        group.days.reduce(0) { $0 + ($1.hours ?? 0) },
                                        group.days.count, group.days.count == 1 ? "" : "s"))
                                .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.success)
                        }
                        .padding(.top, 6)
                        ForEach(group.days) { d in Card { PunchLine(day: d) } }
                    }
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}

/// The full list of one person's MC or leave requests.
struct LeaveHistoryListView: View {
    let title: String
    let name: String
    let rows: [LeaveRequest]
    var empty = "Nothing on record."

    var body: some View {
        GradientScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("\(name) · \(title)").font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                    if rows.isEmpty {
                        EmptyHint(icon: "tray", text: empty)
                    }
                    ForEach(rows) { LeaveRequestRow(request: $0) }
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}

/// Every No Pay Leave payback on record for one person.
struct PaybackHistoryListView: View {
    let name: String
    let rows: [RecordsPayback]

    var body: some View {
        GradientScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("\(name) · Payback history").font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                    if rows.isEmpty { EmptyHint(icon: "tray", text: "No paybacks on record.") }
                    ForEach(rows) { PaybackRow(payback: $0) }
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}

/// Every expense claim on record for one person.
struct ClaimHistoryListView: View {
    let name: String
    let rows: [ExpenseClaim]

    var body: some View {
        GradientScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("\(name) · Expense claim history").font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                    if rows.isEmpty { EmptyHint(icon: "tray", text: "No expense claims on record.") }
                    ForEach(rows) { ExpenseClaimRow(claim: $0) }
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}

/// A payback card: the No Pay Leave day paid back, the off day worked, status and days.
struct PaybackRow: View {
    let payback: RecordsPayback

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Pay Leave \(Fmt.date(payback.nplDate))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("Worked \(Fmt.date(payback.workDate))")
                        .font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
                    if let r = payback.rejectionReason, !r.isEmpty {
                        Text(r).font(.caption2).foregroundStyle(Theme.danger).lineLimit(2)
                    } else if let note = payback.note, !note.isEmpty {
                        Text(note).font(.caption2).foregroundStyle(Theme.ink.opacity(0.55)).lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusPill(status: payback.status)
                    Text(Fmt.days(payback.days)).font(.caption2).foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
        }
    }
}

/// One day's check-in / check-out line. A punch with no clock-out shows the
/// hours so far when it's today, or "No clock-out" for an earlier day (the
/// person forgot to clock out, so the hours can't be worked out).
struct PunchLine: View {
    let day: AttendanceDay

    private var open: Bool { day.clockIn != nil && day.clockOut == nil }
    private var inProgress: Bool { open && day.date == AttendanceMonth.today() }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(AttendanceMonth.dayLabel(day.date))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("In \(AttendanceMonth.time(day.clockIn))  ·  Out \(day.clockOut != nil ? AttendanceMonth.time(day.clockOut) : (inProgress ? "…" : "—"))")
                    .font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
            }
            Spacer()
            if let h = day.hours {
                Text(String(format: "%.2f h", h))
                    .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Theme.success)
            } else if inProgress, let start = Fmt.dateObj(day.clockIn) {
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.2f h", max(0, ctx.date.timeIntervalSince(start) / 3600)))
                            .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Theme.warning)
                        Text("so far").font(.caption2).foregroundStyle(Theme.ink.opacity(0.7))
                    }
                }
            } else if open {
                Text("No clock-out")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.warning)
            }
        }
    }
}

/// A leave request card — type, dates, reason, status and days.
struct LeaveRequestRow: View {
    let request: LeaveRequest

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.leaveType).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("\(Fmt.date(request.startDate)) → \(Fmt.date(request.endDate))")
                        .font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
                    if let reason = request.reason, !reason.isEmpty {
                        Text(reason).font(.caption2).foregroundStyle(Theme.ink.opacity(0.55)).lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusPill(status: request.status)
                    Text(Fmt.days(request.days)).font(.caption2).foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
        }
    }
}
