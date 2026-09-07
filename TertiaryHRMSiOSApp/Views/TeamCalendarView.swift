import SwiftUI

/// Team calendar — a month grid of everyone's approved leave, mirroring the web
/// app's calendar (month title, ‹ Today ›, a Sun–Sat grid with a chip per
/// person per day). A segmented control narrows it to just your own leave.
///
/// A colleague's leave *type* is only present when the server chose to disclose
/// it (your own leave, or an approver viewing). When it is nil the chip reads
/// just the name — the masking is the server's decision, not this view's.
struct TeamCalendarView: View {
    @State private var state: LoadState<TeamCalendarResponse> = .idle
    @State private var mineOnly = false
    @State private var month: Date = Date().startOfMonth
    @State private var selected: DayBucket?

    private let cal = Calendar(identifier: .gregorian)

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        scopePicker
                        weekdayRow
                        grid(for: data)
                        legend
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .navigationTitle("Calendar")
        .sheet(item: $selected) { bucket in
            DayDetailSheet(bucket: bucket)
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
        }
    }

    // MARK: Header — month title + ‹ Today ›

    private var header: some View {
        HStack {
            Text(monthTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 8) {
                navButton("chevron.left") { shift(-1) }
                Button("Today") { month = Date().startOfMonth }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white.opacity(0.10))
                    .clipShape(Capsule())
                navButton("chevron.right") { shift(1) }
            }
        }
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.10))
                .clipShape(Circle())
        }
        .accessibilityLabel(icon == "chevron.left" ? "Previous month" : "Next month")
    }

    private func shift(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: month) {
            month = d.startOfMonth
            Task { await load() }        // year may have changed
        }
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"
        return f.string(from: month)
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $mineOnly) {
            Text("Everyone").tag(false)
            Text("Only me").tag(true)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Show leave for everyone or only me")
    }

    // MARK: Grid

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { d in
                Text(d)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(for data: TeamCalendarResponse) -> some View {
        let days = monthDays()
        let byDay = index(data)
        let holidays = holidayMap(data)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in
                if let day {
                    dayCell(day, entries: byDay[key(day)] ?? [], holiday: holidays[key(day)])
                } else {
                    Color.clear.frame(height: 84)   // leading/trailing blanks
                }
            }
        }
    }

    private func dayCell(_ day: Date, entries: [TeamLeaveEntry], holiday: String?) -> some View {
        let isToday = cal.isDateInToday(day)
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(cal.component(.day, from: day))")
                    .font(.caption.weight(isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? .white : .white.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(isToday ? Theme.sky : .clear)
                    .clipShape(Circle())
                Spacer(minLength: 0)
            }
            if holiday != nil {
                chip(text: "Holiday", tint: Color(red: 0.88, green: 0.25, blue: 0.35))
            }
            ForEach(entries.prefix(holiday == nil ? 2 : 1)) { e in
                chip(text: e.isSelf ? "You" : firstName(e.employeeName),
                     tint: e.isSelf ? Theme.sky : Color(red: 0.95, green: 0.65, blue: 0.20))
            }
            let shown = (holiday == nil ? 2 : 1)
            if entries.count > shown {
                Text("+\(entries.count - shown) more")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(height: 84, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background(isToday ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !entries.isEmpty || holiday != nil else { return }
            selected = DayBucket(date: day, entries: entries, holiday: holiday)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(day, entries, holiday))
    }

    private func chip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.85))
            .foregroundStyle(.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(Theme.sky, "You")
            legendDot(Color(red: 0.95, green: 0.65, blue: 0.20), "Colleague")
            legendDot(Color(red: 0.88, green: 0.25, blue: 0.35), "Holiday")
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.7))
    }

    private func legendDot(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 10, height: 10)
            Text(label)
        }
    }

    // MARK: Data shaping

    /// Every day of the displayed month, padded with nils so the 1st lands on
    /// its real weekday column.
    private func monthDays() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let leading = cal.component(.weekday, from: month) - 1   // 1 = Sunday
        var out: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: month) { out.append(date) }
        }
        while out.count % 7 != 0 { out.append(nil) }
        return out
    }

    /// Explode each multi-day leave into the days it covers, so a request that
    /// spans a week shows on every one of those days.
    private func index(_ data: TeamCalendarResponse) -> [String: [TeamLeaveEntry]] {
        var map: [String: [TeamLeaveEntry]] = [:]
        let source = mineOnly ? data.entries.filter(\.isSelf) : data.entries
        for e in source {
            guard let start = Fmt.dateObj(e.startDate) else { continue }
            let end = Fmt.dateObj(e.endDate) ?? start
            var day = cal.startOfDay(for: start)
            let last = cal.startOfDay(for: end)
            var guardCount = 0
            while day <= last, guardCount < 400 {
                map[key(day), default: []].append(e)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next; guardCount += 1
            }
        }
        return map
    }

    /// Holiday titles by day key — derived per render, never stored in @State
    /// (mutating state while building the body is undefined behaviour).
    private func holidayMap(_ data: TeamCalendarResponse) -> [String: String] {
        var out: [String: String] = [:]
        for h in data.holidays {
            guard let d = Fmt.dateObj(h.startDate) else { continue }
            out[key(cal.startOfDay(for: d))] = h.title
        }
        return out
    }

    private func key(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func firstName(_ full: String) -> String {
        full.split(separator: " ").first.map(String.init) ?? full
    }

    private func accessibilityText(_ day: Date, _ entries: [TeamLeaveEntry], _ holiday: String?) -> String {
        let f = DateFormatter(); f.dateStyle = .full
        var s = f.string(from: day)
        if let holiday { s += ", \(holiday)" }
        if !entries.isEmpty {
            s += ", \(entries.count) on leave: " + entries.map(\.employeeName).joined(separator: ", ")
        }
        return s
    }

    // MARK: Load

    private func load() async {
        state = .loading
        do {
            let year = cal.component(.year, from: month)
            let data = try await HRMSAPI.shared.teamCalendar(year: year)
            state = .loaded(data)
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the calendar.")
        }
    }
}

/// One tapped day, for the detail sheet.
struct DayBucket: Identifiable {
    let date: Date
    let entries: [TeamLeaveEntry]
    let holiday: String?
    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Tapping a day lists everyone out that day, with whatever detail the server
/// disclosed for each person.
private struct DayDetailSheet: View {
    let bucket: DayBucket

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if let h = bucket.holiday {
                        Card {
                            HStack(spacing: 10) {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(Color(red: 0.88, green: 0.25, blue: 0.35))
                                Text(h).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Spacer()
                            }
                        }
                    }

                    if bucket.entries.isEmpty && bucket.holiday == nil {
                        EmptyHint(icon: "calendar", text: "Nobody is on leave.")
                    }

                    ForEach(bucket.entries) { e in
                        Card {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(e.isSelf ? "You" : e.employeeName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(e.isSelf ? Theme.sky : .white)
                                    Text(detail(e))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var title: String {
        let f = DateFormatter(); f.dateStyle = .full
        return f.string(from: bucket.date)
    }

    private func detail(_ e: TeamLeaveEntry) -> String {
        var bits = [e.leaveType ?? "On leave"]
        bits.append(e.halfDay ? "Half day" : Fmt.days(e.days))
        if let d = e.department, !e.isSelf { bits.append(d) }
        return bits.joined(separator: " · ")
    }
}

private extension Date {
    /// First moment of this date's month, in the current calendar.
    var startOfMonth: Date {
        let cal = Calendar(identifier: .gregorian)
        return cal.date(from: cal.dateComponents([.year, .month], from: self)) ?? self
    }
}
