import Foundation

// MARK: - Dashboard summary  (/api/mobile/summary)
struct DashboardSummary: Codable {
    let name: String?
    let role: String?
    let isAdmin: Bool
    let alAvailable: Double?
    let mcAvailable: Double?
    let otRemaining: Double?
    let expenseYtd: Double
    let pendingLeaves: Int
    let pendingClaims: Int
    /// Holds TRAINER_ADMIN → show the Trainers directory. Optional so an older
    /// server (without the field) still decodes; treated as false.
    var canManageTrainers: Bool? = nil
    /// The signed-in person's own leave tiles, the same summary as the web staff dashboard and
    /// the decision email (build 34). Shown as given. nil on an older server or without an employee.
    var leaveSummary: [SummaryStat]? = nil
    /// Accountants (not admins) only: pending claims and this month's bank income / expenses.
    var financeKpis: FinanceKpis? = nil
    /// Trainer Admins only: trainer counts (all / ACLP / non-ACLP).
    var trainerKpis: TrainerKpis? = nil

    var showsTrainers: Bool { canManageTrainers ?? false }

    enum CodingKeys: String, CodingKey {
        case name, role, isAdmin, alAvailable, mcAvailable, otRemaining, expenseYtd, pendingLeaves, pendingClaims,
             canManageTrainers, leaveSummary, financeKpis, trainerKpis
    }
}

extension DashboardSummary {
    // Defined in an extension so the memberwise init stays. The build-34 fields are read with
    // `try?`: a field this build cannot read hides its tiles instead of failing Home.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        isAdmin = try c.decode(Bool.self, forKey: .isAdmin)
        alAvailable = try c.decodeIfPresent(Double.self, forKey: .alAvailable)
        mcAvailable = try c.decodeIfPresent(Double.self, forKey: .mcAvailable)
        otRemaining = try c.decodeIfPresent(Double.self, forKey: .otRemaining)
        expenseYtd = try c.decode(Double.self, forKey: .expenseYtd)
        pendingLeaves = try c.decode(Int.self, forKey: .pendingLeaves)
        pendingClaims = try c.decode(Int.self, forKey: .pendingClaims)
        canManageTrainers = try c.decodeIfPresent(Bool.self, forKey: .canManageTrainers)
        leaveSummary = (try? c.decodeIfPresent([SummaryStat].self, forKey: .leaveSummary)) ?? nil
        financeKpis = (try? c.decodeIfPresent(FinanceKpis.self, forKey: .financeKpis)) ?? nil
        trainerKpis = (try? c.decodeIfPresent(TrainerKpis.self, forKey: .trainerKpis)) ?? nil
    }
}

/// One leave tile of `summary.leaveSummary`: "Paid leave taken" / "3 days" / optional hint
/// ("12 of 14 left").
struct SummaryStat: Codable, Equatable, Identifiable {
    let label: String
    let value: String
    var hint: String? = nil
    var id: String { label }

    init(label: String, value: String, hint: String? = nil) { self.label = label; self.value = value; self.hint = hint }

    enum CodingKeys: String, CodingKey { case label, value, hint }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        if let s = try? c.decode(String.self, forKey: .value) { value = s }
        else if let n = try? c.decode(Double.self, forKey: .value) { value = Fmt.num(n) }
        else { value = "-" }
        hint = (try? c.decodeIfPresent(String.self, forKey: .hint)) ?? nil
    }
}

/// `summary.financeKpis` (accountants): the web dashboard's FinanceKpiRow.
struct FinanceKpis: Codable, Equatable {
    let pendingClaims: Int
    let pendingClaimsAmount: Double
    let incomeMonth: Double
    let incomeYtd: Double
    let expensesMonth: Double
    let expensesYtd: Double
    /// "Nov" (Singapore time).
    let monthLabel: String
    let year: Int
    /// Bank credits / debits this month, statement imports and the latest reconciliation
    /// (web e46f631, 22 Nov 2026). Optional: an older server leaves them out.
    var incomeCountMonth: Int? = nil
    var expenseCountMonth: Int? = nil
    var statementImports: Int? = nil
    /// yyyy-MM-dd: the last bank date the imported statements cover.
    var statementLatestDate: String? = nil
    var statementLastImportedAt: String? = nil
    var reconciliation: FinanceReconciliation? = nil
}

/// The latest bank reconciliation run (DBS against QuickBooks). `toReview`: unreviewed lines that are not a match.
struct FinanceReconciliation: Codable, Equatable {
    let status: String
    let periodStart: String
    let periodEnd: String
    let matched: Int
    let toReview: Int
    let createdAt: String
}

/// `summary.trainerKpis` (Trainer Admins): the web dashboard's TrainerKpiRow.
struct TrainerKpis: Codable, Equatable {
    let total: Int
    let aclp: Int
    let nonAclp: Int
}

