import AppKit
import XCTest
@testable import Catalyst

@MainActor
final class CommandPanelInteractionTests: XCTestCase {
    func testSearchFieldSupportsSelectAllAndMouseHitTesting() throws {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        let field = controller.searchFieldForTesting
        let window = try XCTUnwrap(controller.window)

        window.makeKeyAndOrderFront(nil)
        field.stringValue = "Catalyst"
        XCTAssertTrue(window.makeFirstResponder(field))

        let selectAll = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        ))
        XCTAssertTrue(field.performKeyEquivalent(with: selectAll))
        XCTAssertEqual(field.currentEditor()?.selectedRange, NSRange(location: 0, length: 8))

        window.contentView?.layoutSubtreeIfNeeded()
        let center = field.convert(
            NSPoint(x: field.bounds.midX, y: field.bounds.midY),
            to: window.contentView
        )
        let hitView = window.contentView?.hitTest(center)
        XCTAssertTrue(hitView === field || hitView?.isDescendant(of: field) == true)
    }

    func testResultsUseFadeMaskWithoutSeparatorBars() throws {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        let scrollView = controller.resultsScrollViewForTesting

        controller.window?.contentView?.layoutSubtreeIfNeeded()
        XCTAssertTrue(scrollView.layer?.mask is CAGradientLayer)
        XCTAssertFalse(containsSeparator(in: controller.window?.contentView))
    }

    func testPanelDismissesWhenItLosesKeyFocus() throws {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        var dismissed = false
        controller.onDismiss = { dismissed = true }
        controller.window?.orderFront(nil)

        controller.windowDidResignKey(
            Notification(name: NSWindow.didResignKeyNotification, object: controller.window)
        )

        XCTAssertTrue(dismissed)
    }

    func testCommandKActionsForSelectedApplication() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.setSearchQueryForTesting("Chess")

        XCTAssertEqual(
            controller.selectedActionMenuTitlesForTesting(),
            [
                "Open Application",
                "Add Aliases",
                "Show in Finder",
                "Copy Path",
                "Uninstall Application…"
            ]
        )
    }

    func testTOTPActionOnlyAppearsForItemsWithTOTP() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        func item(hasTOTP: Bool) -> CommandItem {
            CommandItem(
                title: "Login",
                subtitle: "user@example.com",
                icon: nil,
                kind: .passwordItem(PasswordManagerItem(
                    providerID: "test",
                    providerName: "Test",
                    vaultID: "vault",
                    itemID: "item",
                    title: "Login",
                    email: "user@example.com",
                    hasTOTP: hasTOTP
                ))
            )
        }

        XCTAssertTrue(controller.actionMenuTitlesForTesting(for: item(hasTOTP: true)).contains("Copy TOTP"))
        XCTAssertFalse(controller.actionMenuTitlesForTesting(for: item(hasTOTP: false)).contains("Copy TOTP"))
    }

    func testCredentialActionsOnlyAppearForAvailableFields() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        let item = CommandItem(
            title: "Login",
            subtitle: "",
            icon: nil,
            kind: .passwordItem(PasswordManagerItem(
                providerID: "test", providerName: "Test", vaultID: "vault", itemID: "item",
                title: "Login", email: "", hasUsername: false, hasPassword: true, hasTOTP: false
            ))
        )

        let titles = controller.actionMenuTitlesForTesting(for: item)
        XCTAssertEqual(titles, ["Copy Password"])
    }

    func testRunningApplicationOffersRestartAction() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.setSearchQueryForTesting("Finder")

        XCTAssertTrue(
            controller.selectedActionMenuTitlesForTesting().contains("Restart Application")
        )
    }

    func testLargeActionPaletteStaysBoundedInsideLauncher() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.setSearchQueryForTesting("Finder")
        controller.showActionsForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(controller.actionPaletteFrameForTesting.height, 350)
        XCTAssertGreaterThanOrEqual(controller.actionPaletteFrameForTesting.minY, 0)
        XCTAssertGreaterThanOrEqual(controller.actionPaletteSearchFrameForTesting.minY, 0)
    }

    func testArrowSelectionScrollsLargeActionPalette() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.setSearchQueryForTesting("Finder")
        controller.showActionsForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        controller.movePaletteSelectionForTesting(by: -1)
        let lastActionOffset = controller.actionPaletteScrollOffsetForTesting
        XCTAssertGreaterThanOrEqual(lastActionOffset, 0)
        for _ in 0..<7 {
            controller.movePaletteSelectionForTesting(by: -1)
        }

        XCTAssertEqual(controller.selectedPaletteActionTitleForTesting, "Open Application")
        XCTAssertTrue(controller.selectedPaletteActionIsVisibleForTesting)
        XCTAssertNotEqual(controller.actionPaletteScrollOffsetForTesting, lastActionOffset)
    }

    func testActionsPaletteFocusesSearchAndMovesSelection() throws {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        let window = try XCTUnwrap(controller.window)
        window.makeKeyAndOrderFront(nil)
        controller.setSearchQueryForTesting("Chess")

        controller.showActionsForTesting()
        XCTAssertTrue(controller.actionPaletteSearchIsFocusedForTesting)
        XCTAssertEqual(controller.selectedPaletteActionTitleForTesting, "Open Application")

        controller.movePaletteSelectionForTesting(by: 1)
        XCTAssertEqual(controller.selectedPaletteActionTitleForTesting, "Add Aliases")

        controller.movePaletteSelectionForTesting(by: 1)
        XCTAssertEqual(controller.selectedPaletteActionTitleForTesting, "Show in Finder")

        let centers = controller.paletteRowCenterPositionsForTesting
        XCTAssertEqual(centers.count, 5)
        XCTAssertEqual(abs(centers[1] - centers[0]), 44, accuracy: 0.5)
        XCTAssertEqual(abs(centers[2] - centers[1]), 44, accuracy: 0.5)
        XCTAssertEqual(abs(centers[3] - centers[2]), 44, accuracy: 0.5)
        XCTAssertEqual(abs(centers[4] - centers[3]), 44, accuracy: 0.5)
        XCTAssertEqual(controller.paletteFooterTrailingDifferenceForTesting, 0, accuracy: 0.5)
    }

    func testActionPaletteSearchSupportsSelectAll() throws {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        let window = try XCTUnwrap(controller.window)
        window.makeKeyAndOrderFront(nil)
        controller.showActionsForTesting()

        let field = controller.actionPaletteSearchFieldForTesting
        field.stringValue = "restart"
        XCTAssertTrue(window.makeFirstResponder(field))
        let selectAll = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        ))

        XCTAssertTrue(field.performKeyEquivalent(with: selectAll))
        XCTAssertEqual(field.currentEditor()?.selectedRange, NSRange(location: 0, length: 7))
    }

    func testActionPaletteDoesNotHideLauncherSearch() throws {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        let window = try XCTUnwrap(controller.window)
        window.makeKeyAndOrderFront(nil)

        controller.showActionsForTesting()

        XCTAssertFalse(controller.searchFieldForTesting.isHidden)
        XCTAssertTrue(controller.actionPaletteSearchIsFocusedForTesting)
    }

    func testDictionaryDefinitionUsesTypographicHierarchy() throws {
        let definition = try XCTUnwrap(DictionaryLookup().formattedDefinition("raucous"))
        let value = definition.string

        XCTAssertTrue(value.hasPrefix("raucous "))
        XCTAssertTrue(value.contains("\nadjective"))
        XCTAssertTrue(value.contains("\n\nDERIVATIVES\n"))
        XCTAssertTrue(value.contains("\n\nORIGIN\n"))

        let wordRange = (value as NSString).range(of: "raucous")
        let sectionRange = (value as NSString).range(of: "DERIVATIVES")
        let wordFont = try XCTUnwrap(definition.attribute(.font, at: wordRange.location, effectiveRange: nil) as? NSFont)
        let sectionFont = try XCTUnwrap(definition.attribute(.font, at: sectionRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertGreaterThan(wordFont.pointSize, sectionFont.pointSize)
    }

    func testSystemCommandsAreAvailable() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        XCTAssertTrue(controller.resultTitlesForTesting.contains("Restart Device"))
        XCTAssertTrue(controller.resultTitlesForTesting.contains("Lock Device"))
        XCTAssertTrue(controller.resultTitlesForTesting.contains("Shut Down Device"))
        XCTAssertTrue(controller.lockMechanismAvailableForTesting)

        XCTAssertFalse(containsLabel("Quick Actions", in: controller.window?.contentView))
    }

    func testRunningApplicationStateIsExposedForIndicator() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.setSearchQueryForTesting("Finder")

        XCTAssertTrue(controller.resultTitlesForTesting.contains("Finder"))
        XCTAssertTrue(controller.runningResultTitlesForTesting.contains("Finder"))
    }

    func testIndicatorRowsHaveEvenVerticalRoom() {
        _ = NSApplication.shared
        let controller = CommandPanelController()

        XCTAssertEqual(controller.selectableRowHeightForTesting, 48)
    }

    func testSearchResultIconsEncapsulateCommandsButPreserveApplicationIcons() {
        _ = NSApplication.shared
        let cell = LauncherResultCell()
        cell.configure(with: CommandRegistry.builtIns[0].item)
        XCTAssertTrue(cell.iconIsEncapsulatedForTesting)
        XCTAssertEqual(cell.iconTileSizeForTesting, 22)
        XCTAssertEqual(cell.iconArtworkSizeForTesting, 12)

        cell.configure(with: CommandItem(
            title: "Finder",
            subtitle: "",
            icon: NSImage(size: NSSize(width: 32, height: 32)),
            kind: .application(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        ))
        XCTAssertFalse(cell.iconIsEncapsulatedForTesting)
        XCTAssertEqual(cell.iconArtworkSizeForTesting, 28)
    }

    func testSettingsExposeRequestedOptions() {
        _ = NSApplication.shared
        let controller = CatalystSettingsWindowController()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertTrue(containsLabel("Show Menu Bar Icon", in: controller.window?.contentView))
        XCTAssertTrue(containsLabel("Search Appears On", in: controller.window?.contentView))
        XCTAssertTrue(containsLabel("Password Manager", in: controller.window?.contentView))
        XCTAssertTrue(containsLabel("Toast Duration", in: controller.window?.contentView))
        XCTAssertEqual(controller.window?.title, "Catalyst Settings")
        XCTAssertTrue(controller.window?.styleMask.contains(.titled) == true)
        XCTAssertEqual(
            CatalystHighlightColor.allCases.map(\.title),
            ["Blue", "Red", "Orange", "Pink", "Green", "Gray"]
        )
        XCTAssertEqual(
            CatalystHotKey.allCases.map(\.title),
            ["⌥ Space", "⌘ Space", "⌃ Space", "⌥⌘ Space"]
        )
        XCTAssertEqual(CatalystPreferences.shared.backgroundOpacity, 0.72, accuracy: 0.37)
    }

    func testCameraPreviewLayerCanBeRecreatedAfterLeavingCamera() {
        let cameraView = CameraPreviewView()

        cameraView.preparePreviewLayer()
        XCTAssertTrue(cameraView.hasPreviewLayer)
        cameraView.stop()
        XCTAssertFalse(cameraView.hasPreviewLayer)
        cameraView.preparePreviewLayer()
        XCTAssertTrue(cameraView.hasPreviewLayer)
    }

    func testCatalystLifecycleCommandsAreSearchable() {
        _ = NSApplication.shared
        let controller = CommandPanelController()

        controller.setSearchQueryForTesting("Restart Catalyst")
        XCTAssertTrue(controller.resultTitlesForTesting.contains("Restart Catalyst"))

        controller.setSearchQueryForTesting("Quit Catalyst")
        XCTAssertTrue(controller.resultTitlesForTesting.contains("Quit Catalyst"))
    }

    func testKeyboardLockCommandOffersCleaningDurations() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.setSearchQueryForTesting("Lock Keyboard")

        XCTAssertTrue(controller.resultTitlesForTesting.contains("Lock Keyboard"))
        XCTAssertEqual(
            controller.selectedActionMenuTitlesForTesting(),
            ["30 Seconds", "1 Minute", "2 Minutes", "5 Minutes"]
        )
    }

    func testKeyboardLockCoversNormalModifierAndHardwareKeyEvents() {
        let mask = KeyboardLockController.keyboardEventMask
        let requiredTypes: [UInt32] = [
            CGEventType.keyDown.rawValue,
            CGEventType.keyUp.rawValue,
            CGEventType.flagsChanged.rawValue,
            14 // NX_SYSDEFINED: media, brightness, illumination, eject, etc.
        ]

        for type in requiredTypes {
            XCTAssertNotEqual(mask & (CGEventMask(1) << type), 0, "Missing event type \(type)")
        }
    }

    func testToggleSystemAppearanceCommandIsSearchable() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.setSearchQueryForTesting("Toggle System Appearance")

        XCTAssertTrue(controller.resultTitlesForTesting.contains("Toggle System Appearance"))
    }

    func testSystemSettingsSubpagesAreSearchable() {
        _ = NSApplication.shared
        let controller = CommandPanelController()

        controller.setSearchQueryForTesting("Bluetooth")
        XCTAssertTrue(controller.resultTitlesForTesting.contains("Bluetooth"))

        controller.setSearchQueryForTesting("Displays")
        XCTAssertTrue(controller.resultTitlesForTesting.contains("Displays"))
    }

    func testCommandPanelUsesInsetLayerShadowWithoutNativeBorder() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertFalse(controller.window?.hasShadow ?? true)
        XCTAssertTrue(controller.window?.styleMask.contains(.borderless) ?? false)
        XCTAssertFalse(controller.window?.isOpaque ?? true)
        XCTAssertEqual(controller.window?.backgroundColor, .clear)
        XCTAssertGreaterThan(controller.launcherShadowOpacityForTesting, 0)
        let frame = try! XCTUnwrap(controller.window?.contentView?.bounds)
        let shadowFrame = controller.launcherShadowFrameForTesting
        XCTAssertGreaterThanOrEqual(shadowFrame.minX, LauncherShadowView.requiredClearance)
        XCTAssertGreaterThanOrEqual(shadowFrame.minY, LauncherShadowView.requiredClearance)
        XCTAssertGreaterThanOrEqual(
            frame.maxX - shadowFrame.maxX,
            LauncherShadowView.requiredClearance
        )
        XCTAssertGreaterThanOrEqual(
            frame.maxY - shadowFrame.maxY,
            LauncherShadowView.requiredClearance
        )
    }

    func testCommandPanelDoesNotAnimateBeforeAppearing() {
        _ = NSApplication.shared
        let controller = CommandPanelController()

        XCTAssertEqual(controller.window?.animationBehavior, NSWindow.AnimationBehavior.none)
    }

    func testWarmCommandPanelShowCompletesWithinTwentyMilliseconds() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        var samples: [TimeInterval] = []

        for _ in 0..<7 {
            let start = ProcessInfo.processInfo.systemUptime
            controller.show()
            samples.append(ProcessInfo.processInfo.systemUptime - start)
            controller.dismiss()
        }

        let median = samples.sorted()[samples.count / 2]
        XCTAssertLessThan(median, 0.02, "Median show latency was \(median * 1_000) ms")
    }

    func testTypingUpdatesResultsWithinOneFrame() {
        _ = NSApplication.shared
        let controller = CommandPanelController()
        let queries = ["s", "sa", "saf", "safa", "safar", "safari", "cal"]
        var samples: [TimeInterval] = []
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        controller.window?.contentView?.displayIfNeeded()

        for query in queries {
            let start = ProcessInfo.processInfo.systemUptime
            controller.setSearchQueryForTesting(query)
            controller.window?.contentView?.layoutSubtreeIfNeeded()
            controller.window?.contentView?.displayIfNeeded()
            samples.append(ProcessInfo.processInfo.systemUptime - start)
        }

        let slowest = samples.max() ?? 0
        let timings = zip(queries, samples).map { "\($0): \($1 * 1_000) ms" }.joined(separator: ", ")
        XCTAssertLessThan(slowest, 0.016, "Query timings: \(timings)")
    }

    private func containsSeparator(in view: NSView?) -> Bool {
        guard let view, !view.isHidden else { return false }
        if let box = view as? NSBox, box.boxType == .separator { return true }
        return view.subviews.contains(where: containsSeparator(in:))
    }

    private func containsLabel(_ text: String, in view: NSView?) -> Bool {
        guard let view else { return false }
        if let field = view as? NSTextField, field.stringValue.contains(text) { return true }
        return view.subviews.contains { containsLabel(text, in: $0) }
    }

    private func findLabel(_ text: String, in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.stringValue == text { return field }
        for subview in view.subviews {
            if let match = findLabel(text, in: subview) { return match }
        }
        return nil
    }
}
