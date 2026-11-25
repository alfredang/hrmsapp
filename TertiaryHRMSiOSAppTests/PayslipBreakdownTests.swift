import XCTest
@testable import TertiaryHRMSiOSApp

/// Payslip pay breakdown (web 26 Nov 2026): employer CPF, intern (no CPF), unpaid leave deducted and
/// paybacks added back on `/api/mobile/payslips`, and the lines the app shows for them.
final class PayslipBreakdownTests: XCTestCase {
    private func decode(_ extra: String) throws -> Payslip {
        let json = """
        {"payslips":[{"id":"p1","payPeriodStart":"2026-11-01T00:00:00.000Z","payPeriodEnd":"2026-11-30T00:00:00.000Z",
         "paymentDate":null,"basicSalary":5000,"allowances":0,"overtime":0,"bonus":0,"grossSalary":5192.31,
         "cpfEmployee":1038.46,"totalDeductions":1038.46,"netSalary":4153.85,"status":"PAID",
         "pdfPath":"/api/payroll/payslip/p1/pdf"\(extra)}]}
        """
        return try JSONDecoder().decode(PayslipsResponse.self, from: Data(json.utf8)).payslips[0]
    }

    private func line(_ p: Payslip, _ id: String) -> PayslipLine? { p.breakdown.first { $0.id == id } }

    func testStaffWithAllFieldsPresent() throws {
        let p = try decode("""
        ,"cpfEmployer":882.69,"intern":false,"unpaidLeaveDays":2,"unpaidLeaveDeduction":461.54,
         "paybackDays":1,"paybackAmount":230.77
        """)
        XCTAssertEqual(p.cpfEmployer, 882.69)
        XCTAssertFalse(p.intern)
        XCTAssertEqual(p.unpaidLeaveDays, 2)
        XCTAssertEqual(p.unpaidLeaveDeduction, 461.54)
        XCTAssertEqual(p.paybackDays, 1)
        XCTAssertEqual(p.paybackAmount, 230.77)
        XCTAssertEqual(p.totalCpf, 1038.46 + 882.69, accuracy: 0.001)

        XCTAssertEqual(p.breakdown.map(\.id),
                       ["gross", "payback", "unpaid", "cpf.employee", "cpf.employer", "cpf.total", "takehome"])
        XCTAssertEqual(line(p, "gross")?.value, "S$5,192.31")
        XCTAssertEqual(line(p, "payback")?.label, "Payback added back (1 day worked)")
        XCTAssertEqual(line(p, "payback")?.value, "+ S$230.77")
        XCTAssertEqual(line(p, "unpaid")?.label, "No Pay Leave (2 days)")
        XCTAssertEqual(line(p, "unpaid")?.value, "− S$461.54")
        XCTAssertEqual(line(p, "cpf.employee")?.value, "− S$1,038.46")
        XCTAssertEqual(line(p, "cpf.employer")?.value, "S$882.69")
        XCTAssertNotNil(line(p, "cpf.employer")?.note, "says the company pays it")
        XCTAssertEqual(line(p, "cpf.total")?.value, "S$1,921.15")
        XCTAssertEqual(line(p, "takehome")?.value, "S$4,153.85")
        XCTAssertEqual(line(p, "takehome")?.style, .total)
    }

    func testOlderServerWithoutTheNewFields() throws {
        let p = try decode("")
        XCTAssertEqual(p.cpfEmployer, 0)
        XCTAssertFalse(p.intern)
        XCTAssertEqual(p.unpaidLeaveDays, 0)
        XCTAssertEqual(p.unpaidLeaveDeduction, 0)
        XCTAssertEqual(p.paybackDays, 0)
        XCTAssertEqual(p.paybackAmount, 0)
        // No payback or unpaid lines when there is nothing to show; staff CPF lines still there.
        XCTAssertEqual(p.breakdown.map(\.id), ["gross", "cpf.employee", "cpf.employer", "cpf.total", "takehome"])
    }

    func testNullsDecodeAsDefaults() throws {
        let p = try decode("""
        ,"cpfEmployer":null,"intern":null,"unpaidLeaveDays":null,"unpaidLeaveDeduction":null,
         "paybackDays":null,"paybackAmount":null
        """)
        XCTAssertEqual(p.cpfEmployer, 0)
        XCTAssertFalse(p.intern)
        XCTAssertEqual(p.paybackAmount, 0)
    }

    func testInternHasNoCpfAndMcCountsAsUnpaid() throws {
        let p = try decode("""
        ,"cpfEmployer":0,"intern":true,"unpaidLeaveDays":1.5,"unpaidLeaveDeduction":122.73,
         "paybackDays":0,"paybackAmount":0
        """)
        XCTAssertTrue(p.intern)
        XCTAssertEqual(p.breakdown.map(\.id), ["gross", "unpaid", "cpf.none", "takehome"])
        XCTAssertEqual(line(p, "unpaid")?.label, "MC / No Pay Leave (1.5 days)")
        XCTAssertEqual(line(p, "cpf.none")?.label, "CPF: None (interns have no CPF)")
        XCTAssertNil(line(p, "cpf.none")?.value)
        XCTAssertNil(line(p, "cpf.employee"))
        XCTAssertNil(line(p, "cpf.employer"))
    }

    func testSgdFormat() {
        XCTAssertEqual(Fmt.sgd(1700), "S$1,700.00")
        XCTAssertEqual(Fmt.sgd(0), "S$0.00")
        XCTAssertEqual(Fmt.sgd(-5), "-S$5.00")
        XCTAssertEqual(Fmt.sgd(1234567.891), "S$1,234,567.89")
    }
}
