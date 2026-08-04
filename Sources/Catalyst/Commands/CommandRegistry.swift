import AppKit

struct CommandDescriptor {
    let title: String
    let subtitle: String
    let symbolName: String
    let kind: CommandKind
    var aliases: [String] = []

    var item: CommandItem {
        CommandItem(
            title: title,
            subtitle: subtitle,
            icon: NSImage(systemSymbolName: symbolName, accessibilityDescription: title),
            kind: kind,
            aliases: aliases
        )
    }
}

enum CommandRegistry {
    static let builtIns: [CommandDescriptor] = [
        CommandDescriptor(title: "Open Camera", subtitle: "Catalyst", symbolName: "camera.fill", kind: .camera),
        CommandDescriptor(title: "Quit Focused App", subtitle: "System Actions", symbolName: "xmark.app.fill", kind: .quitFocused),
        CommandDescriptor(title: "Quit All Apps", subtitle: "System Actions", symbolName: "xmark.circle.fill", kind: .quitAll),
        CommandDescriptor(title: "Restart Device", subtitle: "System Actions", symbolName: "arrow.clockwise.circle.fill", kind: .restartDevice),
        CommandDescriptor(title: "Lock Device", subtitle: "System Actions", symbolName: "lock.fill", kind: .lockDevice),
        CommandDescriptor(title: "Lock Keyboard", subtitle: "Cleaning", symbolName: "keyboard.badge.ellipsis", kind: .lockKeyboard),
        CommandDescriptor(title: "Shut Down Device", subtitle: "System Actions", symbolName: "power.circle.fill", kind: .shutDownDevice),
        CommandDescriptor(title: "Toggle System Appearance", subtitle: "System Actions", symbolName: "circle.lefthalf.filled", kind: .toggleSystemAppearance),
        CommandDescriptor(title: "Restart Catalyst", subtitle: "Catalyst", symbolName: "arrow.clockwise", kind: .restartCatalyst),
        CommandDescriptor(title: "Quit Catalyst", subtitle: "Catalyst", symbolName: "xmark.circle", kind: .quitCatalyst),
        CommandDescriptor(title: "Settings", subtitle: "Catalyst", symbolName: "gearshape.fill", kind: .settings)
    ]
}
