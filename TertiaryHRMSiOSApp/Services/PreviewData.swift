import Foundation

/// Realistic sample data used ONLY for App Store screenshot capture and UI checks,
/// surfaced when the app is launched with `-uiPreview`. Never reachable in a normal
/// install — `HRMSAPI` only returns these when that launch argument is present, and
/// `AuthViewModel.bootstrap()` only seeds the signed-in shell under the same flag.
/// Dates are anchored around mid-2026 so the modules look freshly in use.
enum PreviewData {

    /// Screenshot capture only: `-uiPreview -uiPreviewFlag <name>` (e.g. `team`, `requests`)
    /// or `-uiPreviewQuery <text>` to pre-set a screen's state. Inert without `-uiPreview`.
    static func flag(_ name: String) -> Bool {
        let a = ProcessInfo.processInfo.arguments
        guard a.contains("-uiPreview") else { return false }
        return a.indices.contains { a[$0] == "-uiPreviewFlag" && $0 + 1 < a.count && a[$0 + 1].split(separator: ",").contains(Substring(name)) }
    }
    static var query: String? {
        let a = ProcessInfo.processInfo.arguments
        guard a.contains("-uiPreview"), let i = a.firstIndex(of: "-uiPreviewQuery"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    // MARK: Dashboard
    /// `-uiPreviewIntern` / `-uiPreviewStaff` sign the preview in as an intern / plain staff member.
    static var previewIntern: Bool { ProcessInfo.processInfo.arguments.contains("-uiPreviewIntern") }
    static var previewStaff: Bool { ProcessInfo.processInfo.arguments.contains("-uiPreviewStaff") }
    static var summary: DashboardSummary { DashboardSummary(
        name: previewIntern ? "Jamie Koh" : previewStaff ? "Sarah Lim" : "Alfred Ang",
        role: previewIntern ? "Intern" : previewStaff ? "Staff" : "Administrator",
        isAdmin: !(previewIntern || previewStaff),
        alAvailable: 12.5, mcAvailable: 14, otRemaining: 8,
        expenseYtd: 1860.50, pendingLeaves: 3, pendingClaims: 2,
        canManageTrainers: !(previewIntern || previewStaff),
        leaveSummary: [
            SummaryStat(label: "Paid leave taken", value: "5.5 days"),
            SummaryStat(label: "Annual leave balance", value: "12.5 days"),
            SummaryStat(label: "MC taken", value: "0 days"),
            SummaryStat(label: "No-pay leave taken", value: "2 days", hint: "11 of 14 left"),
        ],
        trainerKpis: previewIntern || previewStaff ? nil
            : TrainerKpis(total: 128, aclp: 74, nonAclp: 54)) }

    /// The accountant preview of an approver: the summary plus the finance tiles.
    static func summary(view: String) -> DashboardSummary {
        var s = summary
        if view == "accountant" {
            s.financeKpis = FinanceKpis(pendingClaims: 2, pendingClaimsAmount: 486.40, incomeMonth: 182_400,
                                        incomeYtd: 2_104_900, expensesMonth: 141_250, expensesYtd: 1_688_300,
                                        monthLabel: "Nov", year: 2026, incomeCountMonth: 172, expenseCountMonth: 107,
                                        statementImports: 33, statementLatestDate: "2026-11-16",
                                        statementLastImportedAt: "2026-11-16T05:21:55.243Z",
                                        reconciliation: FinanceReconciliation(status: "COMPLETED", periodStart: "2026-10-01",
                                                                              periodEnd: "2026-10-31", matched: 268, toReview: 4,
                                                                              createdAt: "2026-11-02T03:00:00.000Z"))
        }
        return s
    }

    // MARK: Approvals
    static let approvals = ApprovalsResponse(
        leaves: [
            PendingLeave(id: "pl1", employee: "Sarah Lim", leaveType: "Annual Leave", leaveCode: "AL",
                         startDate: "2026-07-20T00:00:00.000Z", endDate: "2026-07-22T00:00:00.000Z",
                         days: 3, dayType: "FULL_DAY", reason: "Family trip", documentUrl: nil,
                         createdAt: "2026-07-14T03:20:00.000Z"),
            PendingLeave(id: "pl2", employee: "Daniel Tan", leaveType: "Medical Leave", leaveCode: "MC",
                         startDate: "2026-07-17T00:00:00.000Z", endDate: "2026-07-17T00:00:00.000Z",
                         days: 1, dayType: "FULL_DAY", reason: "Flu", documentUrl: "/api/uploads/mc.jpg",
                         createdAt: "2026-07-16T22:05:00.000Z"),
        ],
        claims: [
            PendingClaim(id: "pc1", employee: "Sarah Lim", category: "Travel",
                         description: "Client visit — taxi", amount: 24.80,
                         expenseDate: "2026-07-13T00:00:00.000Z", receiptUrl: nil,
                         createdAt: "2026-07-13T09:30:00.000Z"),
        ],
        paybacks: [
            PendingPayback(id: "pb31", employee: "Mei Ling Goh", nplDate: "2026-07-10T00:00:00.000Z",
                           workDate: "2026-07-11T00:00:00.000Z", days: 1, note: nil,
                           clocked: "9:02 am – 6:05 pm", createdAt: "2026-07-16T07:53:00.000Z"),
        ])

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
            LeaveBalance(code: "NPL", name: "No Pay Leave", paid: false,
                         entitlement: 0, carriedOver: 0, used: 2, pending: 1,
                         earned: 0, autoDeducted: 0, proRated: 14, available: 11),
        ],
        types: [
            LeaveType(id: "lt-al", code: "AL", name: "Annual Leave", paid: true, defaultDays: 16),
            LeaveType(id: "lt-mc", code: "MC", name: "Medical Leave", paid: true, defaultDays: 14),
            LeaveType(id: "lt-cl", code: "CL", name: "Childcare Leave", paid: true, defaultDays: 6),
            LeaveType(id: "lt-npl", code: "NPL", name: "No Pay Leave", paid: false, defaultDays: 14),
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
                 phone: "+65 9123 4567", employmentType: "FULL_TIME", startDate: "2015-01-05T09:00:00Z", intern: false),
        Employee(id: "e2", employeeId: "E0014", name: "Jasmine Lee", position: "HR Manager",
                 department: "Human Resources", avatarUrl: nil, email: "jasmine.lee@tertiaryinfotech.com",
                 phone: "+65 9234 5678", employmentType: "FULL_TIME", startDate: "2018-03-12T09:00:00Z", intern: false),
        Employee(id: "e3", employeeId: "E0027", name: "Daniel Tan", position: "Senior Trainer",
                 department: "Training", avatarUrl: nil, email: "daniel.tan@tertiaryinfotech.com",
                 phone: "+65 9345 6789", employmentType: "FULL_TIME", startDate: "2019-07-01T09:00:00Z", intern: false),
        Employee(id: "e4", employeeId: "E0033", name: "Priya Nair", position: "Course Consultant",
                 department: "Sales", avatarUrl: nil, email: "priya.nair@tertiaryinfotech.com",
                 phone: "+65 9456 7890", employmentType: "FULL_TIME", startDate: "2021-09-20T09:00:00Z", intern: false),
        Employee(id: "e5", employeeId: "E0041", name: "Marcus Wong", position: "Software Engineer",
                 department: "Technology", avatarUrl: nil, email: "marcus.wong@tertiaryinfotech.com",
                 phone: "+65 9567 8901", employmentType: "FULL_TIME", startDate: "2022-11-02T09:00:00Z", intern: false),
        Employee(id: "e6", employeeId: "E0048", name: "Siti Rahman", position: "Finance Executive",
                 department: "Finance", avatarUrl: nil, email: "siti.rahman@tertiaryinfotech.com",
                 phone: "+65 9678 9012", employmentType: "FULL_TIME", startDate: "2023-02-15T09:00:00Z", intern: false),
        Employee(id: "e7", employeeId: "I0002", name: "Amanda Halim", position: "Intern (NYP)",
                 department: "Software Development", avatarUrl: nil, email: "amanda.halim@tertiaryinfotech.com",
                 phone: "+65 9789 0123", employmentType: "INTERN", startDate: "2026-09-01T09:00:00Z", intern: true),
        Employee(id: "e8", employeeId: "I0011", name: "Rachel Chua", position: "Intern (SP)",
                 department: "Marketing", avatarUrl: nil, email: "rachel.chua@tertiaryinfotech.com",
                 phone: "+65 9890 1234", employmentType: "INTERN", startDate: "2026-09-14T09:00:00Z", intern: true),
        Employee(id: "e9", employeeId: "I0012", name: "Kenneth Wang", position: "Intern (SP)",
                 department: "Software Development", avatarUrl: nil, email: "kenneth.wang@tertiaryinfotech.com",
                 phone: "+65 9901 2345", employmentType: "INTERN", startDate: "2026-10-05T09:00:00Z", intern: true),
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
    static let teamCalendar = TeamCalendarResponse(
        year: 2026,
        canSeeTypes: true,
        entries: [
            TeamLeaveEntry(id: "tl1", employeeId: "E0001", employeeName: "Alfred Ang", department: "Management",
                           startDate: "2026-09-08T00:00:00Z", endDate: "2026-09-09T00:00:00Z",
                           days: 2, halfDay: false, leaveType: "Annual Leave", isSelf: true, group: "staff", category: "ANNUAL_LEAVE"),
            TeamLeaveEntry(id: "tl2", employeeId: "E0002", employeeName: "Femina Jasmin", department: "Engineering",
                           startDate: "2026-09-10T00:00:00Z", endDate: "2026-09-10T00:00:00Z",
                           days: 1, halfDay: false, leaveType: "Annual Leave", isSelf: false, group: "intern", category: "ANNUAL_LEAVE"),
            TeamLeaveEntry(id: "tl3", employeeId: "E0003", employeeName: "Amanda Halim", department: "Operations",
                           startDate: "2026-09-15T00:00:00Z", endDate: "2026-09-16T00:00:00Z",
                           days: 1.5, halfDay: true, leaveType: "Annual Leave", isSelf: false, group: "intern", category: "ANNUAL_LEAVE"),
            TeamLeaveEntry(id: "tl4", employeeId: "E0004", employeeName: "Tan Yong Huat", department: "Training",
                           startDate: "2026-09-10T00:00:00Z", endDate: "2026-09-10T00:00:00Z",
                           days: 1, halfDay: false, leaveType: "Medical Leave", isSelf: false, group: "staff", category: "MEDICAL_LEAVE"),
            TeamLeaveEntry(id: "tl5", employeeId: "E0001", employeeName: "Alfred Ang", department: "Management",
                           startDate: "2026-11-11T00:00:00Z", endDate: "2026-11-12T00:00:00Z",
                           days: 2, halfDay: false, leaveType: "Annual Leave", isSelf: true, group: "staff", category: "ANNUAL_LEAVE"),
            TeamLeaveEntry(id: "tl6", employeeId: "E0002", employeeName: "Femina Jasmin", department: "Engineering",
                           startDate: "2026-11-11T00:00:00Z", endDate: "2026-11-11T00:00:00Z",
                           days: 1, halfDay: false, leaveType: "Medical Leave", isSelf: false, group: "intern", category: "MEDICAL_LEAVE"),
            TeamLeaveEntry(id: "tl7", employeeId: "E0003", employeeName: "Amanda Halim", department: "Operations",
                           startDate: "2026-11-11T00:00:00Z", endDate: "2026-11-11T00:00:00Z",
                           days: 0.5, halfDay: true, leaveType: "Annual Leave", isSelf: false, group: "intern", category: "ANNUAL_LEAVE"),
            TeamLeaveEntry(id: "tl8", employeeId: "E0004", employeeName: "Tan Yong Huat", department: "Training",
                           startDate: "2026-11-18T00:00:00Z", endDate: "2026-11-20T00:00:00Z",
                           days: 3, halfDay: false, leaveType: "Annual Leave", isSelf: false, group: "staff", category: "ANNUAL_LEAVE"),
            TeamLeaveEntry(id: "tl9", employeeId: "E0005", employeeName: "Cheryl Lim", department: "Operations",
                           startDate: "2026-11-09T00:00:00Z", endDate: "2026-11-09T00:00:00Z",
                           days: 1, halfDay: false, leaveType: nil, isSelf: false, group: "staff"),
        ],
        holidays: [
            TeamHoliday(id: "h1", title: "🎉 Public Holiday", startDate: "2026-09-21T00:00:00Z", endDate: "2026-09-21T00:00:00Z"),
            TeamHoliday(id: "h2", title: "🪔 Deepavali", startDate: "2026-11-08T00:00:00Z", endDate: "2026-11-08T00:00:00Z"),
            TeamHoliday(id: "h3", title: "🎄 Christmas Day", startDate: "2026-12-25", endDate: "2026-12-25"),
        ],
        // Active people only: Cheryl Lim (E0005) has left, so her leave shows only under Everyone.
        people: [
            TeamCalendarPerson(id: "E0001", name: "Alfred Ang", intern: false, workdays: [1, 2, 3, 4, 5]),
            TeamCalendarPerson(id: "E0003", name: "Amanda Halim", intern: true, workdays: [1, 2, 3, 4, 5]),
            TeamCalendarPerson(id: "I0005", name: "Evan Pang", intern: true, workdays: [1, 2, 3, 4]),
            TeamCalendarPerson(id: "E0002", name: "Femina Jasmin", intern: true, workdays: [1, 2, 3, 4, 5]),
            TeamCalendarPerson(id: "E0008", name: "Jyoti Chopra", intern: false, workdays: [1, 2, 3, 4, 5]),
            TeamCalendarPerson(id: "E0004", name: "Tan Yong Huat", intern: false, workdays: [1, 2, 3, 4, 5]),
        ],
        // Build 34: approved time off / Off Days, birthdays (approvers), the viewer's workdays.
        timeOff: [
            TeamTimeOffEntry(id: "to1", employeeId: "I0005", employeeName: "Evan Pang", date: "2026-11-11T00:00:00.000Z",
                             startTime: "00:00", endTime: "00:00", hours: 0, offDay: true, isSelf: false, group: "intern"),
            TeamTimeOffEntry(id: "to2", employeeId: "I0005", employeeName: "Evan Pang", date: "2026-11-17T00:00:00.000Z",
                             startTime: "14:00", endTime: "16:00", hours: 2, offDay: false, isSelf: false, group: "intern"),
            TeamTimeOffEntry(id: "to3", employeeId: "E0001", employeeName: "Alfred Ang", date: "2026-11-24T00:00:00.000Z",
                             startTime: "10:00", endTime: "11:30", hours: 1.5, offDay: false, isSelf: true, group: "staff"),
        ],
        birthdays: [
            TeamBirthday(id: "bd-E0008-2026", employeeId: "E0008", name: "Jyoti Chopra", date: "2026-11-26T04:00:00.000Z"),
            TeamBirthday(id: "bd-E0004-2026", employeeId: "E0004", name: "Tan Yong Huat", date: "2026-09-03T04:00:00.000Z"),
        ],
        ownWorkdays: [1, 2, 3, 4, 5],
        categories: CalendarCategory.fallback)

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
        employmentType: "FULL_TIME", nationality: "Singaporean", gender: "Male",
        dateOfBirth: "1982-04-18T09:00:00Z", address: "1 Tampines Central, Singapore 529536",
        startDate: "2015-01-05T09:00:00Z", endDate: nil, status: "Active", avatarUrl: nil,
        monthlyLeaveRate: 1.33, roles: ["ADMIN", "HR"], role: "ADMIN",
        workdays: [1, 2, 3, 4, 5], workingDays: ["Mon", "Tue", "Wed", "Thu", "Fri"], offDays: ["Sat", "Sun"],
        officeHours: "9am to 6pm"))

    // MARK: Public holidays
    static func holidays(_ year: Int) -> [PublicHoliday] {
        [
            PublicHoliday(date: "\(year)-01-01", name: "New Year's Day"),
            PublicHoliday(date: "\(year)-08-09", name: "National Day"),
            PublicHoliday(date: "\(year)-12-25", name: "Christmas Day"),
        ]
    }

    // MARK: Notifications
    static let notifications: [AppNotification] = [
        AppNotification(id: "n0", title: "New No Pay Leave payback",
                        message: "Mei Ling Goh worked Sat, 11 Jul 2026 to pay back 1 day of No Pay Leave on Fri, 10 Jul 2026.",
                        type: "PAYBACK_SUBMITTED", read: false, link: "/leave/payback?request=pb31",
                        createdAt: "2026-07-17T07:53:00.000Z",
                        action: NoticeAction(kind: "payback", requestId: "pb31")),
        AppNotification(id: "n00", title: "New Annual Leave request",
                        message: "Sarah Lim submitted a Annual Leave request for 3 day(s).",
                        type: "LEAVE_SUBMITTED", read: false, link: "/leave?request=pl1",
                        createdAt: "2026-07-17T03:20:00.000Z"),
        AppNotification(id: "n1", title: "Leave approved",
                        message: "Your annual leave (22–23 Jun) was approved by Jasmine Lee.",
                        type: "LEAVE_APPROVED", read: false, link: "/leave",
                        createdAt: "2026-07-17T02:10:00.000Z"),
        AppNotification(id: "n2", title: "Off-in-lieu approved",
                        message: "Your overtime on 14 Jun was approved — 1 day credited.",
                        type: "OT_APPROVED", read: false, link: "/timesheet",
                        createdAt: "2026-07-15T08:00:00.000Z"),
        AppNotification(id: "n3", title: "Leave rejected",
                        message: "Your leave request for 30 Jun was declined.",
                        type: "LEAVE_REJECTED", read: true, link: "/leave",
                        createdAt: "2026-07-12T04:30:00.000Z"),
    ]

    // MARK: Attendance (clock in/out)
    static let attendance = AttendanceResponse(
        today: AttendancePunch(id: "a0", date: "2026-06-17T00:00:00Z",
                               clockIn: "2026-06-17T01:02:00Z", clockOut: nil),
        recent: [
            AttendancePunch(id: "a0", date: "2026-06-17T00:00:00Z",
                            clockIn: "2026-06-17T01:02:00Z", clockOut: nil),
            AttendancePunch(id: "a1", date: "2026-06-16T00:00:00Z",
                            clockIn: "2026-06-16T00:58:00Z", clockOut: "2026-06-16T09:34:00Z"),
            AttendancePunch(id: "a2", date: "2026-06-15T00:00:00Z",
                            clockIn: "2026-06-15T01:05:00Z", clockOut: "2026-06-15T09:02:00Z"),
            AttendancePunch(id: "a3", date: "2026-06-12T00:00:00Z",
                            clockIn: "2026-06-12T00:55:00Z", clockOut: "2026-06-12T05:31:00Z"),
            AttendancePunch(id: "a4", date: "2026-06-11T00:00:00Z",
                            clockIn: "2026-06-11T01:10:00Z", clockOut: "2026-06-11T09:12:00Z"),
        ])

    // MARK: Attendance history + admin summary
    static func employeeRecords(id: String) -> EmployeeRecords {
        let person = employees.employees.first { $0.id == id }
        let thisMonth = attendanceHistory(month: AttendanceMonth.current())
        let lastMonth = attendanceHistory(month: AttendanceMonth.shift(AttendanceMonth.current(), by: -1))
        let days = thisMonth.days + lastMonth.days.map {
            AttendanceDay(id: "p" + $0.id, date: $0.date, clockIn: $0.clockIn,
                          clockOut: $0.clockOut ?? $0.clockIn, hours: $0.hours ?? 0)
        }
        return EmployeeRecords(
            employee: RecordsEmployee(id: id, employeeCode: person?.employeeId ?? "E0000",
                                      name: person?.name ?? "Employee", position: person?.position,
                                      department: person?.department, employmentType: person?.employmentType),
            attendance: RecordsAttendance(days: days, totalHours: thisMonth.totalHours + lastMonth.totalHours,
                                          daysWorked: thisMonth.daysWorked + lastMonth.daysWorked),
            leave: leave.requests,
            intern: person?.intern ?? false,
            mustClockIn: person?.intern ?? false,
            balances: [
                RecordsBalance(code: "AL", name: "Annual Leave", taken: 5, available: 7, allowance: 12),
                RecordsBalance(code: "MC", name: "MC", taken: 2, available: 12, allowance: 14),
                RecordsBalance(code: "NPL", name: "No Pay Leave", taken: 0, available: 14, allowance: 14),
            ],
            paybacks: [
                RecordsPayback(id: "pb1", nplDate: "2026-11-11T00:00:00Z", workDate: "2026-11-22T00:00:00Z",
                               days: 1, note: "Worked the Saturday roadshow", status: "PENDING"),
                RecordsPayback(id: "pb2", nplDate: "2026-10-01T00:00:00Z", workDate: "2026-10-11T00:00:00Z",
                               days: 1, status: "APPROVED", approver: "Alfred Ang"),
            ],
            claims: expenses.claims)
    }

    static func attendanceHistory(month: String) -> AttendanceHistory {
        let days = [
            AttendanceDay(id: "h0", date: "\(month)-17", clockIn: "\(month)-17T01:02:00Z", clockOut: nil, hours: nil),
            AttendanceDay(id: "h1", date: "\(month)-16", clockIn: "\(month)-16T00:58:00Z", clockOut: "\(month)-16T09:34:00Z", hours: 8.6),
            AttendanceDay(id: "h2", date: "\(month)-15", clockIn: "\(month)-15T01:05:00Z", clockOut: "\(month)-15T09:02:00Z", hours: 7.95),
            AttendanceDay(id: "h3", date: "\(month)-12", clockIn: "\(month)-12T00:55:00Z", clockOut: "\(month)-12T05:31:00Z", hours: 4.6),
            AttendanceDay(id: "h4", date: "\(month)-11", clockIn: "\(month)-11T01:10:00Z", clockOut: "\(month)-11T09:12:00Z", hours: 8.03),
        ]
        return AttendanceHistory(month: month,
                                 employee: AttendanceEmployee(id: "e1", name: "Amanda Halim", employeeCode: "I0002"),
                                 days: days, totalHours: 29.18, daysWorked: 5)
    }

    static func attendanceSummary(month: String) -> AttendanceSummary {
        AttendanceSummary(month: month, employees: [
            AttendanceSummaryRow(id: "e1", name: "Amanda Halim", employeeCode: "I0002", isIntern: true,
                                 daysWorked: 5, totalHours: 29.18, lastPunchDate: "\(month)-17", clockedInNow: true),
            AttendanceSummaryRow(id: "e2", name: "Kenneth Wang", employeeCode: "I0012", isIntern: true,
                                 daysWorked: 9, totalHours: 71.5, lastPunchDate: "\(month)-16", clockedInNow: false),
            AttendanceSummaryRow(id: "e3", name: "Rachel Chua", employeeCode: "I0011", isIntern: true,
                                 daysWorked: 0, totalHours: 0, lastPunchDate: nil, clockedInNow: false),
        ], totalHours: 100.68)
    }

    // MARK: Leave & MC summary (admin)
    static func leaveSummary(month: String) -> LeaveSummary {
        let types = [
            LeaveTypeTotal(code: "AL", name: "Annual Leave", approvedDays: 4, pendingDays: 2, employeesOnLeave: 2),
            LeaveTypeTotal(code: "MC", name: "Medical Leave", approvedDays: 4, pendingDays: 0, employeesOnLeave: 3),
            LeaveTypeTotal(code: "CL", name: "Compassionate Leave", approvedDays: 0, pendingDays: 0, employeesOnLeave: 0),
        ]
        func bal(_ al: Double, _ mc: Double) -> [LeaveSummaryBalance] {
            [LeaveSummaryBalance(code: "AL", name: "Annual Leave", entitlement: 7, usedYtd: 7 - al, pending: 0, available: al),
             LeaveSummaryBalance(code: "MC", name: "Medical Leave", entitlement: 14, usedYtd: 14 - mc, pending: 0, available: mc)]
        }
        func req(_ code: String, _ name: String, _ status: String, _ start: String, _ end: String, _ days: Double) -> LeaveSummaryRequest {
            LeaveSummaryRequest(leaveType: code, leaveTypeName: name, status: status, startDate: "\(month)-\(start)",
                                endDate: "\(month)-\(end)", totalDays: days, daysInMonth: days, halfDayPosition: nil,
                                hasDocument: code == "MC")
        }
        let employees = [
            LeaveSummaryEmployee(employeeId: "E0003", name: "Daniel Tan", category: "STAFF", position: "Trainer",
                                 department: "Training", mcDays: 2,
                                 leaveTaken: ["MC": DaysPair(approved: 2, pending: 0), "AL": DaysPair(approved: 3, pending: 0)],
                                 requests: [req("MC", "Medical Leave", "APPROVED", "06", "07", 2),
                                            req("AL", "Annual Leave", "APPROVED", "20", "22", 3)],
                                 timeOff: nil, balances: bal(2, 10)),
            LeaveSummaryEmployee(employeeId: "E0014", name: "Grace Lim", category: "STAFF", position: "Executive",
                                 department: "Operations", mcDays: 0,
                                 leaveTaken: ["AL": DaysPair(approved: 1, pending: 2)],
                                 requests: [req("AL", "Annual Leave", "APPROVED", "09", "09", 1),
                                            req("AL", "Annual Leave", "PENDING", "29", "30", 2)],
                                 timeOff: nil, balances: bal(1, 14)),
            LeaveSummaryEmployee(employeeId: "I0002", name: "Amanda Halim", category: "INTERN", position: "Intern (NYP)",
                                 department: "Software Development", mcDays: 1,
                                 leaveTaken: ["MC": DaysPair(approved: 1, pending: 0)],
                                 requests: [req("MC", "Medical Leave", "APPROVED", "03", "03", 1)],
                                 timeOff: LeaveSummaryTimeOff(approvedHours: 2.5, pendingHours: 0, requests: [
                                    .init(date: "\(month)-14", startTime: "14:00", endTime: "16:30", hours: 2.5,
                                          reason: "Exams", status: "APPROVED")]),
                                 balances: bal(3, 13)),
            LeaveSummaryEmployee(employeeId: "I0012", name: "Kenneth Wang", category: "INTERN", position: "Intern (SP)",
                                 department: "Software Development", mcDays: 1,
                                 leaveTaken: ["MC": DaysPair(approved: 1, pending: 0)],
                                 requests: [req("MC", "Medical Leave", "APPROVED", "15", "15", 1)],
                                 timeOff: nil, balances: bal(2, 13)),
        ]
        return LeaveSummary(month: month,
                            totals: LeaveSummaryTotals(headcount: .init(staff: 2, interns: 2, total: 4), byLeaveType: types,
                                                       mc: .init(approvedDays: 4, pendingDays: 0, employeesOnMc: 3),
                                                       timeOff: HoursPair(approvedHours: 2.5, pendingHours: 0)),
                            employees: employees)
    }

    // MARK: Time off (hourly)
    static let timeOff: [TimeOffRequest] = [
        TimeOffRequest(id: "to1", date: "2026-07-30T00:00:00.000Z",
                       startTime: "14:00", endTime: "16:30", hours: 2.5,
                       reason: "EXAMS", reasonDetail: nil, status: "PENDING",
                       approvalComment: nil, rejectionReason: nil,
                       createdAt: "2026-07-20T02:00:00.000Z"),
        TimeOffRequest(id: "to2", date: "2026-07-08T00:00:00.000Z",
                       startTime: "09:00", endTime: "13:00", hours: 4,
                       reason: "EMERGENCY", reasonDetail: nil, status: "APPROVED",
                       approvalComment: "Take care!", rejectionReason: nil,
                       createdAt: "2026-07-07T01:15:00.000Z"),
        TimeOffRequest(id: "to3", date: "2026-06-19T00:00:00.000Z",
                       startTime: "15:00", endTime: "18:00", hours: 3,
                       reason: "OTHERS", reasonDetail: "School enrolment appointment",
                       status: "REJECTED", approvalComment: nil,
                       rejectionReason: "Please reschedule — project deadline that day.",
                       createdAt: "2026-06-15T06:40:00.000Z"),
    ]

    /// Approver view of everyone's time off (`-uiPreview` only).
    static let teamTimeOff: [TimeOffRequest] = [
        TimeOffRequest(id: "tt1", date: "2026-11-12T00:00:00.000Z", startTime: "14:00", endTime: "16:30", hours: 2.5,
                       reason: "EXAMS", reasonDetail: "Final-year project presentation at NYP, School of Information Technology",
                       status: "PENDING", approvalComment: nil, rejectionReason: nil,
                       createdAt: "2026-11-05T02:00:00.000Z", employeeName: "Amanda Halim"),
        TimeOffRequest(id: "tt2", date: "2026-11-11T00:00:00.000Z", startTime: "09:00", endTime: "11:00", hours: 2,
                       reason: "EMERGENCY", reasonDetail: "Family emergency — accompanying a parent to the polyclinic",
                       status: "PENDING", approvalComment: nil, rejectionReason: nil,
                       createdAt: "2026-11-09T23:40:00.000Z", employeeName: "Kenneth Wang"),
        TimeOffRequest(id: "tt3", date: "2026-11-03T00:00:00.000Z", startTime: "15:00", endTime: "18:00", hours: 3,
                       reason: "OTHERS", reasonDetail: "School enrolment appointment", status: "APPROVED",
                       approvalComment: nil, rejectionReason: nil, createdAt: "2026-10-30T06:40:00.000Z",
                       employeeName: "Rachel Chua"),
    ]

    // MARK: Timesheet admin (approvers)
    static let corrections: [AttendanceCorrection] = [
        AttendanceCorrection(id: "c1", employeeId: "e1", employeeName: "Amanda Halim", employeeCode: "I0002",
                             date: "2026-11-06", kind: "CLOCK_OUT", requestedClockIn: nil,
                             requestedClockOut: "2026-11-06T10:00:00.000Z", currentClockIn: "2026-11-06T01:02:00.000Z",
                             currentClockOut: nil, reason: "Forgot to clock out after the client workshop ran late.",
                             status: "PENDING", rejectionReason: nil, createdAt: "2026-11-07T01:00:00.000Z"),
    ]

    static let offInLieu: [OffInLieuEntry] = [
        OffInLieuEntry(id: "o1", employeeId: "e9", employeeCode: "E0003", employeeName: "Daniel Tan", date: "2026-11-08",
                       dayName: "Sat", isPublicHoliday: false, hours: 8, otCredited: 0, status: "PENDING", adminComment: nil),
        OffInLieuEntry(id: "o2", employeeId: "e10", employeeCode: "E0014", employeeName: "Grace Lim", date: "2026-11-01",
                       dayName: "Sat", isPublicHoliday: false, hours: 4, otCredited: 0.5, status: "APPROVED", adminComment: nil),
    ]

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

    // MARK: Leave rules (preview: `-uiPreviewLeave al-excess` triggers the AL→NPL suggestion)
    static func applyLeaveError(leaveTypeId: String) -> LeaveSubmitError? {
        guard ProcessInfo.processInfo.arguments.contains("al-excess"), leaveTypeId == "lt-al" else { return nil }
        let body = #"{"error":"This request is 15 day(s) but you only have 12.5 day(s) of annual leave available. Leave beyond your entitlement must be taken as No Pay Leave: shorten this request to 12.5 day(s) and apply for the remaining 2.5 day(s) as No Pay Leave (you have 11 No Pay Leave day(s) left this year).","code":"AL_EXCEEDS_BALANCE","alAvailable":12.5,"excessDays":2.5,"npl":{"cap":14,"used":2,"pending":1,"remaining":11},"suggestedLeaveTypeCode":"NPL"}"#
        return LeaveSubmitError.parse(status: 400, data: Data(body.utf8))
    }

    // MARK: Trainers (Trainer Admin directory)
    static let trainerList: [TrainerListItem] = [
        TrainerListItem(id: "tr-1", name: "ALFRED ANG CHEW HOE (DR)", nickname: "Alfred", phone: "+65 9123 4567",
                        email: "alfred.ang@example.com", trainerType: "ACLP", inTms: true,
                        trainingCerts: ["Advanced Certificate in Learning and Performance (ACLP, 2023)", "ACTA", "DACE",
                                        "Graduate Certificate in Workplace Learning (GCWLP)"],
                        certifications: ["PMP", "AWS Solutions Architect"],
                        skills: ["Python", "Generative AI", "Power BI"], education: "PhD, National University of Singapore",
                        financeBackground: true, ibfFitDeclaration: true, classesCount: 214, lastClassDate: "2026-11-04",
                        courseTitles: ["Generative AI for Business", "Python for Data Analytics"]),
        TrainerListItem(id: "tr-2", name: "TAN MEI LING", phone: "+65 9234 5678", email: "meiling.tan@example.com",
                        trainerType: "ACLP", inTms: true, trainingCerts: ["ALCP", "Associate Adult Educator (AAE) Programme"],
                        certifications: ["CFA Level II", "CCAR-F"], skills: ["Financial Modelling", "Excel"],
                        financeBackground: true, ibfFitDeclaration: true, classesCount: 58, lastClassDate: "2026-10-28",
                        courseTitles: ["Financial Modelling with Excel"]),
        TrainerListItem(id: "tr-3", name: "RAJESH KUMAR S/O MURUGAN", phone: "+65 9345 6789",
                        email: "rajesh.k@example.com", trainerType: "non-ACLP", inTms: true, trainingCerts: ["ACTA"],
                        certifications: ["CISSP", "CEH"], skills: ["Cybersecurity", "Linux"], classesCount: 31,
                        lastClassDate: "2026-09-19", courseTitles: ["Cybersecurity Essentials"]),
        TrainerListItem(id: "tr-4", name: "NURUL HUDA BINTE ISMAIL", phone: "+65 9456 7890",
                        email: "nurul.huda@example.com", trainerType: "ACLP", inTms: true, trainingCerts: ["ACLP", "DDDLP"],
                        certifications: [], skills: ["Articulate Storyline", "Instructional Design"], classesCount: 77,
                        lastClassDate: "2026-11-01", courseTitles: ["E-Learning Design with Storyline"]),
        TrainerListItem(id: "tr-5", name: "LIM WEI JIE", email: "weijie.lim@example.com", trainerType: "Applicant",
                        status: "Applicant", inTms: false, trainingCerts: [], certifications: ["Google Data Analytics"],
                        skills: ["SQL", "Tableau"]),
    ]

    /// More → Trainers (contact list for everyone), derived from the same sample trainers.
    static var trainerContacts: TrainerContactsResponse {
        let list = trainerList.filter { $0.status != "Applicant" }.map {
            TrainerContact(id: $0.id, name: $0.name, email: $0.email, phone: $0.phone,
                           trainingCerts: $0.trainingCerts, skills: $0.skills,
                           courseTitles: $0.courseTitles, lastClassDate: $0.lastClassDate)
        }
        return TrainerContactsResponse(count: list.count, trainers: list)
    }

    static func trainers(_ f: TrainerFilter) -> TrainersResponse {
        let q = f.query.lowercased()
        let list = trainerList.filter { t in
            (q.isEmpty || ([t.name, t.email ?? ""] + t.certifications + t.skills).joined(separator: " ").lowercased().contains(q))
            && f.certs.allSatisfy { t.trainingCerts.contains($0.rawValue) }
            && (!f.finance || t.financeBackground) && (!f.ibfFit || t.ibfFitDeclaration)
            && (f.status == .all || (f.status == .applicants) == (t.status == "Applicant"))
        }
        return TrainersResponse(count: list.count, trainers: list)
    }

    static func trainerDetail(id: String) -> TrainerDetail {
        let json = #"""
        {"trainer":{"id":"tr-1","name":"ALFRED ANG CHEW HOE (DR)","nickname":"Alfred","nric":"S1234567D",
        "phone":"+65 9123 4567","email":"alfred.ang@example.com","secondaryEmail":"alfred@example.org",
        "nationality":"Singaporean","linkedinUrl":"https://www.linkedin.com/in/example","trainerType":"ACLP",
        "status":"Active","inTms":true,"trainingCerts":["ACLP","ACTA","DACE"],
        "certifications":["PMP","AWS Solutions Architect","Google Cloud Digital Leader"],
        "skills":["Python","Generative AI","Power BI","Machine Learning","Data Analytics"],
        "education":"PhD (Electrical Engineering), National University of Singapore",
        "experience":["Founder & Principal Trainer, Tertiary Infotech Academy (2012 – present)","Senior Research Scientist, A*STAR (2005 – 2012)"],
        "summary":"Technologist and adult educator with 20+ years in AI, data and cloud. Leads the AI and analytics curriculum.",
        "financeBackground":true,"financeEvidence":["CFA Institute investment foundations"],"ibfFitDeclaration":true,
        "ibfFitFiles":["IBF Fit and Proper - Alfred Ang.pdf"],"actaFolder":"ALFRED ANG","evidenceFiles":["ACLP cert.pdf"],
        "courses":[{"title":"Generative AI for Business","code":"TGS-2023012345","classes":48,"first":"2023-03-02","last":"2026-11-04"},
                   {"title":"Python for Data Analytics","code":"TGS-2021008765","classes":36,"first":"2021-06-14","last":"2026-10-21"},
                   {"title":"Power BI Dashboards","code":"C0412","classes":12,"first":"2024-01-08","last":"2026-08-30"}],
        "recentClasses":[{"start":"2026-11-04","title":"Generative AI for Business","run":"RUN-48","status":"Completed"},
                         {"start":"2026-10-21","title":"Python for Data Analytics","run":36,"status":"Completed"},
                         {"start":"2026-11-18","title":"Generative AI for Business","run":"RUN-49","status":"Confirmed"}],
        "calendarClasses":[{"date":"2026-11-18","title":"Generative AI for Business","calendar":"Trainer schedule"}],
        "classesCount":214,"lastClassDate":"2026-11-04","adminNotes":"Preferred for AI and analytics runs."}}
        """#
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(TrainerDetailResponse.self, from: Data(json.utf8)).trainer
    }
}

// MARK: Finance details (accountant Home → Income / Expenses / Bank statements / Bank reconciliation)
extension PreviewData {
    static func bankTransactions(_ direction: BankDirection, month: String) -> BankTransactionsMonth {
        let income: [(String, String, Double, String)] = [
            ("16", "SkillsFuture Singapore Agency - course fee grant", 48_250.00, "Grant"),
            ("14", "UOB corporate training - Python for Data Analysis", 12_960.00, "Corporate"),
            ("12", "PayNow - Tan Wei Ming - WSQ Data Analytics", 650.00, "Course fee"),
            ("10", "Stripe payout", 7_412.35, "Online"),
            ("6", "PUB - Power BI in-house run", 18_400.00, "Corporate"),
            ("3", "GIRO - Adecco Personnel", 9_870.00, "Corporate"),
        ]
        let expenses: [(String, String, Double, String)] = [
            ("15", "Salary - November", 96_400.00, "Payroll"),
            ("13", "Google Workspace", 1_284.00, "Software"),
            ("11", "Trainer fee - J. Lee (Python)", 2_400.00, "Trainer"),
            ("8", "Office rental - Woods Square", 9_800.00, "Rent"),
            ("4", "AWS", 612.47, "Software"),
        ]
        let rows = (direction == .credit ? income : expenses).enumerated().map { i, r in
            BankTransaction(id: "\(direction.rawValue)-\(i)", paymentDate: "\(month)-\(r.0.count == 1 ? "0" + r.0 : r.0)",
                            title: r.1, amount: r.2, direction: direction.rawValue, type: r.3,
                            paymentType: "Bank Transfer", paymentRef: "REF\(4810 + i)",
                            status: i < 2 ? "Pending" : "Recorded",
                            rawDescription: "\(r.1.uppercased())\nDBS \(direction == .credit ? "INWARD" : "OUTWARD") \(4810 + i)",
                            statementRef: "DBS-\(month)")
        }
        return BankTransactionsMonth(month: month, direction: direction.rawValue, count: rows.count,
                                     total: rows.reduce(0) { $0 + $1.amount }, transactions: rows)
    }

    static let statementImports: [StatementImport] = [
        StatementImport(batchId: "b3", importedAt: "2026-11-16T05:21:55.243Z", from: "2026-11-01", to: "2026-11-16",
                        credits: 98, debits: 61, creditTotal: 140_742.99, debitTotal: 364_908.01, statementRef: "DBS Nov 2026"),
        StatementImport(batchId: "b2", importedAt: "2026-11-02T02:10:11.000Z", from: "2026-10-01", to: "2026-10-31",
                        credits: 181, debits: 112, creditTotal: 402_118.40, debitTotal: 377_090.12, statementRef: "DBS Oct 2026"),
        StatementImport(batchId: "b1", importedAt: "2026-10-01T03:00:00.000Z", from: "2026-09-01", to: "2026-09-30",
                        credits: 166, debits: 104, creditTotal: 356_004.10, debitTotal: 341_772.55, statementRef: "DBS Sep 2026"),
    ]

    static let reconciliationRuns: [ReconciliationRun] = [
        ReconciliationRun(id: "r2", periodStart: "2026-10-01", periodEnd: "2026-10-31", status: "COMPLETED",
                          bankCount: 293, qbCount: 290, matchedCount: 268, mismatchCount: 2, unmatchedBankCount: 2,
                          unmatchedQbCount: 1, reviewedCount: 1, matchRate: 92.2, createdAt: "2026-11-02T03:00:00.000Z"),
        ReconciliationRun(id: "r1", periodStart: "2026-09-01", periodEnd: "2026-09-30", status: "COMPLETED",
                          bankCount: 270, qbCount: 268, matchedCount: 266, mismatchCount: 0, unmatchedBankCount: 0,
                          unmatchedQbCount: 0, reviewedCount: 4, matchRate: 98.5, createdAt: "2026-10-02T03:00:00.000Z"),
    ]

    static func reconciliationDetail(id: String) -> ReconciliationDetail {
        let run = reconciliationRuns.first { $0.id == id } ?? reconciliationRuns[0]
        let items: [ReconciliationItem] = [
            ReconciliationItem(id: "i1", status: "AMOUNT_MISMATCH", bankDate: "2026-10-28", bankAmount: 1_284.00,
                               bankDirection: "DEBIT", bankDescription: "GOOGLE WORKSPACE", qbTxnType: "Expense",
                               qbDate: "2026-10-28", qbAmount: 1_248.00, qbDirection: "DEBIT", qbDocNumber: "E-2291",
                               qbPayee: "Google Asia Pacific"),
            ReconciliationItem(id: "i2", status: "UNMATCHED_BANK", bankDate: "2026-10-21", bankAmount: 650.00,
                               bankDirection: "CREDIT", bankDescription: "PAYNOW TAN WEI MING"),
            ReconciliationItem(id: "i3", status: "UNMATCHED_BANK", bankDate: "2026-10-09", bankAmount: 18.00,
                               bankDirection: "DEBIT", bankDescription: "BANK CHARGES"),
            ReconciliationItem(id: "i4", status: "UNMATCHED_QB", qbTxnType: "Payment", qbDate: "2026-10-30",
                               qbAmount: 2_400.00, qbDirection: "CREDIT", qbDocNumber: "INV-1182", qbPayee: "Adecco Personnel"),
            ReconciliationItem(id: "i5", status: "AMOUNT_MISMATCH", bankDate: "2026-10-05", bankAmount: 9_800.00,
                               bankDirection: "DEBIT", bankDescription: "WOODS SQUARE RENT", qbTxnType: "Bill",
                               qbDate: "2026-10-05", qbAmount: 9_810.00, qbDirection: "DEBIT", qbPayee: "Woods Square",
                               reviewed: true),
            ReconciliationItem(id: "i6", status: "MATCHED", bankDate: "2026-10-15", bankAmount: 96_400.00,
                               bankDirection: "DEBIT", bankDescription: "SALARY OCTOBER", qbTxnType: "Expense",
                               qbDate: "2026-10-15", qbAmount: 96_400.00, qbDirection: "DEBIT", qbPayee: "Payroll"),
            ReconciliationItem(id: "i7", status: "MATCHED", bankDate: "2026-10-03", bankAmount: 48_250.00,
                               bankDirection: "CREDIT", bankDescription: "SKILLSFUTURE SINGAPORE", qbTxnType: "Payment",
                               qbDate: "2026-10-03", qbAmount: 48_250.00, qbDirection: "CREDIT", qbPayee: "SSG"),
        ]
        return ReconciliationDetail(run: run, items: items)
    }
}

// MARK: SOPs
extension PreviewData {
    static let sops: [Sop] = [
        Sop(slug: "apply-leave", title: "Applying for leave", category: "Human Resources",
            summary: "How staff and interns apply for annual leave, MC and other leave in the HRMS.",
            purpose: "Keep leave fair, recorded and approved before it is taken.", scope: "All staff and interns.",
            owner: "HR", triggers: ["You plan to take leave", "You are unwell (MC)"],
            steps: [SopStep(title: "Check your balance", detail: "Open Leave and check the days left.", owner: "Employee"),
                    SopStep(title: "Apply in the HRMS", detail: "Pick the type and dates; attach the MC for medical leave.",
                            items: ["Annual leave at least 3 days ahead", "MC on the day"], owner: "Employee", timing: "Before the leave"),
                    SopStep(title: "Approval", detail: "Your approver decides in the HRMS; you get a notification.",
                            owner: "Approver", timing: "Within 2 working days", note: "Leave is not approved until the status says Approved.")],
            references: [SopReference(label: "HR mailbox", value: "hr@tertiaryinfotech.com", href: "mailto:hr@tertiaryinfotech.com")],
            source: "HR policy as the HRMS enforces it"),
        Sop(slug: "class-setup", title: "Setting up a class", category: "Operations",
            summary: "Create the class run, assign the trainer and publish it for registration.", owner: "Operations",
            steps: [SopStep(title: "Create the class run", detail: "Enter dates, venue and trainer in the TMS.", owner: "Course administrator"),
                    SopStep(title: "Publish", detail: "Open the run for registration.", owner: "Course administrator")],
            source: "POM section 3.1"),
        Sop(slug: "assessment-appeal", title: "Handling an assessment appeal", category: "Assessment",
            summary: "Receive, review and decide on a learner's appeal against an assessment result.", owner: "Assessment manager",
            steps: [SopStep(title: "Receive the appeal", detail: "Log it within 1 working day.", timing: "Within 1 working day")],
            source: "POM section 5.4"),
    ]
}
