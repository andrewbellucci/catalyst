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
        case .defined(let command):
            return execute(command, previousApplication: previousApplication)
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
        case .emptyTrash:
            return systemActions.confirmEmptyTrash() ? .dismiss : .none
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
        case .passwordItem:
            return .none
        }
    }

    var lockMechanismAvailable: Bool { systemActions.lockMechanismAvailable }

    private func execute(
        _ command: CatalystCommand,
        previousApplication: NSRunningApplication?
    ) -> CommandOutcome {
        switch command.action {
        case .native(let native):
            return executeNative(native, previousApplication: previousApplication)
        case .openURL(let value):
            guard let url = URL(string: value) else { return .none }
            NSWorkspace.shared.open(url)
            return .dismiss
        case .runProcess(let configuration):
            run(configuration)
            return .dismiss
        }
    }

    private func executeNative(
        _ native: NativeCommandID,
        previousApplication: NSRunningApplication?
    ) -> CommandOutcome {
        let legacy: CommandKind = switch native {
        case .camera: .camera
        case .quitFocused: .quitFocused
        case .quitAll: .quitAll
        case .restartDevice: .restartDevice
        case .lockDevice: .lockDevice
        case .lockKeyboard: .lockKeyboard
        case .emptyTrash: .emptyTrash
        case .shutDownDevice: .shutDownDevice
        case .toggleSystemAppearance: .toggleSystemAppearance
        case .restartCatalyst: .restartCatalyst
        case .quitCatalyst: .quitCatalyst
        case .settings: .settings
        }
        return execute(legacy, previousApplication: previousApplication)
    }

    private func run(_ configuration: ProcessConfiguration) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            if configuration.runsThroughShell {
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", ([configuration.executable] + configuration.arguments).joined(separator: " ")]
            } else {
                process.executableURL = URL(fileURLWithPath: configuration.executable)
                process.arguments = configuration.arguments
            }
            if let directory = configuration.workingDirectory, !directory.isEmpty {
                process.currentDirectoryURL = URL(fileURLWithPath: NSString(string: directory).expandingTildeInPath)
            }
            try? process.run()
        }
    }
}
