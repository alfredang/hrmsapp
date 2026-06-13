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

    // MARK: - Typed reads

    func summary()  async throws -> DashboardSummary { try await get("api/mobile/summary") }
    func leave()    async throws -> LeaveResponse     { try await get("api/mobile/leave") }
    func employees()async throws -> EmployeesResponse { try await get("api/mobile/employees") }
    func expenses() async throws -> ExpensesResponse  { try await get("api/mobile/expenses") }
    func payslips() async throws -> PayslipsResponse  { try await get("api/mobile/payslips") }
    func calendar() async throws -> CalendarResponse  { try await get("api/mobile/calendar") }
    func profile()  async throws -> ProfileResponse   { try await get("api/mobile/profile") }
    func timesheet()async throws -> TimesheetResponse { try await get("api/timesheet") }

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