// MARK: - Leave  (/api/mobile/leave)
struct LeaveResponse: Codable {
    let balances: [LeaveBalance]
    let types: [LeaveType]
    let requests: [LeaveRequest]
}

struct LeaveBalance: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let paid: Bool
    let entitlement: Double
    let carriedOver: Double
    let used: Double
    let pending: Double
    let earned: Double
    let autoDeducted: Double
    let proRated: Double?
    let available: Double

    /// No Pay Leave: `proRated` is the yearly cap (a flat 14 since 20 Nov 2026) and `available` the days left.
    var isNoPayLeave: Bool { code.uppercased() == LeaveRules.nplCode }
}

struct LeaveType: Codable, Identifiable {
    let id: String
    let code: String
    let name: String
    let paid: Bool
    let defaultDays: Int
}

struct LeaveRequest: Codable, Identifiable {
    let id: String
    let leaveType: String
    let leaveCode: String
    let startDate: String?
    let endDate: String?
    let days: Double
    let dayType: String
    let status: String
    let reason: String?
    let approver: String?
    let approvedAt: String?
    let rejectionReason: String?
    let createdAt: String?
}

// MARK: - Pending approvals  (/api/mobile/approvals — MANAGER/HR/ADMIN)
struct ApprovalsResponse: Codable {
    let leaves: [PendingLeave]
    let claims: [PendingClaim]
    /// No Pay Leave paybacks waiting (web 23 Nov 2026). Absent on an older server → empty.
    var paybacks: [PendingPayback] = []

    init(leaves: [PendingLeave], claims: [PendingClaim], paybacks: [PendingPayback] = []) {
        self.leaves = leaves; self.claims = claims; self.paybacks = paybacks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        leaves = try c.decode([PendingLeave].self, forKey: .leaves)
        claims = try c.decode([PendingClaim].self, forKey: .claims)
        paybacks = (try? c.decodeIfPresent([PendingPayback].self, forKey: .paybacks)) ?? []
    }
}

/// A No Pay Leave payback waiting for approval: the person worked an off day (`workDate`) to pay
/// back a No Pay Leave day (`nplDate`). `clocked` = their punch on the day worked, as evidence.
/// Approve / reject: `POST /api/leave/payback/{id}/approve|reject`.
struct PendingPayback: Codable, Identifiable, Equatable {
    let id: String
    let employee: String
    let nplDate: String?
    let workDate: String?
    let days: Double
    var note: String? = nil
    var clocked: String? = nil
    var createdAt: String? = nil
}

struct PendingLeave: Codable, Identifiable {
    let id: String
    let employee: String
    let leaveType: String
    let leaveCode: String
    let startDate: String?
    let endDate: String?
    let days: Double
    let dayType: String
    let reason: String?
    let documentUrl: String?
    let createdAt: String?
}

/// Approver Home: what is waiting for a decision, by type: leave, MC, time off, claims and No Pay
/// Leave payback. Missed punches are not on Home (Alfred, 23 Nov 2026: "nobody can understand";
/// they stay in More → Timesheet). Built from the Approvals feeds, so the numbers match that screen.
struct PendingApprovals: Equatable {
    var leave = 0, mc = 0, timeOff = 0, claims = 0, paybacks = 0
    var total: Int { leave + mc + timeOff + claims + paybacks }

    init(leave: Int = 0, mc: Int = 0, timeOff: Int = 0, claims: Int = 0, paybacks: Int = 0) {
        self.leave = leave; self.mc = mc; self.timeOff = timeOff; self.claims = claims; self.paybacks = paybacks
    }

    init(approvals: ApprovalsResponse, timeOff: [TimeOffRequest]) {
        let mc = approvals.leaves.filter { LeaveRules.medicalCodes.contains($0.leaveCode.uppercased()) }.count
        self.init(leave: approvals.leaves.count - mc, mc: mc,
                  timeOff: timeOff.filter { $0.status.uppercased() == "PENDING" }.count,
                  claims: approvals.claims.count, paybacks: approvals.paybacks.count)
    }
}

struct PendingClaim: Codable, Identifiable {
    let id: String
    let employee: String
    let category: String?
    let description: String
    let amount: Double
    let expenseDate: String?
    let receiptUrl: String?
    let createdAt: String?
}

// MARK: - Employees  (/api/mobile/employees)
struct EmployeesResponse: Codable {
    let isAdmin: Bool
    let employees: [Employee]
}

struct Employee: Codable, Identifiable {
    let id: String
    let employeeId: String
    let name: String
    let position: String?
    let department: String?
    let avatarUrl: String?
    let email: String?
    let phone: String?
    let employmentType: String?
    let startDate: String?
    /// Approvers only: true for an intern. nil for everyone else and on an older server.
    var intern: Bool? = nil
}

