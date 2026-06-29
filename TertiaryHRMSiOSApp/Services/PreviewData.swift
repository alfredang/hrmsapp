import Foundation

/// Realistic sample data used ONLY for App Store screenshot capture and UI checks,
/// surfaced when the app is launched with `-uiPreview`. Never reachable in a normal
/// install — `HRMSAPI` only returns these when that launch argument is present, and
/// `AuthViewModel.bootstrap()` only seeds the signed-in shell under the same flag.
/// Dates are anchored around mid-2026 so the modules look freshly in use.
enum PreviewData {

    // MARK: Dashboard
    static let summary = DashboardSummary(
        name: "Alfred Ang", role: "Administrator", isAdmin: true,
        alAvailable: 12.5, mcAvailable: 14, otRemaining: 8,
        expenseYtd: 1860.50, pendingLeaves: 3, pendingClaims: 2)

    // MARK: Leave
    static let leave = LeaveResponse(
        balances: [
            LeaveBalance(code: "AL", name: "Annual Leave", paid: true,
                         entitlement: 16, carriedOver: 2, used: 5.5, pending: 1,
                         earned: 16, autoDeducted: 0, proRated: nil, available: 12.5),
            LeaveBalance(code: "MC", name: "Medical Leave", paid: true,
                         entitlement: 14, carriedOver: 0, used: 0, pending: 0,
                         earned: 14, autoDeducted: 0, proRated: nil, available: 14),
            LeaveBalance(code: "CL", name: "Childcare Leave", paid: true,
                         entitlement: 6, carriedOver: 0, used: 2, pending: 0,
                         earned: 6, autoDeducted: 0, proRated: nil, available: 4),
            LeaveBalance(code: "OT", name: "Off-in-lieu (OT)", paid: true,
                         entitlement: 12, carriedOver: 0, used: 4, pending: 0,
                         earned: 12, autoDeducted: 0, proRated: nil, available: 8),
        ],
        types: [
            LeaveType(id: "lt-al", code: "AL", name: "Annual Leave", paid: true, defaultDays: 16),
            LeaveType(id: "lt-mc", code: "MC", name: "Medical Leave", paid: true, defaultDays: 14),
            LeaveType(id: "lt-cl", code: "CL", name: "Childcare Leave", paid: true, defaultDays: 6),
            LeaveType(id: "lt-ul", code: "UL", name: "Unpaid Leave", paid: false, defaultDays: 0),
        ],
        requests: [
            LeaveRequest(id: "lr-1", leaveType: "Annual Leave", leaveCode: "AL",
                         startDate: "2026-06-22T09:00:00Z", endDate: "2026-06-23T09:00:00Z", days: 2, dayType: "FULL",
                         status: "PENDING", reason: "Family trip", approver: nil,
                         approvedAt: nil, rejectionReason: nil, createdAt: "2026-06-12T09:00:00Z"),
            LeaveRequest(id: "lr-2", leaveType: "Annual Leave", leaveCode: "AL",
                         startDate: "2026-05-19T09:00:00Z", endDate: "2026-05-20T09:00:00Z", days: 2, dayType: "FULL",
                         status: "APPROVED", reason: "Personal", approver: "Jasmine Lee",
                         approvedAt: "2026-05-10T09:00:00Z", rejectionReason: nil, createdAt: "2026-05-08T09:00:00Z"),
            LeaveRequest(id: "lr-3", leaveType: "Childcare Leave", leaveCode: "CL",
                         startDate: "2026-04-03T09:00:00Z", endDate: "2026-04-03T09:00:00Z", days: 1, dayType: "FULL",
                         status: "APPROVED", reason: "Child's school event", approver: "Jasmine Lee",
                         approvedAt: "2026-03-28T09:00:00Z", rejectionReason: nil, createdAt: "2026-03-27T09:00:00Z"),
            LeaveRequest(id: "lr-4", leaveType: "Medical Leave", leaveCode: "MC",
                         startDate: "2026-02-11T09:00:00Z", endDate: "2026-02-11T09:00:00Z", days: 1, dayType: "FULL",
                         status: "APPROVED", reason: "Medical appointment", approver: "Jasmine Lee",
                         approvedAt: "2026-02-12T09:00:00Z", rejectionReason: nil, createdAt: "2026-02-11T09:00:00Z"),
        ])

