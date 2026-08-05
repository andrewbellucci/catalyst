import AppKit
import Carbon

extension Notification.Name {
    static let catalystHotKeyDidChange = Notification.Name("CatalystHotKeyDidChange")
    static let catalystHighlightDidChange = Notification.Name("CatalystHighlightDidChange")
    static let catalystTransparencyDidChange = Notification.Name("CatalystTransparencyDidChange")
    static let catalystStatusBarVisibilityDidChange = Notification.Name(
        "CatalystStatusBarVisibilityDidChange"
    )
    static let catalystPasswordManagerDidChange = Notification.Name(
        "CatalystPasswordManagerDidChange"
    )
}

enum CatalystSearchDisplay: String, CaseIterable {
    case active
    case main

    var title: String {
        switch self {
        case .active: "Active Display"
        case .main: "Main Display"
        }
    }
}

enum CatalystToastDuration: String, CaseIterable {
    case two, three, five, eight

    var seconds: TimeInterval {
        switch self {
        case .two: 2
        case .three: 3
        case .five: 5
        case .eight: 8
        }
    }

    var title: String { "\(Int(seconds)) Seconds" }
}

enum CatalystHighlightColor: String, CaseIterable {
    case blue, red, orange, pink, green, gray

    var title: String { rawValue.capitalized }

    var color: NSColor {
        switch self {
        case .blue: .systemBlue
        case .red: .systemRed
        case .orange: .systemOrange
        case .pink: .systemPink
        case .green: .systemGreen
        case .gray: .systemGray
        }
    }
}

enum CatalystHotKey: String, CaseIterable {
    case optionSpace
    case commandSpace
    case controlSpace
    case optionCommandSpace

    var title: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .commandSpace: "⌘ Space"
        case .controlSpace: "⌃ Space"
        case .optionCommandSpace: "⌥⌘ Space"
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .optionSpace: UInt32(optionKey)
        case .commandSpace: UInt32(cmdKey)
        case .controlSpace: UInt32(controlKey)
        case .optionCommandSpace: UInt32(optionKey | cmdKey)
        }
    }

    var keyCode: UInt32 { UInt32(kVK_Space) }
}

@MainActor
final class CatalystPreferences {
    static let shared = CatalystPreferences()

    private enum Key {
        static let hotKey = "hotKey"
        static let highlightColor = "highlightColor"
        static let backgroundOpacity = "backgroundOpacity"
        static let showsStatusBarIcon = "showsStatusBarIcon"
        static let searchDisplay = "searchDisplay"
        static let passwordManagerID = "passwordManagerID"
        static let toastDuration = "toastDuration"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hotKey: CatalystHotKey {
        get { CatalystHotKey(rawValue: defaults.string(forKey: Key.hotKey) ?? "") ?? .optionSpace }
        set {
            defaults.set(newValue.rawValue, forKey: Key.hotKey)
            NotificationCenter.default.post(name: .catalystHotKeyDidChange, object: self)
        }
    }

    var highlightColor: CatalystHighlightColor {
        get {
            CatalystHighlightColor(rawValue: defaults.string(forKey: Key.highlightColor) ?? "") ?? .blue
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.highlightColor)
            NotificationCenter.default.post(name: .catalystHighlightDidChange, object: self)
        }
    }

    var backgroundOpacity: Double {
        get {
            guard defaults.object(forKey: Key.backgroundOpacity) != nil else { return 0.72 }
            return min(max(defaults.double(forKey: Key.backgroundOpacity), 0.05), 1)
        }
        set {
            defaults.set(min(max(newValue, 0.05), 1), forKey: Key.backgroundOpacity)
            NotificationCenter.default.post(name: .catalystTransparencyDidChange, object: self)
        }
    }

    var showsStatusBarIcon: Bool {
        get {
            guard defaults.object(forKey: Key.showsStatusBarIcon) != nil else { return true }
            return defaults.bool(forKey: Key.showsStatusBarIcon)
        }
        set {
            defaults.set(newValue, forKey: Key.showsStatusBarIcon)
            NotificationCenter.default.post(
                name: .catalystStatusBarVisibilityDidChange,
                object: self
            )
        }
    }

    var searchDisplay: CatalystSearchDisplay {
        get {
            CatalystSearchDisplay(rawValue: defaults.string(forKey: Key.searchDisplay) ?? "")
                ?? .active
        }
        set { defaults.set(newValue.rawValue, forKey: Key.searchDisplay) }
    }

    var passwordManagerID: String? {
        get {
            guard defaults.object(forKey: Key.passwordManagerID) != nil else {
                return PasswordManagerRegistry.available.first?.id
            }
            let value = defaults.string(forKey: Key.passwordManagerID) ?? ""
            return value.isEmpty ? nil : value
        }
        set {
            defaults.set(newValue ?? "", forKey: Key.passwordManagerID)
            NotificationCenter.default.post(name: .catalystPasswordManagerDidChange, object: self)
        }
    }

    var toastDuration: CatalystToastDuration {
        get {
            CatalystToastDuration(rawValue: defaults.string(forKey: Key.toastDuration) ?? "")
                ?? .three
        }
        set { defaults.set(newValue.rawValue, forKey: Key.toastDuration) }
    }
}