extension Employee {
    /// "Full time" / "Part time" / "Contract" / "Intern" (approvers only; nil when not sent).
    var employmentLabel: String? {
        switch employmentType?.uppercased() {
        case "FULL_TIME": return "Full time"
        case "PART_TIME": return "Part time"
        case "CONTRACT": return "Contract"
        case "INTERN": return "Intern"
        default: return nil
        }
    }
}

/// The Team tab's Staff / Interns lists (approvers). Works on the server's `intern` flag.
enum EmployeeGroup: String, CaseIterable, Identifiable {
    case staff, interns
    var id: String { rawValue }
    var title: String { self == .staff ? "Staff" : "Interns" }

    /// Two lists are offered only when the server flagged at least one person (approvers, new server).
    static func isAvailable(_ list: [Employee]) -> Bool { list.contains { $0.intern != nil } }

    /// A person without the flag counts as staff.
    func filter(_ list: [Employee]) -> [Employee] {
        list.filter { ($0.intern ?? false) == (self == .interns) }
    }
}

// MARK: - Expenses  (/api/mobile/expenses)
struct ExpensesResponse: Codable {
    let approvedTotal: Double
    let categories: [ExpenseCategory]
    let claims: [ExpenseClaim]
}

struct ExpenseCategory: Codable, Identifiable {
    let id: String
    let code: String
    let name: String
}

struct ExpenseClaim: Codable, Identifiable {
    let id: String
    let description: String
    let amount: Double
    let currency: String
    let category: String?
    let expenseDate: String?
    let status: String
    let receiptUrl: String?
    let approver: String?
    let approvedAt: String?
    let rejectionReason: String?
    let createdAt: String?
}

// MARK: - Payslips  (/api/mobile/payslips)
struct PayslipsResponse: Codable {
    let payslips: [Payslip]
}

struct Payslip: Codable, Identifiable {
    let id: String
    let payPeriodStart: String?
    let payPeriodEnd: String?
    let paymentDate: String?
    let basicSalary: Double
    let allowances: Double
    let overtime: Double
    let bonus: Double
    let grossSalary: Double
    let cpfEmployee: Double
    let totalDeductions: Double
    let netSalary: Double
    let status: String
    let pdfPath: String
}

// MARK: - Calendar  (/api/mobile/calendar)
struct CalendarResponse: Codable {
    let events: [CalendarEvent]
}

/// Company-wide approved leave for the team calendar (`/api/mobile/team-calendar`).
/// `leaveType` is nil when the viewer may not see a colleague's leave type — the
/// server masks it rather than trusting the client to hide it.
struct TeamCalendarResponse: Codable {
    let year: Int
    let canSeeTypes: Bool
    let entries: [TeamLeaveEntry]
    let holidays: [TeamHoliday]
    /// Approvers only: every active staff member and intern, with or without leave, for the
    /// calendar's person filter. nil for everyone else; absent on an older server.
    var people: [TeamCalendarPerson]? = nil
    /// Build 34 (all optional, absent on an older server):
    /// approved time off and Off Days — approvers: everyone's; others: their own.
    var timeOff: [TeamTimeOffEntry]? = nil
    /// Approvers only, else nil.
    var birthdays: [TeamBirthday]? = nil
    /// The viewer's own workdays (ISO 1 = Mon … 7 = Sun), or nil.
    var ownWorkdays: [Int]? = nil
    /// Colour + emoji legend (`CalendarLegendTable` falls back to the built-in table).
    var categories: [CalendarCategoryInfo]? = nil

    enum CodingKeys: String, CodingKey {
        case year, canSeeTypes, entries, holidays, people, timeOff, birthdays, ownWorkdays, categories
    }
}

extension TeamCalendarResponse {
    // In an extension so the memberwise init stays. The new fields are read with `try?`, so
    // one this build cannot read is left out instead of failing the whole calendar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        year = try c.decode(Int.self, forKey: .year)
        canSeeTypes = try c.decode(Bool.self, forKey: .canSeeTypes)
        entries = try c.decode([TeamLeaveEntry].self, forKey: .entries)
        holidays = try c.decode([TeamHoliday].self, forKey: .holidays)
        people = try c.decodeIfPresent([TeamCalendarPerson].self, forKey: .people)
        timeOff = (try? c.decodeIfPresent([TeamTimeOffEntry].self, forKey: .timeOff)) ?? nil
        birthdays = (try? c.decodeIfPresent([TeamBirthday].self, forKey: .birthdays)) ?? nil
        ownWorkdays = (try? c.decodeIfPresent([Int].self, forKey: .ownWorkdays)) ?? nil
        categories = (try? c.decodeIfPresent([CalendarCategoryInfo].self, forKey: .categories)) ?? nil
    }
}

