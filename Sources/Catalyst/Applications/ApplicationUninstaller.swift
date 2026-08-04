import AppKit
import Foundation

@MainActor
final class ApplicationUninstaller {
    private let applicationURL: URL
    private let fileManager: FileManager

    init(applicationURL: URL, fileManager: FileManager = .default) {
        self.applicationURL = applicationURL.standardizedFileURL
        self.fileManager = fileManager
    }

    func chooseFilesToRemove() -> [URL]? {
        let candidates = uninstallCandidates()
        return UninstallConfirmationPanel(
            files: candidates,
            applicationURL: applicationURL
        ).runModal()
    }

    func moveToTrash(_ urls: [URL]) throws {
        for url in urls where fileManager.fileExists(atPath: url.path) {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    }

    private func uninstallCandidates() -> [URL] {
        var urls = [applicationURL]
        let library = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
        let appName = applicationURL.deletingPathExtension().lastPathComponent
        let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier

        urls.append(contentsOf: [
            library.appendingPathComponent("Application Support/\(appName)"),
            library.appendingPathComponent("Caches/\(appName)"),
            library.appendingPathComponent("Logs/\(appName)")
        ])
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            urls.append(contentsOf: [
                library.appendingPathComponent("Application Support/\(bundleIdentifier)"),
                library.appendingPathComponent("Caches/\(bundleIdentifier)"),
                library.appendingPathComponent("Preferences/\(bundleIdentifier).plist"),
                library.appendingPathComponent("Saved Application State/\(bundleIdentifier).savedState"),
                library.appendingPathComponent("Containers/\(bundleIdentifier)"),
                library.appendingPathComponent("Application Scripts/\(bundleIdentifier)"),
                library.appendingPathComponent("HTTPStorages/\(bundleIdentifier)"),
                library.appendingPathComponent("WebKit/\(bundleIdentifier)"),
                library.appendingPathComponent("Cookies/\(bundleIdentifier).binarycookies")
            ])
        }

        var seen = Set<String>()
        return urls.filter {
            fileManager.fileExists(atPath: $0.path)
                && seen.insert($0.standardizedFileURL.path).inserted
        }
    }
}

@MainActor
private final class UninstallFilesView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let files: [URL]
    private let applicationURL: URL
    private var selectedIndexes: IndexSet
    private let summaryLabel = NSTextField(labelWithString: "")
    var selectedURLs: [URL] { selectedIndexes.map { files[$0] } }

    init(files: [URL], applicationURL: URL) {
        self.files = files
        self.applicationURL = applicationURL
        selectedIndexes = IndexSet(integersIn: files.indices)
        let rowHeight: CGFloat = 58
        let listHeight = min(290, max(rowHeight, CGFloat(files.count) * rowHeight))
        super.init(frame: NSRect(x: 0, y: 0, width: 570, height: listHeight + 34))

        summaryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.frame = NSRect(x: 4, y: listHeight + 9, width: 562, height: 18)
        addSubview(summaryLabel)

        let table = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.width = 568
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = rowHeight
        table.intercellSpacing = .zero
        table.backgroundColor = .controlBackgroundColor
        table.selectionHighlightStyle = .none
        table.dataSource = self
        table.delegate = self

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 570, height: listHeight))
        scrollView.documentView = table
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 10
        scrollView.layer?.masksToBounds = true
        addSubview(scrollView)
        table.reloadData()
        table.scrollRowToVisible(0)
        updateSummary()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func numberOfRows(in tableView: NSTableView) -> Int { files.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let url = files[row]
        let cell = NSTableCellView()

        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(selectionChanged(_:)))
        checkbox.state = selectedIndexes.contains(row) ? .on : .off
        checkbox.tag = row
        checkbox.setAccessibilityLabel("Remove \(url.lastPathComponent)")
        checkbox.frame = NSRect(x: 10, y: 18, width: 20, height: 20)
        cell.addSubview(checkbox)

        let icon = NSImageView(frame: NSRect(x: 42, y: 11, width: 36, height: 36))
        icon.image = NSWorkspace.shared.icon(forFile: url.path)
        icon.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(icon)

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 14, weight: url == applicationURL ? .semibold : .medium)
        name.lineBreakMode = .byTruncatingMiddle
        name.frame = NSRect(x: 90, y: 30, width: 350, height: 19)
        cell.addSubview(name)

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let parentPath = url.deletingLastPathComponent().path
        let parent = parentPath.hasPrefix(home) ? "~" + parentPath.dropFirst(home.count) : parentPath
        let path = NSTextField(labelWithString: String(parent))
        path.font = .systemFont(ofSize: 13)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle
        path.frame = NSRect(x: 90, y: 10, width: 350, height: 18)
        cell.addSubview(path)

        let size = NSTextField(labelWithString: Self.formattedSize(of: url))
        size.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        size.textColor = .tertiaryLabelColor
        size.alignment = .right
        size.frame = NSRect(x: 448, y: 20, width: 100, height: 18)
        cell.addSubview(size)
        return cell
    }

    @objc private func selectionChanged(_ sender: NSButton) {
        if sender.state == .on {
            selectedIndexes.insert(sender.tag)
        } else {
            selectedIndexes.remove(sender.tag)
        }
        updateSummary()
    }

    private func updateSummary() {
        let count = selectedURLs.count
        summaryLabel.stringValue = "\(count) of \(files.count) items selected"
    }

    private static func formattedSize(of url: URL) -> String {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return "—" }
        var bytes = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        if values.isDirectory == true,
           let enumerator = FileManager.default.enumerator(
               at: url,
               includingPropertiesForKeys: Array(keys),
               options: [.skipsHiddenFiles, .skipsPackageDescendants]
           ) {
            bytes = 0
            for case let child as URL in enumerator {
                let childValues = try? child.resourceValues(forKeys: keys)
                bytes += Int64(childValues?.totalFileAllocatedSize ?? childValues?.fileAllocatedSize ?? 0)
            }
        }
        guard bytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

