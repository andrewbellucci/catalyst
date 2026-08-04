import XCTest
@testable import Catalyst

@MainActor
final class CommandExecutorTests: XCTestCase {
    func testNavigationCommandsReturnExplicitOutcomes() {
        let executor = CommandExecutor()

        XCTAssertEqual(executor.execute(.camera, previousApplication: nil), .showCamera)
        XCTAssertEqual(executor.execute(.settings, previousApplication: nil), .showSettings)
        XCTAssertEqual(
            executor.execute(.lockKeyboard, previousApplication: nil),
            .showKeyboardLockDurations
        )
        XCTAssertEqual(
            executor.execute(.dictionary("catalyst"), previousApplication: nil),
            .showDefinition("catalyst")
        )
    }

    func testApplicationCommandUsesApplicationLauncher() {
        let launcher = RecordingApplicationLauncher()
        let executor = CommandExecutor(applicationLauncher: launcher)
        let url = URL(fileURLWithPath: "/Applications/T3 Code (Nightly).app")

        XCTAssertEqual(executor.execute(.application(url), previousApplication: nil), .dismiss)
        XCTAssertEqual(launcher.openedURL, url)
    }

    func testColdLaunchActivationPolicyRetriesWhileApplicationCreatesItsWindow() {
        XCTAssertEqual(
            ApplicationLauncher.activationRetryDelays,
            [.zero, .milliseconds(150), .milliseconds(500), .seconds(1), .seconds(2), .seconds(4)]
        )
    }

    func testInvalidColdLaunchResponseFallsBackToFinderCompatibleLauncher() async throws {
        let fallback = RecordingApplicationLauncher()
        let launcher = ApplicationLauncher(
            workspaceOpen: { _, completion in completion(nil, nil) },
            fallback: fallback
        )
        let url = URL(fileURLWithPath: "/Applications/T3 Code (Nightly).app")

        launcher.open(url)
        await Task.yield()

        XCTAssertEqual(fallback.openedURL, url)
    }
}

@MainActor
private final class RecordingApplicationLauncher: ApplicationOpening {
    private(set) var openedURL: URL?

    func open(_ url: URL) {
        openedURL = url
    }
}
