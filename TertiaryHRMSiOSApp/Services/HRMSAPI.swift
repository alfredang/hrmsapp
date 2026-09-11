import Foundation

/// Read (and a few write) calls against the HRMS backend's mobile JSON API
/// (`/api/mobile/*`) plus a couple of existing endpoints. Uses the shared cookie
/// store, so it rides the same authenticated session established at login.
actor HRMSAPI {
    static let shared = HRMSAPI()

    private let base = AuthService.baseURL
    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    enum APIError: LocalizedError {
        case unauthorized
        case http(Int)
        case network
        case decoding

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Your session expired. Please sign in again."
            case .http(let c): return "Request failed (\(c))."
            case .network: return "Network error. Check your connection."
            case .decoding: return "Unexpected response from the server."
            }
        }
    }

    // Screenshot/demo seed: when launched with `-uiPreview`, every read returns realistic
    // sample data instead of hitting the backend (no fake data ships to real installs).
    private let isPreview = ProcessInfo.processInfo.arguments.contains("-uiPreview")

    // MARK: - Typed reads

    func summary()  async throws -> DashboardSummary { isPreview ? PreviewData.summary   : try await get("api/mobile/summary") }
    func leave()    async throws -> LeaveResponse     { isPreview ? PreviewData.leave     : try await get("api/mobile/leave") }
    func employees()async throws -> EmployeesResponse { isPreview ? PreviewData.employees : try await get("api/mobile/employees") }
    func expenses() async throws -> ExpensesResponse  { isPreview ? PreviewData.expenses  : try await get("api/mobile/expenses") }
    func payslips() async throws -> PayslipsResponse  { isPreview ? PreviewData.payslips  : try await get("api/mobile/payslips") }
    func calendar() async throws -> CalendarResponse  { isPreview ? PreviewData.calendar  : try await get("api/mobile/calendar") }
    func profile()  async throws -> ProfileResponse   { isPreview ? PreviewData.profile   : try await get("api/mobile/profile") }

    /// Company-wide approved leave for the team calendar.
    func teamCalendar(year: Int) async throws -> TeamCalendarResponse {
        if isPreview { return PreviewData.teamCalendar }
        // A query string passed to appendingPathComponent is treated as part of
        // the path and turns `?` into `%3F`, which makes this endpoint 404.
        // Build the query separately so the server receives the intended route.
        var comps = URLComponents(url: base.appendingPathComponent("api/mobile/team-calendar"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "year", value: String(year))]
        return try await get(url: comps.url!)
    }
    func attendance() async throws -> AttendanceResponse { isPreview ? PreviewData.attendance : try await get("api/mobile/attendance") }

    /// Weekly timesheet (existing /api/timesheet). `weekStart` is a Monday
    /// `yyyy-MM-dd`; nil returns the server's current week.
    func timesheet(weekStart: String? = nil) async throws -> TimesheetResponse {
        if isPreview { return PreviewData.timesheet }
        guard let weekStart else { return try await get("api/timesheet") }
        // Note: appendingPathComponent percent-encodes "?", so build the query URL properly.
        var comps = URLComponents(url: base.appendingPathComponent("api/timesheet"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "weekStart", value: weekStart)]
        return try await get(url: comps.url!)
    }

    /// The employee's hourly time-off requests (raw array, newest first).
    func timeOff() async throws -> [TimeOffRequest] {
        isPreview ? PreviewData.timeOff : try await get("api/time-off")
    }

    func approvals() async throws -> ApprovalsResponse { isPreview ? PreviewData.approvals : try await get("api/mobile/approvals") }

    /// Curated SG public holidays (public endpoint). `date` is plain `yyyy-MM-dd`.
    func publicHolidays(year: Int) async throws -> [PublicHoliday] {
        if isPreview { return PreviewData.holidays(year) }
        let resp: PublicHolidaysResponse = try await get("api/public-holidays?year=\(year)")
        return resp.holidays
    }

    /// Staff-relevant notifications (raw array). Newest first.
    func notifications() async throws -> [AppNotification] {
        if isPreview { return PreviewData.notifications }
        let all: [AppNotification] = try await get("api/notifications")
        return all.filter(\.isStaffRelevant)
    }

    /// Mark a single notification read (owner only). POST /api/notifications/{id}/read.
    func markNotificationRead(id: String) async throws {
        if isPreview { return }
        var req = URLRequest(url: base.appendingPathComponent("api/notifications/\(id)/read"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (_, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else { throw APIError.http(code) }
    }

    // MARK: - Approve / reject pending requests (existing web routes)

    enum ApprovalKind: String {
        case leave = "api/leave"
        case claim = "api/expenses"
    }

    /// POST /api/{leave|expenses}/{id}/{approve|reject} — MANAGER/HR/ADMIN only.
    func decide(_ kind: ApprovalKind, id: String, approve: Bool, reason: String? = nil) async throws {
        if isPreview { return }
        let action = approve ? "approve" : "reject"
        var req = URLRequest(url: base.appendingPathComponent("\(kind.rawValue)/\(id)/\(action)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [:]
        if !approve, let reason, !reason.isEmpty { body["reason"] = reason }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not \(action) the request."])
        }
    }

    // MARK: - Apply for leave (POST /api/leave)

    func applyLeave(leaveTypeId: String, startDate: String, endDate: String,
                    dayType: String, reason: String,
                    documentUrl: String? = nil, documentFileName: String? = nil) async throws {
        var req = URLRequest(url: base.appendingPathComponent("api/leave"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "leaveTypeId": leaveTypeId, "startDate": startDate, "endDate": endDate,
            "dayType": dayType, "reason": reason,
        ]
        if let documentUrl { body["documentUrl"] = documentUrl }
        if let documentFileName { body["documentFileName"] = documentFileName }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not submit your leave request."])
        }
    }

    // MARK: - Time off (hourly): request + cancel (existing /api/time-off routes)

    /// POST /api/time-off. Times are "HH:mm" 24-hour; `reasonDetail` is
    /// required by the server when reason == OTHERS.
    func submitTimeOff(date: String, startTime: String, endTime: String,
                       reason: String, reasonDetail: String? = nil) async throws {
        if isPreview { return }
        var req = URLRequest(url: base.appendingPathComponent("api/time-off"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "date": date, "startTime": startTime, "endTime": endTime, "reason": reason,
        ]
        if let reasonDetail, !reasonDetail.isEmpty { body["reasonDetail"] = reasonDetail }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not submit your time-off request."])
        }
    }

    /// POST /api/time-off/{id}/cancel — owner's PENDING requests only.
    func cancelTimeOff(id: String) async throws {
        if isPreview { return }
        var req = URLRequest(url: base.appendingPathComponent("api/time-off/\(id)/cancel"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not cancel the request."])
        }
    }

    // MARK: - Submit weekly timesheet (POST /api/timesheet)

    /// POST /api/timesheet {weekStart, entries:[{date, hours}]} — weekend /
    /// public-holiday hours for Off-In-Lieu credit.
    func submitTimesheet(weekStart: String, entries: [TimesheetEntry]) async throws {
        if isPreview { return }
        var req = URLRequest(url: base.appendingPathComponent("api/timesheet"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "weekStart": weekStart,
            "entries": entries.map { ["date": $0.date, "hours": $0.hours] },
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not submit your timesheet."])
        }
    }

    // MARK: - Clock in / out (POST /api/mobile/attendance/clock-{in,out})

    enum ClockAction: String { case clockIn = "clock-in", clockOut = "clock-out" }

    func clock(_ action: ClockAction) async throws {
        if isPreview { return }
        var req = URLRequest(url: base.appendingPathComponent("api/mobile/attendance/\(action.rawValue)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not record the punch."])
        }
    }

    // MARK: - Upload a supporting document (POST /api/upload, multipart)

    /// Uploads a photo (e.g. a medical certificate) to the web app's existing
    /// upload endpoint and returns the `{url, fileName}` pair that
    /// `POST /api/leave` accepts as `documentUrl`/`documentFileName`.
    func uploadDocument(imageData: Data, fileName: String) async throws -> (url: String, fileName: String) {
        if isPreview { return ("/api/uploads/preview.jpg", fileName) }
        let boundary = "hrms-\(UUID().uuidString)"
        var req = URLRequest(url: base.appendingPathComponent("api/upload"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 90

        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        req.httpBody = body

        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw APIError.unauthorized }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(code), let url = json?["url"] as? String else {
            let msg = json?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not upload the photo."])
        }
        return (url, (json?["fileName"] as? String) ?? fileName)
    }

    // MARK: - Submit a claim with receipt photo (POST /api/mobile/claims, multipart)

    func submitClaim(claimType: String, categoryId: String?, description: String,
                     amount: Double, expenseDate: String,
                     imageData: Data, fileName: String) async throws {
        if isPreview { return }
        let boundary = "hrms-\(UUID().uuidString)"
        var req = URLRequest(url: base.appendingPathComponent("api/mobile/claims"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 90

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("claimType", claimType)
        if let categoryId { field("categoryId", categoryId) }
        field("description", description)
        field("amount", String(format: "%.2f", amount))
        field("expenseDate", expenseDate)
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"receipt\"; filename=\"\(fileName)\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        req.httpBody = body

        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not submit your claim."])
        }
    }

    // MARK: - Profile: self-edit + change password

    /// PATCH /api/employees/{id} with a `personalInfo` block. `id` is the
    /// internal employee id (== the session's employeeId claim), which the
    /// server's self-edit check requires. Only the provided keys are updated.
    func updateProfile(employeeId: String, personalInfo: [String: Any]) async throws {
        if isPreview { return }
        var req = URLRequest(url: base.appendingPathComponent("api/employees/\(employeeId)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["personalInfo": personalInfo])
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not save your profile."])
        }
    }

    /// PATCH /api/profile/password {currentPassword, newPassword}. newPassword ≥ 6 chars.
    func changePassword(current: String, new: String) async throws {
        if isPreview { return }
        var req = URLRequest(url: base.appendingPathComponent("api/profile/password"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["currentPassword": current, "newPassword": new])
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not update your password."])
        }
    }

    // MARK: - Authenticated PDF download (existing payslip PDF route)

    func downloadPDF(path: String) async throws -> Data {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.setValue("application/pdf", forHTTPHeaderField: "Accept")
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw APIError.http(code) }
        return data
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await get(url: base.appendingPathComponent(path))
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else { throw APIError.http(code) }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func safe(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await session.data(for: req) }
        catch { throw APIError.network }
    }
}
