import SwiftUI

// Calendar parity with the web of 20 Nov 2026 (1.18 build 34). The web sources are
// `src/lib/calendar-categories.ts` (colours, emoji), `src/lib/calendar-summary.ts` (month totals)
// and `src/components/calendar/calendar-view.tsx` (off-day shading, filters). Everything here is
// pure and unit-tested in `ParityBuild34Tests`; `TeamCalendarView` only draws it.

// MARK: - Categories (colour + emoji legend)

/// One legend row of `GET /api/mobile/team-calendar` → `categories`.
struct CalendarCategoryInfo: Codable, Equatable, Identifiable {
    let key: String
    let label: String
    /// "#RRGGBB"
    let color: String
    var emoji: String? = nil
    var id: String { key }
}

enum CalendarCategory {
    static let holiday = "HOLIDAY"
    static let annualLeave = "ANNUAL_LEAVE"
    static let medicalLeave = "MEDICAL_LEAVE"
    static let noPayLeave = "NO_PAY_LEAVE"
    static let otherLeave = "OTHER_LEAVE"
    static let timeOff = "TIME_OFF"
    static let birthday = "BIRTHDAY"

    /// The web's table (calendar-categories.ts, legend order), used when the server sends none.
    static let fallback: [CalendarCategoryInfo] = [
        .init(key: "HOLIDAY", label: "Public Holiday", color: "#ef4444", emoji: ""),
        .init(key: "ANNUAL_LEAVE", label: "Annual Leave", color: "#f59e0b", emoji: "🏖️"),
        .init(key: "MEDICAL_LEAVE", label: "Medical Leave", color: "#ec4899", emoji: "🤒"),
        .init(key: "NO_PAY_LEAVE", label: "No Pay Leave", color: "#64748b", emoji: "💸"),
        .init(key: "OTHER_LEAVE", label: "Other Leave", color: "#9a6b4f", emoji: "📋"),
        .init(key: "TIME_OFF", label: "Time Off", color: "#06b6d4", emoji: "⏰"),
        .init(key: "BIRTHDAY", label: "Birthday", color: "#d946ef", emoji: "🎂"),
        .init(key: "MEETING", label: "Meeting", color: "#3b82f6", emoji: ""),
        .init(key: "TRAINING", label: "Training", color: "#a855f7", emoji: ""),
        .init(key: "COMPANY_EVENT", label: "Company Event", color: "#22c55e", emoji: ""),
    ]

    static func isLeave(_ key: String?) -> Bool { key?.hasSuffix("_LEAVE") ?? false }
}

/// The legend table in use: the server's rows, with any category it lacks (or sends with a bad
/// colour) taken from the built-in table.
struct CalendarLegendTable: Equatable {
    let rows: [CalendarCategoryInfo]

    init(_ server: [CalendarCategoryInfo]?) {
        var rows = (server ?? []).filter { Self.parseHex($0.color) != nil }
        for f in CalendarCategory.fallback where !rows.contains(where: { $0.key == f.key }) { rows.append(f) }
        self.rows = rows
    }

    func info(_ key: String) -> CalendarCategoryInfo? { rows.first { $0.key == key } }
    func label(_ key: String) -> String { info(key)?.label ?? key }
    /// 24-bit colour; grey (#6b7280, the web's default) for an unknown category.
    func hex(_ key: String) -> UInt32 { info(key).flatMap { Self.parseHex($0.color) } ?? 0x6B7280 }
    /// The emoji in front of a title ("" when the category has none).
    func emoji(_ key: String) -> String {
        if let e = info(key)?.emoji, !e.isEmpty { return e }
        return CalendarCategory.fallback.first { $0.key == key }?.emoji ?? ""
    }

    /// "#ef4444" → 0xEF4444; nil unless exactly #RRGGBB.
    static func parseHex(_ s: String) -> UInt32? {
        guard s.count == 7, s.hasPrefix("#") else { return nil }
        return UInt32(s.dropFirst(), radix: 16)
    }

    /// A darker shade (the web chip text in light mode keeps `1 − amount` of each channel).
    static func darken(_ hex: UInt32, _ amount: Double) -> UInt32 {
        func ch(_ shift: UInt32) -> UInt32 { UInt32((Double((hex >> shift) & 0xFF) * (1 - amount)).rounded()) }
        return (ch(16) << 16) | (ch(8) << 8) | ch(0)
    }

