import XCTest
@testable import TertiaryHRMSiOSApp

/// CPF EZPay submissions (web 26 Nov 2026): `/api/mobile/cpf-submissions` and the optional
/// `cpfSubmission` on each `/api/mobile/payslips` row.
final class CpfSubmissionDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: List

    func testDecodesListInServerOrderWithNullFields() throws {
        let json = """
        {"cpfSubmissions": [
          {"id":"f2","name":"CPF-Submission-11-2026__ezpay.pdf","month":11,"year":2026,"periodLabel":"November 2026",
           "sizeBytes":184320,"uploadedAt":"2026-12-10T03:12:00.000Z","downloadPath":"/api/payroll/cpf-submission/files/f2"},
          {"id":"f1","name":"scan.pdf","month":null,"year":null,"periodLabel":null,
           "sizeBytes":null,"uploadedAt":null,"downloadPath":"/api/payroll/cpf-submission/files/f1"}
        ]}
        """
        let r = try decoder.decode(CpfSubmissionsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(r.cpfSubmissions.map(\.id), ["f2", "f1"], "keeps the server's latest-first order")

        let nov = r.cpfSubmissions[0]
        XCTAssertEqual(nov.month, 11)
        XCTAssertEqual(nov.year, 2026)
        XCTAssertEqual(nov.sizeBytes, 184320)
        XCTAssertEqual(nov.title, "November 2026")
        XCTAssertEqual(nov.downloadPath, "/api/payroll/cpf-submission/files/f2")
        XCTAssertTrue(nov.detail.hasPrefix("CPF-Submission-11-2026__ezpay.pdf · Uploaded "))
        XCTAssertTrue(nov.detail.hasSuffix(CpfSubmission.size(184320)))

        let scan = r.cpfSubmissions[1]
        XCTAssertNil(scan.month)
        XCTAssertNil(scan.year)
        XCTAssertNil(scan.periodLabel)
        XCTAssertNil(scan.sizeBytes)
        XCTAssertNil(scan.uploadedAt)
        XCTAssertEqual(scan.title, "scan.pdf", "falls back to the file name")
        XCTAssertEqual(scan.detail, "scan.pdf")
    }

    func testListToleratesMissingKeysAndDropsBrokenRows() throws {
        let json = """
        {"cpfSubmissions": [
          {"id":"f3","name":"CPF-Submission-10-2026__a.pdf","downloadPath":"/api/payroll/cpf-submission/files/f3"},
          {"id":"bad","name":"no path.pdf"},
          {"id":"f4","name":"b.pdf","sizeBytes":"2048","month":"9","downloadPath":"/x/f4"}
        ]}
        """
        let r = try decoder.decode(CpfSubmissionsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(r.cpfSubmissions.map(\.id), ["f3", "f4"])
        XCTAssertNil(r.cpfSubmissions[0].periodLabel)
        XCTAssertEqual(r.cpfSubmissions[1].sizeBytes, 2048)
        XCTAssertEqual(r.cpfSubmissions[1].month, 9)
    }

    func testEmptyList() throws {
        let r = try decoder.decode(CpfSubmissionsResponse.self, from: Data(#"{"cpfSubmissions":[]}"#.utf8))
        XCTAssertTrue(r.cpfSubmissions.isEmpty)
    }

    // MARK: Payslip.cpfSubmission

    private func payslip(_ extra: String) -> String {
        """
        {"id":"p1","payPeriodStart":"2026-11-01T00:00:00.000Z","payPeriodEnd":"2026-11-30T00:00:00.000Z",
         "paymentDate":null,"basicSalary":5000,"allowances":0,"overtime":0,"bonus":0,"grossSalary":5000,
         "cpfEmployee":1000,"totalDeductions":1000,"netSalary":4000,"status":"PAID",
         "pdfPath":"/api/payroll/payslip/p1/pdf"\(extra)}
        """
    }

    private func decodePayslips(_ rows: String...) throws -> [Payslip] {
        let json = #"{"payslips":["# + rows.joined(separator: ",") + "]}"
        return try decoder.decode(PayslipsResponse.self, from: Data(json.utf8)).payslips
    }

    func testPayslipWithCpfSubmission() throws {
        let p = try decodePayslips(payslip("""
        ,"cpfSubmission":{"id":"f2","name":"CPF-Submission-11-2026__ezpay.pdf","periodLabel":"November 2026",
          "downloadPath":"/api/payroll/cpf-submission/files/f2"}
        """))[0]
        let cpf = try XCTUnwrap(p.cpfSubmission)
        XCTAssertEqual(cpf.id, "f2")
        XCTAssertEqual(cpf.title, "November 2026")
        XCTAssertEqual(cpf.downloadPath, "/api/payroll/cpf-submission/files/f2")
        XCTAssertEqual(p.netSalary, 4000)
    }

    func testPayslipCpfSubmissionNullMissingOrMalformed() throws {
        let rows = try decodePayslips(
            payslip(#","cpfSubmission":null"#),                       // staff, or no statement on file
            payslip(""),                                              // older server
            payslip(#","cpfSubmission":{"id":"x"}"#),                 // malformed: ignored, payslip kept
            payslip(#","cpfSubmission":{"id":"f","name":"a.pdf","periodLabel":null,"downloadPath":"/p/f"}"#)
        )
        XCTAssertEqual(rows.count, 4)
        XCTAssertNil(rows[0].cpfSubmission)
        XCTAssertNil(rows[1].cpfSubmission)
        XCTAssertNil(rows[2].cpfSubmission)
        XCTAssertEqual(rows[3].cpfSubmission?.title, "a.pdf", "falls back to the file name")
        XCTAssertEqual(rows[1].pdfPath, "/api/payroll/payslip/p1/pdf")
    }

    // MARK: Share copy

    func testTemporaryShareCopyIsAPdfWithASafeName() throws {
        let url = try XCTUnwrap(CpfStatementPDFView.writeTemporary(Data("%PDF-1.4".utf8), name: "a/b:c"))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.lastPathComponent, "a-b-c.pdf")
        XCTAssertEqual(try Data(contentsOf: url), Data("%PDF-1.4".utf8))
    }
}
