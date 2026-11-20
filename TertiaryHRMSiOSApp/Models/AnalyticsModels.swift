import Foundation

// Analytics (`GET /api/mobile/analytics`, approvers only) — the data behind the web
// /dashboard/analytics page: the last 12 months of bank revenue and expenses, approved leave
// per person and headcount. The server sends small rows; the app filters and sums them here
// (`AnalyticsSlice`), the same way the web page does in the browser.

struct AnalyticsMonth: Decodable, Identifiable, Equatable {
    let key: String     // "2026-11"
    let label: String   // "Nov"
    let year: Int
    var id: String { key }
    /// "Nov 2026"
    var title: String { "\(label) \(year)" }

    init(key: String, label: String, year: Int) { self.key = key; self.label = label; self.year = year }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        label = (try? c.decode(String.self, forKey: .label)) ?? key
        year = (try? c.decode(Int.self, forKey: .year)) ?? Int(key.prefix(4)) ?? 0
    }
    private enum CodingKeys: String, CodingKey { case key, label, year }
}

struct AnalyticsFinanceRow: Decodable, Equatable {
    let month: String
    let type: String
    let revenue: Double
    let expenses: Double

    init(month: String, type: String, revenue: Double, expenses: Double) {
        self.month = month; self.type = type; self.revenue = revenue; self.expenses = expenses
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month = try c.decode(String.self, forKey: .month)
        type = (try? c.decode(String.self, forKey: .type)) ?? "Other"
        revenue = (try? c.decode(Double.self, forKey: .revenue)) ?? 0
        expenses = (try? c.decode(Double.self, forKey: .expenses)) ?? 0
    }
    private enum CodingKeys: String, CodingKey { case month, type, revenue, expenses }
}

enum AnalyticsLeaveCategory: String, CaseIterable, Identifiable {
    case leave = "LEAVE", mc = "MC", npl = "NPL"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .leave: return "Leave"
        case .mc: return "MC"
        case .npl: return "No Pay Leave"
        }
    }
    var short: String { self == .npl ? "NPL" : label }
}

struct AnalyticsLeaveRow: Decodable, Equatable {
    let month: String
    let personId: String
    /// Unknown categories from a newer server count as ordinary leave.
    let category: AnalyticsLeaveCategory
    let days: Double

    init(month: String, personId: String, category: AnalyticsLeaveCategory, days: Double) {
        self.month = month; self.personId = personId; self.category = category; self.days = days
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month = try c.decode(String.self, forKey: .month)
        personId = try c.decode(String.self, forKey: .personId)
        category = AnalyticsLeaveCategory(rawValue: (try? c.decode(String.self, forKey: .category)) ?? "") ?? .leave
        days = (try? c.decode(Double.self, forKey: .days)) ?? 0
    }
    private enum CodingKeys: String, CodingKey { case month, personId, category, days }
}

struct AnalyticsPerson: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let code: String
    let intern: Bool
    let active: Bool

    init(id: String, name: String, code: String, intern: Bool, active: Bool = true) {
        self.id = id; self.name = name; self.code = code; self.intern = intern; self.active = active
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Employee"
        code = (try? c.decode(String.self, forKey: .code)) ?? ""
        intern = (try? c.decode(Bool.self, forKey: .intern)) ?? false
        active = (try? c.decode(Bool.self, forKey: .active)) ?? true
    }
    private enum CodingKeys: String, CodingKey { case id, name, code, intern, active }
}

struct AnalyticsHeadcountRow: Decodable, Equatable {
    let month: String
    let staff: Int
    let interns: Int

    init(month: String, staff: Int, interns: Int) { self.month = month; self.staff = staff; self.interns = interns }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month = try c.decode(String.self, forKey: .month)
        staff = (try? c.decode(Int.self, forKey: .staff)) ?? 0
        interns = (try? c.decode(Int.self, forKey: .interns)) ?? 0
    }
    private enum CodingKeys: String, CodingKey { case month, staff, interns }
}

struct AnalyticsFinanceRange: Decodable, Equatable {
    let from: String
    let to: String
}

/// One active person reduced to the three attributes the workforce donuts need (no name, no
/// date of birth). A missing attribute reads as "Not recorded".
struct AnalyticsBreakdownPerson: Decodable, Equatable {
    let intern: Bool
    let gender: String
    let ageGroup: String
    let ethnicGroup: String

