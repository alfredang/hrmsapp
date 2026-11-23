import XCTest
@testable import TertiaryHRMSiOSApp

/// Approve / Reject on a request notice, and No Pay Leave paybacks in Approvals (23 Nov 2026).
final class NoticeActionTests: XCTestCase {
    private func notice(_ json: String) throws -> AppNotification {
        try JSONDecoder().decode(AppNotification.self, from: Data(json.utf8))
    }

    func testServerActionIsUsed() throws {
        let n = try notice(#"{"id":"n","title":"t","message":"m","type":"PAYBACK_SUBMITTED","read":false,"link":"/leave/payback?request=P1","createdAt":null,"action":{"kind":"payback","requestId":"P1"}}"#)
        XCTAssertEqual(n.requestAction, NoticeAction(kind: "payback", requestId: "P1"))
        XCTAssertEqual(n.requestAction?.decision, .request(.payback))
    }

    func testOlderServerDerivesActionFromTypeAndLink() throws {
        let leave = try notice(#"{"id":"n","title":"t","message":"m","type":"LEAVE_SUBMITTED","read":false,"link":"/leave?request=L1","createdAt":null}"#)
        XCTAssertEqual(leave.requestAction, NoticeAction(kind: "leave", requestId: "L1"))
        let punch = try notice(#"{"id":"n","title":"t","message":"m","type":"ATTENDANCE_CORRECTION_SUBMITTED","read":false,"link":"/timesheet/overview?request=C1","createdAt":null,"action":null}"#)
        XCTAssertEqual(punch.requestAction?.decision, .correction)
    }

    func testInfoNoticesAndLinksWithoutIdHaveNoAction() throws {
        XCTAssertNil(try notice(#"{"id":"n","title":"t","message":"m","type":"HR_COMPLIANCE","read":false,"link":"/dashboard","createdAt":null}"#).requestAction)
        XCTAssertNil(try notice(#"{"id":"n","title":"t","message":"m","type":"LEAVE_SUBMITTED","read":false,"link":"/leave","createdAt":null}"#).requestAction)
    }

    func testApprovalsDecodePaybacksAndToleratesOlderServer() throws {
        let old = try JSONDecoder().decode(ApprovalsResponse.self, from: Data(#"{"leaves":[],"claims":[]}"#.utf8))
        XCTAssertEqual(old.paybacks, [])
        let new = try JSONDecoder().decode(ApprovalsResponse.self, from: Data(#"{"leaves":[],"claims":[],"paybacks":[{"id":"P31","employee":"FEMINA JASMIN","nplDate":"2026-10-30T00:00:00.000Z","workDate":"2026-10-31T00:00:00.000Z","days":1,"note":null,"clocked":null,"createdAt":"2026-11-23T07:53:44.576Z"}]}"#.utf8))
        XCTAssertEqual(new.paybacks.map(\.id), ["P31"])
        XCTAssertEqual(PendingApprovals(approvals: new, timeOff: []).total, 1)
    }

    func testPaybackLinkOpensApprovalsForApprovers() {
        XCTAssertEqual(PushRoute.from(link: "/leave/payback?request=P1", isAdmin: true, mustClockIn: false), .approvals)
        XCTAssertEqual(PushRoute.from(link: "/leave/payback", isAdmin: false, mustClockIn: false), .tab(1))
    }
}
