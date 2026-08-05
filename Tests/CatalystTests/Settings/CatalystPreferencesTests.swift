import XCTest
@testable import Catalyst

@MainActor
final class CatalystPreferencesTests: XCTestCase {
    func testStatusBarIconIsVisibleByDefaultAndPersistsChanges() throws {
        let suiteName = "CatalystPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CatalystPreferences(defaults: defaults)

        XCTAssertTrue(preferences.showsStatusBarIcon)
        preferences.showsStatusBarIcon = false
        XCTAssertFalse(preferences.showsStatusBarIcon)
    }

    func testSearchDisplayDefaultsToActiveAndPersistsMain() throws {
        let suiteName = "CatalystPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CatalystPreferences(defaults: defaults)

        XCTAssertEqual(preferences.searchDisplay, .active)
        preferences.searchDisplay = .main
        XCTAssertEqual(preferences.searchDisplay, .main)
    }

    func testPasswordManagerDefaultsToFirstProviderAndCanBeDisabled() throws {
        let suiteName = "CatalystPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CatalystPreferences(defaults: defaults)

        XCTAssertEqual(preferences.passwordManagerID, "proton-pass")
        preferences.passwordManagerID = nil
        XCTAssertNil(preferences.passwordManagerID)
    }

    func testToastDurationDefaultsToThreeSecondsAndPersists() throws {
        let suiteName = "CatalystPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CatalystPreferences(defaults: defaults)

        XCTAssertEqual(preferences.toastDuration, .three)
        preferences.toastDuration = .eight
        XCTAssertEqual(preferences.toastDuration.seconds, 8)
    }

    func testNotchToastFrameAppearsBelowTheSafeArea() {
        let frame = NotchToastController.frame(
            for: NSSize(width: 300, height: 50),
            on: NSRect(x: 0, y: 0, width: 1_512, height: 982),
            safeAreaTop: 32
        )

        XCTAssertEqual(frame.midX, 756)
        XCTAssertEqual(frame.maxY, 942)
    }

    func testNotchToastUsesCompactMacOSSizing() {
        XCTAssertEqual(NotchToastController.toastHeight, 42)
        XCTAssertEqual(NotchToastController.indicatorDiameter, 10)
        XCTAssertEqual(NotchToastController.indicatorHaloDiameter, 20)
    }

    func testNotchToastCollapsesIntoItsTopCenter() {
        let expanded = NSRect(x: 600, y: 900, width: 240, height: 42)
        let collapsed = NotchToastController.collapsedFrame(for: expanded)

        XCTAssertEqual(collapsed.size, NSSize(width: 44, height: 6))
        XCTAssertEqual(collapsed.midX, expanded.midX)
        XCTAssertEqual(collapsed.maxY, expanded.maxY + 8)
    }

    func testLauncherScreenSelectionUsesPointerForActiveAndFirstScreenForMain() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1_000, height: 800),
            CGRect(x: 1_000, y: 0, width: 1_000, height: 800)
        ]

        XCTAssertEqual(
            LauncherScreenSelector.targetIndex(
                screenFrames: screens,
                mouseLocation: CGPoint(x: 1_500, y: 400),
                preference: .active
            ),
            1
        )
        XCTAssertEqual(
            LauncherScreenSelector.targetIndex(
                screenFrames: screens,
                mouseLocation: CGPoint(x: 1_500, y: 400),
                preference: .main
            ),
            0
        )
    }
}
