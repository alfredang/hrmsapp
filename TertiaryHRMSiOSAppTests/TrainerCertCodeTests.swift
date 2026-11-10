import XCTest
@testable import TertiaryHRMSiOSApp

final class TrainerCertCodeTests: XCTestCase {
    func testLongCertNamesCollapseToCodes() {
        XCTAssertEqual(TrainingCert.shortCode("Advanced Certificate in Learning and Performance (ACLP, 2023)"), "ACLP")
        XCTAssertEqual(TrainingCert.shortCode("alcp"), "ACLP")
        XCTAssertEqual(TrainingCert.shortCode("DDDPL"), "DDDLP")
        XCTAssertEqual(TrainingCert.shortCode("Diploma in Adult and Continuing Education"), "DACE")
    }

    func testUnknownCertsAreCappedAt14Chars() {
        let s = TrainingCert.shortCode("Graduate Certificate in Workplace Learning (GCWLP)")
        XCTAssertLessThanOrEqual(s.count, 14)
        XCTAssertTrue(s.hasSuffix("…"))
        XCTAssertEqual(TrainingCert.shortCode("GCWLP"), "GCWLP")
    }

    func testShortCodesDedupeAndPutAccreditationsFirst() {
        XCTAssertEqual(TrainingCert.shortCodes(["Associate Adult Educator", "ACLP", "ACLP (2023)", "ACTA"]),
                       ["ACLP", "ACTA", "Associate Adu…"])
    }

    func testWhatsAppOnlyForSingaporeMobiles() {
        XCTAssertEqual(TrainerContact(id: "1", name: "A", phone: "+65 9123 4567").whatsAppURL?.absoluteString,
                       "https://wa.me/6591234567")
        XCTAssertEqual(TrainerContact(id: "2", name: "B", phone: "81234567").whatsAppURL?.absoluteString,
                       "https://wa.me/6581234567")
        XCTAssertNil(TrainerContact(id: "3", name: "C", phone: "62345678").whatsAppURL)
        XCTAssertNil(TrainerContact(id: "4", name: "D", phone: nil).whatsAppURL)
    }
}
