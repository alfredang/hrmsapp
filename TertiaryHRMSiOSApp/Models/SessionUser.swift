import Foundation

/// The authenticated user, decoded from the HRMS backend's `/api/auth/session`.
/// Shape mirrors the NextAuth session callback in `src/lib/auth.ts`.
struct SessionUser: Codable, Equatable {
    let id: String?
    let email: String?
    let name: String?
    let role: String?
    let roles: [String]?
    let employeeId: String?

    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        if let e = email, !e.isEmpty { return e }
        return "Employee"
    }

    var primaryRole: String { role ?? roles?.first ?? "STAFF" }

    /// Initials for the avatar chip, e.g. "Alfred Ang" → "AA".
    var initials: String {
        let source = (name?.isEmpty == false ? name! : (email ?? "?"))
        let parts = source.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "@" })
        let letters = parts.prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "?" : s
    }
}

/// Envelope returned by `/api/auth/session` (`{ "user": { ... }, "expires": ... }`),
/// or literal `null` when unauthenticated.
struct SessionResponse: Codable {
    let user: SessionUser?
    let expires: String?
}
