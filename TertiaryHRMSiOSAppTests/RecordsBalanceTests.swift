import XCTest
@testable import TertiaryHRMSiOSApp

/// Team → person records (web 25 Nov 2026): leave / MC / No Pay Leave balance tiles, and
/// clock-in history only for people who clock in.
final class RecordsBalanceTests: XCTestCase {
    private func decode(_ json: String) throws -> EmployeeRecords {
        try JSONDecoder().decode(EmployeeRecords.self, from: Data(json.utf8))
    }

    private let base = """
    "employee": {"id":"e1","employeeCode":"E0005","name":"Jyoti","position":null,"department":null,"employmentType":"FULL_TIME"},
    "attendance": {"days": [], "totalHours": 0, "daysWorked": 0},
    "leave": [
      {"id":"l1","leaveType":"Annual Leave","leaveCode":"AL","startDate":"2026-11-16T00:00:00Z","endDate":"2026-11-17T00:00:00Z","days":2,"dayType":"FULL_DAY","status":"APPROVED"},
      {"id":"l2","leaveType":"No Pay Leave","leaveCode":"NPL","startDate":"2026-10-01T00:00:00Z","endDate":"2026-10-01T00:00:00Z","days":1,"dayType":"FULL_DAY","status":"APPROVED"}
    ]
    """

    func testDecodesBalancesAndTileText() throws {
        let r = try decode("""
        {\(base), "intern": false, "mustClockIn": false, "balances": [
          {"code":"AL","name":"Annual Leave","taken":5,"pending":0,"available":7,"allowance":12},
          {"code":"MC","name":"MC","taken":1.5,"pending":0,"available":12.5,"allowance":14},
          {"code":"NPL","name":"No Pay Leave","taken":1,"pending":0,"available":13,"allowance":14}
        ]}
        """)
        let b = try XCTUnwrap(r.balances)
        XCTAssertEqual(b.map(\.kind), [.al, .mc, .npl])
        XCTAssertEqual(b[0].takenText, "5 taken")
        XCTAssertEqual(b[0].balanceText, "7/12 balance")
        XCTAssertEqual(b[1].balanceText, "12.5/14 balance")
        XCTAssertEqual(r.requests(for: b[0]).map(\.id), ["l1"])
        XCTAssertEqual(r.requests(for: b[2]).map(\.id), ["l2"])
    }

    func testDecodesPaybacksAndClaims() throws {
        let r = try decode("""
        {\(base), "paybacks": [
          {"id":"pb1","nplDate":"2026-11-11T00:00:00.000Z","workDate":"2026-11-22T00:00:00.000Z","days":1,"note":null,"status":"PENDING","approver":null,"approvedAt":null,"rejectionReason":null,"createdAt":"2026-11-23T01:00:00.000Z"}
        ], "claims": [
          {"id":"c1","description":"Grab to client","amount":28.4,"currency":"SGD","category":"Travel","categoryCode":"TRV","expenseDate":"2026-11-20T00:00:00.000Z","status":"APPROVED","receiptUrl":null,"driveWebViewLink":null,"approver":"Alfred Ang","approvedAt":null,"rejectionReason":null,"createdAt":null}
        ]}
        """)
        XCTAssertEqual(r.paybacks?.first?.days, 1)
        XCTAssertEqual(r.paybacks?.first?.status, "PENDING")
        XCTAssertEqual(r.claims?.first?.amount, 28.4)
        XCTAssertNil(try decode("{\(base)}").paybacks)
    }

    func testClockHistoryOnlyForPeopleWhoClockIn() throws {
        let staff = try decode("{\(base), \"intern\": false, \"mustClockIn\": false}")
        XCTAssertFalse(staff.showsClock(listIntern: nil))
        let intern = try decode("{\(base), \"intern\": true, \"mustClockIn\": true}")
        XCTAssertTrue(intern.showsClock(listIntern: false))
        // Older server: no flags, no balances; fall back to the Team list's intern flag.
        let old = try decode("{\(base)}")
        XCTAssertNil(old.balances)
        XCTAssertFalse(old.showsClock(listIntern: false))
        XCTAssertTrue(old.showsClock(listIntern: true))
    }
}