struct TeamCalendarPerson: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let intern: Bool
    /// ISO weekdays (1 = Mon … 7 = Sun) for shading their off days; absent on an older server.
    var workdays: [Int]? = nil
}

struct TeamLeaveEntry: Codable, Identifiable {
    let id: String
    let employeeId: String
    let employeeName: String
    let department: String?
    let startDate: String?
    let endDate: String?
    let days: Double
    let halfDay: Bool
    let leaveType: String?
    let isSelf: Bool
    /// Approvers only: whose leave it is ("staff" | "intern"). Absent for everyone else and on
    /// older servers. Groups the person filter when the server sends no roster.
    var group: String? = nil
    /// ANNUAL_LEAVE | MEDICAL_LEAVE | NO_PAY_LEAVE | OTHER_LEAVE, or nil when the type is hidden
    /// from the viewer (build 34). See `resolvedCategory`.
    var category: String? = nil
}

/// The calendar's "Leave & time off for" person filter (approvers): Everyone or one person.
/// The list is the server's roster of active people (`people`), grouped Staff then Interns,
/// each with their number of leave and time-off entries (as the web). On an older server (no
/// roster) it is built from the leave and time-off entries instead; a viewer who is not an
/// approver gets no filter.
struct TeamCalendarPeople: Equatable {
    struct Option: Identifiable, Equatable {
        let id: String
        let name: String
        let count: Int
        /// "ANG SEE SIANG (3)"; no count for a person without leave.
        var label: String { count > 0 ? "\(name) (\(count))" : name }
    }
    struct Group: Identifiable, Equatable {
        let title: String
        let options: [Option]
        var id: String { title }
    }

    let groups: [Group]
    var all: [Option] { groups.flatMap(\.options) }
    var isAvailable: Bool { !all.isEmpty }
    func option(_ id: String?) -> Option? { id.flatMap { id in all.first { $0.id == id } } }

    init(_ data: TeamCalendarResponse) {
        var counts: [String: Int] = [:]
        let timeOff = data.timeOff ?? []
        for e in data.entries { counts[e.employeeId, default: 0] += 1 }
        for t in timeOff { counts[t.employeeId, default: 0] += 1 }

        let roster: [TeamCalendarPerson]
        if let people = data.people {
            roster = people
        } else if data.canSeeTypes || data.entries.contains(where: { $0.group != nil }) || timeOff.contains(where: { $0.group != nil }) {
            // Older server, approver: only the people who have leave or time off are known.
            var seen = Set<String>()
            roster = data.entries.compactMap { e in
                seen.insert(e.employeeId).inserted
                    ? TeamCalendarPerson(id: e.employeeId, name: e.employeeName, intern: e.group == "intern") : nil
            } + timeOff.compactMap { t in
                seen.insert(t.employeeId).inserted
                    ? TeamCalendarPerson(id: t.employeeId, name: t.employeeName, intern: t.group == "intern") : nil
            }
        } else {
            roster = []
        }
        func section(_ title: String, intern: Bool) -> Group? {
            let rows = roster.filter { $0.intern == intern }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { Option(id: $0.id, name: $0.name, count: counts[$0.id] ?? 0) }
            return rows.isEmpty ? nil : Group(title: title, options: rows)
        }
        groups = [section("Staff", intern: false), section("Interns", intern: true)].compactMap { $0 }
    }

    /// Leave of one person, or everything when nobody (or someone not in the list) is picked.
    func filter(_ entries: [TeamLeaveEntry], personId: String?) -> [TeamLeaveEntry] {
        guard let p = option(personId) else { return entries }
        return entries.filter { $0.employeeId == p.id }
    }
}

struct TeamHoliday: Codable, Identifiable {
    let id: String
    let title: String
    let startDate: String?
    let endDate: String?
}

struct CalendarEvent: Codable, Identifiable {
    let id: String
    let title: String
    let startDate: String?
    let endDate: String?
    let allDay: Bool
    let type: String
    let color: String?
    let description: String?
}

// MARK: - Profile  (/api/mobile/profile)
struct ProfileResponse: Codable {
    let employee: EmployeeProfile?
}

struct EmployeeProfile: Codable {
    let id: String
    let employeeId: String
    let name: String
    let email: String
    let phone: String?
    let position: String?
    let department: String?
    let employmentType: String
    let nationality: String
    let gender: String
    let dateOfBirth: String?
    let address: String?
    let startDate: String?
    let endDate: String?
    let status: String
    let avatarUrl: String?
    let monthlyLeaveRate: Double?
    let roles: [String]
    let role: String
    /// Work Schedule card (build 34; absent on an older server): ISO weekdays 1 = Mon … 7 = Sun,
    /// their day names, the off days and the office hours ("9am to 6pm").
    var workdays: [Int]? = nil
    var workingDays: [String]? = nil
    var offDays: [String]? = nil
    var officeHours: String? = nil

