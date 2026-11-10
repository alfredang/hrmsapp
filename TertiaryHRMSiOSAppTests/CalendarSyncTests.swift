import XCTest
@testable import TertiaryHRMSiOSApp

final class CalendarSyncTests: XCTestCase {
    private let cal = Calendar.current
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    private func item(_ key: String, title: String = "AL — Alfred Ang") -> HRMSCalendarItem {
        HRMSCalendarItem(key: key, title: title, notes: "Annual Leave · 1 day", start: d(2026, 11, 11), end: d(2026, 11, 11), allDay: true)
    }
    private func existing(_ id: String, cal calId: String, key: String, matching item: HRMSCalendarItem?) -> ExistingCalendarEvent {
        ExistingCalendarEvent(eventId: id, calendarId: calId, key: key, fingerprint: item?.fingerprint ?? "stale")
    }

    func testCreatesOneCopyPerCalendar() {
        let a = item("leave:1")
        let plan = HRMSCalendarSync.plan(items: [a], existing: [], calendarIds: ["work", "home"])
        XCTAssertEqual(plan, [.create(key: "leave:1", calendarId: "work"), .create(key: "leave:1", calendarId: "home")])
    }

    func testUpToDateCopyIsLeftAlone() {
        let a = item("leave:1")
        XCTAssertEqual(HRMSCalendarSync.plan(items: [a], existing: [existing("e1", cal: "work", key: "leave:1", matching: a)],
                                             calendarIds: ["work"]), [])
    }

    func testChangedItemIsUpdatedInPlace() {
        let a = item("leave:1", title: "MC — Alfred Ang")
        let plan = HRMSCalendarSync.plan(items: [a], existing: [existing("e1", cal: "work", key: "leave:1", matching: nil)],
                                         calendarIds: ["work"])
        XCTAssertEqual(plan, [.update(key: "leave:1", eventId: "e1")])
    }

    func testCancelledOrRejectedItemIsDeleted() {
        // leave:2 is no longer in HRMS (cancelled / rejected) → its copy goes.
        let a = item("leave:1")
        let plan = HRMSCalendarSync.plan(items: [a], existing: [existing("e1", cal: "work", key: "leave:1", matching: a),
                                                               existing("e2", cal: "work", key: "leave:2", matching: nil)],
                                         calendarIds: ["work"])
        XCTAssertEqual(plan, [.delete(eventId: "e2")])
    }

    func testDuplicatesCollapseToOne() {
        let a = item("leave:1")
        let plan = HRMSCalendarSync.plan(items: [a], existing: [existing("e1", cal: "work", key: "leave:1", matching: a),
                                                               existing("e9", cal: "work", key: "leave:1", matching: a)],
                                         calendarIds: ["work"])
        XCTAssertEqual(plan, [.delete(eventId: "e9")])
    }

    func testCopiesInUntickedCalendarAreRemoved() {
        let a = item("leave:1")
        let plan = HRMSCalendarSync.plan(items: [a], existing: [existing("e1", cal: "old", key: "leave:1", matching: a)],
                                         calendarIds: ["work"])
        XCTAssertEqual(plan, [.delete(eventId: "e1"), .create(key: "leave:1", calendarId: "work")])
    }

    func testMarkerParsingIgnoresOtherEvents() {
        XCTAssertEqual(HRMSCalendarSync.markerKey(in: "Annual Leave\n\nHRMS id: leave:abc"), "leave:abc")
        XCTAssertNil(HRMSCalendarSync.markerKey(in: "Lunch with Ben"))
        XCTAssertNil(HRMSCalendarSync.markerKey(in: nil))
    }

    func testAllDayFingerprintIgnoresEventKitEndOfDay() {
        let saved = item("leave:1")
        let endOfDay = cal.date(byAdding: .second, value: 86_399, to: d(2026, 11, 11))!
        let readBack = HRMSCalendarSync.fingerprint(title: saved.title, start: saved.start, end: endOfDay,
                                                    allDay: true, notes: saved.eventNotes)
        XCTAssertEqual(readBack, saved.fingerprint)
    }

    func testItemsHonourOptionsAndRoles() {
        let mine = TeamLeaveEntry(id: "1", employeeId: "E1", employeeName: "Alfred Ang", department: nil,
                                  startDate: "2026-11-11T00:00:00Z", endDate: "2026-11-12T00:00:00Z",
                                  days: 2, halfDay: false, leaveType: "Medical Leave", isSelf: true)
        let other = TeamLeaveEntry(id: "2", employeeId: "E2", employeeName: "Tan Mei Ling", department: "Ops",
                                   startDate: "2026-11-13", endDate: "2026-11-13",
                                   days: 1, halfDay: false, leaveType: "Annual Leave", isSelf: false)
        let hol = TeamHoliday(id: "h", title: "Deepavali", startDate: "2026-11-08", endDate: "2026-11-08")
        let window = d(2026, 1, 1)...d(2027, 12, 31)

        var opts = CalendarSyncOptions()   // defaults: own leave + own time off
        var items = HRMSCalendarSync.items(entries: [mine, other], holidays: [hol], timeOff: [], options: opts,
                                           isAdmin: false, window: window)
        XCTAssertEqual(items.map(\.key), ["leave:1"])
        XCTAssertEqual(items[0].title, "MC — Alfred Ang")
        XCTAssertTrue(items[0].allDay)
        XCTAssertEqual(items[0].end, d(2026, 11, 12))

        opts.holidays = true; opts.teamLeave = true
        items = HRMSCalendarSync.items(entries: [mine, other], holidays: [hol], timeOff: [], options: opts,
                                       isAdmin: false, window: window)
        XCTAssertEqual(Set(items.map(\.key)), ["leave:1", "holiday:2026-11-08"], "team leave is admins only")
        items = HRMSCalendarSync.items(entries: [mine, other], holidays: [hol], timeOff: [], options: opts,
                                       isAdmin: true, window: window)
        XCTAssertEqual(Set(items.map(\.key)), ["leave:1", "leave:2", "holiday:2026-11-08"])
    }

    func testTimeOffTitlesAndApprovedOnly() {
        XCTAssertEqual(HRMSCalendarSync.timeRange(HRMSCalendarSync.time("2026-11-11", "14:00")!,
                                                  HRMSCalendarSync.time("2026-11-11", "16:00")!), "2–4pm")
        XCTAssertEqual(HRMSCalendarSync.timeRange(HRMSCalendarSync.time("2026-11-11", "11:00")!,
                                                  HRMSCalendarSync.time("2026-11-11", "13:30")!), "11am–1:30pm")
        XCTAssertEqual(HRMSCalendarSync.leaveCode("Annual Leave"), "AL")
        XCTAssertEqual(HRMSCalendarSync.leaveCode("No Pay Leave"), "NPL")
        XCTAssertEqual(HRMSCalendarSync.leaveCode(nil), "Leave")
    }
}
