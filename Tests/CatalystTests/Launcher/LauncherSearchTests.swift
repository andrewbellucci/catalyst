import AppKit
import XCTest
@testable import Catalyst

@MainActor
final class LauncherSearchTests: XCTestCase {
    func testSearchCombinesBuiltInAndDynamicCommands() {
        let search = LauncherSearch(settingsPanes: [])
        search.prepare()

        XCTAssertTrue(search.results(for: "Open Camera").contains { $0.title == "Open Camera" })
        XCTAssertTrue(search.results(for: "20 percent of 85").contains { $0.title == "17" })
        XCTAssertTrue(search.results(for: "define catalyst").contains {
            if case .dictionary("catalyst") = $0.kind { return true }
            return false
        })
    }

    func testBuiltInCommandMetadataHasUniqueUsageIdentifiers() {
        let identifiers = CommandRegistry.builtIns.map { $0.item.usageIdentifier }
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    func testEmptyTrashCommandIsSearchable() {
        let search = LauncherSearch(settingsPanes: [])

        let result = search.results(for: "empty trash").first { $0.title == "Empty Trash" }

        XCTAssertNotNil(result)
    }

    func testPasswordManagerQueriesRequirePassPrefix() {
        XCTAssertNil(LauncherSearch.passwordManagerQuery(from: "github"))
        XCTAssertNil(LauncherSearch.passwordManagerQuery(from: "password"))
        XCTAssertEqual(LauncherSearch.passwordManagerQuery(from: "pass"), "")
        XCTAssertEqual(LauncherSearch.passwordManagerQuery(from: "PASS GitHub"), "GitHub")
    }

    func testAcceptedQuitRequestImmediatelyClearsRunningStatus() throws {
        let search = LauncherSearch(settingsPanes: [])
        search.prepare()
        let finder = try XCTUnwrap(search.results(for: "Finder").first {
            if case .application = $0.kind { return $0.title == "Finder" }
            return false
        })
        guard case .application(let url) = finder.kind else {
            return XCTFail("Finder result was not an application")
        }
        XCTAssertTrue(finder.isRunning)

        search.markApplicationStopped(at: url)

        let updated = try XCTUnwrap(search.results(for: "Finder").first {
            if case .application = $0.kind { return $0.title == "Finder" }
            return false
        })
        XCTAssertFalse(updated.isRunning)
    }

    func testPeriodicReconciliationRepairsMissedApplicationStateEvents() async throws {
        let search = LauncherSearch(settingsPanes: [])
        search.prepare()
        let finder = try XCTUnwrap(search.results(for: "Finder").first {
            if case .application = $0.kind { return $0.title == "Finder" }
            return false
        })
        guard case .application(let url) = finder.kind else {
            return XCTFail("Finder result was not an application")
        }

        search.markApplicationStopped(at: url)
        try await Task.sleep(for: .milliseconds(1_250))

        let reconciled = try XCTUnwrap(search.results(for: "Finder").first {
            if case .application = $0.kind { return $0.title == "Finder" }
            return false
        })
        XCTAssertTrue(reconciled.isRunning)
    }
}
