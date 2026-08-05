import Foundation

struct PasswordManagerDescriptor: Sendable {
    let id: String
    let name: String
    let makeProvider: @Sendable () -> any PasswordManagerProvider
}

enum PasswordManagerRegistry {
    static let available: [PasswordManagerDescriptor] = [
        PasswordManagerDescriptor(
            id: "proton-pass",
            name: "Proton Pass",
            makeProvider: { ProtonPassProvider() }
        )
    ]
}
