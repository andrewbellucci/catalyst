import Foundation

@MainActor
final class PasswordManagerCatalog {
    var onChange: (() -> Void)?
    private(set) var items: [PasswordManagerItem] = []
    private(set) var error: Error?
    private let providers: [any PasswordManagerProvider]

    init(providers: [any PasswordManagerProvider] = PasswordManagerRegistry.available.map { $0.makeProvider() }) {
        self.providers = providers
    }

    var selectedItems: [PasswordManagerItem] {
        guard let selectedID = CatalystPreferences.shared.passwordManagerID else { return [] }
        return items.filter { $0.providerID == selectedID }
    }

    func reload() {
        Task {
            var loaded: [PasswordManagerItem] = []
            var lastError: Error?
            for provider in providers where provider.isAvailable {
                do { loaded.append(contentsOf: try await provider.items()) }
                catch { lastError = error }
            }
            items = loaded
            error = lastError
            onChange?()
        }
    }

    func value(for field: PasswordManagerField, in item: PasswordManagerItem) async throws -> String {
        guard let provider = providers.first(where: { $0.id == item.providerID }) else {
            throw PasswordManagerError.providerUnavailable("Password manager is no longer available.")
        }
        return try await provider.value(for: field, in: item)
    }

    func prepareValues(in item: PasswordManagerItem) async {
        guard let provider = providers.first(where: { $0.id == item.providerID }) else { return }
        await provider.prepareValues(in: item)
    }
}
