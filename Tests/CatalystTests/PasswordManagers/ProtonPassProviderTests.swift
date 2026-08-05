import XCTest
@testable import Catalyst

final class ProtonPassProviderTests: XCTestCase {
    func testProcessRunnerDrainsLargeOutputWithoutDeadlocking() throws {
        let output = try ProcessCommandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-c", "import sys; sys.stdout.write('x' * 1_000_000)"]
        )

        XCTAssertEqual(output.count, 1_000_000)
    }

    func testListsOnlyNonSecretItemSummariesAcrossVaults() async throws {
        let provider = ProtonPassProvider { arguments in
            if arguments.starts(with: ["vault", "list"]) {
                return Data(#"{"vaults":[{"name":"Personal","vault_id":"vault-1","share_id":"share-1"}]}"#.utf8)
            }
            XCTAssertEqual(arguments, [
                "item", "list", "--share-id", "share-1",
                "--output", "json", "--filter-type", "login", "--show-secrets"
            ])
            return Data(#"{"items":[{"id":"item-1","share_id":"share-1","content":{"title":"GitHub","note":"","item_uuid":"uuid","content":{"Login":{"email":"dev@example.com","username":"dev","password":"not-retained","urls":[],"totp_uri":"otpauth://totp/example","passkeys":[]}},"extra_fields":[]}}]}"#.utf8)
        }

        let items = try await provider.items()

        XCTAssertEqual(items, [PasswordManagerItem(
            providerID: "proton-pass",
            providerName: "Proton Pass",
            vaultID: "share-1",
            itemID: "item-1",
            title: "GitHub",
            email: "dev@example.com",
            hasTOTP: true
        )])
    }

    func testRetrievesOnlyTheExplicitlyRequestedField() async throws {
        let item = PasswordManagerItem(
            providerID: "proton-pass",
            providerName: "Proton Pass",
            vaultID: "share-1",
            itemID: "item-1",
            title: "GitHub",
            email: "dev@example.com",
            hasTOTP: true
        )
        let provider = ProtonPassProvider { arguments in
            XCTAssertEqual(arguments, [
                "item", "view", "--share-id", "share-1",
                "--item-id", "item-1", "--field", "password"
            ])
            return Data("secret-value\n".utf8)
        }

        let value = try await provider.value(for: .password, in: item)
        XCTAssertEqual(value, "secret-value")
    }

    func testPreparingValuesEliminatesCommandDelayWhenCopying() async throws {
        let calls = CallCounter()
        let item = PasswordManagerItem(
            providerID: "proton-pass", providerName: "Proton Pass",
            vaultID: "share-1", itemID: "item-1", title: "GitHub",
            email: "dev@example.com", hasTOTP: true
        )
        let provider = ProtonPassProvider { arguments in
            await calls.increment(arguments.last ?? "")
            try await Task.sleep(for: .milliseconds(150))
            return Data("value\n".utf8)
        }

        await provider.prepareValues(in: item)
        let start = ContinuousClock.now
        _ = try await provider.value(for: .username, in: item)
        _ = try await provider.value(for: .password, in: item)
        _ = try await provider.value(for: .totp, in: item)

        XCTAssertLessThan(start.duration(to: .now), .milliseconds(50))
        let total = await calls.total
        XCTAssertEqual(total, 3)
    }

    func testTOTPBoundaryUsesThirtySecondWindows() {
        let date = Date(timeIntervalSince1970: 61)
        XCTAssertEqual(ProtonPassProvider.nextTOTPBoundary(after: date).timeIntervalSince1970, 90)
    }

    func testCatalogLoadSeedsUsernameAndPasswordWithoutAnotherCommand() async throws {
        let calls = CallCounter()
        let provider = ProtonPassProvider { arguments in
            await calls.increment(arguments.first ?? "")
            if arguments.starts(with: ["vault", "list"]) {
                return Data(#"{"vaults":[{"share_id":"share-1"}]}"#.utf8)
            }
            return Data(#"{"items":[{"id":"item-1","share_id":"share-1","content":{"title":"GitHub","content":{"Login":{"email":"dev@example.com","username":"dev","password":"secret","totp_uri":""}}}}]}"#.utf8)
        }

        let items = try await provider.items()
        let item = try XCTUnwrap(items.first)
        let username = try await provider.value(for: .username, in: item)
        let password = try await provider.value(for: .password, in: item)
        XCTAssertEqual(username, "dev")
        XCTAssertEqual(password, "secret")
        let total = await calls.total
        XCTAssertEqual(total, 2)
    }
}

private actor CallCounter {
    private(set) var total = 0
    func increment(_ field: String) { total += 1 }
}
