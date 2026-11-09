import SwiftUI

// Timesheets are for interns only (Alfred, 10 Nov 2026 — mirrors the web):
// - Approvers: ONE "Timesheet" screen — missing-punch requests and Off In Lieu entries to
//   approve, then every intern's days worked + total hours for a month (tap for the days).
//   Replaces the separate "Intern Attendance" screen.
// - Interns: "Timesheet" — their own clock-in / clock-out days and hours by month.
// - Staff: no Timesheet; they log weekend / public-holiday work under "Off In Lieu".

/// Approvers: interns' monthly days + hours, missing punches and Off In Lieu approvals.
struct TimesheetAdminView: View {
    @State private var month = AttendanceMonth.current()
    @State private var summary: LoadState<AttendanceSummary> = .idle
    @State private var corrections: [AttendanceCorrection] = []
    @State private var offInLieu: [OffInLieuEntry] = []
    @State private var actionError: String?
    @State private var openCorrection: AttendanceCorrection?
    @State private var openOil: OffInLieuEntry?
    @State private var openIntern: AttendanceSummaryRow?
    @State private var showIntern = false

    private var pendingOil: [OffInLieuEntry] { offInLieu.filter { $0.status.uppercased() == "PENDING" } }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $summary, load: loadAll) { data in
                let interns = data.employees.filter(\.isIntern)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Timesheet").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                            Spacer()
                            MonthSwitcher(month: $month)
                        }
                        HStack(spacing: 12) {
                            StatTile(value: "\(interns.count)", label: "Interns", icon: "person.2.fill", tint: Theme.sky)
                            StatTile(value: "\(interns.reduce(0) { $0 + $1.daysWorked })", label: "Days worked",
                                     icon: "calendar.badge.checkmark", tint: .teal)
                            StatTile(value: Fmt.num(interns.reduce(0) { $0 + $1.totalHours }), label: "Hours",
                                     icon: "sum", tint: .teal)
                        }
                        if let actionError { StatusBanner(kind: .error, text: actionError) }

                        CollapsibleSection(title: "Missing punches", icon: "clock.badge.exclamationmark",
                                           count: corrections.count, countIsAttention: true) {
                            if corrections.isEmpty {
                                allClear("No missing-punch requests waiting.")
                            } else {
                                OneLineTable(rows: corrections, nameTitle: "Intern", columns: [
                                    OneLineColumn(id: "Request", width: 150),
                                    OneLineColumn(id: "Date", width: 92),
                                    OneLineColumn(id: "Time", width: 76),
                                    OneLineColumn(id: "Reason", width: 220),
                                ], name: \.employeeName) { c, col in
                                    switch col.id {
                                    case "Request": TableText(text: c.kindLabel)
                                    case "Date": TableText(text: AttendanceMonth.shortLabel(c.date))
                                    case "Time": TableText(text: requestedTime(c))
                                    default: TableText(text: c.reason, secondary: true)
                                    }
                                } onTap: { openCorrection = $0 }
                            }
                        }

                        CollapsibleSection(title: "Off In Lieu to approve", icon: "calendar.badge.plus",
                                           count: pendingOil.count, countIsAttention: true) {
                            if pendingOil.isEmpty {
                                allClear("No weekend or public-holiday hours waiting.")
                            } else {
                                OneLineTable(rows: pendingOil, nameTitle: "Employee", columns: [
                                    OneLineColumn(id: "Status", width: 84),
                                    OneLineColumn(id: "Day", width: 104),
                                    OneLineColumn(id: "Hours", width: 56, alignment: .trailing),
                                    OneLineColumn(id: "Credit", width: 70, alignment: .trailing),
                                ], name: \.employeeName) { e, col in
                                    switch col.id {
                                    case "Status": StatusPill(status: e.status)
                                    case "Day": TableText(text: "\(e.dayName), \(AttendanceMonth.shortLabel(e.date))")
                                    case "Hours": TableText(text: "\(Fmt.num(e.hours)) h", bold: true)
                                    default: TableText(text: Fmt.days(credit(e)), secondary: true)
                                    }
                                } onTap: { openOil = $0 }
                            }
                        }

                        CollapsibleSection(title: "Interns · \(AttendanceMonth.label(month))", icon: "person.badge.clock",
                                           count: interns.count) {
                            if interns.isEmpty {
                                EmptyHint(icon: "person.crop.circle.badge.questionmark",
                                          text: "No interns or check-ins for \(AttendanceMonth.label(month)).")
                            } else {
                                OneLineTable(rows: interns, nameTitle: "Intern", columns: [
                                    OneLineColumn(id: "Days", width: 50, alignment: .trailing),
                                    OneLineColumn(id: "Hours", width: 70, alignment: .trailing),
                                    OneLineColumn(id: "Last check-in", width: 104),
                                    OneLineColumn(id: "Now", width: 84),
                                ], name: \.name) { r, col in
                                    switch col.id {
                                    case "Days": TableText(text: "\(r.daysWorked)", bold: true)
                                    case "Hours": TableText(text: String(format: "%.1f h", r.totalHours), bold: true)
                                    case "Last check-in": TableText(text: r.lastPunchDate.map(AttendanceMonth.shortLabel) ?? "—",
                                                                    secondary: true)
                                    default:
                                        if r.clockedInNow { StatusPill(status: "WORKING") } else { TableText(text: "—", secondary: true) }
                                    }
                                } onTap: { openIntern = $0; showIntern = true }
                                Text("Tap an intern for each day's clock-in and clock-out.")
                                    .font(.caption).foregroundStyle(Theme.mist)
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await loadAll() }
            }
        }
        .brandBar()
        .onChange(of: month) { _ in Task { await loadSummary() } }
        .navigationDestination(isPresented: $showIntern) {
            if let r = openIntern { InternAttendanceDetailView(row: r, month: month) }
        }
        .sheet(item: $openCorrection) { c in
            RecordSheet(title: c.employeeName, status: c.status, fields: [
                RecordField(label: "Request", value: c.kindLabel),
                RecordField(label: "Date", value: AttendanceMonth.dayLabel(c.date)),
                RecordField(label: "Requested clock-in", value: c.requestedClockIn.map(AttendanceMonth.time) ?? "—"),
                RecordField(label: "Requested clock-out", value: c.requestedClockOut.map(AttendanceMonth.time) ?? "—"),
                RecordField(label: "Recorded", value: "\(AttendanceMonth.time(c.currentClockIn)) – \(AttendanceMonth.time(c.currentClockOut))"),
                RecordField(label: "Submitted", value: Fmt.date(c.createdAt)),
            ], longText: c.reason,
            onApprove: { await decideCorrection(c, approve: true, comment: nil) },
            onReject: { reason in await decideCorrection(c, approve: false, comment: reason) })
        }
        .sheet(item: $openOil) { e in
            RecordSheet(title: e.employeeName, status: e.status, fields: [
                RecordField(label: "Day", value: "\(e.dayName), \(AttendanceMonth.dayLabel(e.date))"
                            + (e.isPublicHoliday ? " (public holiday)" : "")),
                RecordField(label: "Hours worked", value: "\(Fmt.num(e.hours)) h"),
                RecordField(label: "Off In Lieu credit", value: Fmt.days(credit(e))),
            ], longTextTitle: "Admin comment", longText: e.adminComment,
            onApprove: { await decideOil(e, approve: true, comment: nil) },
            onReject: { reason in await decideOil(e, approve: false, comment: reason) })
        }
    }

    private func allClear(_ text: String) -> some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.success)
                Text(text).font(.subheadline).foregroundStyle(Theme.mist)
            }
        }
    }

    /// 8 h → 1 day, 4 h → 0.5 day (server `otForHours`).
    private func credit(_ e: OffInLieuEntry) -> Double {
        e.otCredited > 0 ? e.otCredited : (e.hours >= 8 ? 1 : e.hours >= 4 ? 0.5 : 0)
    }

    private func requestedTime(_ c: AttendanceCorrection) -> String {
        switch c.kind.uppercased() {
        case "CLOCK_IN": return AttendanceMonth.time(c.requestedClockIn)
        case "CLOCK_OUT": return AttendanceMonth.time(c.requestedClockOut)
        default: return AttendanceMonth.time(c.requestedClockIn)
        }
    }

    // MARK: Actions

    private func decideCorrection(_ c: AttendanceCorrection, approve: Bool, comment: String?) async {
        actionError = nil
        do {
            try await HRMSAPI.shared.decideCorrection(id: c.id, approve: approve, comment: comment)
            await loadQueues(); await loadSummary()
        } catch { actionError = (error as NSError).localizedDescription }
    }

    private func decideOil(_ e: OffInLieuEntry, approve: Bool, comment: String?) async {
        actionError = nil
        do {
            try await HRMSAPI.shared.decideOffInLieu(entryId: e.id, approve: approve, comment: comment)
            await loadQueues()
        } catch { actionError = (error as NSError).localizedDescription }
    }

    // MARK: Loading

    private func loadAll() async {
        async let queues: Void = loadQueues()
        await loadSummary()
        await queues
    }

    private func loadSummary() async {
        if case .loaded = summary {} else { summary = .loading }
        do { summary = .loaded(try await HRMSAPI.shared.attendanceSummary(month: month)) }
        catch { summary = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }

    /// The approval queues are best-effort: a failure here must not hide the intern hours.
    private func loadQueues() async {
        async let c = try? HRMSAPI.shared.pendingCorrections()
        async let o = try? HRMSAPI.shared.offInLieuEntries()
        corrections = await c ?? []
        offInLieu = await o ?? []
    }
}

/// Interns: their own clock-in / clock-out days and hours for a month.
struct MyTimesheetView: View {
    @State private var month = AttendanceMonth.current()

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AttendanceHistorySection(title: "Timesheet", month: $month)
                    NavigationLink { WeeklyTimesheetView() } label: {
                        Card {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus").foregroundStyle(Theme.sky)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Weekend & public-holiday hours").font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text("Log them for Off In Lieu").font(.caption).foregroundStyle(Theme.mist)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}
