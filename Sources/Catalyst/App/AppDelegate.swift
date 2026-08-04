import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: CommandPanelController!
    private var statusMenu: StatusMenuController!
    private var globalHotKey: GlobalHotKey!
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = CommandPanelController()
        panelController.onDismiss = { [weak self] in self?.hidePanel() }
        panelController.previousApplication = { [weak self] in self?.previousApp }

        observeActiveApplications()
        statusMenu = StatusMenuController { [weak self] in self?.togglePanel() }
        statusMenu.setVisible(CatalystPreferences.shared.showsStatusBarIcon)
        globalHotKey = GlobalHotKey { [weak self] in self?.togglePanel() }
        registerHotKey()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyPreferenceDidChange),
            name: .catalystHotKeyDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusBarVisibilityPreferenceDidChange),
            name: .catalystStatusBarVisibilityDidChange,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.applicationWillTerminate()
        globalHotKey?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func observeActiveApplications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = current
        }
    }

    @objc private func applicationActivated(_ note: Notification) {
        guard
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        previousApp = app
    }

    private func registerHotKey() {
        let preference = CatalystPreferences.shared.hotKey
        let status = globalHotKey.register(preference)
        guard status == noErr else {
            NSLog("Could not register \(preference.title) hotkey: \(status)")
            return
        }

        runLaunchSmokeIfRequested(registrationStatus: status)
    }

    @objc private func hotKeyPreferenceDidChange() {
        registerHotKey()
    }

    @objc private func statusBarVisibilityPreferenceDidChange() {
        statusMenu.setVisible(CatalystPreferences.shared.showsStatusBarIcon)
    }

    private func runLaunchSmokeIfRequested(registrationStatus: OSStatus) {
        if ProcessInfo.processInfo.environment["CATALYST_PREVIEW"] == "1" {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let appearanceName = ProcessInfo.processInfo.environment["CATALYST_PREVIEW_APPEARANCE"] {
                    self.panelController.window?.appearance = NSAppearance(
                        named: appearanceName == "dark" ? .darkAqua : .aqua
                    )
                }
                self.togglePanel()
                if ProcessInfo.processInfo.environment["CATALYST_PREVIEW_SCROLL_FADE"] == "1" {
                    self.panelController.configureScrollFadePreview()
                }
                if ProcessInfo.processInfo.environment["CATALYST_PREVIEW_ACTIONS"] == "1" {
                    self.panelController.configureActionsPreview()
                }
                if ProcessInfo.processInfo.environment["CATALYST_PREVIEW_CAMERA"] == "1" {
                    self.panelController.configureCameraPreview()
                }
                if ProcessInfo.processInfo.environment["CATALYST_PREVIEW_SETTINGS"] == "1" {
                    self.panelController.configureSettingsPreview()
                }
                if let query = ProcessInfo.processInfo.environment["CATALYST_PREVIEW_QUERY"] {
                    self.panelController.configureQueryPreview(query)
                }
                guard let path = ProcessInfo.processInfo.environment["CATALYST_PREVIEW_CAPTURE"] else {
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard
                        let view = self.panelController.window?.contentView,
                        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)
                    else { return }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    if let data = bitmap.representation(using: .png, properties: [:]) {
                        try? data.write(to: URL(fileURLWithPath: path))
                    }
                    NSApp.terminate(nil)
                }
            }
            return
        }
        if ProcessInfo.processInfo.environment["CATALYST_CAMERA_SMOKE"] == "1" {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.togglePanel()
                let passed = self.panelController.runCameraNavigationSmoke()
                let result = passed ? "PASS" : "FAIL"
                FileHandle.standardOutput.write(Data("\(result): camera navigation\n".utf8))
                NSApp.terminate(nil)
            }
            return
        }
        guard ProcessInfo.processInfo.environment["CATALYST_HOTKEY_SMOKE"] == "1" else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.togglePanel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let visible = self.panelController.window?.isVisible == true
                let focused = self.panelController.isSearchFieldFocused
                let key = self.panelController.window?.isKeyWindow == true
                let active = NSApp.isActive
                let acceptsTyping = self.panelController.acceptsImmediateTyping
                let passed = registrationStatus == noErr && visible && acceptsTyping
                let result = passed ? "PASS" : "FAIL"
                let message = """
                \(result): registration=\(registrationStatus) windowVisible=\(visible) appActive=\(active) windowKey=\(key) searchFocused=\(focused)

                """
                FileHandle.standardOutput.write(Data(message.utf8))
                NSApp.terminate(nil)
            }
        }
    }

    @objc private func togglePanel() {
        if panelController.window?.isVisible == true {
            hidePanel()
        } else {
            if let frontmost = NSWorkspace.shared.frontmostApplication,
               frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousApp = frontmost
            }
            panelController.show()
        }
    }

    private func hidePanel() {
        panelController.dismiss()
    }
}
