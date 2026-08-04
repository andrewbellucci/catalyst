import Foundation

final class ApplicationAliasStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "applicationAliases") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func aliases(for url: URL, bundleIdentifier: String? = nil) -> [String] {
        storedAliases[identifier(for: url, bundleIdentifier: bundleIdentifier)] ?? []
    }

    func setAliases(_ aliases: [String], for url: URL, bundleIdentifier: String? = nil) {
        var values = storedAliases
        let key = identifier(for: url, bundleIdentifier: bundleIdentifier)
        let cleaned = aliases.reduce(into: [String]()) { result, alias in
            let value = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !value.isEmpty,
                !result.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame })
            else { return }
            result.append(value)
        }
        if cleaned.isEmpty {
            values.removeValue(forKey: key)
        } else {
            values[key] = cleaned
        }
        defaults.set(values, forKey: storageKey)
    }

    private var storedAliases: [String: [String]] {
        defaults.dictionary(forKey: storageKey) as? [String: [String]] ?? [:]
    }

    private func identifier(for url: URL, bundleIdentifier: String?) -> String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier)"
        }
        return "path:\(url.standardizedFileURL.path)"
    }
}
