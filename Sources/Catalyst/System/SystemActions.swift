import AppKit
import Darwin

@MainActor
final class SystemActions {
    private static let loginFrameworkPath =
        "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"

    func quitAllApplications() {
        for application in NSWorkspace.shared.runningApplications {
            guard
                application.activationPolicy == .regular,
                application.bundleIdentifier != Bundle.main.bundleIdentifier,
                application.bundleIdentifier != "com.apple.finder"
            else { continue }
            application.terminate()
        }
    }

    func confirmRestart() -> Bool {
        confirmPowerAction(
            title: "Restart this Mac?",
            detail: "All open applications will be asked to quit.",
            buttonTitle: "Restart",
            script: "tell application \"System Events\" to restart"
        )
    }

    func confirmShutDown() -> Bool {
        confirmPowerAction(
            title: "Shut down this Mac?",
            detail: "All open applications will be asked to quit.",
            buttonTitle: "Shut Down",
            script: "tell application \"System Events\" to shut down"
        )
    }

    func confirmEmptyTrash() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Empty the Trash?"
        alert.informativeText = "This permanently deletes every item in the Trash."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Empty")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let succeeded = runSystemEventScript("tell application \"Finder\" to empty trash")
        if !succeeded { showAutomationPermissionAlert() }
        return succeeded
    }

    func toggleAppearance() -> Bool {
        let succeeded = runSystemEventScript(
            "tell application \"System Events\" to tell appearance preferences "
            + "to set dark mode to not dark mode"
        )
        if !succeeded { showAutomationPermissionAlert() }
        return succeeded
    }

    func lockDevice() -> Bool {
        guard
            let handle = dlopen(Self.loginFrameworkPath, RTLD_LAZY),
            let symbol = dlsym(handle, "SACLockScreenImmediate")
        else {
            NSSound.beep()
            NSLog("Lock Device failed: session lock endpoint is unavailable")
            return false
        }
        typealias LockScreenFunction = @convention(c) () -> Void
        unsafeBitCast(symbol, to: LockScreenFunction.self)()
        dlclose(handle)
        return true
    }

    func restartCatalyst() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try process.run()
            NSApp.terminate(nil)
            return true
        } catch {
            NSSound.beep()
            NSLog("Could not restart Catalyst: \(error)")
            return false
        }
    }

    var lockMechanismAvailable: Bool {
        guard let handle = dlopen(Self.loginFrameworkPath, RTLD_LAZY) else { return false }
        defer { dlclose(handle) }
        return dlsym(handle, "SACLockScreenImmediate") != nil
    }

    private func confirmPowerAction(
        title: String,
        detail: String,
        buttonTitle: String,
        script: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: buttonTitle)
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        return runSystemEventScript(script)
    }

    private func runSystemEventScript(_ source: String) -> Bool {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        script.executeAndReturnError(&error)
        if let error {
            NSSound.beep()
            NSLog("System action failed: %@", error)
            return false
        }
        return true
    }

    private func showAutomationPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "System Events Permission Required"
        alert.informativeText =
            "Allow Catalyst to control System Events in System Settings → "
            + "Privacy & Security → Automation, then run the command again."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
