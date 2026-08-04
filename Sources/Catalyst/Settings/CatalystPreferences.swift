import AppKit
import Carbon

extension Notification.Name {
    static let catalystHotKeyDidChange = Notification.Name("CatalystHotKeyDidChange")
    static let catalystHighlightDidChange = Notification.Name("CatalystHighlightDidChange")
    static let catalystTransparencyDidChange = Notification.Name("CatalystTransparencyDidChange")
    static let catalystStatusBarVisibilityDidChange = Notification.Name(
        "CatalystStatusBarVisibilityDidChange"
    )
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
}
