import SwiftUI

/// Team calendar in the Planner app's design (Alfred, 11 Nov 2026), adapted to HRMS:
///  * **Month** — Mon-first edge-to-edge grid with thin separators; adjacent-month days greyed;
///    up to two tinted chips per day (You = premium blue, Colleague = amber) and "+N"; today is a
///    filled premium-blue circle on a tinted cell; public holidays are light grey and named.
///    Tap a day to select it; its leave and holiday are listed as cards below the grid.
///  * **List** — upcoming leave and holidays grouped by day.
/// Everyone / Only me sits in the filter menu next to the month chevrons. A colleague's leave
/// *type* is only present when the server chose to disclose it (your own, or an approver).
struct TeamCalendarView: View {
    @State private var state: LoadState<TeamCalendarResponse> = .idle
    @State private var loadedYear: Int?
    @AppStorage("teamCalendar.mode") private var modeRaw = Mode.month.rawValue
    @State private var mineOnly = false
    @State private var month: Date
    @State private var selectedDay: Date

    private enum Mode: String, CaseIterable, Identifiable {
        case month, list
        var id: String { rawValue }
        var title: String { self == .month ? "Month" : "List" }
    }

    private var mode: Mode { Mode(rawValue: modeRaw) ?? .month }

    /// Weeks start on Monday.
    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()
    private var cal: Calendar { Self.cal }

    static let youTint = Theme.premier
    static let colleagueTint = Color(hex: 0xB45309)          // amber text, readable on the light fill
    static let colleagueFill = Color(hex: 0xF5A524)
    static let holidayRed = Color(hex: 0xC2271D)
    static let holidayFill = Color(hex: 0xE9ECF2)            // light grey public-holiday cell
    private let cellHeight: CGFloat = 70

    init() {
        let today = Self.cal.startOfDay(for: Date())
        _month = State(initialValue: Self.cal.date(from: Self.cal.dateComponents([.year, .month], from: today)) ?? today)
        _selectedDay = State(initialValue: today)
    }

    var body: some View {
        GradientScreen {
            VStack(spacing: 0) {
                Picker("View", selection: $modeRaw) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                AsyncContent(state: $state, load: { await load() }) { data in
                    let days = index(data)
                    let holidays = holidayMap(data)
                    switch mode {
                    case .month:
                        ScrollView {
                            VStack(spacing: 0) {
                                monthHeader
                                monthGrid(days, holidays)
                                legend
                                dayAgenda(days[selectedDay] ?? [], holiday: holidays[selectedDay])
                            }
                        }
                        .refreshable { await load(force: true) }
                    case .list:
                        agendaList(data)
                            .refreshable { await load(force: true) }
                    }
                }
            }
        }
        .brandBar()
        .navigationTitle("Calendar")
    }

    // MARK: - Month header: title, Today, filter, ‹ ›

