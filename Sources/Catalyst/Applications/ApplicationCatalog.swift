import AppKit

struct InstalledApplication {
    let name: String
    let url: URL
    let bundleIdentifier: String?
    let icon: NSImage
}

final class ApplicationCatalog {
    private(set) var applications: [InstalledApplication] = []

    func load() {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        var found: [String: URL] = [:]

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                found[name.lowercased()] = url
            }
        }

        if let finder = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
            found["finder"] = finder
        }

        applications = found.map { _, url in
            InstalledApplication(
                name: url.deletingPathExtension().lastPathComponent,
                url: url,
                bundleIdentifier: Bundle(url: url)?.bundleIdentifier,
                icon: NSWorkspace.shared.icon(forFile: url.path)
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func search(
        _ query: String,
        aliases: (InstalledApplication) -> [String] = { _ in [] },
        limit: Int = 8
    ) -> [InstalledApplication] {
        let needle = query.lowercased()
        if needle.isEmpty {
            return Array(applications.prefix(limit))
        }
        let ranked = applications.compactMap { app -> (InstalledApplication, Int)? in
            let bestScore = ([app.name] + aliases(app)).compactMap { candidate -> Int? in
                let name = candidate.lowercased()
                if name == needle { return 0 }
                if name.hasPrefix(needle) { return 1 }
                if name.contains(needle) { return 2 }
                if isSubsequence(needle, of: name) { return 3 }
                return nil
            }.min()
            if let bestScore { return (app, bestScore) }
            return nil
        }
        return ranked.sorted {
            $0.1 == $1.1 ? $0.0.name.count < $1.0.name.count : $0.1 < $1.1
        }.prefix(limit).map(\.0)
    }

    private func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var index = needle.startIndex
        for character in haystack where index < needle.endIndex && character == needle[index] {
            index = needle.index(after: index)
        }
        return index == needle.endIndex
    }
}
