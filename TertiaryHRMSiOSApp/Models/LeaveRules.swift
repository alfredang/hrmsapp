import Foundation

/// Client-side mirror of the server's leave rules (`src/lib/leave-policy.ts` in the web repo).
/// The server is authoritative — these only shape the form and interpret its error codes.
enum LeaveRules {
    static let nplCode = "NPL"
    /// Medical leave codes (server `MEDICAL_LEAVE_CODES`).
    static let medicalCodes: Set<String> = ["MC", "SL", "MEDICAL"]
    /// Reason prefix the web form uses when an intern's sick leave goes in as NPL.
    static let internSickReason = "Sick leave (MC)"

    /// An intern is a user whose roles are exactly ["INTERN"] (admins also hold INTERN to switch views).
    static func isIntern(roles: [String]?) -> Bool {
        guard let roles, roles.count == 1 else { return false }
        return roles[0].uppercased() == "INTERN"
    }

    static func isMedical(_ type: LeaveType?) -> Bool {
        guard let type else { return false }
        return medicalCodes.contains(type.code.uppercased())
            || type.name.localizedCaseInsensitiveContains("medical")
    }

    static func noPayLeaveType(in types: [LeaveType]) -> LeaveType? {
        types.first { $0.code.uppercased() == nplCode }
    }

    /// The reason sent for an intern's sick leave: always starts with "Sick leave (MC)",
    /// matching the web form (`Sick leave (MC) — <reason>`).
    static func internSickReason(_ reason: String) -> String {
        let r = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if r.isEmpty { return internSickReason }
        if r.hasPrefix(internSickReason) { return r }
        return "\(internSickReason) — \(r)"
    }
}

/// No Pay Leave cap status: 21 days/year prorated by months served.
struct NplStatus: Codable, Equatable {
    let cap: Double
    let used: Double
    let pending: Double
    let remaining: Double
}

/// A rejected `POST /api/leave`, decoded from the server's `{error, code, …}` body.
enum LeaveSubmitError: LocalizedError, Equatable {
    /// AL request beyond what annual leave (+ OIL / advance) covers → suggest No Pay Leave.
    case alExceedsBalance(message: String, alAvailable: Double?, excessDays: Double?, npl: NplStatus?)
    /// Interns have no paid MC → their sick leave must be No Pay Leave.
    case internMcNotPaid(message: String)
    /// No Pay Leave beyond the prorated yearly cap.
    case nplCapExceeded(message: String, npl: NplStatus?, requested: Double?)
    case unauthorized
    case other(message: String, status: Int)

    var errorDescription: String? {
        switch self {
        case .alExceedsBalance(let m, _, _, _), .internMcNotPaid(let m), .nplCapExceeded(let m, _, _):
            return m
        case .unauthorized: return "Your session expired. Please sign in again."
        case .other(let m, _): return m
        }
    }

    /// The server suggested resubmitting as No Pay Leave.
    var suggestsNoPayLeave: Bool {
        switch self {
        case .alExceedsBalance, .internMcNotPaid: return true
        default: return false
        }
    }

    var npl: NplStatus? {
        switch self {
        case .alExceedsBalance(_, _, _, let n), .nplCapExceeded(_, let n, _): return n
        default: return nil
        }
    }

    static let fallbackMessage = "Could not submit your leave request."

    private struct Body: Decodable {
        let error: String?
        let code: String?
        let alAvailable: Double?
        let excessDays: Double?
        let npl: NplStatus?
        let requested: Double?
        let suggestedLeaveTypeCode: String?
    }

    /// Map a non-2xx response to a typed error. Tolerates non-JSON bodies.
    static func parse(status: Int, data: Data) -> LeaveSubmitError {
        if status == 401 { return .unauthorized }
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else {
            return .other(message: fallbackMessage, status: status)
        }
        let message = body.error?.isEmpty == false ? body.error! : fallbackMessage
        switch body.code {
        case "AL_EXCEEDS_BALANCE":
            return .alExceedsBalance(message: message, alAvailable: body.alAvailable,
                                     excessDays: body.excessDays, npl: body.npl)
        case "INTERN_MC_NOT_PAID":
            return .internMcNotPaid(message: message)
        case "NPL_CAP_EXCEEDED":
            return .nplCapExceeded(message: message, npl: body.npl, requested: body.requested)
        default:
            return .other(message: message, status: status)
        }
    }
}