    /// Chip text: darkened in light, the colour itself in dark (the web chip style).
    func ink(_ key: String) -> Color { Color(light: Self.darken(hex(key), 0.45), dark: hex(key)) }
    func color(_ key: String) -> Color { Color(hex: hex(key)) }
}

// MARK: - New team-calendar rows

/// Approved time off or an intern's full-day Off Day (`timeOff`). Approvers get everyone's,
/// others only their own.
struct TeamTimeOffEntry: Codable, Identifiable, Equatable {
    let id: String
    let employeeId: String
    let employeeName: String
    /// ISO date (`@db.Date`, read by its yyyy-MM-dd part).
    let date: String?
    /// "HH:mm"
    let startTime: String
    let endTime: String
    let hours: Double
    let offDay: Bool
    let isSelf: Bool
    /// Approvers only: "staff" | "intern".
    var group: String? = nil

    init(id: String, employeeId: String, employeeName: String, date: String?, startTime: String, endTime: String,
         hours: Double, offDay: Bool, isSelf: Bool, group: String? = nil) {
        self.id = id; self.employeeId = employeeId; self.employeeName = employeeName; self.date = date
        self.startTime = startTime; self.endTime = endTime; self.hours = hours; self.offDay = offDay
        self.isSelf = isSelf; self.group = group
    }

    enum CodingKeys: String, CodingKey { case id, employeeId, employeeName, date, startTime, endTime, hours, offDay, isSelf, group }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        employeeId = (try? c.decode(String.self, forKey: .employeeId)) ?? ""
        employeeName = (try? c.decode(String.self, forKey: .employeeName)) ?? "Employee"
        date = try? c.decodeIfPresent(String.self, forKey: .date)
        startTime = (try? c.decode(String.self, forKey: .startTime)) ?? ""
        endTime = (try? c.decode(String.self, forKey: .endTime)) ?? ""
        if let h = try? c.decode(Double.self, forKey: .hours) { hours = h }
        else { hours = (try? c.decode(String.self, forKey: .hours)).flatMap(Double.init) ?? 0 }
        offDay = (try? c.decode(Bool.self, forKey: .offDay)) ?? false
        isSelf = (try? c.decode(Bool.self, forKey: .isSelf)) ?? false
        group = try? c.decodeIfPresent(String.self, forKey: .group)
    }
}

/// Approvers only (`birthdays`): day and month, never the age. `date` is SGT noon.
struct TeamBirthday: Codable, Identifiable, Equatable {
    let id: String
    let employeeId: String
    let name: String
    let date: String
}

extension TeamLeaveEntry {
    /// The colour category: the server's, or on an older server one derived from the leave type
    /// name (same rules as the web `leaveCategory`). nil when the type is hidden from the viewer.
    var resolvedCategory: String? {
        if let c = category, !c.isEmpty { return c }
        guard let t = leaveType?.lowercased(), !t.isEmpty else { return nil }
        if t.contains("no pay") || t.contains("unpaid") || t == "npl" { return CalendarCategory.noPayLeave }
        if t.contains("annual") || t.contains("lieu") { return CalendarCategory.annualLeave }
        if t.contains("medical") || t.contains("sick") || t == "mc" { return CalendarCategory.medicalLeave }
        return CalendarCategory.otherLeave
    }
}

// MARK: - What the filters leave on the calendar

/// Leave, time off and birthdays after "Everyone / Only me" and the person filter. Public
/// holidays are separate and always show. Birthdays are not leave: "Only me" hides them, and a
/// picked person shows only theirs.
struct TeamCalendarVisible {
    let entries: [TeamLeaveEntry]
    let timeOff: [TeamTimeOffEntry]
    let birthdays: [TeamBirthday]

    init(_ data: TeamCalendarResponse, people: TeamCalendarPeople, personId: String?, mineOnly: Bool) {
        let person = people.option(personId)
        var e = data.entries, t = data.timeOff ?? [], b = data.birthdays ?? []
        if mineOnly { e = e.filter(\.isSelf); t = t.filter(\.isSelf); b = [] }
        if let p = person {
            e = e.filter { $0.employeeId == p.id }
            t = t.filter { $0.employeeId == p.id }
            b = b.filter { $0.employeeId == p.id }
        }
        entries = e; timeOff = t; birthdays = b
    }
}