    /// The rows of My Profile → Work Schedule (the web WorkScheduleCard), or nil on a server that
    /// sends no schedule. Day names come from the server, else from `workdays`.
    var workSchedule: [(label: String, value: String, icon: String)]? {
        guard workdays != nil || workingDays != nil || offDays != nil || officeHours != nil else { return nil }
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let days = workdays.flatMap { $0.isEmpty ? nil : $0 } ?? [1, 2, 3, 4, 5]
        let working = workingDays ?? names.enumerated().filter { days.contains($0.offset + 1) }.map(\.element)
        let off = offDays ?? names.enumerated().filter { !days.contains($0.offset + 1) }.map(\.element)
        func text(_ s: String?) -> String {
            guard let s, !s.isEmpty else { return "—" }
            return s
        }
        return [
            ("Title", text(position), "briefcase"),
            ("Department", text(department), "building.2"),
            ("Working hours", text(officeHours ?? "9am to 6pm"), "clock"),
            ("Working days", working.isEmpty ? "None" : working.joined(separator: ", "), "calendar.badge.checkmark"),
            ("Off days", off.isEmpty ? "None" : off.joined(separator: ", "), "calendar.badge.minus"),
        ]
    }
}

// MARK: - Public holidays  (/api/public-holidays?year= — public, no auth)
struct PublicHolidaysResponse: Codable {
    let holidays: [PublicHoliday]
}

struct PublicHoliday: Codable, Identifiable {
    var id: String { date }
    /// Plain `yyyy-MM-dd` (NOT ISO8601) — parse with a dedicated formatter.
    let date: String
    let name: String
}

// MARK: - Notifications  (/api/notifications — returns a raw array)
struct AppNotification: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let type: String
    let read: Bool
    let link: String?
    let createdAt: String?
    /// Approvers: the request a request notice is about (web 23 Nov 2026), so it can be approved or
    /// rejected on the notice itself. Use `requestAction`, which also reads older servers' links.
    var action: NoticeAction? = nil

    /// The request this notice can act on: the server's `action`, else derived from the type and
    /// the `?request=<id>` in the link (a server from before 23 Nov 2026). Nil for other notices.
    var requestAction: NoticeAction? {
        if let action, action.decision != nil { return action }
        guard let kind = NoticeAction.kindByType[type],
              let id = URLComponents(string: link ?? "")?.queryItems?.first(where: { $0.name == "request" })?.value,
              !id.isEmpty else { return nil }
        return NoticeAction(kind: kind, requestId: id)
    }

    /// Only these types are relevant to a staff member's mobile view.
    static let staffTypes: Set<String> = [
        "LEAVE_APPROVED", "LEAVE_REJECTED", "OT_APPROVED", "OT_REJECTED",
        "WOODS_SQUARE_APPROVED", "WOODS_SQUARE_DECLINED", "INFO",
    ]
    var isStaffRelevant: Bool { AppNotification.staffTypes.contains(type) }

    /// The server already scopes `/api/notifications` to the signed-in user, so every row is
    /// theirs: decisions, missed clock-in/out and timesheet reminders, and (for admins) new
    /// leave / MC / time-off / expense requests awaiting approval. All of them are shown.
    var isShownInApp: Bool { true }
}

/// `kind`: leave | timeOff | expense | payback | correction (web `RequestActionKind`).
struct NoticeAction: Codable, Equatable {
    let kind: String
    let requestId: String

    static let kindByType: [String: String] = [
        "LEAVE_SUBMITTED": "leave", "TIME_OFF_SUBMITTED": "timeOff", "EXPENSE_SUBMITTED": "expense",
        "PAYBACK_SUBMITTED": "payback", "ATTENDANCE_CORRECTION_SUBMITTED": "correction",
    ]

    enum Decision: Equatable {
        case request(HRMSAPI.ApprovalKind)
        case correction
    }

    /// Which API decides it; nil for a kind this build does not know.
    var decision: Decision? {
        switch kind {
        case "leave": return .request(.leave)
        case "timeOff": return .request(.timeOff)
        case "expense": return .request(.claim)
        case "payback": return .request(.payback)
        case "correction": return .correction
        default: return nil
        }
    }
}

// MARK: - Attendance clock in/out  (/api/mobile/attendance)
struct AttendanceResponse: Codable {
    let today: AttendancePunch?
    let recent: [AttendancePunch]
}

/// One punch record per day. `date` is present in `recent` items only.
struct AttendancePunch: Codable, Identifiable {
    let id: String
    let date: String?
    let clockIn: String?
    let clockOut: String?

