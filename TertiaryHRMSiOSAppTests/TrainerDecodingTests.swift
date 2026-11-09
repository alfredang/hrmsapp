import XCTest
@testable import TertiaryHRMSiOSApp

/// Trainer directory payloads (`/api/mobile/trainers`, `/api/mobile/trainers/{id}`), including
/// the messy shapes the importer can leave behind (nulls, numeric "run", junk JSON rows).
final class TrainerDecodingTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    func testListDecodes() throws {
        let json = #"""
        {"count":2,"trainers":[
          {"id":"t1","name":"ALFRED ANG CHEW HOE (DR)","nickname":"Alfred","phone":"+65 9123 4567","email":"a@x.com",
           "trainerType":"ACLP","status":"Active","inTms":true,"trainingCerts":["ACLP","ACTA"],
           "certifications":["PMP"],"skills":["Python","Power BI"],"education":"PhD","summary":null,
           "financeBackground":true,"ibfFitDeclaration":false,"classesCount":214,"lastClassDate":"2026-11-04",
           "courseTitles":["Generative AI for Business"]},
          {"id":"t2","name":"LIM WEI JIE","nickname":null,"phone":null,"email":null,"trainerType":null,
           "status":"Applicant","inTms":false,"trainingCerts":[],"certifications":[],"skills":[],
           "education":null,"summary":null,"financeBackground":false,"ibfFitDeclaration":false,
           "classesCount":0,"lastClassDate":null,"courseTitles":[]}
        ]}
        """#
        let r = try decode(TrainersResponse.self, json)
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.trainers[0].name, "ALFRED ANG CHEW HOE (DR)", "names stay uppercase as sent")
        XCTAssertEqual(r.trainers[0].trainingCerts, ["ACLP", "ACTA"])
        XCTAssertEqual(r.trainers[0].topTags(), ["PMP", "Python", "Power BI"])
        XCTAssertTrue(r.trainers[0].financeBackground)
        XCTAssertNil(r.trainers[1].phone)
        XCTAssertEqual(r.trainers[1].status, "Applicant")
    }

    func testListToleratesMissingAndNullFields() throws {
        let r = try decode(TrainersResponse.self, #"{"trainers":[{"id":"t9","name":"X","trainingCerts":null,"skills":["", " SQL "]}]}"#)
        XCTAssertEqual(r.count, 1, "count falls back to the array length")
        let t = r.trainers[0]
        XCTAssertEqual(t.trainingCerts, [])
        XCTAssertEqual(t.skills, ["SQL"], "blank entries dropped, whitespace trimmed")
        XCTAssertEqual(t.status, "Active")
        XCTAssertFalse(t.inTms)
        XCTAssertEqual(t.classesCount, 0)
    }

    func testDetailDecodesAllSections() throws {
        let json = #"""
        {"trainer":{"id":"t1","name":"ALFRED ANG CHEW HOE (DR)","nickname":"Alfred","nric":"S1234567D",
          "phone":"+65 9123 4567","email":"a@x.com","secondaryEmail":null,"nationality":"Singaporean",
          "linkedinUrl":"linkedin.com/in/x","trainerType":"ACLP","status":"Active","inTms":true,
          "trainingCerts":["ACLP","AE Registry"],"certifications":["PMP"],"skills":["Python"],
          "education":"PhD","experience":["Founder (2012 – present)"],"summary":"AI trainer",
          "financeBackground":true,"financeEvidence":["CFA"],"ibfFitDeclaration":true,"ibfFitFiles":["form.pdf"],
          "actaFolder":"ALFRED ANG","evidenceFiles":[],
          "courses":[{"title":"GenAI","code":"TGS-1","classes":48,"first":"2023-03-02","last":"2026-11-04"},
                     {"title":"No count","classes":"7"}, "junk", null],
          "recentClasses":[{"start":"2026-11-04","title":"GenAI","run":36,"status":"Completed"},
                           {"start":"2026-11-18","title":"GenAI","run":"RUN-49"}],
          "calendarClasses":null,"classesCount":214,"lastClassDate":"2026-11-04","adminNotes":null,
          "createdAt":"2026-01-01T00:00:00.000Z","editedAt":null}}
        """#
        let t = try decode(TrainerDetailResponse.self, json).trainer
        XCTAssertEqual(t.maskedNric, "S****567D")
        XCTAssertEqual(t.courses.count, 2, "non-object rows in the JSON column are skipped")
        XCTAssertEqual(t.courses[0].classes, 48)
        XCTAssertEqual(t.courses[1].classes, 7, "string counts are accepted")
        XCTAssertNil(t.courses[1].code)
        XCTAssertEqual(t.recentClasses[0].run, "36", "numeric run is rendered as text")
        XCTAssertEqual(t.recentClasses[1].run, "RUN-49")
        XCTAssertNil(t.recentClasses[1].status)
        XCTAssertEqual(t.calendarClasses.count, 0)
        XCTAssertEqual(t.experience, ["Founder (2012 – present)"])
        XCTAssertTrue(t.ibfFitDeclaration)
        XCTAssertNil(t.adminNotes)
    }

    func testNricMask() {
        XCTAssertEqual(TrainerDetail.mask("S1234567D"), "S****567D")
        XCTAssertEqual(TrainerDetail.mask("T0012345Z"), "T****345Z")
        XCTAssertEqual(TrainerDetail.mask("ABC"), "****")
        XCTAssertEqual(TrainerDetail.mask(nil), "")
        XCTAssertEqual(TrainerDetail.mask("  "), "")
    }

    func testFilterQueryItems() {
        var f = TrainerFilter()
        XCTAssertTrue(f.queryItems.isEmpty)
        f.query = "  pmp "
        f.certs = [.acta, .aclp]
        f.finance = true
        f.ibfFit = true
        f.status = .trainers
        let items = f.queryItems.map { "\($0.name)=\($0.value ?? "")" }
        XCTAssertEqual(items, ["q=pmp", "cert=ACLP", "cert=ACTA", "finance=1", "ibfFit=1", "status=trainers"])
    }

    func testTelURLStripsFormatting() {
        XCTAssertEqual(TrainerProfileView.telURL("+65 9123 4567")?.absoluteString, "tel:+6591234567")
        XCTAssertNil(TrainerProfileView.telURL("n/a"))
    }
}
