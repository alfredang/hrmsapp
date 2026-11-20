import SwiftUI

/// Team calendar in the Planner app's design (Alfred, 11 Nov 2026), adapted to HRMS:
///  * **Month** — Mon-first edge-to-edge grid with thin separators; adjacent-month days greyed;
///    up to two tinted chips per day and "+N"; today is a filled premium-blue circle on a tinted
///    cell; public holidays are light grey and named. Tap a day to select it; its leave, time off,
///    birthdays and holiday are listed as cards below the grid.
///  * **List** — upcoming leave, time off, birthdays and holidays grouped by day.
/// Colours (build 34, the web of 20 Nov 2026): each leave by its category with its emoji
/// (🏖️ annual, 🤒 medical, 💸 no pay, 📋 other), approved time off and Off Days ⏰, birthdays 🎂
/// (approvers). A colleague's leave whose type is hidden keeps the neutral amber, no emoji.
/// Off days are shaded when one schedule applies (`OffDayShading`); approvers who pick a person
/// see that person's month totals (`CalendarMonthSummary`).
/// Everyone / Only me sits in the filter menu next to the month chevrons. Approvers also get
/// "Leave & time off for": Everyone or one active person (`TeamCalendarPeople`); holidays always show.
/// A colleague's leave *type* is only present when the server chose to disclose it (your own,
/// or an approver).
struct TeamCalendarView: View {
    @State private var state: LoadState<TeamCalendarResponse> = .idle
    @State private var loadedYear: Int?
    @AppStorage("teamCalendar.mode") private var modeRaw = Mode.month.rawValue
    @State private var mineOnly = false
    /// Approvers: the one person whose leave is shown (the web calendar's "Leave shown for"); nil = everyone.
    @State private var personId: String?
    @State private var month: Date
    @State private var selectedDay: Date
    @ObservedObject private var autoSync = CalendarAutoSync.shared

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

