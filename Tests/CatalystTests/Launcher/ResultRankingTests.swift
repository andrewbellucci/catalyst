import AppKit
import XCTest
@testable import Catalyst

@MainActor
final class ResultRankingTests: XCTestCase {
    func testApplicationAliasesArePersistedAndRanked() throws {
        let suiteName = "CatalystAliasTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ApplicationAliasStore(defaults: defaults)
        let url = URL(fileURLWithPath: "/Applications/Example.app")

        store.setAliases(
            ["work", " browser ", "WORK", ""],
            for: url,
            bundleIdentifier: "com.example.app"
        )
        XCTAssertEqual(
            store.aliases(for: url, bundleIdentifier: "com.example.app"),
            ["work", "browser"]
        )

        let history = UsageHistory(defaults: defaults, storageKey: "aliasRankingHistory")
        let item = CommandItem(
            title: "Example",
            subtitle: "",
            icon: nil,
            kind: .application(url),
            aliases: store.aliases(for: url, bundleIdentifier: "com.example.app")
        )
        XCTAssertGreaterThan(ResultRanker(usageHistory: history).score(item, query: "browser"), 0)
    }

    func testRecentUsageCanPromoteAHighlyRelevantApplication() throws {
        let suiteName = "CatalystRankingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let history = UsageHistory(defaults: defaults, now: { now })
        let ranker = ResultRanker(usageHistory: history)
        let systemSettings = CommandItem(
            title: "System Settings",
            subtitle: "",
            icon: nil,
            kind: .application(URL(fileURLWithPath: "/Applications/System Settings.app"))
        )
        let catalystSettings = CommandItem(
            title: "Settings",
            subtitle: "Catalyst",
            icon: nil,
            kind: .settings
        )

        XCTAssertEqual(
            ranker.rank([systemSettings, catalystSettings], query: "settings").first?.title,
            "Settings"
        )
        history.record(systemSettings.usageIdentifier)
        history.record(systemSettings.usageIdentifier)
        XCTAssertEqual(
            ranker.rank([systemSettings, catalystSettings], query: "settings").first?.title,
            "System Settings"
        )
    }
}
