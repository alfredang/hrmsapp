import SwiftUI

/// Admin: every active staff member's and intern's leave and MC for a month —
/// approved vs pending days per type, intern time-off hours, and year balances.
/// Same data the HRMS sends to the AI agent (`/api/mobile/leave-summary`).
struct LeaveSummaryView: View {
    @State private var month = AttendanceMonth.current()
    @State private var state: LoadState<LeaveSummary> = .idle
    @State private var interns = false

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Leave & MC").font(.headline).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            MonthSwitcher(month: $month)
                        }
                        totals(data)
                        Picker("Group", selection: $interns) {
                            Text("Staff (\(data.totals.headcount.staff))").tag(false)
                            Text("Interns (\(data.totals.headcount.interns))").tag(true)
                        }
                        .pickerStyle(.segmented)
                        let rows = data.employees.filter { $0.isIntern == interns }
                        if rows.isEmpty {
                            EmptyHint(icon: "person.crop.circle.badge.questionmark",
                                      text: "No \(interns ? "interns" : "staff") for \(AttendanceMonth.label(month)).")
                        }
                        ForEach(rows) { e in
                            NavigationLink {
                                LeaveSummaryDetailView(employee: e, month: month)
                            } label: { row(e) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .onChange(of: month) { _ in Task { await load() } }
    }

    private func totals(_ data: LeaveSummary) -> some View {
        let al = data.totals.byLeaveType.first { $0.code == "AL" }
        let pending = data.totals.byLeaveType.reduce(0) { $0 + $1.pendingDays }
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(value: "\(data.totals.headcount.total)", label: "People",
                         icon: "person.2.fill", tint: Theme.sky)
                StatTile(value: Self.num(data.totals.mc.approvedDays),
                         label: "MC days · \(data.totals.mc.employeesOnMc) on MC",
                         icon: "cross.case.fill", tint: .pink)
            }
            HStack(spacing: 12) {
                StatTile(value: Self.num(al?.approvedDays ?? 0), label: "AL days",
                         icon: "sun.max.fill", tint: .orange)
                StatTile(value: Self.num(pending), label: "Pending days",
                         icon: "hourglass", tint: .yellow)
            }
        }
    }

    private func row(_ e: LeaveSummaryEmployee) -> some View {
        Card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text([e.employeeId, e.position].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 10) {
                        metric("MC", e.approved("MC"), .pink)
                        metric("AL", e.approved("AL"), .orange)
                        if e.otherApproved > 0 { metric("Other", e.otherApproved, Theme.sky) }
                        if e.isIntern, let t = e.timeOff, t.approvedHours + t.pendingHours > 0 {
                            Text("\(Self.num(t.approvedHours)) h off")
                                .font(.caption2.weight(.semibold)).foregroundStyle(.purple)
                        }
                    }
                }
                Spacer()
                if e.pendingDays > 0 { StatusPill(status: "PENDING") }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func metric(_ label: String, _ v: Double, _ tint: Color) -> some View {
        Text("\(label) \(v == 0 ? "–" : Self.num(v))")
            .font(.caption2.weight(.semibold)).monospacedDigit()
            .foregroundStyle(v == 0 ? .white.opacity(0.45) : tint)
    }

    /// "2" / "1.5"
    static func num(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.leaveSummary(month: month)) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}

/// One person's leave requests in the month plus their year balances.
struct LeaveSummaryDetailView: View {
    let employee: LeaveSummaryEmployee
    let month: String

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text([employee.name, employee.employeeId, employee.department].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 12) {
                        StatTile(value: balance("AL"), label: "AL available", icon: "sun.max.fill", tint: .orange)
                        StatTile(value: balance("MC"), label: "MC available", icon: "cross.case.fill", tint: .pink)
                    }

                    Text(AttendanceMonth.label(month)).font(.headline).foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 4)
                    if employee.requests.isEmpty {
                        EmptyHint(icon: "calendar.badge.checkmark", text: "No leave in \(AttendanceMonth.label(month)).")
                    }
                    ForEach(employee.requests) { r in
                        Card {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.leaveTypeName).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    Text(dates(r)).font(.caption).foregroundStyle(.white.opacity(0.7))
                                    if r.daysInMonth != r.totalDays {
                                        Text("\(Fmt.days(r.daysInMonth)) this month of \(Fmt.days(r.totalDays))")
                                            .font(.caption2).foregroundStyle(.white.opacity(0.55))
                                    }
                                    if r.hasDocument {
                                        Label("Certificate attached", systemImage: "paperclip")
                                            .font(.caption2).foregroundStyle(Theme.sky)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(Fmt.days(r.daysInMonth)).font(.subheadline.weight(.bold))
                                        .monospacedDigit().foregroundStyle(.white)
                                    StatusPill(status: r.status)
                                }
                            }
                        }
                    }

                    if let t = employee.timeOff, !t.requests.isEmpty {
                        Text("Time off (hourly)").font(.headline).foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 4)
                        ForEach(t.requests) { x in
                            Card {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(AttendanceMonth.dayLabel(x.date)).font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text("\(x.startTime)–\(x.endTime) · \(x.reason)")
                                            .font(.caption).foregroundStyle(.white.opacity(0.7))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 6) {
                                        Text("\(LeaveSummaryView.num(x.hours)) h").font(.subheadline.weight(.bold))
                                            .monospacedDigit().foregroundStyle(.white)
                                        StatusPill(status: x.status)
                                    }
                                }
                            }
                        }
                    }

                    if !employee.balances.isEmpty {
                        Text("Year balances").font(.headline).foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 4)
                        Card {
                            VStack(spacing: 10) {
                                ForEach(employee.balances) { b in
                                    HStack {
                                        Text(b.name).font(.subheadline).foregroundStyle(.white)
                                        Spacer()
                                        Text("\(LeaveSummaryView.num(b.usedYtd)) used · \(LeaveSummaryView.num(b.available)) left")
                                            .font(.caption).monospacedDigit().foregroundStyle(.white.opacity(0.75))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .brandBar()
    }

    private func balance(_ code: String) -> String {
        employee.available(code).map(LeaveSummaryView.num) ?? "—"
    }

    private func dates(_ r: LeaveSummaryRequest) -> String {
        r.startDate == r.endDate
            ? AttendanceMonth.dayLabel(r.startDate)
            : "\(AttendanceMonth.dayLabel(r.startDate)) – \(AttendanceMonth.dayLabel(r.endDate))"
    }
}