/// One chip / agenda card on the calendar.
struct TeamCalendarItem: Identifiable, Equatable {
    enum Kind: Equatable { case leave, timeOff, birthday }
    let id: String
    let kind: Kind
    /// Colour category; nil = a colleague's leave whose type is hidden (neutral style, no emoji).
    let category: String?
    let employeeId: String
    let isSelf: Bool
    /// Local start of the first and last day.
    let start: Date
    let end: Date
    /// Short text in the month cell: "🏖️ You", "⏰ Evan".
    let chip: String
    /// Agenda title: "🤒 Femina Jasmin", "⏰ EVAN PANG - Time off 2:00 PM – 4:00 PM", "🎂 EVAN PANG birthday".
    let title: String
    let detail: String

    /// Leave, then time off, then birthdays, each in server order.
    static func build(_ v: TeamCalendarVisible, legend: CalendarLegendTable, isApprover: Bool,
                      calendar: Calendar = TeamCalendarItem.calendar) -> [TeamCalendarItem] {
        func lead(_ emoji: String, _ text: String) -> String { emoji.isEmpty ? text : "\(emoji) \(text)" }
        func first(_ name: String) -> String { name.split(separator: " ").first.map(String.init) ?? name }
        var out: [TeamCalendarItem] = []
        for e in v.entries {
            guard let s = day(e.startDate, calendar) else { continue }
            let cat = e.resolvedCategory
            let emoji = cat.map(legend.emoji) ?? ""
            var bits = [e.leaveType ?? "On leave", e.halfDay ? "Half day" : Fmt.days(e.days)]
            let end = day(e.endDate, calendar) ?? s
            if end != s {
                bits.append("\(s.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated)))")
            }
            if let d = e.department, !e.isSelf { bits.append(d) }
            out.append(.init(id: "leave:\(e.id)", kind: .leave, category: cat, employeeId: e.employeeId, isSelf: e.isSelf,
                             start: s, end: max(s, end),
                             chip: lead(emoji, e.isSelf ? "You" : first(e.employeeName)),
                             title: lead(emoji, e.isSelf ? "You" : e.employeeName),
                             detail: bits.joined(separator: " · ")))
        }
        let toEmoji = legend.emoji(CalendarCategory.timeOff)
        for t in v.timeOff {
            guard let d = day(t.date, calendar) else { continue }
            let what = t.offDay ? "Off Day" : "Time off \(TimeOffView.time12(t.startTime)) – \(TimeOffView.time12(t.endTime))"
            let who = t.isSelf ? "You" : t.employeeName
            out.append(.init(id: "timeoff:\(t.id)", kind: .timeOff, category: CalendarCategory.timeOff,
                             employeeId: t.employeeId, isSelf: t.isSelf, start: d, end: d,
                             chip: lead(toEmoji, t.isSelf ? "You" : first(t.employeeName)),
                             title: lead(toEmoji, isApprover ? "\(who) - \(what)" : what),
                             detail: t.offDay ? "Off Day · Full day" : "Time Off · \(Fmt.num(t.hours)) h"))
        }
        let bdEmoji = legend.emoji(CalendarCategory.birthday)
        for b in v.birthdays {
            guard let d = day(b.date, calendar) else { continue }
            out.append(.init(id: "birthday:\(b.id)", kind: .birthday, category: CalendarCategory.birthday,
                             employeeId: b.employeeId, isSelf: false, start: d, end: d,
                             chip: lead(bdEmoji, first(b.name)), title: lead(bdEmoji, "\(b.name) birthday"),
                             detail: "Birthday"))
        }
        return out
    }

    /// Weeks start on Monday, in the device's time zone (same as the month grid).
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()

    /// "2026-11-08T00:00:00Z" / "2026-11-08" → that day at local midnight, read from the
    /// yyyy-MM-dd part so a date never shifts with the device's time zone.
    static func day(_ iso: String?, _ calendar: Calendar) -> Date? {
        guard let iso, iso.count >= 10 else { return nil }
        let p = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
}

// MARK: - Off-day shading

/// Whose off days are shaded: the staff / intern viewer's own schedule, or the person an approver
/// picked. With "Everyone" there is no single schedule, so nothing is shaded. A day is off when its
/// ISO weekday is not a workday (Mon–Fri when the list is empty) or it holds an approved full-day
/// Off Day for that person.
struct OffDayShading: Equatable {
    static let defaultWorkdays = [1, 2, 3, 4, 5]
    let workdays: [Int]
    /// yyyy-MM-dd of approved full-day Off Days.
    let offDayKeys: Set<String>

