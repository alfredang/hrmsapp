import XCTest
@testable import TertiaryHRMSiOSApp

/// Trainer directory search (mirrors the web filterTrainers / topTags), contact links and
/// the admin list decoders added for the neat-UI update.
final class NeatUILogicTests: XCTestCase {
    private let list = [
        TrainerListItem(id: "1", name: "ALFRED ANG", phone: "91234567", email: "a@example.com",
                        trainingCerts: ["ACLP", "ACTA"], certifications: ["PMP"], skills: ["Python", "Generative AI"],
                        financeBackground: true, ibfFitDeclaration: true),
        TrainerListItem(id: "2", name: "TAN MEI LING", phone: "+65 9234 5678", trainingCerts: ["ACLP"],
                        certifications: ["CFA Level II"], skills: ["Excel", "Python"]),
        TrainerListItem(id: "3", name: "LIM WEI JIE", status: "Applicant", trainingCerts: [],
                        certifications: [], skills: ["SQL"]),
    ]

    func testVocabularyCountsSkillsAcrossTrainers() {
        let vocab = TrainerDirectory.vocabulary(list)
        XCTAssertEqual(vocab.first?.tag, "Python")
        XCTAssertEqual(vocab.first?.count, 2)
        XCTAssertEqual(vocab.first { $0.tag == "PMP" }?.kind, .certification)
    }

    func testSuggestionsPreferPrefixAndSkipPickedTokens() {
        let vocab = TrainerDirectory.vocabulary(list)
        XCTAssertEqual(TrainerDirectory.suggestions(vocab, text: "py", excluding: []).map(\.tag), ["Python"])
        XCTAssertTrue(TrainerDirectory.suggestions(vocab, text: "py", excluding: ["python"]).isEmpty)
        XCTAssertFalse(TrainerDirectory.suggestions(vocab, text: "", excluding: []).isEmpty)
    }

    func testFilterByTagsAccreditationAndStatus() {
        let byTag = TrainerDirectory.filter(list, query: "", tags: ["Python"], accreditations: [], status: .trainers)
        XCTAssertEqual(byTag.map(\.id), ["1", "2"])
        let ibf = TrainerDirectory.filter(list, query: "", tags: ["Python"], accreditations: [.ibfFit, .acta], status: .trainers)
        XCTAssertEqual(ibf.map(\.id), ["1"])
        XCTAssertEqual(TrainerDirectory.filter(list, query: "", tags: [], accreditations: [], status: .applicants).map(\.id), ["3"])
        // "dddpl" / "alcp" typos are aliased like the web.
        XCTAssertEqual(TrainerDirectory.filter(list, query: "alcp tan", tags: [], accreditations: [], status: .all).map(\.id), ["2"])
    }

    func testMatchingSkillComesFirst() {
        XCTAssertEqual(TrainerDirectory.orderByMatch(["Excel", "Python", "SQL"], needles: ["pyth"]), ["Python", "Excel", "SQL"])
    }

    func testWhatsAppAddsSingaporeCodeToEightDigitNumbers() {
        XCTAssertEqual(ContactLinks.whatsApp("9123 4567")?.absoluteString, "https://wa.me/6591234567")
        XCTAssertEqual(ContactLinks.whatsApp("+65 9234 5678")?.absoluteString, "https://wa.me/6592345678")
        XCTAssertNil(ContactLinks.whatsApp("12345"))
        XCTAssertEqual(ContactLinks.tel("+65 9234 5678")?.absoluteString, "tel:+6592345678")
    }

    func testFeedbackURLIsPercentEncoded() {
        let url = FeedbackView.whatsAppURL(title: "Leave & MC", message: "Row cut off?")
        XCTAssertEqual(url?.host, "wa.me")
        XCTAssertTrue(url?.absoluteString.contains("Leave%20%26%20MC") ?? false)
    }

    func testAdminTimeOffDecodesRequesterName() throws {
        let json = #"[{"id":"t1","date":"2026-11-12T00:00:00.000Z","startTime":"14:00","endTime":"16:30","hours":"2.5","reason":"EXAMS","reasonDetail":"Final project","status":"PENDING","createdAt":"2026-11-05T02:00:00.000Z","employee":{"id":"e1","name":"Amanda Halim","department":null}}]"#
        let rows = try JSONDecoder().decode([TimeOffRequest].self, from: Data(json.utf8))
        XCTAssertEqual(rows.first?.employeeName, "Amanda Halim")
        XCTAssertEqual(rows.first?.hours, 2.5)
        XCTAssertEqual(rows.first?.reasonText, "Exams — Final project")
    }

    func testCorrectionAndOffInLieuDecode() throws {
        let c = #"[{"id":"c1","employeeId":"e1","employeeName":"Amanda Halim","employeeCode":"I0002","date":"2026-11-06","kind":"CLOCK_OUT","requestedClockIn":null,"requestedClockOut":"2026-11-06T10:00:00.000Z","currentClockIn":null,"currentClockOut":null,"reason":"Forgot","status":"PENDING","rejectionReason":null,"createdAt":"2026-11-07T01:00:00.000Z"}]"#
        XCTAssertEqual(try JSONDecoder().decode([AttendanceCorrection].self, from: Data(c.utf8)).first?.kindLabel, "Missing clock-out")
        let o = #"[{"id":"o1","employeeId":"e9","employeeCode":"E0003","employeeName":"Daniel Tan","date":"2026-11-08","dayName":"Sat","isPublicHoliday":false,"hours":8,"otCredited":0,"status":"PENDING","adminComment":null}]"#
        XCTAssertEqual(try JSONDecoder().decode([OffInLieuEntry].self, from: Data(o.utf8)).first?.hours, 8)
    }
}