    init(intern: Bool, gender: String, ageGroup: String, ethnicGroup: String) {
        self.intern = intern; self.gender = gender; self.ageGroup = ageGroup; self.ethnicGroup = ethnicGroup
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ k: CodingKeys) -> String {
            let v = ((try? c.decode(String.self, forKey: k)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? WorkforceBreakdown.notRecorded : v
        }
        intern = (try? c.decode(Bool.self, forKey: .intern)) ?? false
        gender = text(.gender); ageGroup = text(.ageGroup); ethnicGroup = text(.ethnicGroup)
    }
    private enum CodingKeys: String, CodingKey { case intern, gender, ageGroup, ethnicGroup }
}

struct AnalyticsData: Decodable {
    let months: [AnalyticsMonth]
    /// nil when the server withholds accounting data from this viewer.
    let finance: [AnalyticsFinanceRow]?
    let financeRange: AnalyticsFinanceRange?
    let leave: [AnalyticsLeaveRow]
    let people: [AnalyticsPerson]
    let headcount: [AnalyticsHeadcountRow]
    /// One row per active person, for the workforce breakdown. nil when the server could not
    /// load it or does not send it yet (older server): the section is then hidden.
    let breakdown: [AnalyticsBreakdownPerson]?

    init(months: [AnalyticsMonth], finance: [AnalyticsFinanceRow]?, financeRange: AnalyticsFinanceRange?,
         leave: [AnalyticsLeaveRow], people: [AnalyticsPerson], headcount: [AnalyticsHeadcountRow],
         breakdown: [AnalyticsBreakdownPerson]? = nil) {
        self.months = months; self.finance = finance; self.financeRange = financeRange
        self.leave = leave; self.people = people; self.headcount = headcount; self.breakdown = breakdown
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        months = try c.decode([AnalyticsMonth].self, forKey: .months)
        finance = try? c.decodeIfPresent([AnalyticsFinanceRow].self, forKey: .finance)
        financeRange = try? c.decodeIfPresent(AnalyticsFinanceRange.self, forKey: .financeRange)
        leave = (try? c.decodeIfPresent([AnalyticsLeaveRow].self, forKey: .leave)) ?? []
        people = (try? c.decodeIfPresent([AnalyticsPerson].self, forKey: .people)) ?? []
        headcount = (try? c.decodeIfPresent([AnalyticsHeadcountRow].self, forKey: .headcount)) ?? []
        breakdown = try? c.decodeIfPresent([AnalyticsBreakdownPerson].self, forKey: .breakdown)
    }
    private enum CodingKeys: String, CodingKey { case months, finance, financeRange, leave, people, headcount, breakdown }

    /// Active staff and interns now, for the Home tiles: from the breakdown (one row per active
    /// person), else the latest headcount month. nil when the server sent neither.
    var activeCounts: (staff: Int, interns: Int)? {
        if let b = breakdown {
            let interns = b.filter(\.intern).count
            return (b.count - interns, interns)
        }
        return headcount.last.map { ($0.staff, $0.interns) }
    }
}

// MARK: - Workforce breakdown (gender, age group, ethnic group)

/// The three donuts of the web's Workforce breakdown, counted on the device for one
/// Staff / Interns / All choice. Categories keep a fixed order, empty ones are dropped, and
/// "Not recorded" is always last in neutral grey (`colorHex == nil`).
struct WorkforceBreakdown {
    static let notRecorded = "Not recorded"
    static let genders = ["Male", "Female", "Other"]
    static let ageGroups = ["Under 25", "25–34", "35–44", "45–54", "55 and over"]
    static let ethnicGroups = ["Chinese", "Malay", "Indian", "Eurasian", "Others"]
    /// Categorical slots and the ordered age ramp, validated on the light and the dark card (web).
    static let slots: [UInt32] = [0x5B82F0, 0x22978B, 0xBF8420, 0x8E5FD0, 0xD9627A]
    static let ageRamp: [UInt32] = [0xA9BEF7, 0x7F9DF3, 0x5B82F0, 0x3D63D6, 0x2A47A8]