    static let colleagueTint = Theme.warning          // amber text, readable on the light fill
    static let colleagueFill = Color(hex: 0xF5A524)
    static let holidayRed = Theme.danger
    static let holidayFill = Color(light: 0xE9ECF2, dark: 0x1F2937)            // light grey public-holiday cell
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
                    let people = TeamCalendarPeople(data)
                    let person = people.option(personId)
                    if people.isAvailable { personFilter(people, person) }
                    let legendTable = CalendarLegendTable(data.categories)
                    let items = TeamCalendarItem.build(
                        TeamCalendarVisible(data, people: people, personId: person?.id, mineOnly: mineOnly),
                        legend: legendTable, isApprover: people.isAvailable, calendar: cal)
                    let days = index(items)
                    let holidays = holidayMap(data)
                    let shading = OffDayShading.make(data, isApprover: people.isAvailable,
                                                     personId: person?.id, mineOnly: mineOnly)
                    switch mode {
                    case .month:
                        ScrollView {
                            VStack(spacing: 0) {
                                monthHeader(person)
                                if let person, people.isAvailable { monthTotals(data, person, legendTable) }
                                monthGrid(days, holidays, shading, legendTable)
                                legend(items, legendTable, shading: shading != nil)
                                dayAgenda(days[selectedDay] ?? [], holiday: holidays[selectedDay], person: person,
                                          offDay: shading?.isOff(selectedDay, calendar: cal) ?? false, legendTable)
                            }
                        }
                        .refreshable { await refresh() }
                    case .list:
                        agendaList(data, items, legendTable)
                            .refreshable { await refresh() }
                    }
                }
            }
        }
        .brandBar()
        .navigationTitle("Calendar")
        .onReceive(NotificationCenter.default.publisher(for: .hrmsForeground)) { _ in Task { await load(force: true) } }
    }

    // MARK: - Leave shown for (approvers)

    /// "Leave & time off for [Everyone ⌄]": every active staff member and intern, grouped, with
    /// their number of leave and time-off entries. Picking a person turns "Only me" off.
    private func personFilter(_ people: TeamCalendarPeople, _ person: TeamCalendarPeople.Option?) -> some View {
        HStack(spacing: 8) {
            Text("Leave & time off for").font(.footnote).foregroundStyle(Theme.mist)
                .lineLimit(1).layoutPriority(1)
            Menu {
                // Buttons, not a Picker: a Picker inside a Menu drops the Staff / Interns headers.
                Button { personId = nil } label: {
                    if person == nil { Label("Everyone", systemImage: "checkmark") } else { Text("Everyone") }
                }
                ForEach(people.groups) { g in
                    Section(g.title) {
                        ForEach(g.options) { o in
                            Button { personId = o.id; mineOnly = false } label: {
                                if person?.id == o.id { Label(o.label, systemImage: "checkmark") } else { Text(o.label) }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: person == nil ? "person.2" : "person.crop.circle")
                    Text(person?.name ?? "Everyone").lineLimit(1).truncationMode(.tail)
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(height: 36)
                .background(Theme.field)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.fieldBorder, lineWidth: 1))
            }
            .accessibilityLabel("Leave and time off for")
            .accessibilityValue(person?.name ?? "Everyone")
            .accessibilityIdentifier("calendar.person")
            if person != nil {
                Button { personId = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.body)
                        .foregroundStyle(Theme.mist).frame(width: 36, height: 36)
                }
                .accessibilityLabel("Show everyone")
                .accessibilityIdentifier("calendar.person.clear")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Approvers with a person picked: that person's leave and time off in the month shown, the
    /// web calendar's chips ("Annual Leave 2 days", "Time Off 3.5 h + 1 off day").
    private func monthTotals(_ data: TeamCalendarResponse, _ person: TeamCalendarPeople.Option,
                             _ legend: CalendarLegendTable) -> some View {
        let c = cal.dateComponents([.year, .month], from: month)
        let summary = CalendarMonthSummary.personMonthSummary(
            CalendarMonthSummary.events(data, calendar: cal), personId: person.id,
            year: c.year ?? 0, month: c.month ?? 0,
            holidayKeys: CalendarMonthSummary.holidayKeys(data, calendar: cal), calendar: cal)
        let tiles = CalendarMonthSummary.tiles(summary)
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(month.formatted(.dateTime.month(.wide).year())) · \(person.name)")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.mist).lineLimit(1)
            FlowLayout(spacing: 6) {
                ForEach(tiles) { t in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(legend.color(t.category)).frame(width: 9, height: 9)
                        Text(t.label).foregroundStyle(Theme.mist)
                        Text(t.value).fontWeight(.semibold).foregroundStyle(Theme.ink)
                    }
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Theme.field)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.fieldBorder, lineWidth: 1))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(t.label) \(t.value)")
                    .accessibilityIdentifier("calendar.total.\(t.category)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar.monthTotals")
    }

    /// "Synced 1:15 PM · Everyone" — the last successful load, like the Planner app.
    private func syncCaption(_ person: TeamCalendarPeople.Option?) -> String {
        let who = mineOnly ? "Only me" : person?.name ?? "Everyone"
        guard let t = autoSync.lastSynced else { return who }
        return "Synced \(t.formatted(date: .omitted, time: .shortened)) · \(who)"
    }

    /// Reload HRMS data and push it to the iPhone Calendar (when sync is on).
    private func refresh() async {
        await load(force: true)
        await autoSync.runNow()
    }

    // MARK: - Month header: title, Today, filter, ‹ ›

    private func monthHeader(_ person: TeamCalendarPeople.Option?) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(syncCaption(person))
                    .font(.caption2).foregroundStyle(Theme.mist)
                    .lineLimit(1)
            }
            Spacer()
            Button { Task { await refresh() } } label: {
                if autoSync.isSyncing { ProgressView().frame(width: 30, height: 32) }
                else { Image(systemName: "arrow.clockwise").frame(width: 30, height: 32) }
            }
            .accessibilityLabel("Refresh")
            Button("Today") { goToToday() }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 6)
            Menu {
                Picker("Show", selection: Binding(get: { mineOnly },
                                                  set: { mineOnly = $0; if $0 { personId = nil } })) {
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

    private func monthGrid(_ days: [Date: [TeamCalendarItem]], _ holidays: [Date: String],
                           _ shading: OffDayShading?, _ legend: CalendarLegendTable) -> some View {
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
                        dayCell(day, items: days[day] ?? [], holiday: holidays[day],
                                isOff: shading?.isOff(day, calendar: cal) ?? false, legend)
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

    private func dayCell(_ day: Date, items entries: [TeamCalendarItem], holiday: String?, isOff: Bool,
                         _ legend: CalendarLegendTable) -> some View {
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
            ForEach(entries.prefix(shown)) { e in chip(e, legend) }
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
        // Off days share the public-holiday grey (as the web).
        .background(isToday || isSelected ? Theme.premier.opacity(0.12)
                    : (inMonth && (holiday != nil || isOff) ? Self.holidayFill
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
        .accessibilityLabel(accessibilityText(day, entries, holiday, isOff: isOff))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The holiday name in the cell: wraps only between words ("🎄 Christmas / Day"); a leading
    /// emoji stays with the first word.
    private func holidayLabel(_ name: String) -> some View {
        var words = name.split(separator: " ").map(String.init)
        if words.count > 2, let first = words.first?.unicodeScalars.first, first.value >= 0x2000 {
            words[1] = "\(words[0]) \(words[1])"
            words.removeFirst()
        }
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

    /// Category colour (tinted fill, darker text), or the neutral amber when the type is hidden.
    private func tint(_ e: TeamCalendarItem, _ legend: CalendarLegendTable) -> (ink: Color, fill: Color) {
        guard let c = e.category else { return (Self.colleagueTint, Self.colleagueFill) }
        return (legend.ink(c), legend.color(c))
    }

    private func chip(_ e: TeamCalendarItem, _ legend: CalendarLegendTable) -> some View {
        let colours = tint(e, legend)
        return Text(e.chip)
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(colours.ink)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 3).fill(colours.fill.opacity(0.18)))
    }

    /// The categories on the calendar for this viewer and filter: Public Holiday, then each kind
    /// of leave / time off / birthday that appears, "Colleague" for leave of a hidden type, and
    /// "Off day" when off days are shaded.
    private func legend(_ items: [TeamCalendarItem], _ table: CalendarLegendTable, shading: Bool) -> some View {
        let present = Set(items.compactMap(\.category))
        let rows = table.rows.filter { $0.key == CalendarCategory.holiday || present.contains($0.key) }
        return FlowLayout(spacing: 6) {
            ForEach(rows) { r in
                legendDot(table.color(r.key), table.emoji(r.key).isEmpty ? r.label : "\(table.emoji(r.key)) \(r.label)")
            }
            if items.contains(where: { $0.kind == .leave && $0.category == nil }) {
                legendDot(Self.colleagueFill, "Colleague")
            }
            if shading { legendDot(Self.holidayFill, "Off day", border: true) }
        }
        .font(.caption2)
        .foregroundStyle(Theme.mist)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar.legend")
    }

    private func legendDot(_ c: Color, _ label: String, border: Bool = false) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 10, height: 10)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.ink.opacity(border ? 0.2 : 0), lineWidth: 1))
            Text(label).lineLimit(1)
        }
        .padding(.trailing, 8)
    }

    // MARK: - Selected-day agenda

    private func dayAgenda(_ entries: [TeamCalendarItem], holiday: String?, person: TeamCalendarPeople.Option?,
                           offDay: Bool, _ legend: CalendarLegendTable) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle(selectedDay) + (offDay && holiday == nil ? " · Off day" : ""))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.mist)
                .padding(.horizontal, 16)
            if let holiday { holidayCard(holiday) }
            if entries.isEmpty && holiday == nil {
                Card {
                    Label(mineOnly ? "You are not on leave."
                          : person.map { "\($0.name) is not on leave." } ?? "Nobody is on leave.", systemImage: "calendar")
                        .font(.subheadline).foregroundStyle(Theme.mist)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
            }
            ForEach(entries) { e in entryCard(e, legend).padding(.horizontal, 16) }
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

    private func entryCard(_ e: TeamCalendarItem, _ legend: CalendarLegendTable) -> some View {
        Card {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint(e, legend).fill)
                    .frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(e.detail)
                        .font(.caption).foregroundStyle(Theme.mist)
                }
                Spacer()
            }
        }
    }

    // MARK: - List mode

    /// Upcoming leave, time off, birthdays and holidays grouped by day. A multi-day leave is
    /// listed once, on its first day from today (its card shows the full date range).
    private func agendaList(_ data: TeamCalendarResponse, _ items: [TeamCalendarItem],
                            _ legend: CalendarLegendTable) -> some View {
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: [TeamCalendarItem]] = [:]
        for e in items where e.end >= today {
            byDay[max(e.start, today), default: []].append(e)
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
                        ForEach(byDay[day] ?? []) { e in entryCard(e, legend).padding(.horizontal, 16) }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Data shaping

    /// Each multi-day item exploded into the days it covers, keyed by local start of day.
    private func index(_ items: [TeamCalendarItem]) -> [Date: [TeamCalendarItem]] {
        var map: [Date: [TeamCalendarItem]] = [:]
        for e in items {
            var day = e.start, n = 0
            while day <= e.end, n < 400 {
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
    static func calendarDay(_ iso: String?) -> Date? { TeamCalendarItem.day(iso, cal) }

    private func dayTitle(_ day: Date) -> String {
        let text = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if cal.isDateInToday(day) { return "Today · \(text)" }
        if cal.isDateInTomorrow(day) { return "Tomorrow · \(text)" }
        return text
    }

    private func accessibilityText(_ day: Date, _ entries: [TeamCalendarItem], _ holiday: String?, isOff: Bool) -> String {
        var s = day.formatted(date: .complete, time: .omitted)
        if let holiday { s += ", \(holiday)" }
        if isOff && holiday == nil { s += ", off day" }
        if !entries.isEmpty { s += ", " + entries.map(\.title).joined(separator: ", ") }
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
            autoSync.noteLoaded()
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the calendar.")
        }
    }
}
