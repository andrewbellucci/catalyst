import AppKit

struct SystemSettingsPane {
    let title: String
    let url: URL
    let icon: NSImage?
    let aliases: [String]
}

struct SystemSettingsCatalog {
    private static let extensionsURL = URL(
        fileURLWithPath: "/System/Library/ExtensionKit/Extensions",
        isDirectory: true
    )

    func panes(in directory: URL = Self.extensionsURL) -> [SystemSettingsPane] {
        let extensionURLs = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        var seen = Set<String>()
        return extensionURLs.compactMap { extensionURL in
            let infoURL = extensionURL.appendingPathComponent("Contents/Info.plist")
            guard
                extensionURL.pathExtension == "appex",
                let data = try? Data(contentsOf: infoURL),
                let info = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: Any],
                let attributes = info["EXAppExtensionAttributes"] as? [String: Any],
                let settings = attributes["SettingsExtensionAttributes"] as? [String: Any],
                settings["allowsXAppleSystemPreferencesURLScheme"] as? Bool == true,
                let identifier = info["CFBundleIdentifier"] as? String,
                !seen.contains(identifier),
                let url = URL(string: "x-apple.systempreferences:\(identifier)")
            else { return nil }

            seen.insert(identifier)
            let rawTitle = (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String)
                ?? extensionURL.deletingPathExtension().lastPathComponent
            let title = displayTitle(rawTitle, identifier: identifier)
            let iconConfiguration = info["CFBundleIcons"] as? [String: Any]
            let graphicConfiguration = iconConfiguration?["ISGraphicIconConfiguration"]
                as? [String: Any]
            let symbolName = graphicConfiguration?["ISSymbolName"] as? String

            return SystemSettingsPane(
                title: title,
                url: url,
                icon: symbolName.flatMap {
                    NSImage(systemSymbolName: $0, accessibilityDescription: title)
                } ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: title),
                aliases: ["settings", "system settings", "system preferences"]
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func displayTitle(_ rawTitle: String, identifier: String) -> String {
        let knownRawTitles = [
            "AccessibilitySettingsExtension": "Accessibility",
            "DateAndTime Extension": "Date & Time",
            "InternetAccountsSettingsExtension": "Internet Accounts",
            "MouseExtension": "Mouse",
            "SoftwareUpdateSettingsExtension": "Software Update",
            "TimeMachineSettings": "Time Machine",
            "TrackpadExtension": "Trackpad",
            "UsersGroups": "Users & Groups",
            "WiFiSettings": "Wi-Fi"
        ]
        if let knownTitle = knownRawTitles[rawTitle] { return knownTitle }

        let knownTitles = [
            "com.apple.Accessibility-Settings.extension": "Accessibility",
            "com.apple.Date-Time-Settings.extension": "Date & Time",
            "com.apple.Desktop-Settings.extension": "Desktop & Dock",
            "com.apple.Internet-Accounts-Settings.extension": "Internet Accounts",
            "com.apple.Mouse-Settings.extension": "Mouse",
            "com.apple.Network-Settings.extension": "Network",
            "com.apple.Print-Scan-Settings.extension": "Printers & Scanners",
            "com.apple.Software-Update-Settings.extension": "Software Update",
            "com.apple.Trackpad-Settings.extension": "Trackpad",
            "com.apple.Users-Groups-Settings.extension": "Users & Groups",
            "com.apple.WiFi-Settings.extension": "Wi-Fi"
        ]
        if let knownTitle = knownTitles[identifier] { return knownTitle }

        return rawTitle
            .replacingOccurrences(of: "SettingsIntentsExtension", with: "")
            .replacingOccurrences(of: "SettingsExtension", with: "")
            .replacingOccurrences(of: " Extension", with: "")
            .replacingOccurrences(of: "Extension", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
