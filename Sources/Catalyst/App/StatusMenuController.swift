import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpen: () -> Void
    private let onSettings: () -> Void

    init(onOpen: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onSettings = onSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let icon = BrandAssets.catalystIcon()
        icon.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = icon

        let menu = NSMenu()
        let openItem = menu.addItem(
            withTitle: "Open Catalyst",
            action: #selector(openCatalyst),
            keyEquivalent: ""
        )
        openItem.target = self
        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Catalyst",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    var isVisible: Bool { statusItem.isVisible }

    @objc private func openCatalyst() { onOpen() }
    @objc private func openSettings() { onSettings() }
}
