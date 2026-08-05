import AppKit

enum CommandRegistry {
    static let builtIns: [CatalystCommand] = [
        builtIn("camera", "Open Camera", "Catalyst", "camera.fill", .camera),
        builtIn("quit-focused", "Quit Focused App", "System Actions", "xmark.app.fill", .quitFocused),
        builtIn("quit-all", "Quit All Apps", "System Actions", "xmark.circle.fill", .quitAll),
        builtIn("restart-device", "Restart Device", "System Actions", "arrow.clockwise.circle.fill", .restartDevice),
        builtIn("lock-device", "Lock Device", "System Actions", "lock.fill", .lockDevice),
        builtIn("lock-keyboard", "Lock Keyboard", "Cleaning", "keyboard.badge.ellipsis", .lockKeyboard),
        builtIn("empty-trash", "Empty Trash", "Cleaning", "trash.fill", .emptyTrash,
                aliases: ["clear trash", "empty bin", "empty recycling bin"]),
        builtIn("shutdown-device", "Shut Down Device", "System Actions", "power.circle.fill", .shutDownDevice),
        builtIn("toggle-system-appearance", "Toggle System Appearance", "System Actions", "circle.lefthalf.filled", .toggleSystemAppearance),
        builtIn("restart-catalyst", "Restart Catalyst", "Catalyst", "arrow.clockwise", .restartCatalyst),
        builtIn("quit-catalyst", "Quit Catalyst", "Catalyst", "xmark.circle", .quitCatalyst),
        builtIn("settings", "Settings", "Catalyst", "gearshape.fill", .settings)
    ]

    private static func builtIn(
        _ id: String, _ title: String, _ category: String, _ symbol: String,
        _ native: NativeCommandID, aliases: [String] = []
    ) -> CatalystCommand {
        CatalystCommand(id: id, title: title, category: category, symbolName: symbol,
                        aliases: aliases, action: .native(native), isEditable: false)
    }
}
