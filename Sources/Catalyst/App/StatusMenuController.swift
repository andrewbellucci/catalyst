import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpen: () -> Void

    init(onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
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
}
