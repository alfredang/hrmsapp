import XCTest
@testable import TertiaryHRMSiOSApp

@MainActor
final class AppearanceTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "appearance-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testDefaultIsSystemExceptTheTwoLightAccounts() {
        XCTAssertEqual(Appearance.defaultFor(email: "angch@tertiaryinfotech.com"), .light)
        XCTAssertEqual(Appearance.defaultFor(email: " TanSC@tertiaryinfotech.com "), .light)
        XCTAssertEqual(Appearance.defaultFor(email: "someone@tertiaryinfotech.com"), .system)
        XCTAssertEqual(Appearance.defaultFor(email: nil), .system)
    }

    func testNothingSavedMeansSystem() {
        let store = AppearanceStore(defaults: freshDefaults())
        XCTAssertEqual(store.selection, .system)
        XCTAssertFalse(store.hasSavedChoice)
    }

    func testAccountDefaultAppliesOnlyWhenNothingIsSaved() {
        let defaults = freshDefaults()
        let store = AppearanceStore(defaults: defaults)
        store.applyAccountDefault(email: "someone@tertiaryinfotech.com")
        XCTAssertFalse(store.hasSavedChoice)                      // System accounts save nothing
        store.applyAccountDefault(email: "angch@tertiaryinfotech.com")
        XCTAssertEqual(store.selection, .light)
        store.select(.dark)
        store.applyAccountDefault(email: "angch@tertiaryinfotech.com")
        XCTAssertEqual(store.selection, .dark)                    // a saved choice is kept
        XCTAssertEqual(AppearanceStore(defaults: defaults).selection, .dark)   // and survives relaunch
    }

    func testInterfaceStyles() {
        XCTAssertEqual(Appearance.light.interfaceStyle, .light)
        XCTAssertEqual(Appearance.dark.interfaceStyle, .dark)
        XCTAssertEqual(Appearance.system.interfaceStyle, .unspecified)
    }
}
