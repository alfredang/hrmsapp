import XCTest
import EventKit
@testable import TertiaryHRMSiOSApp

/// Runs the real EventKit reconcile against a throwaway local calendar. Needs calendar access
/// for the test host (`xcrun simctl privacy <sim> grant calendar com.tertiaryinfotech.hrportal`);
/// skipped otherwise.
@MainActor
final class CalendarSyncEventKitTests: XCTestCase {
    func testReconcileAgainstLocalCalendar() throws {
        let sync = CalendarAutoSync.shared
        try XCTSkipUnless(sync.hasFullAccess, "No calendar access for the test host")
        let store = sync.store
        guard let source = store.sources.first(where: { $0.sourceType == .local }) ?? store.defaultCalendarForNewEvents?.source else {
            throw XCTSkip("No calendar source on this device")
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = "HRMS sync test"
        cal.source = source
        try store.saveCalendar(cal, commit: true)
        defer { try? store.removeCalendar(cal, commit: true) }

        let c = Calendar.current
        let day = c.startOfDay(for: Date())
        let window = c.date(byAdding: .day, value: -60, to: day)!...c.date(byAdding: .day, value: 366, to: day)!
        func items(_ title: String) -> [HRMSCalendarItem] {[
            HRMSCalendarItem(key: "leave:A", title: title, notes: "Annual Leave · 1 day", start: day, end: day, allDay: true),
            HRMSCalendarItem(key: "timeoff:B", title: "Time off 2–4pm", notes: "Exams",
                             start: c.date(byAdding: .hour, value: 14, to: day)!, end: c.date(byAdding: .hour, value: 16, to: day)!, allDay: false),
        ]}
        // A user's own event in the same calendar must never be touched.
        let mine = EKEvent(eventStore: store)
        mine.calendar = cal; mine.title = "Lunch with Ben"; mine.startDate = day; mine.endDate = day.addingTimeInterval(3600)
        try store.save(mine, span: .thisEvent, commit: true)

        func events() -> [EKEvent] {
            store.events(matching: store.predicateForEvents(withStart: window.lowerBound, end: window.upperBound, calendars: [cal]))
        }

        XCTAssertEqual(sync.apply(items: items("AL — Alfred Ang"), calendars: [cal], window: window), "2 added")
        XCTAssertEqual(sync.apply(items: items("AL — Alfred Ang"), calendars: [cal], window: window), "Up to date.")
        XCTAssertEqual(sync.apply(items: items("MC — Alfred Ang"), calendars: [cal], window: window), "1 updated")
        XCTAssertEqual(sync.apply(items: Array(items("MC — Alfred Ang").prefix(1)), calendars: [cal], window: window), "1 removed")

        let left = events()
        XCTAssertEqual(Set(left.compactMap(\.title)), ["MC — Alfred Ang", "Lunch with Ben"])
        XCTAssertEqual(left.first { $0.title == "MC — Alfred Ang" }.flatMap { HRMSCalendarSync.markerKey(in: $0.notes) }, "leave:A")

        // Turning sync off for this calendar removes only HRMS copies.
        XCTAssertEqual(sync.apply(items: [], calendars: [cal], window: window), "1 removed")
        XCTAssertEqual(events().compactMap(\.title), ["Lunch with Ben"])
    }
}