    // MARK: Team
    static let employees = EmployeesResponse(isAdmin: true, employees: [
        Employee(id: "e1", employeeId: "E0001", name: "Alfred Ang", position: "Managing Director",
                 department: "Management", avatarUrl: nil, email: "alfred.ang@tertiaryinfotech.com",
                 phone: "+65 9123 4567", employmentType: "Full-time", startDate: "2015-01-05T09:00:00Z"),
        Employee(id: "e2", employeeId: "E0014", name: "Jasmine Lee", position: "HR Manager",
                 department: "Human Resources", avatarUrl: nil, email: "jasmine.lee@tertiaryinfotech.com",
                 phone: "+65 9234 5678", employmentType: "Full-time", startDate: "2018-03-12T09:00:00Z"),
        Employee(id: "e3", employeeId: "E0027", name: "Daniel Tan", position: "Senior Trainer",
                 department: "Training", avatarUrl: nil, email: "daniel.tan@tertiaryinfotech.com",
                 phone: "+65 9345 6789", employmentType: "Full-time", startDate: "2019-07-01T09:00:00Z"),
        Employee(id: "e4", employeeId: "E0033", name: "Priya Nair", position: "Course Consultant",
                 department: "Sales", avatarUrl: nil, email: "priya.nair@tertiaryinfotech.com",
                 phone: "+65 9456 7890", employmentType: "Full-time", startDate: "2021-09-20T09:00:00Z"),
        Employee(id: "e5", employeeId: "E0041", name: "Marcus Wong", position: "Software Engineer",
                 department: "Technology", avatarUrl: nil, email: "marcus.wong@tertiaryinfotech.com",
                 phone: "+65 9567 8901", employmentType: "Full-time", startDate: "2022-11-02T09:00:00Z"),
        Employee(id: "e6", employeeId: "E0048", name: "Siti Rahman", position: "Finance Executive",
                 department: "Finance", avatarUrl: nil, email: "siti.rahman@tertiaryinfotech.com",
                 phone: "+65 9678 9012", employmentType: "Full-time", startDate: "2023-02-15T09:00:00Z"),
    ])

    // MARK: Expenses
    static let expenses = ExpensesResponse(
        approvedTotal: 1860.50,
        categories: [
            ExpenseCategory(id: "c1", code: "TRV", name: "Travel"),
            ExpenseCategory(id: "c2", code: "MEAL", name: "Meals & Entertainment"),
            ExpenseCategory(id: "c3", code: "OFF", name: "Office Supplies"),
        ],
        claims: [
            ExpenseClaim(id: "x1", description: "Client meeting — Grab", amount: 28.40, currency: "SGD",
                         category: "Travel", expenseDate: "2026-06-09T09:00:00Z", status: "PENDING",
                         receiptUrl: nil, approver: nil, approvedAt: nil, rejectionReason: nil,
                         createdAt: "2026-06-09T09:00:00Z"),
            ExpenseClaim(id: "x2", description: "Team lunch — Q2 review", amount: 184.00, currency: "SGD",
                         category: "Meals & Entertainment", expenseDate: "2026-05-30T09:00:00Z", status: "APPROVED",
                         receiptUrl: nil, approver: "Jasmine Lee", approvedAt: "2026-06-02T09:00:00Z",
                         rejectionReason: nil, createdAt: "2026-05-30T09:00:00Z"),
            ExpenseClaim(id: "x3", description: "Training materials & printing", amount: 96.10, currency: "SGD",
                         category: "Office Supplies", expenseDate: "2026-05-18T09:00:00Z", status: "APPROVED",
                         receiptUrl: nil, approver: "Jasmine Lee", approvedAt: "2026-05-20T09:00:00Z",
                         rejectionReason: nil, createdAt: "2026-05-18T09:00:00Z"),
            ExpenseClaim(id: "x4", description: "Conference registration", amount: 450.00, currency: "SGD",
                         category: "Travel", expenseDate: "2026-04-22T09:00:00Z", status: "APPROVED",
                         receiptUrl: nil, approver: "Jasmine Lee", approvedAt: "2026-04-24T09:00:00Z",
                         rejectionReason: nil, createdAt: "2026-04-22T09:00:00Z"),
        ])

    // MARK: Payslips
    static let payslips = PayslipsResponse(payslips: [
        payslip("p1", "2026-05-01T09:00:00Z", "2026-05-31T09:00:00Z", "2026-05-28T09:00:00Z"),
        payslip("p2", "2026-04-01T09:00:00Z", "2026-04-30T09:00:00Z", "2026-04-28T09:00:00Z"),
        payslip("p3", "2026-03-01T09:00:00Z", "2026-03-31T09:00:00Z", "2026-03-28T09:00:00Z"),
        payslip("p4", "2026-02-01T09:00:00Z", "2026-02-28T09:00:00Z", "2026-02-26T09:00:00Z"),
        payslip("p5", "2026-01-01T09:00:00Z", "2026-01-31T09:00:00Z", "2026-01-29T09:00:00Z"),
    ])

