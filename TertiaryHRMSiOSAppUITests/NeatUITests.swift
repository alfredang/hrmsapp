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

    /// My Profile → Appearance: the three choices exist and picking one selects it.
    func testAppearanceCardSwitchesBetweenLightDarkAndSystem() {
        let app = launch(["-uiPreviewScreen", "profile", "-hrms_appearance", "system"])
        let dark = app.buttons["Dark"]
        for _ in 0..<4 where !dark.isHittable { app.swipeUp() }
        XCTAssertTrue(dark.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Light"].exists)
        XCTAssertTrue(app.buttons["System"].isSelected)
        dark.tap()
        XCTAssertTrue(dark.isSelected)
        snap(app, "ui-appearance-dark")
        app.buttons["Light"].tap()
        XCTAssertTrue(app.buttons["Light"].isSelected)
        snap(app, "ui-appearance-light")
        app.buttons["System"].tap()
        XCTAssertTrue(app.buttons["System"].isSelected)
    }

    func testAnalyticsFiltersDriveTilesAndLists() {
        let app = launch(["-uiPreviewOpen", "analytics"])
        let headcount = app.descendants(matching: .any)["analytics.tile.Headcount"]
        XCTAssertTrue(headcount.waitForExistence(timeout: 10))
        XCTAssertTrue((headcount.value as? String ?? "").hasPrefix("23"), "preview: 14 staff + 9 interns")
        snap(app, "analytics-all")

        app.segmentedControls["analytics.who"].buttons["Interns"].tap()
        XCTAssertTrue((headcount.value as? String ?? "").hasPrefix("9"))
        XCTAssertTrue(app.buttons["analytics.reset"].exists)

        // Hiding a category takes it out of the Expenses tile.
        let expenses = app.descendants(matching: .any)["analytics.tile.Expenses"]
        let before = expenses.value as? String ?? ""
        let payroll = app.buttons["analytics.type.Payroll"]
        for _ in 0..<6 where !payroll.isHittable { app.swipeUp(velocity: .slow) }
        payroll.tap()
        XCTAssertTrue((payroll.value as? String ?? "").hasSuffix("hidden"))
        snap(app, "analytics-categories")
        for i in 1...4 { app.swipeUp(velocity: .slow); snap(app, "analytics-scroll-\(i)") }
        for _ in 0..<12 where !expenses.isHittable { app.swipeDown(velocity: .slow) }
        XCTAssertNotEqual(expenses.value as? String ?? "", before)
        snap(app, "analytics-interns-no-payroll")

        app.buttons["analytics.reset"].tap()
        XCTAssertTrue((headcount.value as? String ?? "").hasPrefix("23"))
    }

    func testCalendarStaffInternFilter() {
        let app = launch(["-uiPreviewOpen", "calendar"])
        let control = app.segmentedControls["calendar.group"]
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        XCTAssertTrue(control.buttons["All 9"].exists)
        control.buttons["Interns 4"].tap()
        snap(app, "calendar-interns")
        control.buttons["Staff 5"].tap()
        XCTAssertTrue(control.buttons["Staff 5"].isSelected)
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
