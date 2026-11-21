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

    /// Trainer Admin view (More → View As, web view mode "trainer"): tabs Home / Trainers / Calendar /
    /// More, Home = the trainer tiles only, More without Applications; switching back returns to Home.
    func testTrainerAdminViewAs() {
        let app = launch(["-uiPreviewViewAs", "trainer"])
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(app.staticTexts["home.trainerAdmin.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["home.kpi.aclp"].value as? String, "74")
        XCTAssertTrue(app.buttons["home.kpi.trainers"].exists)
        XCTAssertTrue(app.buttons["home.kpi.nonaclp"].exists)
        XCTAssertTrue(app.buttons["home.trainerAdmin.directory"].exists)
        XCTAssertFalse(app.buttons["home.kpi.pending"].exists, "no admin tiles")
        XCTAssertFalse(app.staticTexts["Quick actions"].exists, "no quick actions")
        XCTAssertTrue(tabs.buttons["Trainers"].exists)
        XCTAssertFalse(tabs.buttons["Leave"].exists)
        XCTAssertFalse(tabs.buttons["Team"].exists)
        snap(app, "trainer-view-home")

        tabs.buttons["Trainers"].tap()
        XCTAssertTrue(app.buttons["trainers.kpi.all"].waitForExistence(timeout: 10))
        snap(app, "trainer-view-directory")

        tabs.buttons["More"].tap()
        let viewAs = app.buttons["more.viewAs"]
        XCTAssertTrue(viewAs.waitForExistence(timeout: 10))
        XCTAssertEqual(viewAs.value as? String, "Trainer Admin")
        XCTAssertTrue(app.staticTexts["Trainer Admin"].exists)
        XCTAssertFalse(app.staticTexts["APPLICATIONS"].exists)
        XCTAssertFalse(app.staticTexts["Approvals"].exists)
        snap(app, "trainer-view-more")

        viewAs.tap()
        app.buttons["viewAs.mine"].tap()
        XCTAssertTrue(tabs.buttons["Leave"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.buttons["Team"].exists)
        XCTAssertFalse(tabs.buttons["Trainers"].exists)
        XCTAssertTrue(tabs.buttons["Home"].isSelected, "back to Home")
        XCTAssertTrue(app.buttons["home.kpi.pending"].waitForExistence(timeout: 10))

        tabs.buttons["More"].tap()
        XCTAssertTrue(app.staticTexts["Trainer Admin"].waitForExistence(timeout: 5), "Manage link renamed")
        XCTAssertFalse(app.staticTexts["ATTENDANCE"].exists, "admins do not clock in (1.20)")
        app.buttons["more.viewAs"].tap()
        app.buttons["viewAs.trainer"].tap()
        XCTAssertTrue(tabs.buttons["Trainers"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.buttons["Trainers"].isSelected, "lands on the directory")
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

    /// Calendar (build 34): category legend; picking a person shows their month totals and
    /// shades their off days (Evan Pang works Mon–Thu and has an Off Day on 11 Nov).
    func testCalendarColoursTimeOffAndMonthTotals() {
        let app = launch(["-uiPreviewOpen", "calendar"])
        XCTAssertTrue(app.buttons["calendar.person"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["calendar.monthTotals"].exists, "no totals for Everyone")
        snap(app, "calendar-colours-everyone")
        app.buttons["calendar.person"].tap()
        let evan = app.buttons["Evan Pang (2)"]
        XCTAssertTrue(evan.waitForExistence(timeout: 5), "time off counts in the person list")
        evan.tap()
        XCTAssertTrue(app.otherElements["calendar.monthTotals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Time Off 2 h + 1 off day"].exists || app.otherElements["calendar.total.TIME_OFF"].exists)
        snap(app, "calendar-colours-person")
    }

    /// Home: Trainer Admin tiles; My Profile: the Work Schedule card.
    func testHomeTrainerTilesAndProfileWorkSchedule() {
        // Admin Home: what is waiting by type, no trainer tiles (those are in the Trainer Admin view).
        let app = launch([])
        let leave = app.buttons["home.pending.leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["home.kpi.trainers"].exists, "no trainer tiles on the admin Home")
        XCTAssertTrue(app.staticTexts["home.name"].exists)
        XCTAssertEqual(leave.value as? String, "1 waiting")
        XCTAssertEqual(app.buttons["home.pending.timeoff"].value as? String, "2 waiting")
        XCTAssertEqual(app.buttons["home.kpi.pending"].value as? String, "6", "tile = sum of the card")
        snap(app, "home-admin-pending")
        let profile = launch(["-uiPreviewOpen", "profile"])
        XCTAssertTrue(profile.staticTexts["Work Schedule"].waitForExistence(timeout: 10))
        XCTAssertTrue(profile.staticTexts["Mon, Tue, Wed, Thu, Fri"].exists)
        snap(profile, "profile-work-schedule")
    }

    /// Trainer Admin opens on ACLP trainers, A–Z; the ACLP / Non-ACLP / All control and the
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
        // Active people only, the same list as Team (no Analytics headcount since 1.20).
        XCTAssertEqual(staff.value as? String, "6")
        XCTAssertEqual(app.buttons["home.kpi.interns"].value as? String, "3")
        // Leave + MC + time off + claims + missed punches (preview feeds), as the "Waiting" card.
        XCTAssertEqual(app.buttons["home.kpi.pending"].value as? String, "6")
        snap(app, "home-kpi")
        app.buttons["home.kpi.interns"].tap()
        XCTAssertTrue(app.segmentedControls["team.group"].buttons["Interns 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["team.group"].buttons["Interns 3"].isSelected)
    }

    /// Each role has its own Home (1.20): interns clock in from Home; staff see AL / MC left with
    /// Apply for leave / MC; admins see the workforce tiles and never a clock or apply buttons.
    func testHomeFollowsRole() {
        let intern = launch(["-uiPreviewIntern"])
        XCTAssertTrue(intern.buttons["home.clock.punch"].waitForExistence(timeout: 10))
        XCTAssertTrue(intern.buttons["home.apply.MC"].exists)
        XCTAssertTrue(intern.buttons["home.action.mytimesheet"].exists)
        XCTAssertFalse(intern.buttons["home.kpi.staff"].exists)
        snap(intern, "home-intern")
        intern.terminate()

        let staff = launch(["-uiPreviewStaff"])
        XCTAssertTrue(staff.buttons["home.apply.AL"].waitForExistence(timeout: 10))
        XCTAssertEqual(staff.descendants(matching: .any)["home.balance.mc"].value as? String, "14 days")
        XCTAssertFalse(staff.buttons["home.clock.punch"].exists)
        XCTAssertFalse(staff.buttons["home.action.clock"].exists)
        snap(staff, "home-staff")
        staff.buttons["home.profile"].tap()
        XCTAssertTrue(staff.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        staff.terminate()

        let admin = launch([])
        XCTAssertTrue(admin.buttons["home.kpi.staff"].waitForExistence(timeout: 10))
        XCTAssertTrue(admin.buttons["home.action.approvals"].exists)
        XCTAssertFalse(admin.buttons["home.clock.punch"].exists)
        XCTAssertFalse(admin.buttons["home.apply.MC"].exists)
        XCTAssertFalse(admin.buttons["home.analytics"].exists)
        snap(admin, "home-admin")
    }

    /// View As (approvers, 1.20): preview the Staff, Intern and Accountant Homes, then back to Admin.
    func testApproverViewAsPreviewsRoles() {
        let app = launch([])
        let menu = app.buttons["home.viewAs"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertEqual(menu.value as? String, "Admin")
        XCTAssertFalse(app.staticTexts["My balances"].exists, "no balances on the admin Home")

        menu.tap(); app.buttons["viewAs.staff"].tap()
        XCTAssertTrue(app.buttons["home.apply.MC"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Leave"].tap()
        XCTAssertTrue(app.buttons["Apply for Leave"].waitForExistence(timeout: 10), "staff apply for leave")
        app.tabBars.buttons["Home"].tap()
        XCTAssertFalse(app.buttons["home.kpi.pending"].exists)
        XCTAssertFalse(app.buttons["home.clock.punch"].exists)
        XCTAssertTrue(app.staticTexts["home.viewAs.note"].exists)
        snap(app, "viewas-staff")

        app.buttons["home.viewAs"].tap(); app.buttons["viewAs.intern"].tap()
        let punch = app.buttons["home.clock.punch"]
        XCTAssertTrue(punch.waitForExistence(timeout: 10))
        XCTAssertFalse(punch.isEnabled, "no real punch while previewing")
        XCTAssertTrue(app.buttons["home.action.mytimesheet"].exists)
        snap(app, "viewas-intern")

        app.buttons["home.viewAs"].tap(); app.buttons["viewAs.accountant"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["home.finance.income"].waitForExistence(timeout: 10))
        // Accountant Home: finance only (bank statements, reconciliation), no quick actions.
        let recon = app.descendants(matching: .any)["home.finance.reconciliation"]
        for _ in 0..<6 where !recon.exists { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(recon.exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.finance.statements"].exists)
        XCTAssertFalse(app.staticTexts["Quick actions"].exists, "no quick actions for accountants")
        snap(app, "viewas-accountant")

        XCTAssertFalse(app.buttons["home.apply.MC"].exists, "accountants have no leave or MC")
        XCTAssertFalse(app.tabBars.buttons["Leave"].exists, "no Leave tab for accountants")
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.staticTexts["ATTENDANCE"].waitForExistence(timeout: 5), "accountant view clocks in")
        XCTAssertFalse(app.staticTexts["Time Off"].exists)
        XCTAssertFalse(app.staticTexts["Approvals"].exists)
        app.buttons["more.viewAs"].tap(); app.buttons["viewAs.mine"].tap()
        XCTAssertTrue(app.staticTexts["Approvals"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ATTENDANCE"].exists)
        XCTAssertFalse(app.buttons["more.apply.MC"].exists, "admins do not apply for MC")
        // Admin Leave tab: leave management, no Apply button or own balances.
        app.tabBars.buttons["Leave"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Apply for Leave"].exists)
        snap(app, "admin-leave-tab")
    }

    /// Home → My Profile → Edit profile shows the form (1.20: it was a blank sheet).
    func testEditProfileSheetShowsTheForm() {
        let app = launch(["-uiPreviewStaff"])
        let profile = app.buttons["home.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        let edit = app.buttons["Edit profile"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5), "edit form, not a blank sheet")
        snap(app, "edit-profile")
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
