import SwiftUI

/// `yyyy-MM` month keys for the attendance screens — always Singapore time so a
/// month boundary matches the server's punch dates.
enum AttendanceMonth {
    private static let sgt = TimeZone(identifier: "Asia/Singapore")!

    static func current() -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = sgt
        let c = cal.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", c.year!, c.month!)
    }

    static func shift(_ month: String, by n: Int) -> String {
        let parts = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return month }
        let total = parts[0] * 12 + (parts[1] - 1) + n
        return String(format: "%04d-%02d", total / 12, total % 12 + 1)
    }

    /// "October 2026"
    static func label(_ month: String) -> String {
        guard let d = Fmt.ymdDate("\(month)-01") else { return month }
        let f = DateFormatter(); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "LLLL yyyy"
        return f.string(from: d)
    }

    /// "Wed, 8 Oct 2026" for a plain `yyyy-MM-dd`.
    static func dayLabel(_ ymd: String) -> String {
        guard let d = Fmt.ymdDate(ymd) else { return ymd }
        let f = DateFormatter(); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "EEE, d MMM yyyy"
        return f.string(from: d)
    }

    /// Clock time in Singapore time, e.g. "9:21 AM".
    static func time(_ iso: String?) -> String {
        guard let d = Fmt.dateObj(iso) else { return "—" }
        let f = DateFormatter(); f.timeZone = sgt; f.dateFormat = "h:mm a"
        return f.string(from: d)
    }
}

/// Previous / next month switcher shared by the attendance screens.
struct MonthSwitcher: View {
    @Binding var month: String

    var body: some View {
        HStack(spacing: 4) {
            Button { month = AttendanceMonth.shift(month, by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 32, height: 32)
            }
            .accessibilityLabel("Previous month")
            Text(AttendanceMonth.label(month))
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .frame(minWidth: 120)
            Button { month = AttendanceMonth.shift(month, by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 32, height: 32)
            }
            .disabled(month >= AttendanceMonth.current())
            .opacity(month >= AttendanceMonth.current() ? 0.3 : 1)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(4)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Daily check-in / check-out history for one month with the month's total
/// hours — the same content as the web app's "Daily history". Without an
/// `employeeId` it shows the signed-in user's own punches.
struct AttendanceHistorySection: View {
    var employeeId: String? = nil
    var title = "Daily history"
    @Binding var month: String
    /// Bump to force a reload (e.g. after a punch).
    var reloadToken = 0

    @State private var data: AttendanceHistory?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline).foregroundStyle(.white.opacity(0.9))
                Spacer()
                MonthSwitcher(month: $month)
            }
            HStack(spacing: 12) {
                StatTile(value: loading || data == nil ? "—" : String(format: "%.1f h", data!.totalHours),
                         label: "Total hours", icon: "sum", tint: .mint)
                StatTile(value: loading || data == nil ? "—" : "\(data!.daysWorked)",
                         label: "Days worked", icon: "calendar.badge.checkmark", tint: Theme.sky)
            }
            if loading {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if let error {
                StatusBanner(kind: .error, text: error)
            } else if let data, !data.days.isEmpty {
                ForEach(data.days) { row($0) }
                Card {
                    HStack {
                        Text("Total").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "%.2f h", data.totalHours))
                            .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(.mint)
                    }
                }
            } else {
                EmptyHint(icon: "clock.badge.questionmark",
                          text: "No check-ins in \(AttendanceMonth.label(month)).")
            }
        }
        .task(id: "\(month)|\(employeeId ?? "")|\(reloadToken)") { await load() }
    }

    private func row(_ d: AttendanceDay) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AttendanceMonth.dayLabel(d.date))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("In \(AttendanceMonth.time(d.clockIn))  ·  Out \(d.clockOut == nil ? (d.clockIn == nil ? "—" : "…") : AttendanceMonth.time(d.clockOut))")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if let h = d.hours {
                    Text(String(format: "%.2f h", h))
                        .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(.mint)
                } else if d.clockIn != nil {
                    StatusPill(status: "WORKING")
                }
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            data = try await HRMSAPI.shared.attendanceHistory(month: month, employeeId: employeeId)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not load attendance history."
        }
        loading = false
    }
}

/// Admin: each intern's days worked and total hours for a month, drilling
/// into that intern's daily check-in / check-out history. Mirrors the web
/// app's Intern Attendance page (`/attendance/overview`).
struct InternAttendanceView: View {
    @State private var month = AttendanceMonth.current()
    @State private var state: LoadState<AttendanceSummary> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Intern Attendance").font(.headline).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            MonthSwitcher(month: $month)
                        }
                        HStack(spacing: 12) {
                            StatTile(value: "\(data.employees.count)", label: "People tracked",
                                     icon: "person.2.fill", tint: Theme.sky)
                            StatTile(value: String(format: "%.1f h", data.totalHours), label: "Total hours",
                                     icon: "sum", tint: .mint)
                        }
                        if data.employees.isEmpty {
                            EmptyHint(icon: "person.crop.circle.badge.questionmark",
                                      text: "No interns or check-ins for \(AttendanceMonth.label(month)).")
                        }
                        ForEach(data.employees) { r in
                            NavigationLink {
                                InternAttendanceDetailView(row: r, month: month)
                            } label: { row(r) }
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

    private func row(_ r: AttendanceSummaryRow) -> some View {
        Card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("\(r.employeeCode)\(r.isIntern ? "" : " · non-intern") · \(r.daysWorked) day\(r.daysWorked == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text("Last check-in: \(r.lastPunchDate.map(AttendanceMonth.dayLabel) ?? "—")")
                        .font(.caption2).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(String(format: "%.2f h", r.totalHours))
                        .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(.mint)
                    if r.clockedInNow { StatusPill(status: "WORKING") }
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.attendanceSummary(month: month)) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}

/// One intern's daily history (admin drill-down).
struct InternAttendanceDetailView: View {
    let row: AttendanceSummaryRow
    @State var month: String

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(row.name) · \(row.employeeCode)")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    AttendanceHistorySection(employeeId: row.id, title: "Daily history", month: $month)
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}
