import SwiftUI

/// Weekly timesheet — log hours worked on weekends and public holidays for
/// Off-In-Lieu credit, mirroring the web app's /timesheet page. Regular
/// workdays are static rows; only non-workdays get the Off / Half / Full
/// hours selector. OT is credited after admin approval (8h → 1 day, 4h → 0.5).
struct WeeklyTimesheetView: View {
    @State private var state: LoadState<TimesheetResponse> = .idle
    @State private var weekStart = WeeklyTimesheetView.currentMonday()
    /// Local unsaved hour edits keyed by the day's date string.
    @State private var draft: [String: Double] = [:]
    @State private var confirmSubmit = false
    @State private var submitting = false
    @State private var error: String?
    @State private var done = false

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        weekNav
                        if let error { StatusBanner(kind: .error, text: error) }
                        if data.isLocked {
                            StatusBanner(kind: .info, text: "This week is locked and can no longer be edited.")
                        }
                        weekSummary(data)
                        ForEach(data.days) { day in dayRow(day, locked: data.isLocked) }
                        PremierButton(title: "Submit for Approval", systemImage: "paperplane.fill",
                                      loading: submitting, enabled: canSubmit(data)) {
                            confirmSubmit = true
                        }
                        Text("Log hours worked on weekends and public holidays. Submit by 11:30 PM SGT. Off In Lieu days are credited after admin approval.")
                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .alert("Submit timesheet?", isPresented: $confirmSubmit) {
            Button("Submit") { submit() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Submit this week's weekend and public-holiday hours for admin approval?")
        }
        .alert("Timesheet submitted", isPresented: $done) {
            Button("OK") {}
        } message: {
            Text("Your hours were submitted. Off-In-Lieu days are credited after admin approval.")
        }
    }

    // MARK: - Week navigation

    private var onCurrentWeek: Bool { weekStart == WeeklyTimesheetView.currentMonday() }

    private var weekNav: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { changeWeek(by: -7) } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline).foregroundStyle(Theme.sky)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("Week of").font(.caption2).foregroundStyle(.white.opacity(0.6))
                    Text(Fmt.date(weekStart)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
                Spacer()
                Button { changeWeek(by: 7) } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline).foregroundStyle(Theme.sky)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            if !onCurrentWeek {
                Button {
                    weekStart = WeeklyTimesheetView.currentMonday()
                    reload()
                } label: {
                    Label("Jump to current week", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.sky)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Rows

    private func weekSummary(_ data: TimesheetResponse) -> some View {
        let total = data.days.filter(\.isNonWorkDay).reduce(0.0) { $0 + otDays(hours(for: $1)) }
        return StatTile(value: otDaysText(total), label: "Off-In-Lieu this week",
                        icon: "calendar.badge.plus", tint: Theme.sky)
    }

    private func dayRow(_ day: TimesheetDay, locked: Bool) -> some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(day.dayName) · \(Fmt.date(day.date))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    if let ph = day.phName, !ph.isEmpty {
                        Text(ph).font(.caption2).foregroundStyle(.yellow)
                    }
                }
                Spacer()
                if let status = day.status, !status.isEmpty {
                    StatusPill(status: status)
                }
            }
            if day.isNonWorkDay {
                Picker("", selection: hoursBinding(for: day)) {
                    Text("Off (0h)").tag(0.0)
                    Text("Half (4h)").tag(4.0)
                    Text("Full (8h)").tag(8.0)
                }
                .pickerStyle(.segmented)
                .disabled(locked || !day.isSubmittable)
                .padding(.top, 8)
                let h = hours(for: day)
                if h > 0 {
                    Text("→ \(otDaysText(otDays(h))) Off-In-Lieu")
                        .font(.caption).foregroundStyle(Theme.sky)
                        .padding(.top, 4)
                }
            } else {
                Text("Workday")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)
            }
            if let comment = day.adminComment, !comment.isEmpty {
                Text(comment)
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 6)
            }
        }
    }

    private func hoursBinding(for day: TimesheetDay) -> Binding<Double> {
        Binding(get: { hours(for: day) }, set: { draft[day.date] = $0 })
    }

    private func hours(for day: TimesheetDay) -> Double { draft[day.date] ?? day.hours }

    /// 8h → 1 day, 4h → 0.5 day (linear).
    private func otDays(_ hours: Double) -> Double { hours / 8 }

    private func otDaysText(_ d: Double) -> String {
        let s = d.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", d) : String(format: "%.1f", d)
        return "\(s) day\(d == 1 ? "" : "s")"
    }

    private func canSubmit(_ data: TimesheetResponse) -> Bool {
        !data.isLocked && data.days.contains { $0.isNonWorkDay && $0.isSubmittable }
    }

    // MARK: - Actions

    private func submit() {
        guard case .loaded(let data) = state else { return }
        error = nil; submitting = true
        let entries = data.days
            .filter { $0.isNonWorkDay && $0.isSubmittable }
            .map { TimesheetEntry(date: String($0.date.prefix(10)), hours: hours(for: $0)) }
        let week = weekStart
        Task {
            do {
                try await HRMSAPI.shared.submitTimesheet(weekStart: week, entries: entries)
                submitting = false; done = true
                await load()
            } catch {
                submitting = false
                self.error = (error as NSError).localizedDescription
            }
        }
    }

    private func changeWeek(by days: Int) {
        weekStart = WeeklyTimesheetView.shift(weekStart, by: days)
        reload()
    }

    private func reload() {
        error = nil
        state = .loading
        Task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let data = try await HRMSAPI.shared.timesheet(weekStart: weekStart)
            draft = [:]
            state = .loaded(data)
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.")
        }
    }

    // MARK: - Week maths (Asia/Singapore, matching the server's week boundaries)

    private static let sgCalendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return cal
    }()

    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Singapore")!
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// The Monday of the current week in Singapore time, as `yyyy-MM-dd`.
    static func currentMonday() -> String {
        let today = sgCalendar.startOfDay(for: Date())
        let weekday = sgCalendar.component(.weekday, from: today) // 1 = Sunday
        let sinceMonday = (weekday + 5) % 7
        let monday = sgCalendar.date(byAdding: .day, value: -sinceMonday, to: today) ?? today
        return ymd.string(from: monday)
    }

    static func shift(_ day: String, by days: Int) -> String {
        guard let d = ymd.date(from: day),
              let shifted = sgCalendar.date(byAdding: .day, value: days, to: d) else { return day }
        return ymd.string(from: shifted)
    }
}