    /// Worked hours for a completed punch (nil while still clocked in).
    var hours: Double? {
        guard let i = Fmt.dateObj(clockIn), let o = Fmt.dateObj(clockOut) else { return nil }
        return max(0, o.timeIntervalSince(i) / 3600)
    }
}

// MARK: - Attendance history  (/api/mobile/attendance/history?month=YYYY-MM[&employeeId=])
/// One employee's punches for a month, newest first, plus the month's totals.
struct AttendanceHistory: Codable {
    let month: String
    let employee: AttendanceEmployee?
    let days: [AttendanceDay]
    let totalHours: Double
    let daysWorked: Int
}

struct AttendanceEmployee: Codable {
    let id: String
    let name: String
    let employeeCode: String
}

/// A day's punch. `date` is a plain `yyyy-MM-dd`; `hours` is nil until clocked out.
struct AttendanceDay: Codable, Identifiable {
    let id: String
    let date: String
    let clockIn: String?
    let clockOut: String?
    let hours: Double?
}

// MARK: - One person's records (approvers, Team drill-down)  (/api/mobile/employees/{id}/records)
struct EmployeeRecords: Codable {
    let employee: RecordsEmployee
    let attendance: RecordsAttendance
    let leave: [LeaveRequest]

    /// Medical leave (MC / sick leave) — shown apart from other leave.
    var medical: [LeaveRequest] { leave.filter { Self.medicalCodes.contains($0.leaveCode.uppercased()) } }
    var otherLeave: [LeaveRequest] { leave.filter { !Self.medicalCodes.contains($0.leaveCode.uppercased()) } }
    static let medicalCodes: Set<String> = ["MC", "SL"]
}

struct RecordsEmployee: Codable {
    let id: String
    let employeeCode: String
    let name: String
    let position: String?
    let department: String?
    let employmentType: String?
}

/// Every punch on record, newest first, with all-time totals.
struct RecordsAttendance: Codable {
    let days: [AttendanceDay]
    let totalHours: Double
    let daysWorked: Int
}

// MARK: - Intern attendance summary (admin)  (/api/mobile/attendance/summary?month=YYYY-MM)
struct AttendanceSummary: Codable {
    let month: String
    let employees: [AttendanceSummaryRow]
    let totalHours: Double
}

struct AttendanceSummaryRow: Codable, Identifiable {
    let id: String
    let name: String
    let employeeCode: String
    let isIntern: Bool
    let daysWorked: Int
    let totalHours: Double
    let lastPunchDate: String?
    let clockedInNow: Bool
}

