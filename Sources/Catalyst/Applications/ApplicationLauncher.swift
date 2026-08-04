import AppKit
import Carbon.HIToolbox

@MainActor
protocol ApplicationOpening: Sendable {
    func open(_ url: URL)
}

@MainActor
final class ApplicationLauncher: ApplicationOpening {
    typealias WorkspaceOpen = (
        URL,
        @escaping @Sendable (NSRunningApplication?, Error?) -> Void
    ) -> Void

    nonisolated static let activationRetryDelays: [Duration] = [
        .zero,
        .milliseconds(150),
        .milliseconds(500),
        .seconds(1),
        .seconds(2),
        .seconds(4)
    ]

    private let workspaceOpen: WorkspaceOpen
    private let fallback: ApplicationOpening

    init(
        workspace: NSWorkspace = .shared,
        fallback: ApplicationOpening = FinderApplicationLauncher()
    ) {
        self.workspaceOpen = { url, completion in
            workspace.openApplication(
                at: url,
                configuration: .init(),
                completionHandler: completion
            )
        }
        self.fallback = fallback
    }

    init(workspaceOpen: @escaping WorkspaceOpen, fallback: ApplicationOpening) {
        self.workspaceOpen = workspaceOpen
        self.fallback = fallback
    }

    func open(_ url: URL) {
        workspaceOpen(url) { [fallback] application, _ in
            guard
                let application,
                application.processIdentifier > 0,
                application.bundleURL != nil
            else {
                Task { @MainActor in fallback.open(url) }
                return
            }
            Task { @MainActor in
                var previousDelay = Duration.zero
                for delay in Self.activationRetryDelays {
                    let wait = delay - previousDelay
                    if wait != .zero { try? await Task.sleep(for: wait) }
                    guard !application.isTerminated else { return }
                    if Self.hasOnScreenWindow(processIdentifier: application.processIdentifier) {
                        if !application.isActive {
                            _ = application.activate(options: [.activateAllWindows])
                        }
                        return
                    }
                    _ = application.activate(options: [.activateAllWindows])
                    previousDelay = delay
                }
            }
        }
    }

    nonisolated private static func hasOnScreenWindow(processIdentifier: pid_t) -> Bool {
        let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        return windows.contains {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == processIdentifier
                && ($0[kCGWindowLayer as String] as? Int) == 0
        }
    }
}

@MainActor
final class FinderApplicationLauncher: ApplicationOpening {
    func open(_ url: URL) {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenDocuments),
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        let items = NSAppleEventDescriptor.list()
        items.insert(NSAppleEventDescriptor(fileURL: url), at: 1)
        event.setParam(items, forKeyword: AEKeyword(keyDirectObject))
        _ = try? event.sendEvent(options: [.noReply], timeout: 2)
    }
}
