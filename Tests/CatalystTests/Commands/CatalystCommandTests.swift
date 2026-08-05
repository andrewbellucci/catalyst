import XCTest
@testable import Catalyst

@MainActor
final class CatalystCommandTests: XCTestCase {
    func testCustomCommandsRoundTripThroughStore() throws {
        let suite = "CatalystCommandTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CustomCommandStore(defaults: defaults)
        let command = CatalystCommand(
            id: "deploy", title: "Deploy", category: "Development",
            symbolName: "terminal.fill", aliases: ["publish"],
            action: .runProcess(ProcessConfiguration(
                executable: "/usr/bin/env", arguments: ["npm", "run", "deploy"],
                workingDirectory: "~/Developer/site"
            ))
        )

        store.commands = [command]

        XCTAssertEqual(store.commands, [command])
        XCTAssertEqual(store.commands.first?.item.usageIdentifier, "command:deploy")
    }

    func testBuiltInsUseUnifiedDefinitions() {
        XCTAssertTrue(CommandRegistry.builtIns.allSatisfy { !$0.isEditable })
        XCTAssertEqual(
            CommandRegistry.builtIns.first { $0.id == "empty-trash" }?.action,
            .native(.emptyTrash)
        )
    }
}