// MARK: - Time off (hourly, for interns)  (/api/time-off — returns a raw array)
struct TimeOffRequest: Codable, Identifiable {
    let id: String
    /// ISO date of the time off (formatted at the view layer via `Fmt`).
    let date: String
    /// "HH:mm" 24-hour strings, converted to 12-hour at the view layer.
    let startTime: String
    let endTime: String
    let hours: Double
    /// EXAMS | EMERGENCY | UNPAID_LEAVE | OTHERS (an Off Day arrives as OTHERS + `offDay`)
    let reason: String
    let reasonDetail: String?
    /// Full-day intern Off Day (server ≥ 13 Nov 2026 sends `offDay: true`; older rows: false).
    var offDay: Bool = false
    /// PENDING | APPROVED | REJECTED | CANCELLED
    let status: String
    let approvalComment: String?
    let rejectionReason: String?
    let createdAt: String?
    /// The requester — present on the admin list (`GET /api/time-off`, nested `employee.name`).
    var employeeName: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, date, startTime, endTime, hours, reason, reasonDetail, status,
             approvalComment, rejectionReason, createdAt, employee, offDay
    }
    private struct EmployeeRef: Codable { let name: String? }
    // `hours` arrives as a decimal string (e.g. "2.50") — decode leniently.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        startTime = (try? c.decode(String.self, forKey: .startTime)) ?? ""
        endTime = (try? c.decode(String.self, forKey: .endTime)) ?? ""
        hours = TimeOffRequest.flexNumber(c, .hours)
        reason = (try? c.decode(String.self, forKey: .reason)) ?? "OTHERS"
        reasonDetail = try? c.decodeIfPresent(String.self, forKey: .reasonDetail)
        offDay = ((try? c.decodeIfPresent(Bool.self, forKey: .offDay)) ?? false) || reason.uppercased() == "OFF_DAY"
        status = (try? c.decode(String.self, forKey: .status)) ?? "PENDING"
        approvalComment = try? c.decodeIfPresent(String.self, forKey: .approvalComment)
        rejectionReason = try? c.decodeIfPresent(String.self, forKey: .rejectionReason)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        employeeName = (try? c.decodeIfPresent(EmployeeRef.self, forKey: .employee))?.name
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(date, forKey: .date)
        try c.encode(startTime, forKey: .startTime); try c.encode(endTime, forKey: .endTime)
        try c.encode(hours, forKey: .hours); try c.encode(reason, forKey: .reason)
        try c.encodeIfPresent(reasonDetail, forKey: .reasonDetail); try c.encode(status, forKey: .status)
        try c.encodeIfPresent(approvalComment, forKey: .approvalComment)
        try c.encodeIfPresent(rejectionReason, forKey: .rejectionReason)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(EmployeeRef(name: employeeName), forKey: .employee)
        try c.encode(offDay, forKey: .offDay)
    }
    private static func flexNumber(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
        return 0
    }

    // Memberwise init (the custom `init(from:)` above suppresses the synthesized one);
    // used to build the `-uiPreview` sample data.
    init(id: String, date: String, startTime: String, endTime: String, hours: Double,
         reason: String, reasonDetail: String?, status: String,
         approvalComment: String?, rejectionReason: String?, createdAt: String?,
         employeeName: String? = nil, offDay: Bool = false) {
        self.employeeName = employeeName
        self.offDay = offDay
        self.id = id; self.date = date; self.startTime = startTime; self.endTime = endTime
        self.hours = hours; self.reason = reason; self.reasonDetail = reasonDetail
        self.status = status; self.approvalComment = approvalComment
        self.rejectionReason = rejectionReason; self.createdAt = createdAt
    }

    /// Display label for the reason enum.
    var reasonLabel: String {
        if offDay { return "Off Day" }
        switch reason.uppercased() {
        case "EXAMS": return "Exams"
        case "EMERGENCY": return "Emergency"
        case "UNPAID_LEAVE": return "Unpaid leave"
        default: return "Others"
        }
    }

    /// "Exams — detail" (the full text shown in the record sheet).
    var reasonText: String {
        // The server's Off Day detail already reads "Off Day (full day)[ — note]".
        if offDay { return (reasonDetail?.isEmpty == false ? reasonDetail! : "Off Day (full day)") }
        if let d = reasonDetail, !d.isEmpty { return "\(reasonLabel) — \(d)" }
        return reasonLabel
    }

    /// "Full day" for an Off Day, else "2:00 PM – 4:30 PM".
    var timeText: String {
        offDay ? "Full day" : "\(TimeOffView.time12(startTime)) – \(TimeOffView.time12(endTime))"
    }
}

/// `GET /api/mobile/time-off` → `{ requests: [...] }` (the signed-in employee's own).
struct TimeOffEnvelope: Decodable { let requests: [TimeOffRequest] }

// MARK: - Missing-punch corrections (admin)  (GET /api/attendance/corrections?scope=all&status=PENDING)
struct AttendanceCorrection: Codable, Identifiable {
    let id: String
    let employeeId: String
    let employeeName: String
    let employeeCode: String
    /// `yyyy-MM-dd`
    let date: String
    /// CLOCK_IN | CLOCK_OUT | BOTH
    let kind: String
    let requestedClockIn: String?
    let requestedClockOut: String?
    let currentClockIn: String?
    let currentClockOut: String?
    let reason: String
    let status: String
    let rejectionReason: String?
    let createdAt: String?

    var kindLabel: String {
        switch kind.uppercased() {
        case "CLOCK_IN": return "Missing clock-in"
        case "CLOCK_OUT": return "Missing clock-out"
        default: return "Missing clock-in & out"
        }
    }
}

// MARK: - Off In Lieu entries (admin)  (GET /api/timesheet/admin — last 30 days, weekend / PH work)
struct OffInLieuEntry: Codable, Identifiable {
    let id: String
    let employeeId: String
    let employeeCode: String?
    let employeeName: String
    let date: String
    let dayName: String
    let isPublicHoliday: Bool
    let hours: Double
    let otCredited: Double
    let status: String
    let adminComment: String?
}

// MARK: - Timesheet  (existing /api/timesheet)
struct TimesheetResponse: Codable {
    let weekStart: String
    let isLocked: Bool
    let days: [TimesheetDay]
}

