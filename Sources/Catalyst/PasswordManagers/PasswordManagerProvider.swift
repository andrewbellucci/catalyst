import Foundation

enum PasswordManagerField: String, CaseIterable, Sendable {
    case username
    case password
    case totp

    var title: String {
        switch self {
        case .username: "Username"
        case .password: "Password"
        case .totp: "TOTP"
        }
    }
}

struct PasswordManagerItem: Hashable, Sendable {
    let providerID: String
    let providerName: String
    let vaultID: String
    let itemID: String
    let title: String
    let email: String
    let hasUsername: Bool
    let hasPassword: Bool
    let hasTOTP: Bool

    init(
        providerID: String,
        providerName: String,
        vaultID: String,
        itemID: String,
        title: String,
        email: String,
        hasUsername: Bool = true,
        hasPassword: Bool = true,
        hasTOTP: Bool
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.vaultID = vaultID
        self.itemID = itemID
        self.title = title
        self.email = email
        self.hasUsername = hasUsername
        self.hasPassword = hasPassword
        self.hasTOTP = hasTOTP
    }
}

protocol PasswordManagerProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get }
    func items() async throws -> [PasswordManagerItem]
    func prepareValues(in item: PasswordManagerItem) async
    func value(for field: PasswordManagerField, in item: PasswordManagerItem) async throws -> String
}

extension PasswordManagerProvider {
    func prepareValues(in item: PasswordManagerItem) async {}
}

enum PasswordManagerError: LocalizedError {
    case providerUnavailable(String)
    case commandFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let message), .commandFailed(let message): message
        case .invalidResponse: "The password manager returned an invalid response."
        }
    }
}
