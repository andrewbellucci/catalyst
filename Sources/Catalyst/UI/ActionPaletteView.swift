import AppKit

struct PaletteAction {
    let title: String
    let symbolName: String
    let shortcut: String
    let selector: Selector
    var isDestructive = false
}

private final class FlippedActionStackView: NSStackView {
    override var isFlipped: Bool { true }
}

final class ActionPaletteView: NSVisualEffectView, NSTextFieldDelegate {
    static let maximumHeight: CGFloat = 350

    private let backdrop = AdaptiveBackgroundView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let actionsScrollView = NSScrollView()
    private let rows = FlippedActionStackView()
    private let searchField = SearchTextField()
    private var allActions: [PaletteAction] = []
    private var filteredActions: [PaletteAction] = []
    private weak var actionTarget: AnyObject?
    private var selectedIndex = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        backdrop.fillColor = adaptiveColor(
            light: NSColor.white.withAlphaComponent(0.90),
            dark: NSColor.black.withAlphaComponent(0.88)
        )
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 18
        backdrop.layer?.masksToBounds = true
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)

        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        rows.orientation = .vertical
        rows.alignment = .width
        rows.distribution = .fill
        rows.spacing = 2
        rows.translatesAutoresizingMaskIntoConstraints = false
        rows.setHuggingPriority(.required, for: .vertical)

        actionsScrollView.drawsBackground = false
        actionsScrollView.borderType = .noBorder
        actionsScrollView.hasVerticalScroller = true
        actionsScrollView.autohidesScrollers = true
        actionsScrollView.scrollerStyle = .overlay
        actionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        actionsScrollView.documentView = rows
        addSubview(actionsScrollView)

        searchField.placeholderString = "Search for actions…"
        searchField.font = .systemFont(ofSize: 15)
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.heightAnchor.constraint(equalToConstant: 18),
            actionsScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            actionsScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            actionsScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            rows.leadingAnchor.constraint(equalTo: actionsScrollView.contentView.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: actionsScrollView.contentView.trailingAnchor),
            rows.topAnchor.constraint(equalTo: actionsScrollView.contentView.topAnchor),
            rows.widthAnchor.constraint(equalTo: actionsScrollView.contentView.widthAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.topAnchor.constraint(equalTo: actionsScrollView.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchField.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            searchField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            searchField.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, actions: [PaletteAction], target: AnyObject) {
        titleLabel.stringValue = title
        searchField.stringValue = ""
        allActions = actions
        filteredActions = actions
        actionTarget = target
        selectedIndex = 0
        renderRows()
    }

    func preferredHeight(forActionCount count: Int) -> CGFloat {
        min(87 + CGFloat(count) * 44, Self.maximumHeight)
    }

    func focusSearch() {
        window?.makeFirstResponder(searchField)
    }

    var isSearchFocused: Bool {
        window?.firstResponder === searchField || searchField.currentEditor() != nil
    }

    var searchFieldForTesting: NSTextField { searchField }

    var selectedActionTitle: String? {
        filteredActions.indices.contains(selectedIndex) ? filteredActions[selectedIndex].title : nil
    }

    var rowCenterPositions: [CGFloat] {
        layoutSubtreeIfNeeded()
        return rows.arrangedSubviews.map { $0.frame.midY }
    }

    var isSelectedRowVisible: Bool {
        layoutSubtreeIfNeeded()
        guard rows.arrangedSubviews.indices.contains(selectedIndex) else { return false }
        let visibleBounds = actionsScrollView.contentView.bounds
        let selectedFrame = rows.arrangedSubviews[selectedIndex].frame
        return visibleBounds.minY <= selectedFrame.minY
            && visibleBounds.maxY >= selectedFrame.maxY
    }

    var scrollOffset: CGFloat {
        layoutSubtreeIfNeeded()
        return actionsScrollView.contentView.bounds.origin.y
    }

    func moveSelection(by offset: Int) {
        guard !filteredActions.isEmpty else { return }
        selectedIndex = (selectedIndex + offset + filteredActions.count) % filteredActions.count
        renderRows()
    }

    func performSelectedAction() {
        guard filteredActions.indices.contains(selectedIndex), let actionTarget else { return }
        NSApp.sendAction(filteredActions[selectedIndex].selector, to: actionTarget, from: self)
    }

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        filteredActions = query.isEmpty
            ? allActions
            : allActions.filter { $0.title.localizedCaseInsensitiveContains(query) }
        selectedIndex = 0
        renderRows()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func renderRows() {
        for view in rows.arrangedSubviews {
            rows.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, action) in filteredActions.enumerated() {
            guard let actionTarget else { continue }
            rows.addArrangedSubview(makeRow(
                action,
                target: actionTarget,
                selected: index == selectedIndex
            ))
        }
        rows.layoutSubtreeIfNeeded()
        actionsScrollView.layoutSubtreeIfNeeded()
        if rows.arrangedSubviews.indices.contains(selectedIndex) {
            scrollRowToVisible(rows.arrangedSubviews[selectedIndex])
        }
        needsLayout = true
    }

    private func scrollRowToVisible(_ row: NSView) {
        let clipView = actionsScrollView.contentView
        let rowFrame = row.frame
        var origin = clipView.bounds.origin
        if rowFrame.minY < clipView.bounds.minY {
            origin.y = rowFrame.minY
        } else if rowFrame.maxY > clipView.bounds.maxY {
            origin.y = rowFrame.maxY - clipView.bounds.height
        } else {
            return
        }
        clipView.scroll(to: origin)
        actionsScrollView.reflectScrolledClipView(clipView)
    }

    private func makeRow(_ action: PaletteAction, target: AnyObject, selected: Bool) -> NSView {
        let row = AdaptiveBackgroundView()
        row.fillColor = selected
            ? adaptiveColor(
                light: NSColor.black.withAlphaComponent(0.08),
                dark: NSColor.white.withAlphaComponent(0.12)
            )
            : .clear
        row.wantsLayer = true
        row.layer?.cornerRadius = 10

        let button = NSButton(
            image: NSImage(systemSymbolName: action.symbolName, accessibilityDescription: nil)!,
            target: target,
            action: action.selector
        )
        button.title = action.title
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.font = .systemFont(ofSize: 15, weight: .regular)
        button.alignment = .left
        button.isBordered = false
        button.contentTintColor = action.isDestructive ? .systemRed : .labelColor
        if action.isDestructive {
            button.attributedTitle = NSAttributedString(
                string: action.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 15, weight: .regular),
                    .foregroundColor: NSColor.systemRed
                ]
            )
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(button)

        let shortcut = makeShortcutPreview(action.shortcut)
        shortcut.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(shortcut)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 42),
            button.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            button.trailingAnchor.constraint(lessThanOrEqualTo: shortcut.leadingAnchor, constant: -8),
            button.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            shortcut.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            shortcut.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }
}