    struct Slice: Identifiable, Equatable {
        let label: String
        let count: Int
        /// nil = neutral grey ("Not recorded").
        let colorHex: UInt32?
        var id: String { label }
    }
    struct Chart: Identifiable, Equatable {
        let title: String
        let slices: [Slice]
        var id: String { title }
        var total: Int { slices.reduce(0) { $0 + $1.count } }
        /// "43%" — whole percent of this chart's total.
        func percent(_ s: Slice) -> String {
            total > 0 ? "\(Int((Double(s.count) / Double(total) * 100).rounded()))%" : "0%"
        }
    }

    let who: AnalyticsWho
    /// People counted after the Staff / Interns / All choice.
    let count: Int
    let charts: [Chart]
    /// People in `count` whose ethnic group is not recorded.
    let ethnicMissing: Int

    /// "staff" | "interns" | "people"
    var noun: String { who == .staff ? "staff" : who == .interns ? "interns" : "people" }
    /// Shown under the charts when some (or all) of the people have no ethnic group on record.
    var ethnicNote: String? {
        guard ethnicMissing > 0 else { return nil }
        let whom = ethnicMissing == count ? "any of the \(count) \(noun)" : "\(ethnicMissing) of \(count) \(noun)"
        return "Ethnic group is not recorded for \(whom). Set it on each person's page in Staff Management on the web."
    }

    init(_ people: [AnalyticsBreakdownPerson], who: AnalyticsWho) {
        self.who = who
        let shown = people.filter { who.includes(intern: $0.intern) }
        count = shown.count
        ethnicMissing = shown.filter { $0.ethnicGroup == Self.notRecorded }.count
        charts = [
            Chart(title: "Gender", slices: Self.count(shown.map(\.gender), order: Self.genders, colors: Self.slots)),
            Chart(title: "Age group", slices: Self.count(shown.map(\.ageGroup), order: Self.ageGroups, colors: Self.ageRamp)),
            Chart(title: "Ethnic group", slices: Self.count(shown.map(\.ethnicGroup), order: Self.ethnicGroups, colors: Self.slots)),
        ]
    }

    /// People per label in the given order, then any label the app does not know (a newer
    /// server), then "Not recorded"; empty slices are dropped.
    static func count(_ values: [String], order: [String], colors: [UInt32]) -> [Slice] {
        var counts: [String: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        let extra = counts.keys.filter { !order.contains($0) && $0 != notRecorded }.sorted()
        var out: [Slice] = []
        for (i, label) in (order + extra).enumerated() {
            if let n = counts[label], n > 0 { out.append(Slice(label: label, count: n, colorHex: colors[i % colors.count])) }
        }
        if let n = counts[notRecorded], n > 0 { out.append(Slice(label: notRecorded, count: n, colorHex: nil)) }
        return out
    }
}

// MARK: - Filters and the filtered view of the data

enum AnalyticsWho: String, CaseIterable, Identifiable {
    case all, staff, interns
    var id: String { rawValue }
    var title: String { self == .all ? "All" : self == .staff ? "Staff" : "Interns" }
    func includes(intern: Bool) -> Bool { self == .all || (self == .interns) == intern }
}

struct AnalyticsFilter: Equatable {
    var period = 12                     // 3, 6 or 12 months
    var who: AnalyticsWho = .all
    var personId: String? = nil
    var leaveOff: Set<AnalyticsLeaveCategory> = []
    var typeOff: Set<String> = []       // finance categories left out

    var isDefault: Bool { self == AnalyticsFilter() }
}

/// Everything the Analytics screen shows, computed from one filter so the tiles and the
/// charts can never disagree.
struct AnalyticsSlice {
    struct MonthValue: Identifiable {
        let month: AnalyticsMonth
        let values: [String: Double]    // series key -> value
        var id: String { month.key }
        func value(_ key: String) -> Double { values[key] ?? 0 }
    }
    struct PersonRow: Identifiable {
        let person: AnalyticsPerson
        let days: [AnalyticsLeaveCategory: Double]
        var id: String { person.id }
        var total: Double { days.values.reduce(0, +) }
        func value(_ c: AnalyticsLeaveCategory) -> Double { days[c] ?? 0 }
    }
    struct TypeRow: Identifiable {
        let type: String
        let revenue: Double
        let expenses: Double
        var id: String { type }
        var isRevenue: Bool { revenue >= expenses }
        var amount: Double { max(revenue, expenses) }
    }
    struct HeadRow: Identifiable {
        let month: AnalyticsMonth
        let staff: Int
        let interns: Int
        /// Against the month before; nil for the first month shown.
        let change: Int?
        var id: String { month.key }
        var total: Int { staff + interns }
    }

