import Foundation

/// Talks to the live Tertiary HRMS backend (hosted on Coolify) and authenticates
/// real employees against the Coolify PostgreSQL database via its NextAuth (Auth.js)
/// endpoints. No data is read from the database directly — everything goes through
/// the same secure API the web app uses.
///
/// NextAuth credential sign-in is a small dance:
///   1. GET  /api/auth/csrf                     → csrfToken (+ csrf cookie)
///   2. POST /api/auth/callback/{provider}      → sets the session cookie on success
///   3. GET  /api/auth/session                  → the signed-in user (or null)
/// A private cookie store carries the session between calls and persists it across
/// launches so the employee stays logged in.
actor AuthService {
    static let shared = AuthService()

    /// Canonical NextAuth host (matches the provider callback URLs the backend reports).
    static let baseURL = URL(string: "https://hrms.tertiaryinfotech.com")!

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    enum AuthError: LocalizedError {
        case invalidCredentials
        case noAccount
        case network(String)
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidCredentials: return "Invalid email or password. Please try again."
            case .noAccount: return "No account found for this email. Please contact HR."
            case .network(let m): return m
            case .server(let m): return m
            }
        }
    }

    // MARK: - Public API

    /// Password sign-in. Returns the authenticated user on success.
    func signIn(email: String, password: String) async throws -> SessionUser {
        let token = try await csrfToken()
        try await postCallback(provider: "credentials",
                               fields: ["csrfToken": token, "email": email, "password": password])
        guard let user = try await currentUser() else { throw AuthError.invalidCredentials }
        return user
    }

    /// Request a one-time passcode be emailed to the employee.
    func requestOTP(email: String) async throws {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent("api/auth/send-otp"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (data, resp) = try await send(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { throw AuthError.noAccount }
        if code >= 400 {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw AuthError.server(msg ?? "Could not send the code. Please try again.")
        }
    }

    /// Verify the emailed OTP and sign in.
    func verifyOTP(email: String, otp: String) async throws -> SessionUser {
        let token = try await csrfToken()
        try await postCallback(provider: "otp",
                               fields: ["csrfToken": token, "email": email, "otp": otp])
        guard let user = try await currentUser() else { throw AuthError.invalidCredentials }
        return user
    }

    /// The current session user, if a valid session cookie is present.
    func currentUser() async throws -> SessionUser? {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent("api/auth/session"))
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await send(req)
        // `/api/auth/session` returns `null` when unauthenticated.
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == nil || trimmed == "null" || trimmed?.isEmpty == true { return nil }
        let envelope = try? JSONDecoder().decode(SessionResponse.self, from: data)
        return envelope?.user
    }

    /// Clear the server session and local cookies.
    func signOut() async {
        if let token = try? await csrfToken() {
            var req = URLRequest(url: Self.baseURL.appendingPathComponent("api/auth/signout"))
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = formBody(["csrfToken": token, "json": "true"])
            _ = try? await send(req)
        }
        if let cookies = HTTPCookieStorage.shared.cookies {
            for c in cookies where c.domain.contains("tertiaryinfotech") {
                HTTPCookieStorage.shared.deleteCookie(c)
            }
        }
    }

    // MARK: - NextAuth plumbing

    private func csrfToken() async throws -> String {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent("api/auth/csrf"))
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await send(req)
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = obj["csrfToken"] as? String
        else { throw AuthError.server("Could not start sign-in. Please try again.") }
        return token
    }

    /// POST a NextAuth credentials callback. On bad credentials NextAuth still returns
    /// 2xx but does not set a session cookie, so callers must confirm via `currentUser()`.
    private func postCallback(provider: String, fields: [String: String]) async throws {
        var body = fields
        body["callbackUrl"] = Self.baseURL.absoluteString
        body["json"] = "true"
        var req = URLRequest(url: Self.baseURL.appendingPathComponent("api/auth/callback/\(provider)"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = formBody(body)
        let (_, resp) = try await send(req)
        if let code = (resp as? HTTPURLResponse)?.statusCode, code >= 500 {
            throw AuthError.server("The server is unavailable. Please try again later.")
        }
    }

    private func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = fields.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }
        return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    private func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw AuthError.network("Network error. Check your connection and try again.")
        }
    }
}