    init(workdays: [Int]?, offDayKeys: Set<String> = []) {
        if let w = workdays, !w.isEmpty { self.workdays = w } else { self.workdays = Self.defaultWorkdays }
        self.offDayKeys = offDayKeys
    }

    /// nil when no single schedule applies.
    /// - approver (`isApprover`) with a person picked: that person's `people[].workdays`;
    /// - approver on "Only me": the viewer's `ownWorkdays`;
    /// - approver on Everyone: none;
    /// - staff / intern: `ownWorkdays` (none when the server sends no schedule).
    static func make(_ data: TeamCalendarResponse, isApprover: Bool, personId: String?, mineOnly: Bool) -> OffDayShading? {
        let timeOff = data.timeOff ?? []
        func keys(_ rows: [TeamTimeOffEntry]) -> Set<String> {
            Set(rows.filter(\.offDay).compactMap { $0.date.map { String($0.prefix(10)) } })
        }
        if isApprover {
            if let personId {
                let person = data.people?.first { $0.id == personId }
                return OffDayShading(workdays: person?.workdays, offDayKeys: keys(timeOff.filter { $0.employeeId == personId }))
            }
            guard mineOnly, let own = data.ownWorkdays else { return nil }
            return OffDayShading(workdays: own, offDayKeys: keys(timeOff.filter(\.isSelf)))
        }
        guard let own = data.ownWorkdays else { return nil }
        return OffDayShading(workdays: own, offDayKeys: keys(timeOff.filter(\.isSelf)))
    }

    func isOff(_ day: Date, calendar: Calendar = TeamCalendarItem.calendar) -> Bool {
        !workdays.contains(Self.isoWeekday(day, calendar)) || offDayKeys.contains(CalendarMonthSummary.dayKey(day, calendar))
    }

