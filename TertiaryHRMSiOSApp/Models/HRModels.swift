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

    /// Only these types are relevant to a staff member's mobile view.
    static let staffTypes: Set<String> = [
        "LEAVE_APPROVED", "LEAVE_REJECTED", "OT_APPROVED", "OT_REJECTED",
        "WOODS_SQUARE_APPROVED", "WOODS_SQUARE_DECLINED", "INFO",
    ]
    var isStaffRelevant: Bool { AppNotification.staffTypes.contains(type) }
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

// MARK: - Time off (hourly, for interns)  (/api/time-off — returns a raw array)
struct TimeOffRequest: Codable, Identifiable {
    let id: String
    /// ISO date of the time off (formatted at the view layer via `Fmt`).
    let date: String
    /// "HH:mm" 24-hour strings, converted to 12-hour at the view layer.
    let startTime: String
    let endTime: String
    let hours: Double
    /// EXAMS | EMERGENCY | OTHERS
    let reason: String
    let reasonDetail: String?
    /// PENDING | APPROVED | REJECTED | CANCELLED
    let status: String
    let approvalComment: String?
    let rejectionReason: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, date, startTime, endTime, hours, reason, reasonDetail, status,
             approvalComment, rejectionReason, createdAt
    }
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
        status = (try? c.decode(String.self, forKey: .status)) ?? "PENDING"
        approvalComment = try? c.decodeIfPresent(String.self, forKey: .approvalComment)
        rejectionReason = try? c.decodeIfPresent(String.self, forKey: .rejectionReason)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
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
         approvalComment: String?, rejectionReason: String?, createdAt: String?) {
        self.id = id; self.date = date; self.startTime = startTime; self.endTime = endTime
        self.hours = hours; self.reason = reason; self.reasonDetail = reasonDetail
        self.status = status; self.approvalComment = approvalComment
        self.rejectionReason = rejectionReason; self.createdAt = createdAt
    }

    /// Display label for the reason enum.
    var reasonLabel: String {
        switch reason.uppercased() {
        case "EXAMS": return "Exams"
        case "EMERGENCY": return "Emergency"
        default: return "Others"
        }
    }
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
