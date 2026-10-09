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

                        HStack(spacing: 10) {
                            StatTile(value: "\(data.attendance.daysWorked)", label: "Days clocked",
                                     icon: "clock.fill", tint: .mint)
                            StatTile(value: approvedDays(data.medical), label: "MC days",
                                     icon: "cross.case.fill", tint: .pink)
                            StatTile(value: approvedDays(data.otherLeave), label: "Leave days",
                                     icon: "airplane", tint: Theme.sky)
                        }

                        clockSection(data)
                        leaveSection(title: "MC history", icon: "cross.case",
                                     empty: "No medical leave on record.", rows: data.medical, name: data.employee.name)
                        leaveSection(title: "Leave history", icon: "calendar",
                                     empty: "No leave on record.", rows: data.otherLeave, name: data.employee.name)
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
                Text(e.name).font(.title3.weight(.bold)).foregroundStyle(.white)
                Text([e.position, e.department].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                Text([e.employeeCode, e.employmentType?.replacingOccurrences(of: "_", with: " ").capitalized]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.sky)
            }
        }
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
                                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        } else {
                            ForEach(data.attendance.days.prefix(previewCount)) { PunchLine(day: $0) }
                        }
                        Divider().overlay(.white.opacity(0.15))
                        HStack {
                            Text(String(format: "%.1f h total", data.attendance.totalHours))
                                .font(.caption.weight(.semibold)).foregroundStyle(.mint)
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
                        LeaveHistoryListView(title: title, name: name, rows: rows)
                    } label: {
                        Text("See all \(rows.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.sky)
                    }
                }
            }
            if rows.isEmpty {
                Card { Text(empty).font(.subheadline).foregroundStyle(.white.opacity(0.7)) }
            } else {
                ForEach(rows.prefix(previewCount)) { LeaveRequestRow(request: $0) }
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline).foregroundStyle(.white.opacity(0.9))
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
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 12) {
                        StatTile(value: String(format: "%.1f h", attendance.totalHours),
                                 label: "Total hours", icon: "sum", tint: .mint)
                        StatTile(value: "\(attendance.daysWorked)",
                                 label: "Days worked", icon: "calendar.badge.checkmark", tint: Theme.sky)
                    }
                    if attendance.days.isEmpty {
                        EmptyHint(icon: "clock.badge.questionmark", text: "No clock-ins on record.")
                    }
                    ForEach(months, id: \.month) { group in
                        HStack {
                            Text(AttendanceMonth.label(group.month))
                                .font(.headline).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text(String(format: "%.2f h · %d day%@",
                                        group.days.reduce(0) { $0 + ($1.hours ?? 0) },
                                        group.days.count, group.days.count == 1 ? "" : "s"))
                                .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(.mint)
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

    var body: some View {
        GradientScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("\(name) · \(title)").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    ForEach(rows) { LeaveRequestRow(request: $0) }
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}

/// One day's check-in / check-out line.
struct PunchLine: View {
    let day: AttendanceDay

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(AttendanceMonth.dayLabel(day.date))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("In \(AttendanceMonth.time(day.clockIn))  ·  Out \(day.clockOut == nil ? (day.clockIn == nil ? "—" : "…") : AttendanceMonth.time(day.clockOut))")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            if let h = day.hours {
                Text(String(format: "%.2f h", h))
                    .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(.mint)
            } else if day.clockIn != nil {
                StatusPill(status: "WORKING")
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
                    Text(request.leaveType).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("\(Fmt.date(request.startDate)) → \(Fmt.date(request.endDate))")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    if let reason = request.reason, !reason.isEmpty {
                        Text(reason).font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusPill(status: request.status)
                    Text(Fmt.days(request.days)).font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
