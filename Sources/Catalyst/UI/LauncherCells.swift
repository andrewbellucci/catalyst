import AppKit

class FadingScrollView: NSScrollView {
    private let fadeMask = CAGradientLayer()
    private var hoverTrackingArea: NSTrackingArea?
    var allowsHoverScroller = true {
        didSet {
            if !allowsHoverScroller {
                verticalScroller?.alphaValue = 0
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureFadeMask()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureFadeMask()
    }

    private func configureFadeMask() {
        wantsLayer = true
        layer?.mask = fadeMask
        verticalScroller?.alphaValue = 0
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFadeMask),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )
    }

    override func layout() {
        super.layout()
        verticalScroller?.alphaValue = allowsHoverScroller && isMouseInside ? 1 : 0
        updateFadeMask()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    private var isMouseInside: Bool {
        guard let window else { return false }
        return bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        setScrollerVisible(allowsHoverScroller)
    }

    override func mouseExited(with event: NSEvent) {
        setScrollerVisible(false)
    }

    private func setScrollerVisible(_ visible: Bool) {
        guard let verticalScroller else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            verticalScroller.animator().alphaValue = visible ? 1 : 0
        }
    }

    @objc private func updateFadeMask() {
        guard let documentView else { return }
        let visibleRect = contentView.bounds
        let documentRect = documentView.bounds
        let fadesAtTop = visibleRect.minY > documentRect.minY + 0.5
        let fadesAtBottom = visibleRect.maxY < documentRect.maxY - 0.5

        fadeMask.frame = bounds
        fadeMask.colors = [
            NSColor.black.withAlphaComponent(fadesAtTop ? 0 : 1).cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.black.withAlphaComponent(fadesAtBottom ? 0 : 1).cgColor
        ]
        let fadeFraction = min(0.18, 52 / max(contentView.bounds.height, 1))
        fadeMask.locations = [
            0,
            NSNumber(value: fadeFraction),
            NSNumber(value: 1 - fadeFraction),
            1
        ]
    }
}

final class ThumbOnlyScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // Keep the results surface visible; only the scroll thumb is drawn.
    }
}

final class LauncherRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        CatalystPreferences.shared.highlightColor.color.withAlphaComponent(0.38).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 11, yRadius: 11).fill()
    }
}

final class LauncherSectionCell: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("launcher-section")
    private let sectionTitle = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.reuseIdentifier
        sectionTitle.font = .systemFont(ofSize: 12, weight: .regular)
        sectionTitle.textColor = .secondaryLabelColor
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sectionTitle)
        NSLayoutConstraint.activate([
            sectionTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            sectionTitle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String) { sectionTitle.stringValue = title }
}

final class LauncherResultCell: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("launcher-result")
    private let iconContainer = NSView()
    private let iconTile = NSView()
    private let iconView = NSImageView()
    private let runningIndicator = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let resultTypeLabel = NSTextField(labelWithString: "")
    private var iconWidth: NSLayoutConstraint!
    private var iconHeight: NSLayoutConstraint!
    private var iconTileWidth: NSLayoutConstraint!
    private var iconTileHeight: NSLayoutConstraint!
    private var iconIsEncapsulated = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.reuseIdentifier

        iconContainer.wantsLayer = true
        iconTile.wantsLayer = true
        iconTile.layer?.cornerRadius = 6
        iconTile.layer?.masksToBounds = true
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        runningIndicator.wantsLayer = true
        runningIndicator.layer?.backgroundColor = NSColor.secondaryLabelColor.cgColor
        runningIndicator.layer?.cornerRadius = 1.5
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        titleLabel.textColor = .labelColor
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        resultTypeLabel.font = .systemFont(ofSize: 13, weight: .regular)
        resultTypeLabel.textColor = .secondaryLabelColor
        resultTypeLabel.alignment = .right

        for view in [iconContainer, runningIndicator, titleLabel, subtitleLabel, resultTypeLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconTile)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        iconWidth = iconView.widthAnchor.constraint(equalToConstant: 28)
        iconHeight = iconView.heightAnchor.constraint(equalToConstant: 28)
        iconTileWidth = iconTile.widthAnchor.constraint(equalToConstant: 22)
        iconTileHeight = iconTile.heightAnchor.constraint(equalToConstant: 22)
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 28),
            iconContainer.heightAnchor.constraint(equalToConstant: 28),
            iconTile.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconTile.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconTileWidth,
            iconTileHeight,
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconWidth,
            iconHeight,
            runningIndicator.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            runningIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            runningIndicator.widthAnchor.constraint(equalToConstant: 3),
            runningIndicator.heightAnchor.constraint(equalToConstant: 3),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 14),
            subtitleLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: resultTypeLabel.leadingAnchor, constant: -12),
            resultTypeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            resultTypeLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            resultTypeLabel.widthAnchor.constraint(equalToConstant: 110)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: CommandItem) {
        iconView.image = item.icon
        if case .application = item.kind {
            iconIsEncapsulated = false
            iconTile.isHidden = true
            iconView.layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = nil
            iconWidth.constant = 28
            iconHeight.constant = 28
        } else {
            iconIsEncapsulated = true
            iconTile.isHidden = false
            iconTile.layer?.backgroundColor = CatalystPreferences.shared.highlightColor.color
                .withAlphaComponent(0.88).cgColor
            iconView.layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = .white
            iconWidth.constant = 12
            iconHeight.constant = 12
        }
        runningIndicator.isHidden = !item.isRunning
        titleLabel.stringValue = item.title
        subtitleLabel.stringValue = item.subtitle
        subtitleLabel.isHidden = item.subtitle.isEmpty
        resultTypeLabel.stringValue = item.resultType
    }

    var iconIsEncapsulatedForTesting: Bool {
        iconIsEncapsulated
    }

    var iconArtworkSizeForTesting: CGFloat { iconWidth.constant }

    var iconTileSizeForTesting: CGFloat { iconTileWidth.constant }
}
