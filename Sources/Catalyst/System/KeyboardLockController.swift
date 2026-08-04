import AppKit
import CoreGraphics

private final class KeyboardLockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class KeyboardLockController: NSObject {
    static let keyboardEventMask =
        (CGEventMask(1) << CGEventType.keyDown.rawValue)
        | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        | (CGEventMask(1) << 14) // NX_SYSDEFINED hardware/media keys

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var panel: NSPanel?
    private let countdownLabel = NSTextField(labelWithString: "")
    private var endDate: Date?

    @discardableResult
    func start(duration: TimeInterval) -> Bool {
        unlock()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.keyboardEventMask,
            callback: { _, type, event, userInfo in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let userInfo {
                        let controller = Unmanaged<KeyboardLockController>
                            .fromOpaque(userInfo)
                            .takeUnretainedValue()
                        MainActor.assumeIsolated {
                            if let tap = controller.eventTap {
                                CGEvent.tapEnable(tap: tap, enable: true)
                            }
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            _ = CGRequestListenEventAccess()
            showPermissionAlert()
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        endDate = Date().addingTimeInterval(duration)
        showOverlay()
        updateCountdown()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateCountdown),
            userInfo: nil,
            repeats: true
        )
        return true
    }

    @objc func unlock() {
        timer?.invalidate()
        timer = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        endDate = nil
        panel?.orderOut(nil)
        panel = nil
    }

    var isLocked: Bool { eventTap != nil }

    @objc private func updateCountdown() {
        guard let endDate else { return }
        let remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if remaining == 0 {
            unlock()
            return
        }
        let minutes = remaining / 60
        let seconds = remaining % 60
        countdownLabel.stringValue = String(format: "%d:%02d", minutes, seconds)
        countdownLabel.setAccessibilityLabel("Time remaining")
        countdownLabel.setAccessibilityValue(countdownLabel.stringValue)
    }

    private func showOverlay() {
        let panel = KeyboardLockPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 150),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let surface = NSVisualEffectView()
        surface.material = .hudWindow
        surface.state = .active
        surface.wantsLayer = true
        surface.layer?.cornerRadius = 22
        surface.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Keyboard Locked")
        title.font = .systemFont(ofSize: 20, weight: .regular)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        countdownLabel.textColor = .labelColor
        countdownLabel.alignment = .center
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false

        let unlockButton = NSButton(title: "Unlock", target: self, action: #selector(unlock))
        unlockButton.bezelStyle = .rounded
        unlockButton.keyEquivalent = ""
        unlockButton.translatesAutoresizingMaskIntoConstraints = false

        guard let contentView = panel.contentView else { return }
        contentView.addSubview(surface)
        surface.addSubview(title)
        surface.addSubview(countdownLabel)
        surface.addSubview(unlockButton)
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            surface.topAnchor.constraint(equalTo: contentView.topAnchor),
            surface.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            title.topAnchor.constraint(equalTo: surface.topAnchor, constant: 24),
            title.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -24),
            countdownLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            countdownLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            countdownLabel.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            unlockButton.topAnchor.constraint(equalTo: countdownLabel.bottomAnchor, constant: 10),
            unlockButton.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
            unlockButton.widthAnchor.constraint(equalToConstant: 100)
        ])

        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - panel.frame.width / 2,
                y: screen.visibleFrame.midY - panel.frame.height / 2
            ))
        }
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText =
            "Catalyst needs permission to temporarily suppress keyboard input. "
            + "Enable Catalyst in System Settings → Privacy & Security → Accessibility, then try again."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
