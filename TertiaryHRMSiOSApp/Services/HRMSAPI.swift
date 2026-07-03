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
    func timesheet()async throws -> TimesheetResponse { isPreview ? PreviewData.timesheet : try await get("api/timesheet") }
    func attendance() async throws -> AttendanceResponse { isPreview ? PreviewData.attendance : try await get("api/mobile/attendance") }

    // MARK: - Apply for leave (POST /api/leave)

    func applyLeave(leaveTypeId: String, startDate: String, endDate: String,
                    dayType: String, reason: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("api/leave"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "leaveTypeId": leaveTypeId, "startDate": startDate, "endDate": endDate,
            "dayType": dayType, "reason": reason,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await safe(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HRMS", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Could not submit your leave request."])
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
        var req = URLRequest(url: base.appendingPathComponent(path))
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
