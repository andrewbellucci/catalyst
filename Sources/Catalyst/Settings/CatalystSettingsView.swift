import AppKit
import ServiceManagement

@MainActor
final class CatalystSettingsView: NSView {
    let titleLabel = NSTextField(labelWithString: "Settings")
    let stack = NSStackView()

    private let openAtLoginSwitch = NSSwitch()
    private let statusBarIconSwitch = NSSwitch()
    private let hotKeyPopup = NSPopUpButton()
    private let highlightPopup = NSPopUpButton()
    private let transparencySlider = NSSlider()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func synchronize() {
        openAtLoginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        statusBarIconSwitch.state = CatalystPreferences.shared.showsStatusBarIcon ? .on : .off
        hotKeyPopup.selectItem(withTitle: CatalystPreferences.shared.hotKey.title)
        highlightPopup.selectItem(withTitle: CatalystPreferences.shared.highlightColor.title)
        transparencySlider.doubleValue = CatalystPreferences.shared.backgroundOpacity
    }

    private func build() {
        titleLabel.font = .systemFont(ofSize: 22, weight: .regular)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        openAtLoginSwitch.target = self
        openAtLoginSwitch.action = #selector(openAtLoginChanged)
        openAtLoginSwitch.translatesAutoresizingMaskIntoConstraints = false

        statusBarIconSwitch.target = self
        statusBarIconSwitch.action = #selector(statusBarIconChanged)
        statusBarIconSwitch.translatesAutoresizingMaskIntoConstraints = false

        hotKeyPopup.addItems(withTitles: CatalystHotKey.allCases.map(\.title))
        hotKeyPopup.target = self
        hotKeyPopup.action = #selector(hotKeyChanged)
        hotKeyPopup.translatesAutoresizingMaskIntoConstraints = false

        highlightPopup.addItems(withTitles: CatalystHighlightColor.allCases.map(\.title))
        highlightPopup.target = self
        highlightPopup.action = #selector(highlightChanged)
        highlightPopup.translatesAutoresizingMaskIntoConstraints = false

        transparencySlider.minValue = 0.05
        transparencySlider.maxValue = 1
        transparencySlider.isContinuous = true
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencyChanged)
        transparencySlider.widthAnchor.constraint(equalToConstant: 150).isActive = true
        transparencySlider.translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.addArrangedSubview(makeRow(
            title: "Open at Login",
            detail: "Start Catalyst automatically when you sign in.",
            control: openAtLoginSwitch
        ))
        stack.addArrangedSubview(makeRow(
            title: "Show Menu Bar Icon",
            detail: "Keep Catalyst accessible from the menu bar.",
            control: statusBarIconSwitch
        ))
        stack.addArrangedSubview(makeRow(
            title: "Show Catalyst",
            detail: "Choose the global keyboard shortcut.",
            control: hotKeyPopup
        ))
        stack.addArrangedSubview(makeRow(
            title: "Highlight Color",
            detail: "Choose the selected result color.",
            control: highlightPopup
        ))
        stack.addArrangedSubview(makeRow(
            title: "Background Transparency",
            detail: "Adjust how much of the desktop shows through.",
            control: transparencySlider
        ))
    }

    private func makeRow(title: String, detail: String, control: NSView) -> NSView {
        let row = AdaptiveBackgroundView()
        row.fillColor = adaptiveColor(
            light: NSColor.black.withAlphaComponent(0.055),
            dark: NSColor.white.withAlphaComponent(0.09)
        )
        row.wantsLayer = true
        row.layer?.cornerRadius = 12

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(detailLabel)
        row.addSubview(control)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 58),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 9),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    @objc private func openAtLoginChanged() {
        do {
            if openAtLoginSwitch.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
            NSLog("Could not update Open at Login: \(error)")
            synchronize()
        }
    }

    @objc private func hotKeyChanged() {
        guard CatalystHotKey.allCases.indices.contains(hotKeyPopup.indexOfSelectedItem) else { return }
        CatalystPreferences.shared.hotKey = CatalystHotKey.allCases[hotKeyPopup.indexOfSelectedItem]
    }

    @objc private func statusBarIconChanged() {
        CatalystPreferences.shared.showsStatusBarIcon = statusBarIconSwitch.state == .on
    }

    @objc private func highlightChanged() {
        guard CatalystHighlightColor.allCases.indices.contains(highlightPopup.indexOfSelectedItem) else {
            return
        }
        CatalystPreferences.shared.highlightColor =
            CatalystHighlightColor.allCases[highlightPopup.indexOfSelectedItem]
    }

    @objc private func transparencyChanged() {
        CatalystPreferences.shared.backgroundOpacity = transparencySlider.doubleValue
    }
}
