import XCTest
@testable import TertiaryHRMSiOSApp

/// Build 33 (20 Nov 2026): calendar person filter, workforce breakdown, trainer KPI tiles,
/// staff / intern lists. Every new server field is optional; these tests decode the JSON
/// shapes the server sends now, and the older shapes without the new fields.
final class ParityBuild33Tests: XCTestCase {

    // MARK: Team calendar: "Leave shown for"

    private func entry(_ id: String, _ emp: String, _ name: String, group: String? = nil, isSelf: Bool = false) -> TeamLeaveEntry {
        TeamLeaveEntry(id: id, employeeId: emp, employeeName: name, department: nil, startDate: "2026-11-02",
                       endDate: "2026-11-02", days: 1, halfDay: false, leaveType: nil, isSelf: isSelf, group: group)
    }

    func testCalendarPeopleDecodeAndListActivePeopleWithCounts() throws {
        let body = #"""
        {"year":2026,"canSeeTypes":true,"holidays":[],
         "people":[{"id":"e2","name":"Ben","intern":true},{"id":"e4","name":"Dora","intern":false},
                   {"id":"e1","name":"alice","intern":false},{"id":"e5","name":"Eve","intern":true}],
         "entries":[
          {"id":"a","employeeId":"e1","employeeName":"alice","department":null,"startDate":"2026-11-02","endDate":"2026-11-02","days":1,"halfDay":false,"leaveType":"Annual Leave","isSelf":false,"group":"staff"},
          {"id":"b","employeeId":"e2","employeeName":"Ben","department":null,"startDate":"2026-11-03","endDate":"2026-11-03","days":1,"halfDay":false,"leaveType":"Medical Leave","isSelf":false,"group":"intern"},
          {"id":"c","employeeId":"e1","employeeName":"alice","department":null,"startDate":"2026-11-04","endDate":"2026-11-04","days":1,"halfDay":false,"leaveType":"Annual Leave","isSelf":false,"group":"staff"},
          {"id":"d","employeeId":"e9","employeeName":"Left Person","department":null,"startDate":"2026-11-05","endDate":"2026-11-05","days":1,"halfDay":false,"leaveType":"Annual Leave","isSelf":false,"group":"staff"}]}
        """#
        let r = try JSONDecoder().decode(TeamCalendarResponse.self, from: Data(body.utf8))
        XCTAssertEqual(r.people?.count, 4)
        let p = TeamCalendarPeople(r)
        XCTAssertTrue(p.isAvailable)
        XCTAssertEqual(p.groups.map(\.title), ["Staff", "Interns"])
        // Sorted by name within a group; people without leave are listed; a leaver is not.
        XCTAssertEqual(p.groups[0].options.map(\.label), ["alice (2)", "Dora"])
        XCTAssertEqual(p.groups[1].options.map(\.label), ["Ben (1)", "Eve"])
        XCTAssertNil(p.option("e9"))
        // Everyone still includes the leaver's leave; one person shows only theirs.
        XCTAssertEqual(p.filter(r.entries, personId: nil).count, 4)
        XCTAssertEqual(p.filter(r.entries, personId: "e1").map(\.id), ["a", "c"])
        XCTAssertTrue(p.filter(r.entries, personId: "e4").isEmpty, "an active person without leave shows nothing")
        // A stale selection (not in the list) falls back to everyone.
        XCTAssertEqual(p.filter(r.entries, personId: "e9").count, 4)
    }

    func testCalendarPeopleFallBackToEntriesOnAnOlderServer() throws {
        // Approver, server without `people`: built from the entries, grouped by their tag.
        let body = #"""
        {"year":2026,"canSeeTypes":true,"holidays":[],"entries":[
          {"id":"a","employeeId":"e1","employeeName":"A","department":null,"startDate":"2026-11-02","endDate":"2026-11-02","days":1,"halfDay":false,"leaveType":"Annual Leave","isSelf":false,"group":"staff"},
          {"id":"b","employeeId":"e2","employeeName":"B","department":null,"startDate":"2026-11-03","endDate":"2026-11-03","days":1,"halfDay":false,"leaveType":"Medical Leave","isSelf":false,"group":"intern"},
          {"id":"c","employeeId":"e1","employeeName":"A","department":null,"startDate":"2026-11-04","endDate":"2026-11-04","days":1,"halfDay":false,"leaveType":"Annual Leave","isSelf":true,"group":"staff"}]}
        """#
        let r = try JSONDecoder().decode(TeamCalendarResponse.self, from: Data(body.utf8))
        XCTAssertNil(r.people)
        let p = TeamCalendarPeople(r)
        XCTAssertEqual(p.groups.map(\.title), ["Staff", "Interns"])
        XCTAssertEqual(p.all.map(\.label), ["A (2)", "B (1)"])
        XCTAssertEqual(p.filter(r.entries, personId: "e2").map(\.id), ["b"])
    }

    func testCalendarHasNoPersonFilterForNonApprovers() throws {
        // `people` is null and nothing is tagged: no filter, whatever the entries are.
        let body = #"""
        {"year":2026,"canSeeTypes":false,"holidays":[],"people":null,"entries":[
          {"id":"a","employeeId":"e1","employeeName":"A","department":null,"startDate":"2026-11-02","endDate":"2026-11-02","days":1,"halfDay":false,"leaveType":null,"isSelf":false,"group":null}]}
        """#
        let r = try JSONDecoder().decode(TeamCalendarResponse.self, from: Data(body.utf8))
        XCTAssertNil(r.people)
        XCTAssertNil(r.entries[0].group)
        let p = TeamCalendarPeople(r)
        XCTAssertFalse(p.isAvailable)
        XCTAssertEqual(p.filter(r.entries, personId: "e1").count, 1)
    }

    func testCalendarPreviewListsActivePeopleOnly() {
        let p = TeamCalendarPeople(PreviewData.teamCalendar)
        // Since build 34 the counts include approved time off (as the web): Alfred 2 leave + 1
        // time off, Evan 2 time off (an Off Day and an hourly one).
        XCTAssertEqual(p.groups[0].options.map(\.label), ["Alfred Ang (3)", "Jyoti Chopra", "Tan Yong Huat (2)"])
        XCTAssertEqual(p.groups[1].options.map(\.label), ["Amanda Halim (2)", "Evan Pang (2)", "Femina Jasmin (2)"])
        XCTAssertNil(p.option("E0005"), "Cheryl Lim has left")
    }

    // MARK: Analytics: workforce breakdown

    private let analyticsBase = #""months":[{"key":"2026-11","label":"Nov","year":2026}],"finance":null,"leave":[],"people":[],"headcount":[{"month":"2026-11","staff":3,"interns":2}]"#

    func testBreakdownDecodesAndCountsInFixedOrder() throws {
        let body = "{\(analyticsBase)," + #"""
        "breakdown":[
          {"intern":false,"gender":"Female","ageGroup":"35–44","ethnicGroup":"Malay"},
          {"intern":false,"gender":"Male","ageGroup":"25–34","ethnicGroup":"Chinese"},
          {"intern":false,"gender":"Male","ageGroup":"55 and over","ethnicGroup":"Not recorded"},
          {"intern":true,"gender":"Female","ageGroup":"Under 25","ethnicGroup":"Not recorded"},
          {"intern":true,"gender":"Male","ageGroup":"Not recorded","ethnicGroup":"Not recorded"}]}
        """#
        let d = try JSONDecoder().decode(AnalyticsData.self, from: Data(body.utf8))
        let people = try XCTUnwrap(d.breakdown)
        XCTAssertEqual(people.count, 5)

        let staff = WorkforceBreakdown(people, who: .staff)
        XCTAssertEqual(staff.count, 3)
        XCTAssertEqual(staff.noun, "staff")
        XCTAssertEqual(staff.charts.map(\.title), ["Gender", "Age group", "Ethnic group"])
        let gender = staff.charts[0]
        XCTAssertEqual(gender.slices.map(\.label), ["Male", "Female"])
        XCTAssertEqual(gender.slices.map(\.count), [2, 1])
        XCTAssertEqual(gender.slices.map(\.colorHex), [0x5B82F0, 0x22978B])
        XCTAssertEqual(gender.percent(gender.slices[0]), "67%")
        XCTAssertEqual(gender.percent(gender.slices[1]), "33%")
        // Age keeps its ramp position even when earlier groups are empty.
        XCTAssertEqual(staff.charts[1].slices.map(\.label), ["25–34", "35–44", "55 and over"])
        XCTAssertEqual(staff.charts[1].slices.map(\.colorHex), [0x7F9DF3, 0x5B82F0, 0x2A47A8])
        // "Not recorded" is last and grey.
        XCTAssertEqual(staff.charts[2].slices.map(\.label), ["Chinese", "Malay", "Not recorded"])
        XCTAssertEqual(staff.charts[2].slices.map(\.colorHex), [0x5B82F0, 0x22978B, nil])
        XCTAssertEqual(staff.ethnicMissing, 1)
        XCTAssertEqual(staff.ethnicNote, "Ethnic group is not recorded for 1 of 3 staff. Set it on each person's page in Staff Management on the web.")

        let interns = WorkforceBreakdown(people, who: .interns)
        XCTAssertEqual(interns.count, 2)
        XCTAssertEqual(interns.charts[1].slices.map(\.label), ["Under 25", "Not recorded"])
        XCTAssertEqual(interns.charts[2].slices, [.init(label: "Not recorded", count: 2, colorHex: nil)])
        XCTAssertEqual(interns.ethnicNote, "Ethnic group is not recorded for any of the 2 interns. Set it on each person's page in Staff Management on the web.")

        let all = WorkforceBreakdown(people, who: .all)
        XCTAssertEqual(all.count, 5)
        XCTAssertEqual(all.noun, "people")
        XCTAssertEqual(all.charts.map(\.total), [5, 5, 5])
        XCTAssertEqual(d.activeCounts?.staff, 3)
        XCTAssertEqual(d.activeCounts?.interns, 2)
    }

    func testBreakdownIsNilWhenNullOrAbsent() throws {
        let absent = try JSONDecoder().decode(AnalyticsData.self, from: Data("{\(analyticsBase)}".utf8))
        XCTAssertNil(absent.breakdown)
        let null = try JSONDecoder().decode(AnalyticsData.self, from: Data("{\(analyticsBase),\"breakdown\":null}".utf8))
        XCTAssertNil(null.breakdown)
        // Home tiles then use the latest headcount month.
        XCTAssertEqual(absent.activeCounts?.staff, 3)
        XCTAssertEqual(absent.activeCounts?.interns, 2)
        let none = try JSONDecoder().decode(AnalyticsData.self, from: Data(#"{"months":[]}"#.utf8))
        XCTAssertNil(none.activeCounts)
    }

    func testBreakdownToleratesMissingAndUnknownValues() throws {
        let body = "{\(analyticsBase)," + #""breakdown":[{"intern":false,"gender":"Non-binary","ageGroup":null},{"gender":"Male","ageGroup":"25–34","ethnicGroup":" "}]}"#
        let d = try JSONDecoder().decode(AnalyticsData.self, from: Data(body.utf8))
        let b = WorkforceBreakdown(try XCTUnwrap(d.breakdown), who: .all)
        // An unknown label is kept after the known ones, so the shares still add up.
        XCTAssertEqual(b.charts[0].slices.map(\.label), ["Male", "Non-binary"])
        XCTAssertEqual(b.charts[1].slices.map(\.label), ["25–34", "Not recorded"])
        XCTAssertEqual(b.ethnicMissing, 2)
        XCTAssertEqual(WorkforceBreakdown([], who: .staff).charts.map(\.total), [0, 0, 0])
        XCTAssertNil(WorkforceBreakdown([], who: .staff).ethnicNote)
    }

    func testPreviewBreakdownMatchesTheHeadcount() {
        let d = PreviewData.analytics
        XCTAssertEqual(d.activeCounts?.staff, d.headcount.last?.staff)
        XCTAssertEqual(d.activeCounts?.interns, d.headcount.last?.interns)
    }

    // MARK: Trainers: KPI tiles

    func testTrainerStatsLeaveApplicantsOut() throws {
        let body = #"""
        {"count":6,"trainers":[
          {"id":"1","name":"A","status":"Active","trainingCerts":["ACLP","ACTA"]},
          {"id":"2","name":"B","status":"Active","trainingCerts":["Advanced Certificate in Learning and Performance (ACLP, 2023)"]},
          {"id":"3","name":"C","status":"Active","trainingCerts":["ACTA"]},
          {"id":"4","name":"D","status":"Inactive","trainingCerts":[]},
          {"id":"5","name":"E","status":"Applicant","trainingCerts":["ACLP"]},
          {"id":"6","name":"F","status":"Contacted","trainingCerts":[]}]}
        """#
        let all = try JSONDecoder().decode(TrainersResponse.self, from: Data(body.utf8)).trainers
        let s = TrainerStats(all)
        XCTAssertEqual(s.total, 4)
        XCTAssertEqual(s.aclp, 2)
        XCTAssertEqual(s.nonAclp, 2)
        XCTAssertEqual(s.applicants, 2)
        XCTAssertEqual(TrainerStats([]).total, 0)
        // Each choice of the control lists exactly the trainers its tile counts.
        func list(_ f: TrainerAclpFilter) -> [String] {
            TrainerDirectory.filter(all, query: "", tags: [], accreditations: [], status: .trainers, aclp: f).map(\.id)
        }
        XCTAssertEqual(list(.aclp), ["1", "2"])
        XCTAssertEqual(list(.non), ["3", "4"])
        XCTAssertEqual(list(.all), ["1", "2", "3", "4"])
        XCTAssertEqual(TrainerAclpFilter.allCases.map { $0.count(s) }, [2, 2, 4])
        XCTAssertEqual(TrainerAclpFilter.allCases.map(\.title), ["ACLP", "Non-ACLP", "All"])
        // It also applies to applicants when they are shown.
        XCTAssertEqual(TrainerDirectory.filter(all, query: "", tags: [], accreditations: [], status: .applicants, aclp: .aclp).map(\.id), ["5"])
    }

    func testTrainerListIsSortedByName() throws {
        let body = #"""
        {"count":4,"trainers":[
          {"id":"1","name":"ZHANG WEI","status":"Active","trainingCerts":["ACLP"]},
          {"id":"2","name":"alice tan","status":"Active","trainingCerts":["ACLP"]},
          {"id":"3","name":"MUTHU KUMAR","status":"Active","trainingCerts":["ACTA"]},
          {"id":"4","name":"BEN LIM","status":"Active","trainingCerts":["ALCP"]}]}
        """#
        let all = try JSONDecoder().decode(TrainersResponse.self, from: Data(body.utf8)).trainers
        func names(_ f: TrainerAclpFilter) -> [String] {
            TrainerDirectory.filter(all, query: "", tags: [], accreditations: [], status: .trainers, aclp: f).map(\.name)
        }
        XCTAssertEqual(names(.all), ["alice tan", "BEN LIM", "MUTHU KUMAR", "ZHANG WEI"])
        XCTAssertEqual(names(.aclp), ["alice tan", "BEN LIM", "ZHANG WEI"], "the 'ALCP' typo counts as ACLP")
        XCTAssertEqual(names(.non), ["MUTHU KUMAR"])
    }

    func testPreviewTrainerStats() {
        let s = TrainerStats(PreviewData.trainerList)
        XCTAssertEqual([s.total, s.aclp, s.nonAclp, s.applicants], [4, 3, 1, 1])
    }

    // MARK: Team: staff and interns as two lists

    func testEmployeesInternFlagSplitsTheList() throws {
        let body = #"""
        {"isAdmin":true,"employees":[
          {"id":"1","employeeId":"E0001","name":"A","position":null,"department":null,"avatarUrl":null,"email":null,"phone":null,"employmentType":null,"startDate":null,"intern":false},
          {"id":"2","employeeId":"I0001","name":"B","position":null,"department":null,"avatarUrl":null,"email":null,"phone":null,"employmentType":null,"startDate":null,"intern":true},
          {"id":"3","employeeId":"E0002","name":"C","position":null,"department":null,"avatarUrl":null,"email":null,"phone":null,"employmentType":null,"startDate":null,"intern":null}]}
        """#
        let r = try JSONDecoder().decode(EmployeesResponse.self, from: Data(body.utf8))
        XCTAssertTrue(EmployeeGroup.isAvailable(r.employees))
        XCTAssertEqual(EmployeeGroup.staff.filter(r.employees).map(\.id), ["1", "3"])
        XCTAssertEqual(EmployeeGroup.interns.filter(r.employees).map(\.id), ["2"])
    }

    func testEmployeesWithoutTheFlagStayOneList() throws {
        // Older server (field absent) and non-approvers (null for everyone).
        let body = #"""
        {"isAdmin":false,"employees":[
          {"id":"1","employeeId":"E0001","name":"A","position":null,"department":null,"avatarUrl":null,"email":null,"phone":null,"employmentType":null,"startDate":null},
          {"id":"2","employeeId":"I0001","name":"B","position":null,"department":null,"avatarUrl":null,"email":null,"phone":null,"employmentType":null,"startDate":null,"intern":null}]}
        """#
        let r = try JSONDecoder().decode(EmployeesResponse.self, from: Data(body.utf8))
        XCTAssertEqual(r.employees.count, 2)
        XCTAssertFalse(EmployeeGroup.isAvailable(r.employees))
    }
}
