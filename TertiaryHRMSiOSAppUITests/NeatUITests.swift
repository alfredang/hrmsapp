import XCTest

/// UI checks for the neat-UI screens, run on the `-uiPreview` sample data (no network, no login).
/// Set `TEST_RUNNER_SCREENSHOT_DIR=/some/dir` on `xcodebuild test` to also save PNGs there.
final class NeatUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiPreview"] + args
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot); a.name = name; a.lifetime = .keepAlways; add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    func testTrainerSearchSuggestionsBecomeTokens() {
        let app = launch(["-uiPreviewOpen", "trainers"])
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("py")
        let suggestion = app.staticTexts.matching(NSPredicate(format: "label == 'Python'")).firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), "skill suggestion with a count")
        snap(app, "ui-trainers-suggestions")
        suggestion.tap()
        XCTAssertTrue(app.staticTexts["ALFRED ANG CHEW HOE (DR)"].waitForExistence(timeout: 5))
        snap(app, "ui-trainers-token")
        // Accreditation filter lives in one menu, reachable while searching.
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        app.buttons["Filters"].firstMatch.tap()
        XCTAssertTrue(app.buttons["IBF Fit"].waitForExistence(timeout: 5))
        snap(app, "ui-trainers-filter-menu")
    }

    func testTrainerRowContactMenu() {
        let app = launch(["-uiPreviewOpen", "trainers"])
        let contact = app.buttons["Contact TAN MEI LING"]
        XCTAssertTrue(contact.waitForExistence(timeout: 10))
        contact.tap()
        XCTAssertTrue(app.buttons["WhatsApp"].waitForExistence(timeout: 5))
        snap(app, "ui-trainers-contact-menu")
    }

    func testApprovalRowOpensReasonSheet() {
        let app = launch(["-uiPreviewOpen", "approvals"])
        let row = app.buttons["Sarah Lim"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.staticTexts["Family trip"].waitForExistence(timeout: 5), "full reason in the sheet")
        XCTAssertTrue(app.buttons["Approve"].exists)
        snap(app, "ui-approvals-sheet")
    }

    func testTimesheetCollapsesSections() {
        let app = launch(["-uiPreviewOpen", "timesheet"])
        let header = app.buttons["Missing punches"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        header.tap()
        XCTAssertFalse(app.staticTexts["Missing clock-out"].waitForExistence(timeout: 1))
        snap(app, "ui-timesheet-collapsed")
    }
}
