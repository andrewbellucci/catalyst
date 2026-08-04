import AppKit

struct RunningApplicationIdentity: Hashable {
    let bundleIdentifier: String?
    let url: URL?
}

@MainActor
final class RunningApplicationsMonitor: NSObject {
    typealias SnapshotProvider = () -> Set<RunningApplicationIdentity>

    var onChange: (() -> Void)?

    private let workspace: NSWorkspace
    private let reconciliationInterval: TimeInterval
    private let quitSuppressionDuration: TimeInterval
    private let snapshotProvider: SnapshotProvider
    private var timer: Timer?
    private var identities = Set<RunningApplicationIdentity>()
    private var pendingQuitExpirations: [RunningApplicationIdentity: Date] = [:]

    init(
        workspace: NSWorkspace = .shared,
        reconciliationInterval: TimeInterval = 0.5,
        quitSuppressionDuration: TimeInterval = 1,
        snapshotProvider: SnapshotProvider? = nil
    ) {
        self.workspace = workspace
        self.reconciliationInterval = reconciliationInterval
        self.quitSuppressionDuration = quitSuppressionDuration
        self.snapshotProvider = snapshotProvider ?? {
            Set(workspace.runningApplications.map {
                RunningApplicationIdentity(
                    bundleIdentifier: $0.bundleIdentifier,
                    url: $0.bundleURL?.standardizedFileURL
                )
            })
        }
    }

    func start() {
        guard timer == nil else { return }
        let center = workspace.notificationCenter
        center.addObserver(
            self,
            selector: #selector(workspaceApplicationsDidChange),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceApplicationsDidChange),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        reconcile()
        timer = Timer.scheduledTimer(
            timeInterval: reconciliationInterval,
            target: self,
            selector: #selector(reconcileFromTimer),
            userInfo: nil,
            repeats: true
        )
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        workspace.notificationCenter.removeObserver(self)
    }

    func reconcile() {
        let now = Date()
        let actual = snapshotProvider()
        pendingQuitExpirations = pendingQuitExpirations.filter { identity, expiration in
            actual.contains(identity) && expiration > now
        }
        let visible = actual.subtracting(pendingQuitExpirations.keys)
        guard visible != identities else { return }
        identities = visible
        onChange?()
    }

    func markQuitAccepted(bundleIdentifier: String?, url: URL) {
        let identity = RunningApplicationIdentity(
            bundleIdentifier: bundleIdentifier,
            url: url.standardizedFileURL
        )
        pendingQuitExpirations[identity] = Date().addingTimeInterval(quitSuppressionDuration)
        if identities.remove(identity) != nil { onChange?() }
    }

    func isRunning(bundleIdentifier: String?, url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        return identities.contains { identity in
            if let bundleIdentifier { return identity.bundleIdentifier == bundleIdentifier }
            return identity.url == standardizedURL
        }
    }

    @objc private func workspaceApplicationsDidChange(_ notification: Notification) {
        reconcile()
    }

    @objc private func reconcileFromTimer() {
        reconcile()
    }
}