@MainActor
private final class UninstallConfirmationPanel: NSObject {
    private let panel: UninstallModalPanel
    private let picker: UninstallFilesView
    private var accepted = false

    init(files: [URL], applicationURL: URL) {
        let appName = applicationURL.deletingPathExtension().lastPathComponent
        picker = UninstallFilesView(files: files, applicationURL: applicationURL)
        let panelHeight = picker.frame.height + 270
        panel = UninstallModalPanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: panelHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .modalPanel
        panel.isOpaque = false
        panel.backgroundColor = .clear
        let content = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        content.material = .popover
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 24
        content.layer?.masksToBounds = true
        panel.contentView = content

        let icon = NSImageView()
        icon.image = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.imageScaling = .scaleProportionallyUpOrDown

        let title = NSTextField(labelWithString: "Uninstall \(appName)?")
        title.font = .systemFont(ofSize: 21, weight: .semibold)
        title.textColor = .labelColor

        let detail = NSTextField(labelWithString: "Choose which files to move to the Trash. You can restore them later.")
        detail.font = .systemFont(ofSize: 14)
        detail.textColor = .secondaryLabelColor

        let cancel = UninstallDialogButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancel.fillColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.13)
                : NSColor.black.withAlphaComponent(0.08)
        }
        cancel.contentTintColor = .labelColor
        cancel.keyEquivalent = "\u{1b}"

        let uninstall = UninstallDialogButton(
            title: "Uninstall Application",
            target: self,
            action: #selector(uninstallAction)
        )
        uninstall.fillColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.systemRed.withAlphaComponent(0.24)
                : NSColor.systemRed.withAlphaComponent(0.16)
        }
        uninstall.contentTintColor = .systemRed
        uninstall.keyEquivalent = "\r"

        for view in [icon, title, detail, picker, cancel, uninstall] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            icon.topAnchor.constraint(equalTo: content.topAnchor, constant: 30),
            icon.widthAnchor.constraint(equalToConstant: 54),
            icon.heightAnchor.constraint(equalToConstant: 54),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            title.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 24),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 7),
            picker.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            picker.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            picker.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 26),
            picker.heightAnchor.constraint(equalToConstant: picker.frame.height),
            cancel.leadingAnchor.constraint(equalTo: picker.leadingAnchor),
            cancel.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 20),
            cancel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            cancel.heightAnchor.constraint(equalToConstant: 36),
            uninstall.leadingAnchor.constraint(equalTo: cancel.trailingAnchor, constant: 12),
            uninstall.trailingAnchor.constraint(equalTo: picker.trailingAnchor),
            uninstall.topAnchor.constraint(equalTo: cancel.topAnchor),
            uninstall.bottomAnchor.constraint(equalTo: cancel.bottomAnchor),
            uninstall.widthAnchor.constraint(equalTo: cancel.widthAnchor)
        ])
    }

    func runModal() -> [URL]? {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return accepted ? picker.selectedURLs : nil
    }

    @objc private func cancelAction() {
        accepted = false
        NSApp.stopModal()
    }

    @objc private func uninstallAction() {
        accepted = true
        NSApp.stopModal()
    }
}

private final class UninstallModalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class UninstallDialogButton: NSButton {
    var fillColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isBordered = false
        font = .systemFont(ofSize: 15, weight: .medium)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fillColor.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
