import AppKit

enum NativeCommandID: String, Codable, Hashable, Sendable {
    case camera, quitFocused, quitAll, restartDevice, lockDevice, lockKeyboard
    case emptyTrash, shutDownDevice, toggleSystemAppearance, restartCatalyst, quitCatalyst, settings
}

struct ProcessConfiguration: Codable, Hashable, Sendable {
    var executable: String
    var arguments: [String]
    var workingDirectory: String?
    var runsThroughShell: Bool = false
}

enum CatalystCommandAction: Codable, Hashable, Sendable {
    case native(NativeCommandID)
    case openURL(String)
    case runProcess(ProcessConfiguration)
}

struct CatalystCommand: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var category: String
    var symbolName: String
    var aliases: [String]
    var action: CatalystCommandAction
    var isEnabled: Bool = true
    var isEditable: Bool = true

    var item: CommandItem {
        CommandItem(
            title: title,
            subtitle: category,
            icon: NSImage(systemSymbolName: symbolName, accessibilityDescription: title),
            kind: .defined(self),
            aliases: aliases
        )
    }

    var actionTitle: String {
        switch action {
        case .native(.camera): "Open Camera"
        case .native(.lockKeyboard): "Choose Duration"
        case .native(.restartCatalyst): "Restart Catalyst"
        case .native(.quitCatalyst): "Quit Catalyst"
        case .native(.settings): "Open Settings"
        case .openURL: "Open"
        case .runProcess: "Run Command"
        default: "Run Command"
        }
    }
}

extension Notification.Name {
    static let catalystCommandsDidChange = Notification.Name("CatalystCommandsDidChange")
}

@MainActor
final class CustomCommandStore {
    static let shared = CustomCommandStore()
    private static let key = "customCommands"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var commands: [CatalystCommand] {
        get {
            guard let data = defaults.data(forKey: Self.key) else { return [] }
            return (try? JSONDecoder().decode([CatalystCommand].self, from: data)) ?? []
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.key)
            NotificationCenter.default.post(name: .catalystCommandsDidChange, object: self)
        }
    }
}
