import Foundation

struct ProtonPassProvider: PasswordManagerProvider {
    typealias CommandRunner = @Sendable (_ arguments: [String]) async throws -> Data

    let id = "proton-pass"
    let name = "Proton Pass"
    let isAvailable: Bool
    private let runCommand: CommandRunner
    private let valueCache = ProtonPassValueCache()

    init(runCommand: CommandRunner? = nil) {
        if let runCommand {
            self.runCommand = runCommand
            isAvailable = true
        } else if let executable = Self.executableURL() {
            self.runCommand = Self.liveCommandRunner(executable: executable)
            isAvailable = true
        } else {
            self.runCommand = { _ in
                throw PasswordManagerError.providerUnavailable(
                    "Install Proton Pass CLI and run ‘pass-cli login’ before using Proton Pass in Catalyst."
                )
            }
            isAvailable = false
        }
    }

    func items() async throws -> [PasswordManagerItem] {
        let vaultData = try await runCommand(["vault", "list", "--output", "json"])
        let vaults = try JSONDecoder().decode(VaultList.self, from: vaultData).vaults
        var results: [PasswordManagerItem] = []
        for vault in vaults {
            let data = try await runCommand([
                "item", "list", "--share-id", vault.shareID,
                "--output", "json", "--filter-type", "login", "--show-secrets"
            ])
            let items = try JSONDecoder().decode(ItemList.self, from: data).items
            for rawItem in items {
                let item = PasswordManagerItem(
                    providerID: id,
                    providerName: name,
                    vaultID: rawItem.shareID,
                    itemID: rawItem.id,
                    title: rawItem.content.title,
                    email: rawItem.content.content.login?.email ?? "",
                    hasUsername: rawItem.content.content.login?.username.isEmpty == false,
                    hasPassword: rawItem.content.content.login?.password.isEmpty == false,
                    hasTOTP: rawItem.content.content.login?.totpURI.isEmpty == false
                )
                results.append(item)
                if let login = rawItem.content.content.login {
                    await seed(login.username, field: .username, item: item)
                    await seed(login.password, field: .password, item: item)
                }
            }
        }
        return results
    }

    func value(for field: PasswordManagerField, in item: PasswordManagerItem) async throws -> String {
        guard item.providerID == id else { throw PasswordManagerError.invalidResponse }
        let key = Self.cacheKey(field: field, item: item)
        let expiration = field == .totp
            ? Self.nextTOTPBoundary(after: Date())
            : Date().addingTimeInterval(15)
        return try await valueCache.value(for: key, expiresAt: expiration) {
            let data = try await runCommand([
                "item", "view", "--share-id", item.vaultID,
                "--item-id", item.itemID, "--field", field.rawValue
            ])
            guard let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
            else { throw PasswordManagerError.invalidResponse }
            return value
        }
    }

    private func seed(_ value: String, field: PasswordManagerField, item: PasswordManagerItem) async {
        guard !value.isEmpty else { return }
        await valueCache.store(
            value,
            for: Self.cacheKey(field: field, item: item),
            expiresAt: Date().addingTimeInterval(300)
        )
    }

    private static func cacheKey(field: PasswordManagerField, item: PasswordManagerItem) -> String {
        "\(item.vaultID):\(item.itemID):\(field.rawValue)"
    }

    static func nextTOTPBoundary(after date: Date) -> Date {
        Date(timeIntervalSince1970: (floor(date.timeIntervalSince1970 / 30) + 1) * 30)
    }

    func prepareValues(in item: PasswordManagerItem) async {
        await withTaskGroup(of: Void.self) { group in
            let fields = PasswordManagerField.allCases.filter {
                switch $0 {
                case .username: item.hasUsername
                case .password: item.hasPassword
                case .totp: item.hasTOTP
                }
            }
            for field in fields {
                group.addTask { _ = try? await value(for: field, in: item) }
            }
        }
    }

    private struct VaultList: Decodable { let vaults: [Vault] }
    private struct Vault: Decodable {
        let shareID: String
        enum CodingKeys: String, CodingKey { case shareID = "share_id" }
    }
    private struct ItemList: Decodable { let items: [Item] }
    private struct Item: Decodable {
        let id: String
        let shareID: String
        let content: ItemData
        enum CodingKeys: String, CodingKey { case id, content; case shareID = "share_id" }
    }
    private struct ItemData: Decodable {
        let title: String
        let content: ItemContent
    }
    private struct ItemContent: Decodable {
        let login: Login?
        enum CodingKeys: String, CodingKey { case login = "Login" }
    }
    private struct Login: Decodable {
        let email: String
        let username: String
        let password: String
        let totpURI: String
        enum CodingKeys: String, CodingKey { case email, username, password; case totpURI = "totp_uri" }
    }

    private static func liveCommandRunner(executable: URL) -> CommandRunner {
        { arguments in
            try ProcessCommandRunner.run(executable: executable, arguments: arguments)
        }
    }

    private static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/opt/homebrew/bin/pass-cli",
            "/usr/local/bin/pass-cli",
            "\(home)/.local/bin/pass-cli"
        ].first(where: { FileManager.default.isExecutableFile(atPath: $0) })
            .map(URL.init(fileURLWithPath:))
    }
}

private actor ProtonPassValueCache {
    private struct Entry {
        let task: Task<String, Error>
        let expiresAt: Date
    }
    private var entries: [String: Entry] = [:]

    func store(_ value: String, for key: String, expiresAt: Date) {
        entries[key] = Entry(task: Task { value }, expiresAt: expiresAt)
    }

    func value(
        for key: String,
        expiresAt: Date,
        loader: @escaping @Sendable () async throws -> String
    ) async throws -> String {
        if let entry = entries[key], entry.expiresAt > Date() {
            return try await entry.task.value
        }
        let task = Task { try await loader() }
        entries[key] = Entry(task: task, expiresAt: expiresAt)
        do {
            return try await task.value
        } catch {
            entries[key] = nil
            throw error
        }
    }
}