    private var monthHeader: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(mineOnly ? "Only my leave" : "Everyone's leave")
                    .font(.caption2).foregroundStyle(Theme.mist)
            }
            Spacer()
            Button("Today") { goToToday() }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 6)
            Menu {
                Picker("Show", selection: $mineOnly) {
                    Label("Everyone", systemImage: "person.2").tag(false)
                    Label("Only me", systemImage: "person").tag(true)
                }
            } label: {
                Image(systemName: mineOnly ? "line.3.horizontal.decrease.circle.fill"
                                           : "line.3.horizontal.decrease.circle")
                    .frame(width: 34, height: 32)
            }
            .accessibilityLabel("Show leave for everyone or only me")
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 34, height: 32)
            }
            .accessibilityLabel("Previous month")
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 34, height: 32)
            }
            .accessibilityLabel("Next month")
        }
        .font(.body.weight(.semibold))
        .tint(Theme.premier)
        .foregroundStyle(Theme.premier)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { month = next }
        if !cal.isDate(selectedDay, equalTo: month, toGranularity: .month) {
            selectedDay = cal.isDate(Date(), equalTo: month, toGranularity: .month)
                ? cal.startOfDay(for: Date()) : month
        }
        Task { await load() }   // the year may have changed
    }

    private func goToToday() {
        let today = cal.startOfDay(for: Date())
        withAnimation(.easeInOut(duration: 0.2)) {
            month = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
            selectedDay = today
        }
        Task { await load() }
    }

    // MARK: - Month grid

    /// Whole Mon–Sun weeks from the one containing the 1st to the one containing the last day.
    private var weeks: [[Date]] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let lastDay = cal.date(byAdding: .day, value: range.count - 1, to: month) else { return [] }
        let leading = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        guard var day = cal.date(byAdding: .day, value: -leading, to: month) else { return [] }
        var result: [[Date]] = []
        while day <= lastDay {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(day)
                day = cal.date(byAdding: .day, value: 1, to: day) ?? day
            }
            result.append(week)
        }
        return result
    }

    private func monthGrid(_ days: [Date: [TeamLeaveEntry]], _ holidays: [Date: String]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.mist)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
            Divider()
            ForEach(weeks, id: \.first) { week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        dayCell(day, entries: days[day] ?? [], holiday: holidays[day])
                        if day != week.last { Divider() }
                    }
                }
                .frame(height: cellHeight)
                Divider()
            }
        }
        .background(Theme.card)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                shiftMonth(value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private func dayCell(_ day: Date, entries: [TeamLeaveEntry], holiday: String?) -> some View {
        let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = cal.isDateInToday(day)
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let room = holiday == nil ? 2 : 1
        let shown = entries.count > room ? max(0, room - 1) : entries.count
        return VStack(spacing: 2) {
            Text("\(cal.component(.day, from: day))")
                .font(.footnote.weight(isToday || isSelected ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white
                                 : (isSelected ? Theme.premier
                                    : (holiday != nil ? Self.holidayRed : Theme.ink)))
                .frame(width: 22, height: 22)
                .background(Circle().fill(isToday ? Theme.premier : Color.clear))
            if let holiday { holidayLabel(holiday) }
            ForEach(entries.prefix(shown)) { e in chip(e) }
            if shown < entries.count {
                Text("+\(entries.count - shown)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.mist)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 1.5)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(isToday || isSelected ? Theme.premier.opacity(0.12)
                    : (holiday != nil ? Self.holidayFill
                       : (inMonth ? Color.clear : Theme.ink.opacity(0.035))))
        .opacity(inMonth ? 1 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDay = day
            if !inMonth {
                month = cal.date(from: cal.dateComponents([.year, .month], from: day)) ?? day
                Task { await load() }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(day, entries, holiday))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The holiday name in the cell: wraps only between words ("Christmas / Day").
    private func holidayLabel(_ name: String) -> some View {
        let words = name.split(separator: " ").map(String.init)
        return VStack(spacing: 0) {
            if words.count > 1 {
                Text(words[0]).lineLimit(1)
                Text(words.dropFirst().joined(separator: " ")).lineLimit(1).truncationMode(.tail)
            } else {
                Text(name).lineLimit(1)
            }
        }
        .font(.system(size: 8.5, weight: .semibold))
        .minimumScaleFactor(0.75)
        .foregroundStyle(Self.holidayRed)
        .frame(maxWidth: .infinity)
    }

    private func chip(_ e: TeamLeaveEntry) -> some View {
        let tint = e.isSelf ? Self.youTint : Self.colleagueTint
        let fill = e.isSelf ? Self.youTint : Self.colleagueFill
        return Text(e.isSelf ? "You" : firstName(e.employeeName))
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(tint)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 3).fill(fill.opacity(0.18)))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(Self.youTint, "You")
            legendDot(Self.colleagueFill, "Colleague")
            legendDot(Self.holidayFill, "Public holiday", border: true)
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(Theme.mist)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func legendDot(_ c: Color, _ label: String, border: Bool = false) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 10, height: 10)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.ink.opacity(border ? 0.2 : 0), lineWidth: 1))
            Text(label)
        }
    }

    // MARK: - Selected-day agenda

    private func dayAgenda(_ entries: [TeamLeaveEntry], holiday: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle(selectedDay))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.mist)
                .padding(.horizontal, 16)
            if let holiday { holidayCard(holiday) }
            if entries.isEmpty && holiday == nil {
                Card {
                    Label(mineOnly ? "You are not on leave." : "Nobody is on leave.", systemImage: "calendar")
                        .font(.subheadline).foregroundStyle(Theme.mist)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
            }
            ForEach(entries) { e in entryCard(e).padding(.horizontal, 16) }
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private func holidayCard(_ name: String) -> some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: "flag.fill").foregroundStyle(Self.holidayRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("Public holiday").font(.caption2).foregroundStyle(Theme.mist)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }

    private func entryCard(_ e: TeamLeaveEntry) -> some View {
        Card {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(e.isSelf ? Self.youTint : Self.colleagueFill)
                    .frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.isSelf ? "You" : e.employeeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(e.isSelf ? Self.youTint : Theme.ink)
                    Text(detail(e)).font(.caption).foregroundStyle(Theme.mist)
                }
                Spacer()
            }
        }
    }

    // MARK: - List mode

    /// Upcoming leave and holidays grouped by day. A multi-day leave is listed once, on its
    /// first day from today (its card shows the full date range).
    private func agendaList(_ data: TeamCalendarResponse) -> some View {
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: [TeamLeaveEntry]] = [:]
        for e in (mineOnly ? data.entries.filter(\.isSelf) : data.entries) {
            guard let start = Self.calendarDay(e.startDate) else { continue }
            let end = Self.calendarDay(e.endDate) ?? start
            guard end >= today else { continue }
            byDay[max(start, today), default: []].append(e)
        }
        var holidays: [Date: String] = [:]
        for h in data.holidays {
            guard let d = Self.calendarDay(h.startDate), (Self.calendarDay(h.endDate) ?? d) >= today else { continue }
            holidays[max(d, today)] = h.title
        }
        let upcoming = Set(byDay.keys).union(holidays.keys).sorted()
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if upcoming.isEmpty {
                    EmptyHint(icon: "calendar", text: mineOnly ? "No upcoming leave." : "No upcoming leave or holidays.")
                }
                ForEach(upcoming, id: \.self) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dayTitle(day))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.mist)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        if let h = holidays[day] { holidayCard(h) }
                        ForEach(byDay[day] ?? []) { e in entryCard(e).padding(.horizontal, 16) }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Data shaping

    /// Each multi-day leave exploded into the days it covers, keyed by local start of day.
    private func index(_ data: TeamCalendarResponse) -> [Date: [TeamLeaveEntry]] {
        var map: [Date: [TeamLeaveEntry]] = [:]
        let source = mineOnly ? data.entries.filter(\.isSelf) : data.entries
        for e in source {
            guard let start = Self.calendarDay(e.startDate) else { continue }
            let last = Self.calendarDay(e.endDate) ?? start
            var day = start, n = 0
            while day <= last, n < 400 {
                map[day, default: []].append(e)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next; n += 1
            }
        }
        return map
    }

    /// Holiday names by local start of day; a multi-day holiday covers every day.
    private func holidayMap(_ data: TeamCalendarResponse) -> [Date: String] {
        var out: [Date: String] = [:]
        for h in data.holidays {
            guard let start = Self.calendarDay(h.startDate) else { continue }
            let end = Self.calendarDay(h.endDate) ?? start
            var day = start, n = 0
            while day <= end, n < 10 {
                out[day] = h.title
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next; n += 1
            }
        }
        return out
    }

    /// "2026-11-08T00:00:00Z" or "2026-11-08" → that calendar day at local midnight, read from
    /// the yyyy-MM-dd part so a date never shifts with the device's time zone.
    static func calendarDay(_ iso: String?) -> Date? {
        guard let iso, iso.count >= 10 else { return nil }
        let p = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    private func dayTitle(_ day: Date) -> String {
        let text = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if cal.isDateInToday(day) { return "Today · \(text)" }
        if cal.isDateInTomorrow(day) { return "Tomorrow · \(text)" }
        return text
    }

    private func firstName(_ full: String) -> String {
        full.split(separator: " ").first.map(String.init) ?? full
    }

    private func detail(_ e: TeamLeaveEntry) -> String {
        var bits = [e.leaveType ?? "On leave"]
        bits.append(e.halfDay ? "Half day" : Fmt.days(e.days))
        if let s = Self.calendarDay(e.startDate), let t = Self.calendarDay(e.endDate), s != t {
            bits.append("\(s.formatted(.dateTime.day().month(.abbreviated))) – \(t.formatted(.dateTime.day().month(.abbreviated)))")
        }
        if let d = e.department, !e.isSelf { bits.append(d) }
        return bits.joined(separator: " · ")
    }

    private func accessibilityText(_ day: Date, _ entries: [TeamLeaveEntry], _ holiday: String?) -> String {
        var s = day.formatted(date: .complete, time: .omitted)
        if let holiday { s += ", \(holiday)" }
        if !entries.isEmpty {
            s += ", \(entries.count) on leave: " + entries.map { $0.isSelf ? "you" : $0.employeeName }.joined(separator: ", ")
        }
        return s
    }

    // MARK: - Load

    /// Loads the displayed month's year (skipped when already loaded, unless forced).
    private func load(force: Bool = false) async {
        let year = cal.component(.year, from: month)
        if !force, loadedYear == year, case .loaded = state { return }
        if case .loaded = state {} else { state = .loading }
        do {
            let data = try await HRMSAPI.shared.teamCalendar(year: year)
            state = .loaded(data)
            loadedYear = year
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the calendar.")
        }
    }
}
