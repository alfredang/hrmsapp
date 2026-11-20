import XCTest
@testable import TertiaryHRMSiOSApp

/// `/api/mobile/analytics` decoding (shape of `AnalyticsData` in the web repo's
/// src/lib/analytics.ts) and the filter maths the Analytics screen shares between its
/// tiles, charts and lists. Also the team calendar's All / Staff / Interns filter.
final class AnalyticsTests: XCTestCase {

    private let json = #"""
    {"months":[{"key":"2026-09","label":"Sept","year":2026},{"key":"2026-10","label":"Oct","year":2026},{"key":"2026-11","label":"Nov","year":2026}],
     "finance":[{"month":"2026-10","type":"Income","revenue":1000.5,"expenses":0},
                {"month":"2026-10","type":"Payroll","revenue":0,"expenses":400},
                {"month":"2026-11","type":"Income","revenue":500,"expenses":0},
                {"month":"2026-11","type":"Rental","revenue":0,"expenses":100},
                {"month":"2026-01","type":"Income","revenue":9999,"expenses":0}],
     "financeRange":{"from":"2026-04-30","to":"2026-11-16"},
     "leave":[{"month":"2026-10","personId":"s1","category":"LEAVE","days":2},
              {"month":"2026-10","personId":"i1","category":"MC","days":1.5},
              {"month":"2026-11","personId":"i1","category":"NPL","days":1},
              {"month":"2026-11","personId":"s1","category":"SOMETHING_NEW","days":1},
              {"month":"2026-11","personId":"gone","category":"MC","days":7}],
     "people":[{"id":"s1","name":"STAFF ONE","code":"E0001","intern":false,"active":true},
               {"id":"i1","name":"INTERN ONE","code":"I0001","intern":true,"active":false}],
     "headcount":[{"month":"2026-09","staff":10,"interns":2},{"month":"2026-10","staff":10,"interns":4},{"month":"2026-11","staff":11,"interns":3}],
     "futureField":{"anything":true}}
    """#

    private func data(_ s: String? = nil) throws -> AnalyticsData {
        try JSONDecoder().decode(AnalyticsData.self, from: Data((s ?? json).utf8))
    }

    func testDecodesTheServerShapeAndIgnoresUnknownKeys() throws {
        let d = try data()
        XCTAssertEqual(d.months.map(\.key), ["2026-09", "2026-10", "2026-11"])
        XCTAssertEqual(d.months[0].title, "Sept 2026")
        XCTAssertEqual(d.finance?.count, 5)
        XCTAssertEqual(d.financeRange?.from, "2026-04-30")
        XCTAssertEqual(d.leave[3].category, .leave, "an unknown category counts as ordinary leave")
        XCTAssertEqual(d.people[1].active, false)
        XCTAssertEqual(d.headcount.last?.interns, 3)
    }

    func testFinanceMayBeNullAndListsMayBeMissing() throws {
        let d = try data(#"{"months":[{"key":"2026-11","label":"Nov","year":2026}],"finance":null,"financeRange":null}"#)
        XCTAssertNil(d.finance)
        XCTAssertTrue(d.leave.isEmpty && d.people.isEmpty && d.headcount.isEmpty)
        let s = AnalyticsSlice(d, AnalyticsFilter())
        XCTAssertFalse(s.hasFinance)
        XCTAssertEqual(s.headNow, 0)
    }

    func testDefaultSliceTotals() throws {
        let s = AnalyticsSlice(try data(), AnalyticsFilter())
        XCTAssertEqual(s.revenue, 1500.5, accuracy: 0.001, "the January row is outside the months sent")
        XCTAssertEqual(s.expenses, 500, accuracy: 0.001)
        XCTAssertEqual(s.net, 1000.5, accuracy: 0.001)
        XCTAssertEqual(s.leaveTotal(.leave), 3)       // 2 + the unknown category
        XCTAssertEqual(s.leaveTotal(.mc), 1.5, "leave for a person the server did not send is dropped")
        XCTAssertEqual(s.byPerson.map(\.person.id), ["s1", "i1"])
        XCTAssertEqual(s.headNow, 14)
        XCTAssertEqual(s.headDelta, 2)
        XCTAssertEqual(s.headcount.map(\.change), [nil, 2, 0])
        XCTAssertEqual(s.types.first?.type, "Income")
        XCTAssertEqual(s.rangeLabel, "Sept 2026 to Nov 2026")
    }

    func testPeriodWhoPersonAndTypeFilters() throws {
        let d = try data()
        var f = AnalyticsFilter(); f.period = 1
        var s = AnalyticsSlice(d, f)
        XCTAssertEqual(s.months.map(\.key), ["2026-11"])
        XCTAssertEqual(s.revenue, 500, accuracy: 0.001)
        XCTAssertEqual(s.leaveTotal(.npl), 1)

        f = AnalyticsFilter(); f.who = .interns
        s = AnalyticsSlice(d, f)
        XCTAssertEqual(s.byPerson.map(\.person.id), ["i1"])
        XCTAssertEqual(s.selectablePeople.map(\.id), ["i1"])
        XCTAssertEqual(s.headNow, 3)
        XCTAssertEqual(s.headcount.map(\.staff), [0, 0, 0])

        f.personId = "s1"   // a staff member is not selectable under Interns: ignored
        XCTAssertNil(AnalyticsSlice(d, f).person)

        f = AnalyticsFilter(); f.personId = "s1"; f.leaveOff = [.leave]
        s = AnalyticsSlice(d, f)
        XCTAssertEqual(s.person?.name, "STAFF ONE")
        XCTAssertTrue(s.byPerson.isEmpty)
        XCTAssertEqual(s.leaveSeries, [.mc, .npl])
        XCTAssertEqual(s.headNow, 14, "the person filter does not change headcount")

        f = AnalyticsFilter(); f.typeOff = ["Payroll"]
        s = AnalyticsSlice(d, f)
        XCTAssertEqual(s.expenses, 100, accuracy: 0.001)
        XCTAssertEqual(s.types.count, 3, "a hidden category stays in the list so it can be shown again")
        XCTAssertFalse(f.isDefault)
    }

    func testFormatting() {
        XCTAssertEqual(AnalyticsView.money(3_089_763.4), "$3,089,763")
        XCTAssertEqual(AnalyticsView.money(-189_557), "−$189,557")
        XCTAssertEqual(AnalyticsView.moneyAxis(1_200_000), "$1.2M")
        XCTAssertEqual(AnalyticsView.moneyAxis(400_000), "$400k")
        XCTAssertEqual(AnalyticsView.change(nil), "")
        XCTAssertEqual(AnalyticsView.change(3), "+3")
        XCTAssertEqual(AnalyticsView.change(-2), "−2")
    }

    func testPreviewDataIsConsistent() {
        let d = PreviewData.analytics
        XCTAssertEqual(d.months.count, 12)
        XCTAssertEqual(d.headcount.count, 12)
        let ids = Set(d.people.map(\.id))
        XCTAssertTrue(d.leave.allSatisfy { ids.contains($0.personId) })
    }

    // MARK: Push links for the decisions the server now notifies

    func testDecisionLinksOpenTheRightScreen() {
        XCTAssertEqual(PushRoute.from(link: "/expenses", isAdmin: false, mustClockIn: false), .expenses)
        XCTAssertEqual(PushRoute.from(link: "/expenses", isAdmin: true, mustClockIn: false), .expenses)
        XCTAssertEqual(PushRoute.from(link: "/leave", isAdmin: false, mustClockIn: true), .tab(1))
        XCTAssertEqual(PushRoute.from(link: "/time-off", isAdmin: false, mustClockIn: true), .timeOff)
        XCTAssertEqual(PushRoute.from(link: "/approvals", isAdmin: true, mustClockIn: false), .approvals)
    }

    /// Interns and accountants who must clock in open their own Timesheet; "/attendance" is the
    /// clock for everyone (missed clock-in reminders).
    func testTimesheetAndAttendanceLinks() {
        XCTAssertEqual(PushRoute.from(link: "/timesheet", isAdmin: false, mustClockIn: true), .myTimesheet)
        XCTAssertEqual(PushRoute.from(link: "/timesheet", isAdmin: true, mustClockIn: false), .adminTimesheet)
        XCTAssertEqual(PushRoute.from(link: "/timesheet", isAdmin: false, mustClockIn: false), .notifications)
        XCTAssertEqual(PushRoute.from(link: "/timesheet/overview", isAdmin: true, mustClockIn: false), .adminTimesheet)
        for (admin, clock) in [(false, true), (true, false), (false, false)] {
            XCTAssertEqual(PushRoute.from(link: "/attendance", isAdmin: admin, mustClockIn: clock), .clock)
        }
    }
}
