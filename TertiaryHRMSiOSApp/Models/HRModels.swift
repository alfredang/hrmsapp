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
