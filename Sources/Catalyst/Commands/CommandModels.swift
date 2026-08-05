import AppKit

enum CommandKind {
    case section
    case camera
    case quitFocused
    case quitAll
    case restartDevice
    case lockDevice
    case lockKeyboard
    case emptyTrash
    case shutDownDevice
    case toggleSystemAppearance
    case restartCatalyst
    case quitCatalyst
    case settings
    case systemSettings(URL)
    case dictionary(String)
    case calculation(String)
    case application(URL)
    case passwordItem(PasswordManagerItem)
    case hint
}

struct CommandItem {
    let title: String
    let subtitle: String
    let icon: NSImage?
    let kind: CommandKind
    let isRunning: Bool
    let aliases: [String]

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        kind: CommandKind,
        isRunning: Bool = false,
        aliases: [String] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.kind = kind
        self.isRunning = isRunning
        self.aliases = aliases
    }

    static func section(_ title: String) -> CommandItem {
        CommandItem(title: title, subtitle: "", icon: nil, kind: .section)
    }

    var isSelectable: Bool {
        if case .section = kind { return false }
        return true
    }

    var resultType: String {
        switch kind {
        case .application: "Application"
        case .passwordItem: "Login"
        case .calculation: "Result"
        case .hint: ""
        case .section: ""
        default: "Command"
        }
    }

    var actionTitle: String {
        switch kind {
        case .application: "Open Application"
        case .passwordItem: "Choose Credential Action"
        case .calculation: "Copy Result"
        case .dictionary: "Show Definition"
        case .camera: "Open Camera"
        case .quitFocused, .quitAll, .restartDevice, .lockDevice, .emptyTrash, .shutDownDevice,
             .toggleSystemAppearance:
            "Run Command"
        case .lockKeyboard: "Choose Duration"
        case .restartCatalyst: "Restart Catalyst"
        case .quitCatalyst: "Quit Catalyst"
        case .settings: "Open Settings"
        case .systemSettings: "Open System Settings"
        case .hint, .section: ""
        }
    }

    var usageIdentifier: String {
        switch kind {
        case .application(let url): "application:\(url.standardizedFileURL.path)"
        case .passwordItem(let item):
            "password-manager:\(item.providerID):\(item.vaultID):\(item.itemID)"
        case .camera: "command:camera"
        case .quitFocused: "command:quit-focused"
        case .quitAll: "command:quit-all"
        case .restartDevice: "command:restart-device"
        case .lockDevice: "command:lock-device"
        case .lockKeyboard: "command:lock-keyboard"
        case .emptyTrash: "command:empty-trash"
        case .shutDownDevice: "command:shutdown-device"
        case .toggleSystemAppearance: "command:toggle-system-appearance"
        case .restartCatalyst: "command:restart-catalyst"
        case .quitCatalyst: "command:quit-catalyst"
        case .settings: "command:settings"
        case .systemSettings(let url): "system-settings:\(url.absoluteString)"
        case .dictionary(let term): "dictionary:\(term.lowercased())"
        case .calculation: "command:calculation"
        case .hint: "hint"
        case .section: "section"
        }
    }
}
