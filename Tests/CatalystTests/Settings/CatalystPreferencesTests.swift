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
}
