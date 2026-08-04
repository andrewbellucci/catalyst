import AppKit

enum CommandOutcome: Equatable {
    case none
    case dismiss
    case showCamera
    case showKeyboardLockDurations
    case showSettings
    case showDefinition(String)
}

@MainActor
final class CommandExecutor {
    private let systemActions: SystemActions
    private let applicationLauncher: ApplicationOpening

    init(
        systemActions: SystemActions = SystemActions(),
        applicationLauncher: ApplicationOpening = ApplicationLauncher()
    ) {
        self.systemActions = systemActions
        self.applicationLauncher = applicationLauncher
    }

    func execute(
        _ kind: CommandKind,
        previousApplication: NSRunningApplication?
    ) -> CommandOutcome {
        switch kind {
        case .section, .hint:
            return .none
        case .camera:
            return .showCamera
        case .quitFocused:
            previousApplication?.terminate()
            return .dismiss
        case .quitAll:
            systemActions.quitAllApplications()
            return .dismiss
        case .restartDevice:
            return systemActions.confirmRestart() ? .dismiss : .none
        case .lockDevice:
            return systemActions.lockDevice() ? .dismiss : .none
        case .lockKeyboard:
            return .showKeyboardLockDurations
        case .shutDownDevice:
            return systemActions.confirmShutDown() ? .dismiss : .none
        case .toggleSystemAppearance:
            return systemActions.toggleAppearance() ? .dismiss : .none
        case .restartCatalyst:
            _ = systemActions.restartCatalyst()
            return .none
        case .quitCatalyst:
            NSApp.terminate(nil)
            return .none
        case .settings:
            return .showSettings
        case .systemSettings(let url):
            NSWorkspace.shared.open(url)
            return .dismiss
        case .dictionary(let term):
            return .showDefinition(term)
        case .calculation(let result):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            return .dismiss
        case .application(let url):
            applicationLauncher.open(url)
            return .dismiss
        }
    }

    var lockMechanismAvailable: Bool { systemActions.lockMechanismAvailable }
}
