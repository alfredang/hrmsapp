import XCTest

/// UI checks for the neat-UI screens, run on the `-uiPreview` sample data (no network, no login).
/// Set `TEST_RUNNER_SCREENSHOT_DIR=/some/dir` on `xcodebuild test` to also save PNGs there.
final class NeatUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiPreview"] + args
        // `TEST_RUNNER_UITEST_APPEARANCE=dark|light` runs the same checks in that appearance.
        if let look = ProcessInfo.processInfo.environment["UITEST_APPEARANCE"], !look.isEmpty,
           !args.contains("-hrms_appearance") {
            app.launchArguments += ["-hrms_appearance", look]
        }
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

    /// Calendar (approvers): "Leave shown for" lists active people grouped Staff / Interns with
    /// their leave counts; picking one shows only their leave, the x goes back to everyone.
    func testCalendarPersonFilter() {
        let app = launch(["-uiPreviewOpen", "calendar"])
        let control = app.buttons["calendar.person"]
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        XCTAssertEqual(control.value as? String, "Everyone")
        control.tap()
        let pick = app.buttons["Femina Jasmin (2)"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Jyoti Chopra"].exists, "an active person without leave is listed")
        XCTAssertFalse(app.buttons["Cheryl Lim (1)"].exists, "a person who has left is not listed")
        XCTAssertTrue(app.staticTexts["Interns"].exists, "the list is grouped Staff / Interns")
        snap(app, "calendar-person-menu")
        pick.tap()
        XCTAssertTrue(app.buttons["calendar.person.clear"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["calendar.person"].value as? String, "Femina Jasmin")
        snap(app, "calendar-person-picked")
        app.buttons["calendar.person.clear"].tap()
        XCTAssertEqual(app.buttons["calendar.person"].value as? String, "Everyone")
    }

    /// Analytics: the workforce breakdown starts on Staff; Interns shows the ethnic-group note.
    func testAnalyticsWorkforceBreakdown() {
        let app = launch(["-uiPreviewOpen", "analytics"])
        let who = app.segmentedControls["analytics.breakdown.who"]
        XCTAssertTrue(app.descendants(matching: .any)["analytics.tile.Headcount"].waitForExistence(timeout: 10))
        for _ in 0..<14 where !who.isHittable { app.swipeUp() }
        XCTAssertTrue(who.buttons["Staff"].isSelected)
        let male = app.buttons["analytics.breakdown.Gender.Male"]
        for _ in 0..<4 where !male.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertEqual(male.value as? String, "7, 50%")
        snap(app, "analytics-breakdown-staff")
        for _ in 0..<4 where !who.isHittable { app.swipeDown(velocity: .slow) }
        who.buttons["Interns"].tap()
        XCTAssertEqual(app.buttons["analytics.breakdown.Gender.Male"].value as? String, "5, 56%")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["analytics.breakdown.note"].waitForExistence(timeout: 5))
        snap(app, "analytics-breakdown-interns")
        for _ in 0..<3 where !who.isHittable { app.swipeDown(velocity: .slow) }
        who.buttons["Staff"].tap()
        app.swipeUp()
        snap(app, "analytics-breakdown-staff-full")
    }

    /// Trainer Management opens on ACLP trainers, A–Z; the ACLP / Non-ACLP / All control and the
    /// three KPI tiles (trainers only, no applicants) set the same choice.
    func testTrainerAclpFilterAndKpiTiles() {
        let app = launch(["-uiPreviewOpen", "trainers"])
        let total = app.buttons["trainers.kpi.all"]
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        XCTAssertEqual(total.value as? String, "4")
        XCTAssertEqual(app.buttons["trainers.kpi.aclp"].value as? String, "3")
        XCTAssertEqual(app.buttons["trainers.kpi.non"].value as? String, "1")
        let control = app.segmentedControls["trainers.aclp"]
        XCTAssertTrue(control.buttons["ACLP 3"].isSelected, "opens on ACLP")
        XCTAssertTrue(app.buttons["trainers.kpi.aclp"].isSelected)
        XCTAssertTrue(app.staticTexts["TAN MEI LING"].exists)
        XCTAssertFalse(app.staticTexts["RAJESH KUMAR S/O MURUGAN"].exists)
        // A–Z by name.
        XCTAssertLessThan(app.staticTexts["ALFRED ANG CHEW HOE (DR)"].frame.minY, app.staticTexts["NURUL HUDA BINTE ISMAIL"].frame.minY)
        XCTAssertLessThan(app.staticTexts["NURUL HUDA BINTE ISMAIL"].frame.minY, app.staticTexts["TAN MEI LING"].frame.minY)
        snap(app, "trainers-aclp")

        control.buttons["Non-ACLP 1"].tap()
        XCTAssertTrue(app.staticTexts["RAJESH KUMAR S/O MURUGAN"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["TAN MEI LING"].exists)
        XCTAssertTrue(app.buttons["trainers.kpi.non"].isSelected)
        snap(app, "trainers-non-aclp")

        total.tap()
        XCTAssertTrue(control.buttons["All 4"].isSelected)
        XCTAssertTrue(app.staticTexts["TAN MEI LING"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["RAJESH KUMAR S/O MURUGAN"].exists)
        snap(app, "trainers-all")
        app.buttons["trainers.kpi.aclp"].tap()
        XCTAssertTrue(control.buttons["ACLP 3"].isSelected)
        XCTAssertFalse(app.staticTexts["RAJESH KUMAR S/O MURUGAN"].exists)
    }

    /// Team (approvers): staff and interns are two lists; Home shows the three KPI tiles.
    func testTeamStaffInternListsAndHomeTiles() {
        let app = launch(["-uiPreviewTab", "3"])
        let control = app.segmentedControls["team.group"]
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        XCTAssertTrue(control.buttons["Staff 6"].isSelected)
        XCTAssertFalse(app.staticTexts["Amanda Halim"].exists)
        snap(app, "team-staff")
        control.buttons["Interns 3"].tap()
        XCTAssertTrue(app.staticTexts["Amanda Halim"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Jasmine Lee"].exists)
        snap(app, "team-interns")

        app.tabBars.buttons["Home"].tap()
        let staff = app.buttons["home.kpi.staff"]
        XCTAssertTrue(staff.waitForExistence(timeout: 10))
        XCTAssertEqual(staff.value as? String, "14")
        XCTAssertEqual(app.buttons["home.kpi.interns"].value as? String, "9")
        XCTAssertEqual(app.buttons["home.kpi.pending"].value as? String, "5")
        snap(app, "home-kpi")
        app.buttons["home.kpi.interns"].tap()
        XCTAssertTrue(app.segmentedControls["team.group"].buttons["Interns 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["team.group"].buttons["Interns 3"].isSelected)
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