    let months: [AnalyticsMonth]
    let selectablePeople: [AnalyticsPerson]
    /// The selected person, when they are still within the Who filter.
    let person: AnalyticsPerson?
    let leaveSeries: [AnalyticsLeaveCategory]
    let leaveByMonth: [MonthValue]
    let leaveTotals: [AnalyticsLeaveCategory: Double]
    let byPerson: [PersonRow]
    let hasFinance: Bool
    let financeByMonth: [MonthValue]
    let types: [TypeRow]
    let revenue: Double
    let expenses: Double
    let headcount: [HeadRow]

    var net: Double { revenue - expenses }
    var rangeLabel: String {
        guard let a = months.first, let b = months.last else { return "" }
        return "\(a.title) to \(b.title)"
    }
    func leaveTotal(_ c: AnalyticsLeaveCategory) -> Double { leaveTotals[c] ?? 0 }
    var headNow: Int { headcount.last?.total ?? 0 }
    var headDelta: Int { headNow - (headcount.first?.total ?? 0) }

    init(_ data: AnalyticsData, _ f: AnalyticsFilter) {
        let shown = Array(data.months.suffix(max(1, f.period)))
        let keys = Set(shown.map(\.key))
        months = shown

        let people = Dictionary(data.people.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let selectable = data.people.filter { f.who.includes(intern: $0.intern) }
        selectablePeople = selectable
        let chosen = f.personId.flatMap { id in selectable.first { $0.id == id } }
        person = chosen
        leaveSeries = AnalyticsLeaveCategory.allCases.filter { !f.leaveOff.contains($0) }

        // Leave
        let rows = data.leave.filter { r in
            guard let p = people[r.personId], keys.contains(r.month), !f.leaveOff.contains(r.category) else { return false }
            if let chosen { return r.personId == chosen.id }
            return f.who.includes(intern: p.intern)
        }
        leaveByMonth = shown.map { m in
            var v: [String: Double] = [:]
            for r in rows where r.month == m.key { v[r.category.rawValue, default: 0] += r.days }
            return MonthValue(month: m, values: v)
        }
        var totals: [AnalyticsLeaveCategory: Double] = [:]
        var per: [String: [AnalyticsLeaveCategory: Double]] = [:]
        for r in rows {
            totals[r.category, default: 0] += r.days
            per[r.personId, default: [:]][r.category, default: 0] += r.days
        }
        leaveTotals = totals
        byPerson = per.compactMap { id, d in people[id].map { PersonRow(person: $0, days: d) } }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.person.name < $1.person.name }

        // Finance
        hasFinance = data.finance != nil
        let fin = (data.finance ?? []).filter { keys.contains($0.month) }
        var byType: [String: (Double, Double)] = [:]
        for r in fin {
            let t = byType[r.type] ?? (0, 0)
            byType[r.type] = (t.0 + r.revenue, t.1 + r.expenses)
        }
        types = byType.map { TypeRow(type: $0.key, revenue: $0.value.0, expenses: $0.value.1) }
            .sorted { ($0.revenue + $0.expenses) != ($1.revenue + $1.expenses)
                ? ($0.revenue + $0.expenses) > ($1.revenue + $1.expenses) : $0.type < $1.type }
        let on = fin.filter { !f.typeOff.contains($0.type) }
        financeByMonth = shown.map { m in
            var rev = 0.0, exp = 0.0
            for r in on where r.month == m.key { rev += r.revenue; exp += r.expenses }
            return MonthValue(month: m, values: ["revenue": rev, "expenses": exp])
        }
        revenue = on.reduce(0) { $0 + $1.revenue }
        expenses = on.reduce(0) { $0 + $1.expenses }

        // Headcount (the person filter does not apply)
        let heads = Dictionary(data.headcount.map { ($0.month, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [HeadRow] = []
        for m in shown {
            let h = heads[m.key]
            let staff = f.who == .interns ? 0 : (h?.staff ?? 0)
            let interns = f.who == .staff ? 0 : (h?.interns ?? 0)
            let change = out.last.map { staff + interns - $0.total }
            out.append(HeadRow(month: m, staff: staff, interns: interns, change: change))
        }
        headcount = out
    }
}