struct TimesheetDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let dayName: String
    let isWeekend: Bool
    let isPublicHoliday: Bool
    let phName: String?
    let isNonWorkDay: Bool
    let hours: Double
    let otCredited: Double
    let status: String?
    let adminComment: String?
    let isSubmittable: Bool

    enum CodingKeys: String, CodingKey {
        case date, dayName, isWeekend, isPublicHoliday, phName, isNonWorkDay, hours, otCredited, status, adminComment, isSubmittable
    }
    // `hours` / `otCredited` arrive as decimal strings from the existing endpoint.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        dayName = try c.decode(String.self, forKey: .dayName)
        isWeekend = (try? c.decode(Bool.self, forKey: .isWeekend)) ?? false
        isPublicHoliday = (try? c.decode(Bool.self, forKey: .isPublicHoliday)) ?? false
        phName = try? c.decodeIfPresent(String.self, forKey: .phName)
        isNonWorkDay = (try? c.decode(Bool.self, forKey: .isNonWorkDay)) ?? false
        hours = TimesheetDay.flexNumber(c, .hours)
        otCredited = TimesheetDay.flexNumber(c, .otCredited)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        adminComment = try? c.decodeIfPresent(String.self, forKey: .adminComment)
        isSubmittable = (try? c.decode(Bool.self, forKey: .isSubmittable)) ?? false
    }
    private static func flexNumber(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
        return 0
    }

    // Memberwise init (the custom `init(from:)` above suppresses the synthesized one);
    // used to build the `-uiPreview` sample timesheet.
    init(date: String, dayName: String, isWeekend: Bool, isPublicHoliday: Bool,
         phName: String?, isNonWorkDay: Bool, hours: Double, otCredited: Double,
         status: String?, adminComment: String?, isSubmittable: Bool) {
        self.date = date; self.dayName = dayName; self.isWeekend = isWeekend
        self.isPublicHoliday = isPublicHoliday; self.phName = phName
        self.isNonWorkDay = isNonWorkDay; self.hours = hours; self.otCredited = otCredited
        self.status = status; self.adminComment = adminComment; self.isSubmittable = isSubmittable
    }
}

/// One editable day sent back in `POST /api/timesheet`.
struct TimesheetEntry: Codable {
    let date: String
    let hours: Double
}

// MARK: - Leave & MC summary (admin)  (/api/mobile/leave-summary?month=yyyy-MM)
// Decoded defensively — optional fields default so one odd row can't fail the screen.
struct LeaveSummary: Codable {
    let month: String
    let totals: LeaveSummaryTotals
    let employees: [LeaveSummaryEmployee]
}

struct LeaveSummaryTotals: Codable {
    let headcount: Headcount
    let byLeaveType: [LeaveTypeTotal]
    let mc: McTotal
    let timeOff: HoursPair

    struct Headcount: Codable { let staff: Int; let interns: Int; let total: Int }
    struct McTotal: Codable { let approvedDays: Double; let pendingDays: Double; let employeesOnMc: Int }
}

struct LeaveTypeTotal: Codable, Identifiable {
    let code: String
    let name: String
    let approvedDays: Double
    let pendingDays: Double
    let employeesOnLeave: Int
    var id: String { code }
}

struct HoursPair: Codable { let approvedHours: Double; let pendingHours: Double }

struct DaysPair: Codable { let approved: Double; let pending: Double }

struct LeaveSummaryEmployee: Codable, Identifiable {
    let employeeId: String
    let name: String
    /// STAFF | INTERN
    let category: String
    let position: String?
    let department: String?
    let mcDays: Double
    /// Leave type code → days in the month.
    let leaveTaken: [String: DaysPair]
    let requests: [LeaveSummaryRequest]
    let timeOff: LeaveSummaryTimeOff?
    let balances: [LeaveSummaryBalance]
    var id: String { employeeId }

    var isIntern: Bool { category.uppercased() == "INTERN" }
    func approved(_ code: String) -> Double { leaveTaken[code]?.approved ?? 0 }
    /// Approved days of every type other than AL and MC.
    var otherApproved: Double { leaveTaken.filter { $0.key != "AL" && $0.key != "MC" }.values.reduce(0) { $0 + $1.approved } }
    var pendingDays: Double { leaveTaken.values.reduce(0) { $0 + $1.pending } }
    func available(_ code: String) -> Double? { balances.first { $0.code == code }?.available }
}

struct LeaveSummaryRequest: Codable, Identifiable {
    let leaveType: String
    let leaveTypeName: String
    let status: String
    let startDate: String
    let endDate: String
    let totalDays: Double
    let daysInMonth: Double
    let halfDayPosition: String?
    let hasDocument: Bool
    var id: String { "\(leaveType)|\(startDate)|\(endDate)|\(status)" }
}

struct LeaveSummaryTimeOff: Codable {
    let approvedHours: Double
    let pendingHours: Double
    let requests: [Entry]

    struct Entry: Codable, Identifiable {
        let date: String
        let startTime: String
        let endTime: String
        let hours: Double
        let reason: String
        let status: String
        /// Full-day intern Off Day (absent on older servers → false).
        var offDay: Bool? = nil
        var isOffDay: Bool { offDay ?? false }
        var id: String { "\(date)|\(startTime)" }
    }
}

struct LeaveSummaryBalance: Codable, Identifiable {
    let code: String
    let name: String
    let entitlement: Double
    let usedYtd: Double
    let pending: Double
    let available: Double
    var id: String { code }
}