    /// 1 = Mon … 7 = Sun.
    static func isoWeekday(_ day: Date, _ calendar: Calendar) -> Int {
        let w = calendar.component(.weekday, from: day)   // 1 = Sun … 7 = Sat
        return w == 1 ? 7 : w - 1
    }
}

// MARK: - Month totals for one person (port of src/lib/calendar-summary.ts)

/// An event as the month totals see it (the web `SummaryEvent`).
struct CalendarSummaryEvent: Equatable {
    let category: String
    let start: Date
    let end: Date
    let allDay: Bool
    var personId: String? = nil
    /// Leave: the days charged for the whole request (0.5 for a half day).
    var days: Double? = nil
    /// Time off: hours taken (0 for a full Off Day).
    var hours: Double? = nil
}

struct PersonMonthSummary: Equatable {
    var annualLeaveDays: Double = 0
    var medicalLeaveDays: Double = 0
    var noPayLeaveDays: Double = 0
    var otherLeaveDays: Double = 0
    var timeOffHours: Double = 0
    /// Approved full-day Off Days (interns).
    var offDays: Int = 0
}

enum CalendarMonthSummary {
    static func dayKey(_ d: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func round2(_ n: Double) -> Double { (n * 100).rounded() / 100 }

    /// Totals for `personId` in `month` (1–12; the web's is 0-based) of `year`, in the device's
    /// time zone, the way the month grid places events.
    ///
    /// A leave wholly inside the month counts its charged days. A leave that crosses a month
    /// boundary is split by working days (Mon–Fri, public holidays excluded, as leave is charged),
    /// so the months together add up to the charged days.
    static func personMonthSummary(_ events: [CalendarSummaryEvent], personId: String, year: Int, month: Int,
                                   holidayKeys: Set<String> = [],
                                   calendar: Calendar = TeamCalendarItem.calendar) -> PersonMonthSummary {
        var out = PersonMonthSummary()
        func inMonth(_ d: Date) -> Bool {
            let c = calendar.dateComponents([.year, .month], from: d)
            return c.year == year && c.month == month
        }
        func isWorking(_ d: Date) -> Bool {
            let w = calendar.component(.weekday, from: d)
            return w != 1 && w != 7 && !holidayKeys.contains(dayKey(d, calendar))
        }

        for e in events where e.personId == personId {
            let start = calendar.startOfDay(for: e.start)
            let end = calendar.startOfDay(for: e.end)

            if e.category == CalendarCategory.timeOff {
                guard inMonth(start) else { continue }
                if e.allDay { out.offDays += 1 } else { out.timeOffHours += e.hours ?? 0 }
                continue
            }
            guard CalendarCategory.isLeave(e.category) else { continue }

            // Working and calendar days of the leave, in total and inside the month.
            var working = 0, workingIn = 0, calendarDays = 0, calendarIn = 0
            var d = start, guardCount = 0
            while d <= end, guardCount < 1000 {
                calendarDays += 1
                if inMonth(d) { calendarIn += 1 }
                if isWorking(d) {
                    working += 1
                    if inMonth(d) { workingIn += 1 }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next; guardCount += 1
            }
            guard calendarIn > 0 else { continue }
            let charged = e.days ?? Double(working)
            // No working day in the range (e.g. weekend leave): fall back to calendar days.
            let share = calendarIn == calendarDays ? 1
                : working > 0 ? Double(workingIn) / Double(working) : Double(calendarIn) / Double(calendarDays)
            let days = charged * share

            switch e.category {
            case CalendarCategory.annualLeave: out.annualLeaveDays += days
            case CalendarCategory.medicalLeave: out.medicalLeaveDays += days
            case CalendarCategory.noPayLeave: out.noPayLeaveDays += days
            default: out.otherLeaveDays += days
            }
        }

        out.annualLeaveDays = round2(out.annualLeaveDays)
        out.medicalLeaveDays = round2(out.medicalLeaveDays)
        out.noPayLeaveDays = round2(out.noPayLeaveDays)
        out.otherLeaveDays = round2(out.otherLeaveDays)
        out.timeOffHours = round2(out.timeOffHours)
        return out
    }

    /// The month-total events of the whole response: every leave with a known category, and time off.
    static func events(_ data: TeamCalendarResponse, calendar: Calendar = TeamCalendarItem.calendar) -> [CalendarSummaryEvent] {
        var out: [CalendarSummaryEvent] = []
        for e in data.entries {
            guard let cat = e.resolvedCategory, let s = TeamCalendarItem.day(e.startDate, calendar) else { continue }
            out.append(.init(category: cat, start: s, end: TeamCalendarItem.day(e.endDate, calendar) ?? s,
                             allDay: true, personId: e.employeeId, days: e.days))
        }
        for t in data.timeOff ?? [] {
            guard let d = TeamCalendarItem.day(t.date, calendar) else { continue }
            out.append(.init(category: CalendarCategory.timeOff, start: d, end: d, allDay: t.offDay,
                             personId: t.employeeId, hours: t.hours))
        }
        return out
    }

    /// Start days of the public holidays (the web uses each holiday event's start day).
    static func holidayKeys(_ data: TeamCalendarResponse, calendar: Calendar = TeamCalendarItem.calendar) -> Set<String> {
        Set(data.holidays.compactMap { TeamCalendarItem.day($0.startDate, calendar).map { dayKey($0, calendar) } })
    }

    struct Tile: Identifiable, Equatable {
        let label: String
        let value: String
        let category: String
        var id: String { label }
    }

    /// The web's chips: Annual / Medical / No Pay Leave, Other Leave only when > 0, then Time Off
    /// "X h" plus " + N off day(s)".
    static func tiles(_ s: PersonMonthSummary) -> [Tile] {
        func days(_ n: Double) -> String { "\(number(n)) \(n == 1 ? "day" : "days")" }
        var out: [Tile] = [
            .init(label: "Annual Leave", value: days(s.annualLeaveDays), category: CalendarCategory.annualLeave),
            .init(label: "Medical Leave", value: days(s.medicalLeaveDays), category: CalendarCategory.medicalLeave),
            .init(label: "No Pay Leave", value: days(s.noPayLeaveDays), category: CalendarCategory.noPayLeave),
        ]
        if s.otherLeaveDays > 0 {
            out.append(.init(label: "Other Leave", value: days(s.otherLeaveDays), category: CalendarCategory.otherLeave))
        }
        let off = s.offDays > 0 ? " + \(s.offDays) off \(s.offDays == 1 ? "day" : "days")" : ""
        out.append(.init(label: "Time Off", value: "\(number(s.timeOffHours)) h\(off)", category: CalendarCategory.timeOff))
        return out
    }

    /// A number as JavaScript prints it here (values are already rounded to 2 places): 2, 2.5, 0.33.
    static func number(_ n: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
