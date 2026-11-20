import XCTest
@testable import TertiaryHRMSiOSApp

/// Build 34 (20 Nov 2026): calendar colours + emoji, time off and Off Days, birthdays, off-day
/// shading, month totals; Work Schedule; Home leave / finance / trainer tiles; holiday emoji in
/// iPhone Calendar sync. Every new server field is optional: each shape is decoded with and
/// without it.
final class ParityBuild34Tests: XCTestCase {
    private let cal = TeamCalendarItem.calendar
    private func data(_ s: String) -> Data { Data(s.utf8) }
    /// Local noon, as the web tests build their dates.
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day, hour: 12))!
    }

    // MARK: - Team calendar decoding

    private let calendarJSON = #"""
    {"year":2026,"canSeeTypes":true,
     "entries":[
      {"id":"a","employeeId":"e1","employeeName":"DEEPA ARUMUGAM","department":"Ops","startDate":"2026-11-10T00:00:00.000Z","endDate":"2026-11-10T00:00:00.000Z","days":1,"halfDay":false,"leaveType":"Medical Leave","category":"MEDICAL_LEAVE","isSelf":false,"group":"staff"},
      {"id":"b","employeeId":"e2","employeeName":"EVAN PANG","department":null,"startDate":"2026-11-12T00:00:00.000Z","endDate":"2026-11-13T00:00:00.000Z","days":2,"halfDay":false,"leaveType":"No Pay Leave","category":"NO_PAY_LEAVE","isSelf":false,"group":"intern"}],
     "people":[{"id":"e1","name":"DEEPA ARUMUGAM","intern":false,"workdays":[1,2,3,4,5]},
               {"id":"e2","name":"EVAN PANG","intern":true,"workdays":[1,2,3,4]},
               {"id":"e3","name":"JYOTI CHOPRA","intern":false,"workdays":[]}],
     "holidays":[{"id":"h1","title":"🎄 Christmas Day","startDate":"2026-12-25T00:00:00.000Z","endDate":"2026-12-25T00:00:00.000Z"}],
     "timeOff":[
      {"id":"t1","employeeId":"e2","employeeName":"EVAN PANG","date":"2026-11-18T00:00:00.000Z","startTime":"14:00","endTime":"16:00","hours":2,"offDay":false,"isSelf":false,"group":"intern"},
      {"id":"t2","employeeId":"e2","employeeName":"EVAN PANG","date":"2026-11-19T00:00:00.000Z","startTime":"00:00","endTime":"00:00","hours":"0","offDay":true,"isSelf":false,"group":"intern"}],
     "birthdays":[{"id":"bd-e3-2026","employeeId":"e3","name":"JYOTI CHOPRA","date":"2026-11-26T04:00:00.000Z"},
                  {"id":"bd-e2-2026","employeeId":"e2","name":"EVAN PANG","date":"2026-11-05T04:00:00.000Z"}],
     "ownWorkdays":[1,2,3,4,5],
     "categories":[{"key":"HOLIDAY","label":"Public Holiday","color":"#ef4444","emoji":""},
                   {"key":"ANNUAL_LEAVE","label":"Annual Leave","color":"#f59e0b","emoji":"🏖️"},
                   {"key":"MEDICAL_LEAVE","label":"Medical Leave","color":"#ec4899","emoji":"🤒"},
                   {"key":"NO_PAY_LEAVE","label":"No Pay Leave","color":"#64748b","emoji":"💸"},
                   {"key":"OTHER_LEAVE","label":"Other Leave","color":"#9a6b4f","emoji":"📋"},
                   {"key":"TIME_OFF","label":"Time Off","color":"#06b6d4","emoji":"⏰"},
                   {"key":"BIRTHDAY","label":"Birthday","color":"#d946ef","emoji":"🎂"},
                   {"key":"MEETING","label":"Meeting","color":"#3b82f6","emoji":""}]}
    """#

    private func calendar() throws -> TeamCalendarResponse {
        try JSONDecoder().decode(TeamCalendarResponse.self, from: data(calendarJSON))
    }

    func testTeamCalendarDecodesTheNewFields() throws {
        let r = try calendar()
        XCTAssertEqual(r.entries.map(\.category), ["MEDICAL_LEAVE", "NO_PAY_LEAVE"])
        XCTAssertEqual(r.timeOff?.count, 2)
        XCTAssertEqual(r.timeOff?[0].startTime, "14:00")
        XCTAssertEqual(r.timeOff?[0].hours, 2)
        XCTAssertEqual(r.timeOff?[1].hours, 0, "hours sent as a string still decodes")
        XCTAssertEqual(r.timeOff?[1].offDay, true)
        XCTAssertEqual(r.timeOff?[0].group, "intern")
        XCTAssertEqual(r.birthdays?.map(\.name), ["JYOTI CHOPRA", "EVAN PANG"])
        XCTAssertEqual(r.people?[1].workdays, [1, 2, 3, 4])
        XCTAssertEqual(r.ownWorkdays, [1, 2, 3, 4, 5])
        XCTAssertEqual(r.categories?.count, 8)
        XCTAssertEqual(r.holidays.first?.title, "🎄 Christmas Day")
    }

    func testTeamCalendarFromAnOlderServerHasNoNewFields() throws {
        let body = #"{"year":2026,"canSeeTypes":false,"holidays":[],"entries":[{"id":"a","employeeId":"e1","employeeName":"A","department":null,"startDate":"2026-11-02","endDate":"2026-11-02","days":1,"halfDay":false,"leaveType":null,"isSelf":false}]}"#
        let r = try JSONDecoder().decode(TeamCalendarResponse.self, from: data(body))
        XCTAssertNil(r.timeOff); XCTAssertNil(r.birthdays); XCTAssertNil(r.ownWorkdays); XCTAssertNil(r.categories)
        XCTAssertNil(r.entries[0].category)
        XCTAssertNil(r.entries[0].resolvedCategory, "a colleague's hidden leave type keeps the neutral style")
    }

    func testAMalformedNewFieldDoesNotFailTheCalendar() throws {
        let body = #"{"year":2026,"canSeeTypes":true,"holidays":[],"entries":[],"timeOff":"oops","birthdays":[{"id":1}],"ownWorkdays":null}"#
        let r = try JSONDecoder().decode(TeamCalendarResponse.self, from: data(body))
        XCTAssertNil(r.timeOff)
        XCTAssertNil(r.birthdays)
        XCTAssertNil(r.ownWorkdays)
    }

    func testCategoryFromLeaveTypeOnAnOlderServer() {
        func entry(_ type: String?, category: String? = nil) -> TeamLeaveEntry {
            TeamLeaveEntry(id: "x", employeeId: "e", employeeName: "E", department: nil, startDate: "2026-11-02",
                           endDate: "2026-11-02", days: 1, halfDay: false, leaveType: type, isSelf: true, category: category)
        }
        XCTAssertEqual(entry("Annual Leave").resolvedCategory, "ANNUAL_LEAVE")
        XCTAssertEqual(entry("Medical Leave").resolvedCategory, "MEDICAL_LEAVE")
        XCTAssertEqual(entry("No Pay Leave").resolvedCategory, "NO_PAY_LEAVE")
        XCTAssertEqual(entry("Childcare Leave").resolvedCategory, "OTHER_LEAVE")
        XCTAssertEqual(entry("Annual Leave", category: "OTHER_LEAVE").resolvedCategory, "OTHER_LEAVE", "the server's category wins")
        XCTAssertNil(entry(nil).resolvedCategory)
    }

    // MARK: - Legend

    func testLegendUsesTheServerTableAndFallsBack() {
        let server = CalendarLegendTable([CalendarCategoryInfo(key: "ANNUAL_LEAVE", label: "Annual Leave", color: "#112233", emoji: "🌴"),
                                          CalendarCategoryInfo(key: "TIME_OFF", label: "Time Off", color: "bad", emoji: "x")])
        XCTAssertEqual(server.hex("ANNUAL_LEAVE"), 0x112233)
        XCTAssertEqual(server.emoji("ANNUAL_LEAVE"), "🌴")
        XCTAssertEqual(server.hex("TIME_OFF"), 0x06B6D4, "a bad colour falls back to the built-in row")
        XCTAssertEqual(server.emoji("TIME_OFF"), "⏰")
        let none = CalendarLegendTable(nil)
        XCTAssertEqual(none.rows.map(\.key), CalendarCategory.fallback.map(\.key))
        XCTAssertEqual(none.hex("MEDICAL_LEAVE"), 0xEC4899)
        XCTAssertEqual(none.emoji("NO_PAY_LEAVE"), "💸")
        XCTAssertEqual(none.emoji("OTHER_LEAVE"), "📋")
        XCTAssertEqual(none.emoji("BIRTHDAY"), "🎂")
        XCTAssertEqual(none.emoji("HOLIDAY"), "")
        XCTAssertEqual(none.hex("UNKNOWN"), 0x6B7280)
        // The web's chip text: each channel × (1 − 0.45), rounded.
        XCTAssertEqual(CalendarLegendTable.darken(0xEF4444, 0.45), 0x832525)
    }

    // MARK: - Items and filters

    func testItemsCarryTheCategoryEmojiAndNames() throws {
        let r = try calendar()
        let people = TeamCalendarPeople(r)
        let legend = CalendarLegendTable(r.categories)
        let items = TeamCalendarItem.build(TeamCalendarVisible(r, people: people, personId: nil, mineOnly: false),
                                           legend: legend, isApprover: true, calendar: cal)
        XCTAssertEqual(items.map(\.title), [
            "🤒 DEEPA ARUMUGAM", "💸 EVAN PANG",
            "⏰ EVAN PANG - Time off 2:00 PM – 4:00 PM", "⏰ EVAN PANG - Off Day",
            "🎂 JYOTI CHOPRA birthday", "🎂 EVAN PANG birthday",
        ])
        XCTAssertEqual(items.map(\.chip), ["🤒 DEEPA", "💸 EVAN", "⏰ EVAN", "⏰ EVAN", "🎂 JYOTI", "🎂 EVAN"])
        XCTAssertEqual(items.map(\.category), ["MEDICAL_LEAVE", "NO_PAY_LEAVE", "TIME_OFF", "TIME_OFF", "BIRTHDAY", "BIRTHDAY"])
        XCTAssertEqual(items[2].detail, "Time Off · 2 h")
        XCTAssertEqual(items[3].detail, "Off Day · Full day")
        XCTAssertEqual(items[1].start, cal.startOfDay(for: d(2026, 11, 12)))
        XCTAssertEqual(items[1].end, cal.startOfDay(for: d(2026, 11, 13)))
    }

    func testStaffSeeTheirOwnTimeOffWithoutNameAndColleaguesNeutral() {
        let r = TeamCalendarResponse(
            year: 2026, canSeeTypes: false,
            entries: [
                TeamLeaveEntry(id: "a", employeeId: "me", employeeName: "ME", department: nil, startDate: "2026-11-02",
                               endDate: "2026-11-02", days: 1, halfDay: false, leaveType: "Annual Leave", isSelf: true,
                               category: "ANNUAL_LEAVE"),
                TeamLeaveEntry(id: "b", employeeId: "c", employeeName: "COLLEAGUE ONE", department: nil, startDate: "2026-11-03",
                               endDate: "2026-11-03", days: 1, halfDay: false, leaveType: nil, isSelf: false),
            ],
            holidays: [],
            timeOff: [TeamTimeOffEntry(id: "t", employeeId: "me", employeeName: "ME", date: "2026-11-04T00:00:00.000Z",
                                       startTime: "09:30", endTime: "11:00", hours: 1.5, offDay: false, isSelf: true)])
        let people = TeamCalendarPeople(r)
        XCTAssertFalse(people.isAvailable)
        let items = TeamCalendarItem.build(TeamCalendarVisible(r, people: people, personId: nil, mineOnly: false),
                                           legend: CalendarLegendTable(nil), isApprover: false, calendar: cal)
        XCTAssertEqual(items.map(\.title), ["🏖️ You", "COLLEAGUE ONE", "⏰ Time off 9:30 AM – 11:00 AM"])
        XCTAssertEqual(items.map(\.chip), ["🏖️ You", "COLLEAGUE", "⏰ You"])
        XCTAssertNil(items[1].category)
        XCTAssertEqual(items[2].detail, "Time Off · 1.5 h")
    }

    func testPersonFilterAndOnlyMeApplyToTimeOffAndBirthdays() throws {
        let r = try calendar()
        let people = TeamCalendarPeople(r)
        // Counts include time off, as the web list.
        XCTAssertEqual(people.option("e2")?.label, "EVAN PANG (3)")
        XCTAssertEqual(people.option("e3")?.label, "JYOTI CHOPRA")

        let evan = TeamCalendarVisible(r, people: people, personId: "e2", mineOnly: false)
        XCTAssertEqual(evan.entries.map(\.id), ["b"])
        XCTAssertEqual(evan.timeOff.map(\.id), ["t1", "t2"])
        XCTAssertEqual(evan.birthdays.map(\.employeeId), ["e2"], "a picked person shows only their birthday")

        let jyoti = TeamCalendarVisible(r, people: people, personId: "e3", mineOnly: false)
        XCTAssertTrue(jyoti.entries.isEmpty && jyoti.timeOff.isEmpty)
        XCTAssertEqual(jyoti.birthdays.count, 1)

        let everyone = TeamCalendarVisible(r, people: people, personId: nil, mineOnly: false)
        XCTAssertEqual(everyone.birthdays.count, 2)
        XCTAssertEqual(everyone.timeOff.count, 2)

        let mine = TeamCalendarVisible(r, people: people, personId: nil, mineOnly: true)
        XCTAssertTrue(mine.entries.isEmpty && mine.timeOff.isEmpty && mine.birthdays.isEmpty)
    }

    func testOlderServerRosterIncludesPeopleWithOnlyTimeOff() {
        let r = TeamCalendarResponse(year: 2026, canSeeTypes: true, entries: [], holidays: [],
                                     timeOff: [TeamTimeOffEntry(id: "t", employeeId: "i1", employeeName: "INTERN", date: "2026-11-04",
                                                                startTime: "09:00", endTime: "10:00", hours: 1, offDay: false,
                                                                isSelf: false, group: "intern")])
        let people = TeamCalendarPeople(r)
        XCTAssertEqual(people.groups.map(\.title), ["Interns"])
        XCTAssertEqual(people.all.map(\.label), ["INTERN (1)"])
    }

    // MARK: - Off-day shading

    func testOffDayShadingRule() throws {
        let r = try calendar()
        // Approver, Everyone: no single schedule, nothing shaded.
        XCTAssertNil(OffDayShading.make(r, isApprover: true, personId: nil, mineOnly: false))
        // Approver picks Evan (Mon–Thu): Fridays and weekends are off, and his full-day Off Day.
        let evan = try XCTUnwrap(OffDayShading.make(r, isApprover: true, personId: "e2", mineOnly: false))
        XCTAssertEqual(evan.workdays, [1, 2, 3, 4])
        XCTAssertFalse(evan.isOff(d(2026, 11, 16), calendar: cal), "Mon")
        XCTAssertTrue(evan.isOff(d(2026, 11, 20), calendar: cal), "Fri is not one of his workdays")
        XCTAssertTrue(evan.isOff(d(2026, 11, 22), calendar: cal), "Sun")
        XCTAssertTrue(evan.isOff(d(2026, 11, 19), calendar: cal), "Thu holds an approved Off Day")
        XCTAssertFalse(evan.isOff(d(2026, 11, 18), calendar: cal), "hourly time off is not an off day")
        // A person with no workdays on record gets Mon–Fri.
        let jyoti = try XCTUnwrap(OffDayShading.make(r, isApprover: true, personId: "e3", mineOnly: false))
        XCTAssertEqual(jyoti.workdays, OffDayShading.defaultWorkdays)
        XCTAssertTrue(jyoti.isOff(d(2026, 11, 21), calendar: cal), "Sat")
        XCTAssertFalse(jyoti.isOff(d(2026, 11, 20), calendar: cal), "Fri")
        // Approver on Only me: their own schedule.
        XCTAssertEqual(OffDayShading.make(r, isApprover: true, personId: nil, mineOnly: true)?.workdays, [1, 2, 3, 4, 5])
    }

    func testStaffShadeTheirOwnScheduleOnlyWhenTheServerSendsIt() {
        let base = TeamCalendarResponse(year: 2026, canSeeTypes: false, entries: [], holidays: [])
        XCTAssertNil(OffDayShading.make(base, isApprover: false, personId: nil, mineOnly: false), "older server: no shading")
        var r = base
        r.ownWorkdays = [2, 3, 4, 5, 6]   // Tue–Sat
        r.timeOff = [TeamTimeOffEntry(id: "t", employeeId: "me", employeeName: "ME", date: "2026-11-18T00:00:00.000Z",
                                      startTime: "00:00", endTime: "00:00", hours: 0, offDay: true, isSelf: true)]
        let s = OffDayShading.make(r, isApprover: false, personId: nil, mineOnly: false)
        XCTAssertNotNil(s)
        XCTAssertTrue(s!.isOff(d(2026, 11, 16), calendar: cal), "Mon is off")
        XCTAssertFalse(s!.isOff(d(2026, 11, 21), calendar: cal), "Sat is a workday")
        XCTAssertTrue(s!.isOff(d(2026, 11, 18), calendar: cal), "Wed Off Day")
        r.ownWorkdays = []
        XCTAssertEqual(OffDayShading.make(r, isApprover: false, personId: nil, mineOnly: false)?.workdays, [1, 2, 3, 4, 5])
        XCTAssertEqual(OffDayShading.isoWeekday(d(2026, 11, 22), cal), 7)
        XCTAssertEqual(OffDayShading.isoWeekday(d(2026, 11, 16), cal), 1)
    }

    // MARK: - Month totals (same cases as the server's calendar-summary.test.ts)

    private func leave(_ category: String, _ start: Date, _ end: Date, _ days: Double, _ personId: String = "p1") -> CalendarSummaryEvent {
        CalendarSummaryEvent(category: category, start: start, end: end, allDay: true, personId: personId, days: days)
    }

    func testMonthSummaryAddsUpEachKindForThePerson() {
        let events: [CalendarSummaryEvent] = [
            leave("ANNUAL_LEAVE", d(2026, 11, 2), d(2026, 11, 3), 2),
            leave("ANNUAL_LEAVE", d(2026, 11, 6), d(2026, 11, 6), 0.5),
            leave("MEDICAL_LEAVE", d(2026, 11, 10), d(2026, 11, 10), 1),
            leave("NO_PAY_LEAVE", d(2026, 11, 12), d(2026, 11, 13), 2),
            leave("OTHER_LEAVE", d(2026, 11, 16), d(2026, 11, 16), 1),
            CalendarSummaryEvent(category: "TIME_OFF", start: d(2026, 11, 18), end: d(2026, 11, 18), allDay: false, personId: "p1", hours: 2.5),
            CalendarSummaryEvent(category: "TIME_OFF", start: d(2026, 11, 19), end: d(2026, 11, 19), allDay: false, personId: "p1", hours: 1),
            CalendarSummaryEvent(category: "TIME_OFF", start: d(2026, 11, 20), end: d(2026, 11, 20), allDay: true, personId: "p1", hours: 0),
        ]
        XCTAssertEqual(CalendarMonthSummary.personMonthSummary(events, personId: "p1", year: 2026, month: 11, calendar: cal),
                       PersonMonthSummary(annualLeaveDays: 2.5, medicalLeaveDays: 1, noPayLeaveDays: 2, otherLeaveDays: 1,
                                          timeOffHours: 3.5, offDays: 1))
    }

    func testMonthSummaryIgnoresOtherPeopleMonthsAndNonLeave() {
        let events: [CalendarSummaryEvent] = [
            leave("ANNUAL_LEAVE", d(2026, 11, 2), d(2026, 11, 2), 1, "p2"),
            leave("ANNUAL_LEAVE", d(2026, 10, 26), d(2026, 10, 26), 1),
            CalendarSummaryEvent(category: "MEETING", start: d(2026, 11, 4), end: d(2026, 11, 4), allDay: false, personId: "p1"),
            CalendarSummaryEvent(category: "TIME_OFF", start: d(2026, 12, 1), end: d(2026, 12, 1), allDay: false, personId: "p1", hours: 2),
        ]
        XCTAssertEqual(CalendarMonthSummary.personMonthSummary(events, personId: "p1", year: 2026, month: 11, calendar: cal),
                       PersonMonthSummary())
    }

    func testMonthSummarySplitsLeaveAcrossTheMonthEndByWorkingDays() {
        // Thu 29 Oct – Tue 3 Nov 2026: 4 working days (29, 30 Oct; 2, 3 Nov).
        let events = [leave("ANNUAL_LEAVE", d(2026, 10, 29), d(2026, 11, 3), 4)]
        XCTAssertEqual(CalendarMonthSummary.personMonthSummary(events, personId: "p1", year: 2026, month: 10, calendar: cal).annualLeaveDays, 2)
        XCTAssertEqual(CalendarMonthSummary.personMonthSummary(events, personId: "p1", year: 2026, month: 11, calendar: cal).annualLeaveDays, 2)
    }

    func testMonthSummaryLeavesPublicHolidaysOutOfTheSplit() {
        // Fri 30 Oct – Tue 3 Nov, with Mon 2 Nov a holiday: 2 working days, one in each month.
        let events = [leave("MEDICAL_LEAVE", d(2026, 10, 30), d(2026, 11, 3), 2)]
        let holidays: Set<String> = ["2026-11-02"]
        XCTAssertEqual(CalendarMonthSummary.personMonthSummary(events, personId: "p1", year: 2026, month: 10,
                                                               holidayKeys: holidays, calendar: cal).medicalLeaveDays, 1)
        XCTAssertEqual(CalendarMonthSummary.personMonthSummary(events, personId: "p1", year: 2026, month: 11,
                                                               holidayKeys: holidays, calendar: cal).medicalLeaveDays, 1)
    }

    func testMonthTotalsFromTheResponseAndTheirChips() throws {
        let r = try calendar()
        let s = CalendarMonthSummary.personMonthSummary(CalendarMonthSummary.events(r, calendar: cal), personId: "e2",
                                                        year: 2026, month: 11,
                                                        holidayKeys: CalendarMonthSummary.holidayKeys(r, calendar: cal), calendar: cal)
        XCTAssertEqual(s, PersonMonthSummary(noPayLeaveDays: 2, timeOffHours: 2, offDays: 1))
        XCTAssertEqual(CalendarMonthSummary.tiles(s).map { "\($0.label): \($0.value)" },
                       ["Annual Leave: 0 days", "Medical Leave: 0 days", "No Pay Leave: 2 days", "Time Off: 2 h + 1 off day"])
        let more = PersonMonthSummary(annualLeaveDays: 1, medicalLeaveDays: 0.5, otherLeaveDays: 0.33, timeOffHours: 3.5, offDays: 2)
        XCTAssertEqual(CalendarMonthSummary.tiles(more).map(\.value), ["1 day", "0.5 days", "0 days", "0.33 days", "3.5 h + 2 off days"])
        XCTAssertEqual(CalendarMonthSummary.holidayKeys(r, calendar: cal), ["2026-12-25"])
    }

    // MARK: - Profile: Work Schedule

    private let profileBase = #""id":"x","employeeId":"E1","name":"A","email":"a@b.c","phone":null,"position":"Trainer","department":"Training","employmentType":"FULL_TIME","nationality":"SG","gender":"F","dateOfBirth":null,"address":null,"startDate":null,"endDate":null,"status":"ACTIVE","avatarUrl":null,"monthlyLeaveRate":null,"roles":["STAFF"],"role":"STAFF""#

    func testProfileWorkSchedule() throws {
        let body = #"{"employee":{"# + profileBase + #","workdays":[1,2,3,4],"workingDays":["Mon","Tue","Wed","Thu"],"offDays":["Fri","Sat","Sun"],"officeHours":"9am to 6pm"}}"#
        let e = try XCTUnwrap(JSONDecoder().decode(ProfileResponse.self, from: data(body)).employee)
        XCTAssertEqual(e.workdays, [1, 2, 3, 4])
        let rows = try XCTUnwrap(e.workSchedule)
        XCTAssertEqual(rows.map { $0.label }, ["Title", "Department", "Working hours", "Working days", "Off days"])
        XCTAssertEqual(rows.map { $0.value }, ["Trainer", "Training", "9am to 6pm", "Mon, Tue, Wed, Thu", "Fri, Sat, Sun"])
    }

    func testProfileWithoutScheduleHidesTheCard() throws {
        let old = try XCTUnwrap(JSONDecoder().decode(ProfileResponse.self, from: data(#"{"employee":{"# + profileBase + "}}")).employee)
        XCTAssertNil(old.workSchedule)
        // Only `workdays` sent: the day names are worked out from it.
        let some = try XCTUnwrap(JSONDecoder().decode(ProfileResponse.self, from: data(#"{"employee":{"# + profileBase + #","workdays":[2,3,4,5,6]}}"#)).employee)
        XCTAssertEqual(some.workSchedule.map { $0.suffix(2).map { $0.value } }, ["Tue, Wed, Thu, Fri, Sat", "Mon, Sun"])
    }

    // MARK: - Summary: leave tiles, finance, trainers

    private let summaryBase = #""name":"A","role":"STAFF","isAdmin":false,"alAvailable":1,"mcAvailable":2,"otRemaining":0,"expenseYtd":0,"pendingLeaves":0,"pendingClaims":0"#

    func testSummaryDecodesTheRoleTiles() throws {
        let body = "{" + summaryBase + #","leaveSummary":[{"label":"Paid leave taken","value":"3 days"},{"label":"Annual leave balance","value":"-"},{"label":"MC taken","value":"1 day"},{"label":"No-pay leave taken","value":"2 days","hint":"12 of 14 left"}],"financeKpis":{"pendingClaims":3,"pendingClaimsAmount":245.5,"incomeMonth":142900,"incomeYtd":3123000.25,"expensesMonth":80000,"expensesYtd":900000,"monthLabel":"Nov","year":2026},"trainerKpis":{"total":128,"aclp":74,"nonAclp":54}}"#
        let s = try JSONDecoder().decode(DashboardSummary.self, from: data(body))
        XCTAssertEqual(s.leaveSummary?.map(\.label), ["Paid leave taken", "Annual leave balance", "MC taken", "No-pay leave taken"])
        XCTAssertEqual(s.leaveSummary?.last?.hint, "12 of 14 left")
        XCTAssertNil(s.leaveSummary?.first?.hint)
        XCTAssertEqual(s.financeKpis, FinanceKpis(pendingClaims: 3, pendingClaimsAmount: 245.5, incomeMonth: 142900, incomeYtd: 3123000.25,
                                                  expensesMonth: 80000, expensesYtd: 900000, monthLabel: "Nov", year: 2026))
        XCTAssertEqual(s.trainerKpis, TrainerKpis(total: 128, aclp: 74, nonAclp: 54))
    }

    func testSummaryWithoutOrWithBrokenRoleTilesStillDecodes() throws {
        let old = try JSONDecoder().decode(DashboardSummary.self, from: data("{" + summaryBase + "}"))
        XCTAssertNil(old.leaveSummary); XCTAssertNil(old.financeKpis); XCTAssertNil(old.trainerKpis)
        let nulls = try JSONDecoder().decode(DashboardSummary.self, from: data("{" + summaryBase + #","leaveSummary":null,"financeKpis":null,"trainerKpis":null}"#))
        XCTAssertNil(nulls.leaveSummary); XCTAssertNil(nulls.financeKpis); XCTAssertNil(nulls.trainerKpis)
        let broken = try JSONDecoder().decode(DashboardSummary.self, from: data("{" + summaryBase + #","financeKpis":{"pendingClaims":"x"},"leaveSummary":[{"label":"Paid leave taken","value":3}]}"#))
        XCTAssertNil(broken.financeKpis, "an unreadable finance block hides its tiles, not Home")
        XCTAssertEqual(broken.leaveSummary?.first?.value, "3", "a numeric value is shown as text")
        XCTAssertEqual(broken.alAvailable, 1)
    }

    // MARK: - No Pay Leave is a flat 14 days

    func testNplCapNoteSays14Days() {
        XCTAssertEqual(LeaveRules.nplAnnualCapDays, 14)
        XCTAssertTrue(LeaveRules.nplCapNote.contains("14 days a year"))
        XCTAssertFalse(LeaveRules.nplCapNote.contains("21"))
        XCTAssertFalse(LeaveRules.nplCapNote.lowercased().contains("prorat"))
    }

    // MARK: - iPhone Calendar sync: emoji holiday titles update in place

    func testEmojiHolidayTitleUpdatesTheExistingEventInPlace() {
        let window = d(2026, 1, 1)...d(2027, 12, 31)
        let opts = CalendarSyncOptions(ownLeave: false, ownTimeOff: false, holidays: true, teamLeave: false)
        func items(_ title: String) -> [HRMSCalendarItem] {
            HRMSCalendarSync.items(entries: [], holidays: [TeamHoliday(id: "h", title: title, startDate: "2026-12-25T00:00:00.000Z",
                                                                       endDate: "2026-12-25T00:00:00.000Z")],
                                   timeOff: [], options: opts, isAdmin: false, window: window)
        }
        let old = items("Christmas Day"), new = items("🎄 Christmas Day")
        XCTAssertEqual(old.map(\.key), ["holiday:2026-12-25"])
        XCTAssertEqual(new.map(\.key), old.map(\.key), "the key is the date, not the title")
        let existing = [ExistingCalendarEvent(eventId: "ev1", calendarId: "work", key: old[0].key, fingerprint: old[0].fingerprint)]
        XCTAssertEqual(HRMSCalendarSync.plan(items: new, existing: existing, calendarIds: ["work"]),
                       [.update(key: "holiday:2026-12-25", eventId: "ev1")], "renamed in place: no duplicate, no delete")
        // The same holiday from two years' responses (year overlap) is still one event.
        let twice = HRMSCalendarSync.items(entries: [], holidays: [
            TeamHoliday(id: "a", title: "🎄 Christmas Day", startDate: "2026-12-25T00:00:00.000Z", endDate: nil),
            TeamHoliday(id: "b", title: "🎄 Christmas Day", startDate: "2026-12-25T00:00:00.000Z", endDate: nil),
        ], timeOff: [], options: opts, isAdmin: false, window: window)
        XCTAssertEqual(twice.count, 1)
    }
}
