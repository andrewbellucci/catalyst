import AppKit

final class CommandPanelController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    private static let launcherSize = NSSize(width: 750, height: 475)
    private static let shadowInset = LauncherShadowView.requiredClearance

    var onDismiss: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowToast: ((NotchToast, NSScreen?) -> Void)?
    var previousApplication: (() -> NSRunningApplication?)?

    private let searchField = SearchTextField()
    private let logo = NSImageView()
    private let chrome = AdaptiveBackgroundView()
    private let launcherShadow = LauncherShadowView(cornerRadius: 22)
    private let scrollView = LauncherResultsView()
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let cameraView = CameraPreviewView()
    private let contentBackButton = CircularBackButton()
    private let actionCapsule = AdaptiveBackgroundView()
    private let actionsPalette = ActionPaletteView()
    private let actionTitleLabel = NSTextField(labelWithString: "")
    private let launcherSearch = LauncherSearch()
    private let commandExecutor = CommandExecutor()
    private let dictionary = DictionaryLookup()
    private let keyboardLockController = KeyboardLockController()
    private var items: [CommandItem] = []
    private var monitor: Any?
    private var actionsPaletteHeight: NSLayoutConstraint?
    private var contentBackWidth: NSLayoutConstraint?
    private var contentBackHeight: NSLayoutConstraint?
    private var isPresentingModalDialog = false
    private var totpPreviewTimer: Timer?
    private var totpPreviewCode = ""
    private var totpPreviewExpiresAt: Date?
    private(set) var state: LauncherState = .results
    private lazy var contentBackSurface = liquidGlassSurface(
        containing: contentBackButton,
        cornerRadius: 21
    )
    private lazy var actionCapsuleSurface = liquidGlassSurface(
        containing: actionCapsule,
        cornerRadius: 18
    )

    init() {
        let panel = CommandPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.launcherSize.width + Self.shadowInset * 2,
                height: Self.launcherSize.height + Self.shadowInset * 2
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none
        super.init(window: panel)
        panel.delegate = self
        buildUI()
        launcherSearch.onRunningApplicationsChange = { [weak self] in self?.updateResults() }
        launcherSearch.prepare()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(highlightPreferenceDidChange),
            name: .catalystHighlightDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(passwordManagerPreferenceDidChange),
            name: .catalystPasswordManagerDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transparencyPreferenceDidChange),
            name: .catalystTransparencyDidChange,
            object: nil
        )
        updateResults()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationWillTerminate() {
        launcherSearch.stop()
        keyboardLockController.unlock()
    }

    func show() {
        guard let window else { return }
        let screens = NSScreen.screens
        let screenIndex = LauncherScreenSelector.targetIndex(
            screenFrames: screens.map(\.frame),
            mouseLocation: NSEvent.mouseLocation,
            preference: CatalystPreferences.shared.searchDisplay
        )
        if let screenIndex, screens.indices.contains(screenIndex) {
            let screen = screens[screenIndex]
            let frame = window.frame
            window.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - frame.width / 2,
                y: screen.visibleFrame.maxY - frame.height - 120 + Self.shadowInset
            ))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        searchField.stringValue = ""
        detailLabel.stringValue = ""
        showResults()
        window.makeFirstResponder(searchField)
        installKeyMonitor()
    }

    func dismiss() {
        cameraView.stop()
        window?.orderOut(nil)
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        searchField.stringValue = ""
        showResults()
        updateResults()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isPresentingModalDialog else { return }
        guard window?.isVisible == true else { return }
        onDismiss?()
    }

    var isSearchFieldFocused: Bool {
        window?.firstResponder === searchField || searchField.currentEditor() != nil
    }

    var acceptsImmediateTyping: Bool {
        NSApp.isActive && window?.isKeyWindow == true && isSearchFieldFocused
    }

    func configureScrollFadePreview() {
        searchField.stringValue = "a"
        updateResults()
        window?.contentView?.layoutSubtreeIfNeeded()
        scrollView.scrollToLastItem()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        chrome.translatesAutoresizingMaskIntoConstraints = false
        chrome.wantsLayer = true
        updateChromeTransparency()
        chrome.layer?.cornerRadius = 22
        chrome.layer?.masksToBounds = true

        let surface: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 22
            glass.tintColor = adaptiveColor(
                light: NSColor.white.withAlphaComponent(0.42),
                dark: NSColor.black.withAlphaComponent(0.52)
            )
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = false
            }
            glass.contentView = chrome
            surface = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 22
            effect.addSubview(chrome)
            NSLayoutConstraint.activate([
                chrome.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                chrome.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                chrome.topAnchor.constraint(equalTo: effect.topAnchor),
                chrome.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
            ])
            surface = effect
        }
        launcherShadow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(launcherShadow)
        surface.translatesAutoresizingMaskIntoConstraints = false
        launcherShadow.addSubview(surface)

        logo.image = BrandAssets.catalystGlyph()
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.contentTintColor = .secondaryLabelColor
        logo.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(logo)

        searchField.placeholderString = "Search for apps and commands…"
        searchField.font = .systemFont(ofSize: 22, weight: .regular)
        searchField.textColor = .labelColor
        searchField.placeholderAttributedString = NSAttributedString(
            string: "Search for apps and commands…",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 22, weight: .regular)
            ]
        )
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(searchField)

        scrollView.onSelectionChange = { [weak self] item in
            self?.actionTitleLabel.stringValue = item?.actionTitle ?? ""
        }
        scrollView.onActivate = { [weak self] item in self?.execute(item) }
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(scrollView, positioned: .below, relativeTo: searchField)

        detailLabel.font = .systemFont(ofSize: 15)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 0
        detailLabel.isSelectable = true
        detailLabel.isHidden = true
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(detailLabel)

        cameraView.isHidden = true
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(cameraView)

        contentBackButton.title = ""
        contentBackButton.image = NSImage(
            systemSymbolName: "chevron.left",
            accessibilityDescription: "Back to results"
        )
        contentBackButton.imagePosition = .imageOnly
        contentBackButton.isBordered = false
        contentBackButton.contentTintColor = .labelColor
        contentBackButton.fillColor = adaptiveColor(
            light: NSColor.black.withAlphaComponent(0.10),
            dark: NSColor.white.withAlphaComponent(0.16)
        )
        contentBackButton.wantsLayer = true
        contentBackButton.layer?.cornerRadius = 21
        contentBackButton.toolTip = "Back to results"
        contentBackButton.target = self
        contentBackButton.action = #selector(showResultsFromContent)
        contentBackButton.translatesAutoresizingMaskIntoConstraints = false
        setContentBackHidden(true)
        contentBackSurface.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(contentBackSurface)

        let menuButton = AdaptiveBackgroundButton(
            image: NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Menu")!,
            target: self,
            action: #selector(openSettingsWindow)
        )
        menuButton.isBordered = false
        menuButton.contentTintColor = .secondaryLabelColor
        menuButton.wantsLayer = true
        menuButton.fillColor = adaptiveColor(
            light: NSColor.black.withAlphaComponent(0.08),
            dark: NSColor.white.withAlphaComponent(0.14)
        )
        menuButton.layer?.cornerRadius = 18
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        let menuButtonSurface = liquidGlassSurface(containing: menuButton, cornerRadius: 18)
        menuButtonSurface.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(menuButtonSurface)

        actionCapsule.wantsLayer = true
        actionCapsule.fillColor = adaptiveColor(
            light: NSColor.black.withAlphaComponent(0.08),
            dark: NSColor.white.withAlphaComponent(0.14)
        )
        actionCapsule.layer?.cornerRadius = 18
        actionCapsule.addGestureRecognizer(
            NSClickGestureRecognizer(target: self, action: #selector(showActionsMenu))
        )
        actionCapsule.translatesAutoresizingMaskIntoConstraints = false
        actionCapsuleSurface.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(actionCapsuleSurface)

        actionsPalette.isHidden = true
        actionsPalette.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(actionsPalette)
        actionsPaletteHeight = actionsPalette.heightAnchor.constraint(equalToConstant: 220)
        actionsPaletteHeight?.isActive = true

        actionTitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        actionTitleLabel.textColor = .labelColor
        actionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        actionCapsule.addSubview(actionTitleLabel)

        let footerKeys = NSStackView()
        footerKeys.orientation = .horizontal
        footerKeys.alignment = .centerY
        footerKeys.spacing = 8
        footerKeys.addArrangedSubview(makeKeycap("↵"))
        let actionsLabel = NSTextField(labelWithString: "Actions")
        actionsLabel.font = .systemFont(ofSize: 13, weight: .regular)
        actionsLabel.textColor = .secondaryLabelColor
        footerKeys.addArrangedSubview(actionsLabel)
        footerKeys.addArrangedSubview(makeShortcutPreview("⌘K"))
        footerKeys.translatesAutoresizingMaskIntoConstraints = false
        actionCapsule.addSubview(footerKeys)

        contentBackWidth = contentBackSurface.widthAnchor.constraint(equalToConstant: 0)
        contentBackHeight = contentBackSurface.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            launcherShadow.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Self.shadowInset
            ),
            launcherShadow.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Self.shadowInset
            ),
            launcherShadow.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Self.shadowInset
            ),
            launcherShadow.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Self.shadowInset
            ),
            surface.leadingAnchor.constraint(equalTo: launcherShadow.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: launcherShadow.trailingAnchor),
            surface.topAnchor.constraint(equalTo: launcherShadow.topAnchor),
            surface.bottomAnchor.constraint(equalTo: launcherShadow.bottomAnchor),
            logo.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 14),
            logo.centerYAnchor.constraint(equalTo: chrome.topAnchor, constant: 34),
            logo.widthAnchor.constraint(equalToConstant: 34),
            logo.heightAnchor.constraint(equalToConstant: 34),
            searchField.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: chrome.topAnchor, constant: 37),
            searchField.heightAnchor.constraint(equalToConstant: 30),
            scrollView.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -4),
            scrollView.topAnchor.constraint(equalTo: chrome.topAnchor, constant: 58),
            scrollView.bottomAnchor.constraint(equalTo: chrome.bottomAnchor, constant: -34),
            detailLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 10),
            detailLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -10),
            detailLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            cameraView.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 4),
            cameraView.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -4),
            cameraView.topAnchor.constraint(equalTo: chrome.topAnchor, constant: 4),
            cameraView.bottomAnchor.constraint(equalTo: chrome.bottomAnchor, constant: -4),
            contentBackSurface.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 20),
            contentBackSurface.topAnchor.constraint(equalTo: chrome.topAnchor, constant: 16),
            contentBackWidth!,
            contentBackHeight!,
            menuButtonSurface.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 8),
            menuButtonSurface.centerYAnchor.constraint(equalTo: chrome.bottomAnchor, constant: -25),
            menuButtonSurface.widthAnchor.constraint(equalToConstant: 36),
            menuButtonSurface.heightAnchor.constraint(equalToConstant: 36),
            actionCapsuleSurface.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -8),
            actionCapsuleSurface.centerYAnchor.constraint(equalTo: menuButtonSurface.centerYAnchor),
            actionCapsuleSurface.heightAnchor.constraint(equalToConstant: 36),
            actionCapsuleSurface.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),
            actionsPalette.trailingAnchor.constraint(equalTo: actionCapsuleSurface.trailingAnchor),
            actionsPalette.bottomAnchor.constraint(equalTo: actionCapsuleSurface.topAnchor, constant: -10),
            actionsPalette.widthAnchor.constraint(equalToConstant: 340),
            actionTitleLabel.leadingAnchor.constraint(equalTo: actionCapsule.leadingAnchor, constant: 16),
            actionTitleLabel.centerYAnchor.constraint(equalTo: actionCapsule.centerYAnchor),
            footerKeys.leadingAnchor.constraint(greaterThanOrEqualTo: actionTitleLabel.trailingAnchor, constant: 18),
            footerKeys.trailingAnchor.constraint(equalTo: actionCapsule.trailingAnchor, constant: -10),
            footerKeys.centerYAnchor.constraint(equalTo: actionCapsule.centerYAnchor)
        ])
    }

    func controlTextDidChange(_ obj: Notification) {
        updateResults()
    }

    private func showResults() {
        state = .results
        cameraView.stop()
        setMainSearchVisible(true)
        scrollView.allowsHoverScroller = true
        cameraView.isHidden = true
        setContentBackHidden(true)
        detailLabel.isHidden = true
        scrollView.isHidden = false
        actionTitleLabel.stringValue = scrollView.selectedItem?.actionTitle ?? ""
    }

    @objc private func showResultsFromContent() {
        showResults()
        window?.makeFirstResponder(searchField)
    }

    func runCameraNavigationSmoke() -> Bool {
        showCameraPreview(startSession: false)
        let opened = !cameraView.isHidden && scrollView.isHidden && !contentBackSurface.isHidden
        showResultsFromContent()
        let returned = cameraView.isHidden && !scrollView.isHidden && contentBackSurface.isHidden
        return opened && returned && isSearchFieldFocused
    }

    private func showCameraPreview(startSession: Bool) {
        state = .camera
        setMainSearchVisible(false)
        scrollView.allowsHoverScroller = false
        scrollView.isHidden = true
        detailLabel.isHidden = true
        cameraView.isHidden = false
        setContentBackHidden(false)
        actionTitleLabel.stringValue = "Back to Results"
        if startSession {
            cameraView.start()
        }
    }

    @objc private func openSettingsWindow() {
        onDismiss?()
        onShowSettings?()
    }

    @objc private func highlightPreferenceDidChange() {
        scrollView.redrawSelection()
    }

    @objc private func transparencyPreferenceDidChange() {
        updateChromeTransparency()
    }

    @objc private func passwordManagerPreferenceDidChange() {
        updateResults()
    }

    private func updateChromeTransparency() {
        let opacity = CatalystPreferences.shared.backgroundOpacity
        chrome.fillColor = adaptiveColor(
            light: NSColor.white.withAlphaComponent(opacity),
            dark: NSColor.black.withAlphaComponent(opacity * 0.94)
        )
    }

    private func updateResults() {
        items = launcherSearch.results(for: searchField.stringValue)
        scrollView.display(items)
    }

    private func runningApplication(for url: URL) -> NSRunningApplication? {
        let bundleIdentifier = Bundle(url: url)?.bundleIdentifier
        return NSWorkspace.shared.runningApplications.first { application in
            if let bundleIdentifier {
                return application.bundleIdentifier == bundleIdentifier
            }
            return application.bundleURL?.standardizedFileURL == url.standardizedFileURL
        }
    }

    private func installKeyMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               event.charactersIgnoringModifiers?.lowercased() == "k" {
                self.showActionsMenu()
                return nil
            }
            switch event.keyCode {
            case 53:
                if !self.actionsPalette.isHidden {
                    self.hideActionsPalette()
                    return nil
                }
                if !self.cameraView.isHidden || !self.detailLabel.isHidden {
                    self.showResultsFromContent()
                    return nil
                }
                self.onDismiss?()
                return nil
            case 36:
                if !self.actionsPalette.isHidden {
                    self.actionsPalette.performSelectedAction()
                    return nil
                }
                if let item = self.selectedItem { self.execute(item) }
                return nil
            case 125:
                if !self.actionsPalette.isHidden {
                    self.actionsPalette.moveSelection(by: 1)
                    return nil
                }
                self.scrollView.moveSelection(direction: 1)
                return nil
            case 126:
                if !self.actionsPalette.isHidden {
                    self.actionsPalette.moveSelection(by: -1)
                    return nil
                }
                self.scrollView.moveSelection(direction: -1)
                return nil
            default:
                return event
            }
        }
    }

    private var selectedItem: CommandItem? {
        scrollView.selectedItem
    }

    @objc private func showActionsMenu() {
        guard let item = selectedItem else { return }
        if !actionsPalette.isHidden {
            hideActionsPalette()
            return
        }
        state = .actions
        let actions = paletteActions(for: item)
        actionsPalette.configure(title: item.title, actions: actions, target: self)
        scrollView.allowsHoverScroller = false
        actionsPaletteHeight?.constant = actionsPalette.preferredHeight(forActionCount: actions.count)
        actionsPalette.isHidden = false
        actionsPalette.focusSearch()
        if case .passwordItem(let passwordItem) = item.kind {
            Task { await launcherSearch.preparePasswordManagerValues(in: passwordItem) }
            if passwordItem.hasTOTP {
                startTOTPPreview(for: passwordItem)
            }
        }
    }

    private func paletteActions(for item: CommandItem) -> [PaletteAction] {
        if case .lockKeyboard = item.kind {
            return keyboardLockDurationActions()
        }
        if case .passwordItem = item.kind {
            guard case .passwordItem(let passwordItem) = item.kind else { return [] }
            var actions: [PaletteAction] = []
            if passwordItem.hasUsername {
                actions.append(PaletteAction(
                    title: "Copy Username",
                    symbolName: "person.crop.circle",
                    shortcut: "",
                    selector: #selector(copyPasswordManagerUsername)
                ))
            }
            if !passwordItem.email.isEmpty {
                actions.append(PaletteAction(
                    title: "Copy Email",
                    symbolName: "envelope.fill",
                    shortcut: "",
                    selector: #selector(copyPasswordManagerEmail)
                ))
            }
            if passwordItem.hasPassword {
                actions.append(PaletteAction(
                    title: "Copy Password",
                    symbolName: "key.fill",
                    shortcut: "",
                    selector: #selector(copyPasswordManagerPassword)
                ))
            }
            if passwordItem.hasTOTP {
                actions.append(PaletteAction(
                    title: "Copy TOTP",
                    symbolName: "number.circle",
                    shortcut: "",
                    selector: #selector(copyPasswordManagerTOTP),
                    detail: "Loading…"
                ))
            }
            return actions
        }
        var actions: [PaletteAction] = []
        if !item.actionTitle.isEmpty {
            actions.append(PaletteAction(
                title: item.actionTitle,
                symbolName: "return",
                shortcut: "↵",
                selector: #selector(runSelectedAction)
            ))
        }
        switch item.kind {
        case .application(let url):
            let aliases = launcherSearch.applicationAliases(for: url)
            actions.append(PaletteAction(
                title: aliases.isEmpty ? "Add Aliases" : "Edit Aliases",
                symbolName: "tag",
                shortcut: "",
                selector: #selector(editSelectedApplicationAliases)
            ))
            actions.append(PaletteAction(
                title: "Show in Finder",
                symbolName: "finder",
                shortcut: "⌘↵",
                selector: #selector(revealSelectedApplication)
            ))
            actions.append(PaletteAction(
                title: "Copy Path",
                symbolName: "doc.on.doc",
                shortcut: "⌘C",
                selector: #selector(copySelectedValue)
            ))
            if runningApplication(for: url) != nil {
                actions.append(PaletteAction(
                    title: "Restart Application",
                    symbolName: "arrow.clockwise",
                    shortcut: "",
                    selector: #selector(restartSelectedApplication)
                ))
                actions.append(PaletteAction(
                    title: "Quit Application",
                    symbolName: "xmark.app",
                    shortcut: "",
                    selector: #selector(quitSelectedApplication),
                    isDestructive: true
                ))
                actions.append(PaletteAction(
                    title: "Force Quit Application",
                    symbolName: "exclamationmark.octagon",
                    shortcut: "",
                    selector: #selector(forceQuitSelectedApplication),
                    isDestructive: true
                ))
            }
            actions.append(PaletteAction(
                title: "Uninstall Application…",
                symbolName: "trash",
                shortcut: "",
                selector: #selector(uninstallSelectedApplication),
                isDestructive: true
            ))
        case .dictionary:
            actions.append(PaletteAction(
                title: "Copy Term",
                symbolName: "doc.on.doc",
                shortcut: "⌘C",
                selector: #selector(copySelectedValue)
            ))
        default:
            break
        }
        return actions
    }

    @objc private func editSelectedApplicationAliases() {
        guard let selectedItem, case .application(let url) = selectedItem.kind else { return }
        let currentAliases = launcherSearch.applicationAliases(for: url)
        hideActionsPalette()

        let input = NSTextField(string: currentAliases.joined(separator: ", "))
        input.placeholderString = "work, browser, music"
        input.frame = NSRect(x: 0, y: 0, width: 320, height: 24)

        let alert = NSAlert()
        alert.messageText = currentAliases.isEmpty
            ? "Add Application Aliases"
            : "Edit Application Aliases"
        alert.informativeText =
            "Enter search aliases for \(selectedItem.title), separated by commas."
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            window?.makeFirstResponder(searchField)
            return
        }
        launcherSearch.setApplicationAliases(
            input.stringValue.components(separatedBy: ","),
            for: url
        )
        updateResults()
        window?.makeFirstResponder(searchField)
    }

    private func keyboardLockDurationActions() -> [PaletteAction] {
        [
            PaletteAction(
                title: "30 Seconds",
                symbolName: "timer",
                shortcut: "",
                selector: #selector(lockKeyboardFor30Seconds)
            ),
            PaletteAction(
                title: "1 Minute",
                symbolName: "timer",
                shortcut: "",
                selector: #selector(lockKeyboardFor1Minute)
            ),
            PaletteAction(
                title: "2 Minutes",
                symbolName: "timer",
                shortcut: "",
                selector: #selector(lockKeyboardFor2Minutes)
            ),
            PaletteAction(
                title: "5 Minutes",
                symbolName: "timer",
                shortcut: "",
                selector: #selector(lockKeyboardFor5Minutes)
            )
        ]
    }

    private func showKeyboardLockDurations() {
        state = .keyboardLockDurations
        let actions = keyboardLockDurationActions()
        actionsPalette.configure(title: "Lock Keyboard", actions: actions, target: self)
        scrollView.allowsHoverScroller = false
        actionsPaletteHeight?.constant = actionsPalette.preferredHeight(forActionCount: actions.count)
        actionsPalette.isHidden = false
        actionsPalette.focusSearch()
    }

    @objc private func lockKeyboardFor30Seconds() {
        beginKeyboardLock(duration: 30)
    }

    @objc private func lockKeyboardFor1Minute() {
        beginKeyboardLock(duration: 60)
    }

    @objc private func lockKeyboardFor2Minutes() {
        beginKeyboardLock(duration: 120)
    }

    @objc private func lockKeyboardFor5Minutes() {
        beginKeyboardLock(duration: 300)
    }

    private func beginKeyboardLock(duration: TimeInterval) {
        hideActionsPalette()
        if keyboardLockController.start(duration: duration) {
            onDismiss?()
        }
    }

    private func hideActionsPalette() {
        stopTOTPPreview()
        actionsPalette.isHidden = true
        setMainSearchVisible(true)
        scrollView.allowsHoverScroller = true
        window?.makeFirstResponder(searchField)
    }

    private func startTOTPPreview(for item: PasswordManagerItem) {
        stopTOTPPreview()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                totpPreviewCode = try await launcherSearch.passwordManagerValue(for: .totp, in: item)
                totpPreviewExpiresAt = ProtonPassProvider.nextTOTPBoundary(after: Date())
                updateTOTPPreview()
                totpPreviewTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
                    [weak self] _ in Task { @MainActor in self?.updateTOTPPreview() }
                }
            } catch {
                actionsPalette.updateDetail("Unavailable", for: #selector(copyPasswordManagerTOTP))
            }
        }
    }

    private func updateTOTPPreview() {
        guard !actionsPalette.isHidden, let expiresAt = totpPreviewExpiresAt else { return }
        let remaining = max(0, Int(ceil(expiresAt.timeIntervalSinceNow)))
        if remaining == 0,
           let selectedItem,
           case .passwordItem(let item) = selectedItem.kind {
            startTOTPPreview(for: item)
            return
        }
        actionsPalette.updateDetail(
            totpPreviewCode,
            countdownSeconds: remaining,
            countdownProgress: Double(remaining) / 30,
            for: #selector(copyPasswordManagerTOTP)
        )
    }

    private func stopTOTPPreview() {
        totpPreviewTimer?.invalidate()
        totpPreviewTimer = nil
        totpPreviewCode = ""
        totpPreviewExpiresAt = nil
    }

    @objc private func runSelectedAction() {
        guard let selectedItem else { return }
        hideActionsPalette()
        execute(selectedItem)
    }

    @objc private func revealSelectedApplication() {
        guard let selectedItem, case .application(let url) = selectedItem.kind else { return }
        hideActionsPalette()
        NSWorkspace.shared.activateFileViewerSelecting([url])
        onDismiss?()
    }

    @objc private func quitSelectedApplication() {
        guard let selectedItem, case .application(let url) = selectedItem.kind else { return }
        if runningApplication(for: url)?.terminate() == true {
            launcherSearch.markApplicationStopped(at: url)
        }
        hideActionsPalette()
        updateResults()
    }

    @objc private func restartSelectedApplication() {
        guard let selectedItem, case .application(let url) = selectedItem.kind,
              let application = runningApplication(for: url),
              application.terminate()
        else { return }

        launcherSearch.markApplicationStopped(at: url)
        hideActionsPalette()
        updateResults()

        Task { @MainActor in
            for _ in 0..<100 where !application.isTerminated {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard application.isTerminated else { return }
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: .init(),
                completionHandler: nil
            )
        }
    }

    @objc private func forceQuitSelectedApplication() {
        guard let selectedItem, case .application(let url) = selectedItem.kind else { return }
        if runningApplication(for: url)?.forceTerminate() == true {
            launcherSearch.markApplicationStopped(at: url)
        }
        hideActionsPalette()
        updateResults()
    }

    @objc private func uninstallSelectedApplication() {
        guard let selectedItem, case .application(let url) = selectedItem.kind else { return }
        hideActionsPalette()
        let uninstaller = ApplicationUninstaller(applicationURL: url)
        isPresentingModalDialog = true
        window?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)

        guard let urls = uninstaller.chooseFilesToRemove() else {
            isPresentingModalDialog = false
            window?.makeKeyAndOrderFront(nil)
            window?.makeFirstResponder(searchField)
            return
        }
        runningApplication(for: url)?.terminate()
        do {
            try uninstaller.moveToTrash(urls)
            launcherSearch.reloadApplications()
            updateResults()
            isPresentingModalDialog = false
            onDismiss?()
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn’t Uninstall \(selectedItem.title)"
            alert.runModal()
            isPresentingModalDialog = false
            window?.makeKeyAndOrderFront(nil)
            window?.makeFirstResponder(searchField)
        }
    }

    @objc private func copySelectedValue() {
        guard let selectedItem else { return }
        let value: String
        switch selectedItem.kind {
        case .application(let url):
            value = url.path
        case .dictionary(let term):
            value = term
        case .calculation(let result):
            value = result
        default:
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        hideActionsPalette()
    }

    @objc private func copyPasswordManagerUsername() {
        copyPasswordManagerField(.username)
    }

    @objc private func copyPasswordManagerEmail() {
        guard let selectedItem, case .passwordItem(let item) = selectedItem.kind else { return }
        finishPasswordManagerCopy(item.email, fieldTitle: "Email")
    }

    @objc private func copyPasswordManagerPassword() {
        copyPasswordManagerField(.password)
    }

    @objc private func copyPasswordManagerTOTP() {
        copyPasswordManagerField(.totp)
    }

    private func copyPasswordManagerField(_ field: PasswordManagerField) {
        guard let selectedItem, case .passwordItem(let item) = selectedItem.kind else { return }
        if field == .totp, !totpPreviewCode.isEmpty {
            finishPasswordManagerCopy(totpPreviewCode, field: field)
            return
        }
        Task { @MainActor in
            do {
                let value = try await launcherSearch.passwordManagerValue(for: field, in: item)
                finishPasswordManagerCopy(value, field: field)
            } catch {
                isPresentingModalDialog = true
                let alert = NSAlert(error: error)
                alert.messageText = "Couldn’t Copy \(field.title)"
                alert.runModal()
                isPresentingModalDialog = false
                window?.makeKeyAndOrderFront(nil)
                actionsPalette.focusSearch()
            }
        }
    }

    private func finishPasswordManagerCopy(_ value: String, field: PasswordManagerField) {
        finishPasswordManagerCopy(value, fieldTitle: field.title)
    }

    private func finishPasswordManagerCopy(_ value: String, fieldTitle: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        let screen = window?.screen
        onShowToast?(
            NotchToast(message: "\(fieldTitle) copied", indicatorColor: .systemGreen),
            screen
        )
        hideActionsPalette()
        onDismiss?()
    }

    func selectedActionMenuTitlesForTesting() -> [String] {
        guard let selectedItem else { return [] }
        return paletteActions(for: selectedItem).map(\.title)
    }

    func actionMenuTitlesForTesting(for item: CommandItem) -> [String] {
        paletteActions(for: item).map(\.title)
    }

    func configureActionsPreview() {
        showActionsMenu()
    }

    func configureCameraPreview() {
        showCameraPreview(startSession: false)
    }

    func configureQueryPreview(_ query: String) {
        searchField.stringValue = query
        updateResults()
    }

    func showActionsForTesting() {
        showActionsMenu()
    }

    var actionPaletteSearchIsFocusedForTesting: Bool {
        actionsPalette.isSearchFocused
    }

    var actionPaletteSearchFieldForTesting: NSTextField {
        actionsPalette.searchFieldForTesting
    }

    var actionPaletteFrameForTesting: NSRect { actionsPalette.frame }

    var launcherShadowFrameForTesting: NSRect { launcherShadow.frame }

    var launcherShadowOpacityForTesting: Float { launcherShadow.layer?.shadowOpacity ?? 0 }

    var actionPaletteSearchFrameForTesting: NSRect {
        actionsPalette.searchFieldForTesting.frame
    }

    var selectedPaletteActionTitleForTesting: String? {
        actionsPalette.selectedActionTitle
    }

    var selectedPaletteActionIsVisibleForTesting: Bool {
        actionsPalette.isSelectedRowVisible
    }

    var actionPaletteScrollOffsetForTesting: CGFloat {
        actionsPalette.scrollOffset
    }

    func movePaletteSelectionForTesting(by offset: Int) {
        actionsPalette.moveSelection(by: offset)
    }

    var paletteRowCenterPositionsForTesting: [CGFloat] {
        actionsPalette.rowCenterPositions
    }

    var paletteFooterTrailingDifferenceForTesting: CGFloat {
        window?.contentView?.layoutSubtreeIfNeeded()
        return abs(actionsPalette.frame.maxX - actionCapsuleSurface.frame.maxX)
    }

    var resultTitlesForTesting: [String] {
        items.map(\.title)
    }

    var searchFieldForTesting: NSTextField { searchField }

    var resultsScrollViewForTesting: NSScrollView { scrollView }

    var contentBackButtonForTesting: NSButton { contentBackButton }

    var runningResultTitlesForTesting: [String] {
        items.filter(\.isRunning).map(\.title)
    }

    var selectableRowHeightForTesting: CGFloat { 48 }

    func setSearchQueryForTesting(_ query: String) {
        searchField.stringValue = query
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    }

    private func execute(_ item: CommandItem) {
        launcherSearch.recordUsage(of: item)
        if case .passwordItem = item.kind {
            showActionsMenu()
            return
        }
        switch commandExecutor.execute(item.kind, previousApplication: previousApplication?()) {
        case .none:
            break
        case .dismiss:
            onDismiss?()
        case .showCamera:
            showCameraPreview(startSession: true)
        case .showKeyboardLockDurations:
            showKeyboardLockDurations()
        case .showSettings:
            openSettingsWindow()
        case .showDefinition(let term):
            showDefinition(term)
        }
    }

    private func showDefinition(_ term: String) {
        state = .definition
        setMainSearchVisible(false)
        scrollView.allowsHoverScroller = false
        detailLabel.attributedStringValue = dictionary.formattedDefinition(term)
            ?? NSAttributedString(
                string: "No definition found for “\(term)”.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 17),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        scrollView.isHidden = true
        cameraView.isHidden = true
        setContentBackHidden(false)
        detailLabel.isHidden = false
    }

    private func setMainSearchVisible(_ visible: Bool) {
        logo.isHidden = !visible
        searchField.isHidden = !visible
    }

    private func setContentBackHidden(_ hidden: Bool) {
        contentBackSurface.isHidden = hidden
        contentBackSurface.alphaValue = hidden ? 0 : 1
        contentBackButton.isHidden = hidden
        contentBackWidth?.constant = hidden ? 0 : 42
        contentBackHeight?.constant = hidden ? 0 : 42
    }

    var lockMechanismAvailableForTesting: Bool {
        commandExecutor.lockMechanismAvailable
    }
}