    private static func payslip(_ id: String, _ start: String, _ end: String, _ pay: String) -> Payslip {
        Payslip(id: id, payPeriodStart: start, payPeriodEnd: end, paymentDate: pay,
                basicSalary: 8500, allowances: 600, overtime: 0, bonus: 0,
                grossSalary: 9100, cpfEmployee: 1020, totalDeductions: 1020, netSalary: 8080,
                status: "PAID", pdfPath: "api/payroll/payslip/\(id)/pdf")
    }

    // MARK: Calendar
    static let calendar = CalendarResponse(events: [
        CalendarEvent(id: "ev1", title: "Hari Raya Haji", startDate: "2026-06-06T09:00:00Z", endDate: "2026-06-06T09:00:00Z",
                      allDay: true, type: "HOLIDAY", color: "#E11D48", description: "Public Holiday"),
        CalendarEvent(id: "ev2", title: "Annual Leave — Alfred Ang", startDate: "2026-06-22T09:00:00Z", endDate: "2026-06-23T09:00:00Z",
                      allDay: true, type: "LEAVE", color: "#2563EB", description: "Approved leave"),
        CalendarEvent(id: "ev3", title: "Company Townhall", startDate: "2026-06-27T09:00:00Z", endDate: "2026-06-27T09:00:00Z",
                      allDay: false, type: "EVENT", color: "#0EA5E9", description: "Q2 all-hands, 3:00 PM"),
        CalendarEvent(id: "ev4", title: "National Day", startDate: "2026-08-09T09:00:00Z", endDate: "2026-08-09T09:00:00Z",
                      allDay: true, type: "HOLIDAY", color: "#E11D48", description: "Public Holiday"),
        CalendarEvent(id: "ev5", title: "Team Building Offsite", startDate: "2026-07-18T09:00:00Z", endDate: "2026-07-18T09:00:00Z",
                      allDay: true, type: "EVENT", color: "#0EA5E9", description: "Sentosa"),
    ])

    // MARK: Profile
    static let profile = ProfileResponse(employee: EmployeeProfile(
        id: "e1", employeeId: "E0001", name: "Alfred Ang",
        email: "alfred.ang@tertiaryinfotech.com", phone: "+65 9123 4567",
        position: "Managing Director", department: "Management",
        employmentType: "Full-time", nationality: "Singaporean", gender: "Male",
        dateOfBirth: "1982-04-18T09:00:00Z", address: "1 Tampines Central, Singapore 529536",
        startDate: "2015-01-05T09:00:00Z", endDate: nil, status: "Active", avatarUrl: nil,
        monthlyLeaveRate: 1.33, roles: ["ADMIN", "HR"], role: "ADMIN"))

    // MARK: Timesheet
    static let timesheet: TimesheetResponse = {
        let days = [
            TimesheetDay(date: "2026-06-15T09:00:00Z", dayName: "Mon", isWeekend: false, isPublicHoliday: false,
                         phName: nil, isNonWorkDay: false, hours: 8, otCredited: 0, status: "SUBMITTED",
                         adminComment: nil, isSubmittable: false),
            TimesheetDay(date: "2026-06-16T09:00:00Z", dayName: "Tue", isWeekend: false, isPublicHoliday: false,
                         phName: nil, isNonWorkDay: false, hours: 8.5, otCredited: 0.5, status: "SUBMITTED",
                         adminComment: nil, isSubmittable: false),
            TimesheetDay(date: "2026-06-17T09:00:00Z", dayName: "Wed", isWeekend: false, isPublicHoliday: false,
                         phName: nil, isNonWorkDay: false, hours: 8, otCredited: 0, status: nil,
                         adminComment: nil, isSubmittable: true),
            TimesheetDay(date: "2026-06-18T09:00:00Z", dayName: "Thu", isWeekend: false, isPublicHoliday: false,
                         phName: nil, isNonWorkDay: false, hours: 0, otCredited: 0, status: nil,
                         adminComment: nil, isSubmittable: true),
            TimesheetDay(date: "2026-06-19T09:00:00Z", dayName: "Fri", isWeekend: false, isPublicHoliday: false,
                         phName: nil, isNonWorkDay: false, hours: 0, otCredited: 0, status: nil,
                         adminComment: nil, isSubmittable: true),
            TimesheetDay(date: "2026-06-20T09:00:00Z", dayName: "Sat", isWeekend: true, isPublicHoliday: false,
                         phName: nil, isNonWorkDay: true, hours: 0, otCredited: 0, status: nil,
                         adminComment: nil, isSubmittable: false),
            TimesheetDay(date: "2026-06-21T09:00:00Z", dayName: "Sun", isWeekend: true, isPublicHoliday: false,
                         phName: nil, isNonWorkDay: true, hours: 0, otCredited: 0, status: nil,
                         adminComment: nil, isSubmittable: false),
        ]
        return TimesheetResponse(weekStart: "2026-06-15T09:00:00Z", isLocked: false, days: days)
    }()
}
