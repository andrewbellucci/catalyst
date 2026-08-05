import AppKit

@MainActor
final class CatalystSettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settingsView = CatalystSettingsView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 670),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Catalyst Settings"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        settingsView.synchronize()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(settingsView)
        NSLayoutConstraint.activate([
            settingsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            settingsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            settingsView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            settingsView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            settingsView.stack.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor),
            settingsView.stack.trailingAnchor.constraint(equalTo: settingsView.trailingAnchor),
            settingsView.stack.topAnchor.constraint(equalTo: settingsView.topAnchor)
        ])
    }
}
