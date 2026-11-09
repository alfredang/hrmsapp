import XCTest
@testable import TertiaryHRMSiOSApp

/// The server's leave-rule errors (`POST /api/leave` → 400 `{error, code, …}`), decoded
/// exactly as `src/app/api/leave/route.ts` in the web repo returns them.
final class LeaveRulesTests: XCTestCase {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testAlExceedsBalanceDecodesNplSuggestion() {
        let body = #"{"error":"This request is 5 day(s) but you only have 3 day(s) of annual leave available.","code":"AL_EXCEEDS_BALANCE","alAvailable":3,"excessDays":2,"npl":{"cap":17.5,"used":2,"pending":1,"remaining":14.5},"suggestedLeaveTypeCode":"NPL"}"#
        let err = LeaveSubmitError.parse(status: 400, data: data(body))
        guard case let .alExceedsBalance(message, alAvailable, excessDays, npl) = err else {
            return XCTFail("expected alExceedsBalance, got \(err)")
        }
        XCTAssertTrue(message.hasPrefix("This request is 5 day(s)"))
        XCTAssertEqual(alAvailable, 3)
        XCTAssertEqual(excessDays, 2)
        XCTAssertEqual(npl, NplStatus(cap: 17.5, used: 2, pending: 1, remaining: 14.5))
        XCTAssertTrue(err.suggestsNoPayLeave)
        XCTAssertEqual(err.errorDescription, message)
    }

    func testInternMcNotPaid() {
        let body = #"{"error":"Interns do not have paid medical leave. Please apply for No Pay Leave instead and attach your medical certificate.","code":"INTERN_MC_NOT_PAID","suggestedLeaveTypeCode":"NPL"}"#
        let err = LeaveSubmitError.parse(status: 400, data: data(body))
        guard case .internMcNotPaid(let message) = err else { return XCTFail("got \(err)") }
        XCTAssertTrue(message.contains("No Pay Leave"))
        XCTAssertTrue(err.suggestsNoPayLeave)
        XCTAssertNil(err.npl)
    }

    func testNplCapExceeded() {
        let body = #"{"error":"No Pay Leave is capped at 21 days a year, prorated to 7 day(s).","code":"NPL_CAP_EXCEEDED","npl":{"cap":7,"used":5,"pending":0,"remaining":2},"requested":3}"#
        let err = LeaveSubmitError.parse(status: 400, data: data(body))
        guard case let .nplCapExceeded(_, npl, requested) = err else { return XCTFail("got \(err)") }
        XCTAssertEqual(npl?.remaining, 2)
        XCTAssertEqual(npl?.cap, 7)
        XCTAssertEqual(requested, 3)
        XCTAssertFalse(err.suggestsNoPayLeave, "NPL cap errors must not offer another NPL resubmit")
    }

    func testUncodedErrorKeepsServerMessage() {
        let body = #"{"error":"Insufficient leave balance","available":1,"requested":2}"#
        let err = LeaveSubmitError.parse(status: 400, data: data(body))
        XCTAssertEqual(err, .other(message: "Insufficient leave balance", status: 400))
        XCTAssertFalse(err.suggestsNoPayLeave)
    }

    func testNonJSONBodyAndUnauthorized() {
        XCTAssertEqual(LeaveSubmitError.parse(status: 502, data: data("<html>Bad gateway</html>")),
                       .other(message: LeaveSubmitError.fallbackMessage, status: 502))
        XCTAssertEqual(LeaveSubmitError.parse(status: 401, data: data(#"{"error":"Unauthorized"}"#)), .unauthorized)
    }

    func testInternDetectionRequiresExactlyIntern() {
        XCTAssertTrue(LeaveRules.isIntern(roles: ["INTERN"]))
        XCTAssertFalse(LeaveRules.isIntern(roles: ["ADMIN", "INTERN"]), "admins also hold INTERN to switch views")
        XCTAssertFalse(LeaveRules.isIntern(roles: ["STAFF"]))
        XCTAssertFalse(LeaveRules.isIntern(roles: nil))
        XCTAssertFalse(LeaveRules.isIntern(roles: []))
    }

    func testInternSickReasonMatchesWebFormat() {
        XCTAssertEqual(LeaveRules.internSickReason(""), "Sick leave (MC)")
        XCTAssertEqual(LeaveRules.internSickReason("Sick leave (MC)"), "Sick leave (MC)")
        XCTAssertEqual(LeaveRules.internSickReason("Fever"), "Sick leave (MC) — Fever")
        XCTAssertEqual(LeaveRules.internSickReason("Sick leave (MC) — flu"), "Sick leave (MC) — flu")
    }

    func testMedicalAndNplTypeLookup() {
        let types = [
            LeaveType(id: "a", code: "AL", name: "Annual Leave", paid: true, defaultDays: 14),
            LeaveType(id: "m", code: "MC", name: "Medical Leave", paid: true, defaultDays: 14),
            LeaveType(id: "n", code: "NPL", name: "No Pay Leave", paid: false, defaultDays: 21),
        ]
        XCTAssertTrue(LeaveRules.isMedical(types[1]))
        XCTAssertFalse(LeaveRules.isMedical(types[0]))
        XCTAssertEqual(LeaveRules.noPayLeaveType(in: types)?.id, "n")
    }

    /// `/api/mobile/leave` sends the NPL row with proRated = cap, available = remaining.
    func testLeaveResponseDecodesNplRow() throws {
        let json = #"{"balances":[{"code":"NPL","name":"No Pay Leave","paid":false,"entitlement":0,"carriedOver":0,"used":0,"pending":0,"earned":0,"autoDeducted":0,"proRated":17.5,"available":14.5}],"types":[{"id":"n","code":"NPL","name":"No Pay Leave","paid":false,"defaultDays":21}],"requests":[]}"#
        let r = try JSONDecoder().decode(LeaveResponse.self, from: data(json))
        let npl = try XCTUnwrap(r.balances.first)
        XCTAssertTrue(npl.isNoPayLeave)
        XCTAssertEqual(npl.proRated, 17.5)
        XCTAssertEqual(npl.available, 14.5)
    }

    func testSummaryCanManageTrainersIsOptional() throws {
        let base = #""name":"A","role":"STAFF","isAdmin":false,"alAvailable":1,"mcAvailable":2,"otRemaining":0,"expenseYtd":0,"pendingLeaves":0,"pendingClaims":0"#
        let old = try JSONDecoder().decode(DashboardSummary.self, from: data("{\(base)}"))
        XCTAssertFalse(old.showsTrainers, "an older server without the field hides Trainers")
        let new = try JSONDecoder().decode(DashboardSummary.self, from: data("{\(base),\"canManageTrainers\":true}"))
        XCTAssertTrue(new.showsTrainers)
    }
}
