import Foundation

@MainActor
final class UsageHistory {
    private let defaults: UserDefaults
    private let storageKey: String
    private let now: () -> Date
    private let retention: TimeInterval = 14 * 24 * 60 * 60

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "resultUsageHistory",
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.now = now
    }

    func record(_ identifier: String) {
        var history = load()
        let timestamp = now().timeIntervalSince1970
        history[identifier, default: []].append(timestamp)
        history = pruned(history, relativeTo: timestamp)
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func recentScore(for identifier: String) -> Double {
        recentScores()[identifier] ?? 0
    }

    func recentScores() -> [String: Double] {
        let current = now().timeIntervalSince1970
        let threeDays = 3 * 24 * 60 * 60.0
        return pruned(load(), relativeTo: current).mapValues { timestamps in
            timestamps.reduce(0) { score, timestamp in
                score + 9 * exp(-(current - timestamp) / threeDays)
            }
        }
    }

    private func load() -> [String: [TimeInterval]] {
        guard
            let data = defaults.data(forKey: storageKey),
            let history = try? JSONDecoder().decode([String: [TimeInterval]].self, from: data)
        else { return [:] }
        return history
    }

    private func pruned(
        _ history: [String: [TimeInterval]],
        relativeTo current: TimeInterval
    ) -> [String: [TimeInterval]] {
        history.reduce(into: [:]) { result, entry in
            let recent = entry.value.filter { current - $0 <= retention }
            if !recent.isEmpty {
                result[entry.key] = Array(recent.suffix(50))
            }
        }
    }
}

@MainActor
struct ResultRanker {
    let usageHistory: UsageHistory

    func rank(_ items: [CommandItem], query: String) -> [CommandItem] {
        let historyScores = usageHistory.recentScores()
        return items.map { item in
            (item, relevanceScore(item, query: query) + (historyScores[item.usageIdentifier] ?? 0))
        }.sorted { left, right in
            if left.1 != right.1 { return left.1 > right.1 }
            if left.0.title.count != right.0.title.count {
                return left.0.title.count < right.0.title.count
            }
            return left.0.title.localizedCaseInsensitiveCompare(right.0.title) == .orderedAscending
        }.map(\.0)
    }

    func score(_ item: CommandItem, query: String) -> Double {
        relevanceScore(item, query: query)
            + usageHistory.recentScore(for: item.usageIdentifier)
    }

    func matches(_ item: CommandItem, query: String) -> Bool {
        relevanceScore(item, query: query) > 0
    }

    private func relevanceScore(_ item: CommandItem, query: String) -> Double {
        let primaryScore = matchScore(title: item.title, subtitle: item.subtitle, query: query)
        let aliasScore = item.aliases.map {
            matchScore(title: $0, subtitle: "", query: query)
        }.max() ?? 0
        return max(primaryScore, aliasScore)
    }

    private func matchScore(title: String, subtitle: String, query: String) -> Double {
        let needle = normalized(query)
        guard !needle.isEmpty else { return 0 }
        let name = normalized(title)
        if name == needle { return 100 }
        if name.hasPrefix(needle) { return 94 }
        if name.split(separator: " ").contains(Substring(needle)) { return 88 }
        if name.contains(needle) { return 82 }
        if isSubsequence(needle, of: name) { return 65 }
        return normalized(subtitle).contains(needle) ? 55 : 0
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var index = needle.startIndex
        for character in haystack where index < needle.endIndex && character == needle[index] {
            index = needle.index(after: index)
        }
        return index == needle.endIndex
    }
}
