import AppKit

struct NotchToast {
    let message: String
    let indicatorColor: NSColor
    let duration: TimeInterval

    @MainActor init(
        message: String,
        indicatorColor: NSColor,
        duration: TimeInterval = CatalystPreferences.shared.toastDuration.seconds
    ) {
        self.message = message
        self.indicatorColor = indicatorColor
        self.duration = duration
    }
}

@MainActor
final class NotchToastController {
    static let toastHeight: CGFloat = 42
    static let indicatorDiameter: CGFloat = 10
    static let indicatorHaloDiameter: CGFloat = 20
    private static let toastFont = NSFont.systemFont(ofSize: 15, weight: .medium)
    private var window: NSPanel?
    private var dismissal: DispatchWorkItem?
    private var expandedContentPosition = CGPoint.zero

    func show(_ toast: NotchToast, on screen: NSScreen? = nil) {
        dismissal?.cancel()
        window?.orderOut(nil)

        guard let screen = screen ?? screenContainingPointer() ?? NSScreen.screens.first else { return }
        let content = makeContent(for: toast)
        let textWidth = (toast.message as NSString).size(withAttributes: [.font: Self.toastFont]).width
        let finalSize = NSSize(
            width: min(max(15 + Self.indicatorHaloDiameter + 12 + textWidth + 20, 160), 400),
            height: Self.toastHeight
        )
        let finalFrame = Self.frame(for: finalSize, on: screen.frame, safeAreaTop: screen.safeAreaInsets.top)
        let panel = NSPanel(
            contentRect: finalFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        let animationHost = NSView(frame: NSRect(origin: .zero, size: finalSize))
        animationHost.wantsLayer = true
        animationHost.layer?.masksToBounds = false
        content.frame = animationHost.bounds
        content.autoresizingMask = [.width, .height]
        animationHost.addSubview(content)
        panel.contentView = animationHost
        panel.alphaValue = 1
        animationHost.layoutSubtreeIfNeeded()
        content.layoutSubtreeIfNeeded()
        expandedContentPosition = content.layer?.position ?? CGPoint(x: content.bounds.midX, y: content.bounds.midY)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.layer?.transform = collapsedTransform(for: content)
        content.layer?.opacity = 0
        content.layer?.position = compensatedPosition(for: content, scaleX: 44 / finalSize.width, scaleY: 6 / finalSize.height)
        CATransaction.commit()
        panel.orderFrontRegardless()
        window = panel

        DispatchQueue.main.async { [weak self, weak panel, weak content] in
            guard let self, let panel, let content, self.window === panel else { return }
            self.animate(content, fromCollapsed: true, duration: 0.42)
        }

        let dismissal = DispatchWorkItem { [weak self, weak panel] in
            guard let self, let panel, self.window === panel else { return }
            self.dismiss(panel)
        }
        self.dismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + max(toast.duration, 0.5), execute: dismissal)
    }

    static func frame(
        for size: NSSize,
        on screenFrame: NSRect,
        safeAreaTop: CGFloat
    ) -> NSRect {
        let topInset = safeAreaTop > 0 ? safeAreaTop + 8 : 34
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - topInset - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func collapsedFrame(for expandedFrame: NSRect) -> NSRect {
        let size = NSSize(width: 44, height: 6)
        return NSRect(
            x: expandedFrame.midX - size.width / 2,
            y: expandedFrame.maxY + 8 - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func makeContent(for toast: NotchToast) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.layer?.cornerRadius = Self.toastHeight / 2
        container.layer?.masksToBounds = true

        let indicatorGlow = NSView()
        indicatorGlow.wantsLayer = true
        indicatorGlow.layer?.backgroundColor = toast.indicatorColor.withAlphaComponent(0.28).cgColor
        indicatorGlow.layer?.cornerRadius = Self.indicatorHaloDiameter / 2
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.38
        pulse.toValue = 1
        pulse.duration = 0.75
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        indicatorGlow.layer?.add(pulse, forKey: "catalystToastPulse")
        indicatorGlow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(indicatorGlow)

        let indicator = NSView()
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = toast.indicatorColor.cgColor
        indicator.layer?.cornerRadius = Self.indicatorDiameter / 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicatorGlow.addSubview(indicator)

        let label = NSTextField(labelWithString: toast.message)
        label.font = Self.toastFont
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            indicatorGlow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            indicatorGlow.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            indicatorGlow.widthAnchor.constraint(equalToConstant: Self.indicatorHaloDiameter),
            indicatorGlow.heightAnchor.constraint(equalToConstant: Self.indicatorHaloDiameter),
            indicator.centerXAnchor.constraint(equalTo: indicatorGlow.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: indicatorGlow.centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: Self.indicatorDiameter),
            indicator.heightAnchor.constraint(equalToConstant: Self.indicatorDiameter),
            label.leadingAnchor.constraint(equalTo: indicatorGlow.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: Self.toastHeight)
        ])
        return container
    }

    private func dismiss(_ panel: NSPanel) {
        guard let content = panel.contentView?.subviews.first else { return }
        animate(content, fromCollapsed: false, duration: 0.28) { [weak self, weak panel] in
            panel?.orderOut(nil)
            if self?.window === panel { self?.window = nil }
        }
    }

    private func animate(
        _ view: NSView,
        fromCollapsed: Bool,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        guard let layer = view.layer else {
            completion?()
            return
        }
        let collapsed = collapsedTransform(for: view)
        let startTransform = fromCollapsed ? collapsed : CATransform3DIdentity
        let endTransform = fromCollapsed ? CATransform3DIdentity : collapsed
        let startOpacity: Float = fromCollapsed ? 0 : 1
        let endOpacity: Float = fromCollapsed ? 1 : 0

        let transformAnimation: CAAnimation
        if fromCollapsed {
            let spring = CAKeyframeAnimation(keyPath: "transform")
            spring.values = [
                NSValue(caTransform3D: startTransform),
                NSValue(caTransform3D: CATransform3DMakeScale(1.035, 1.035, 1)),
                NSValue(caTransform3D: CATransform3DMakeScale(0.99, 0.99, 1)),
                NSValue(caTransform3D: endTransform)
            ]
            spring.keyTimes = [0, 0.68, 0.86, 1]
            spring.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeOut)
            ]
            transformAnimation = spring
        } else {
            let shrink = CABasicAnimation(keyPath: "transform")
            shrink.fromValue = NSValue(caTransform3D: startTransform)
            shrink.toValue = NSValue(caTransform3D: endTransform)
            transformAnimation = shrink
        }

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = startOpacity
        opacityAnimation.toValue = endOpacity

        let positionAnimation: CAAnimation
        if fromCollapsed {
            let springPosition = CAKeyframeAnimation(keyPath: "position")
            springPosition.values = [
                NSValue(point: compensatedPosition(for: view, scaleX: 44 / view.bounds.width, scaleY: 6 / view.bounds.height)),
                NSValue(point: compensatedPosition(for: view, scaleX: 1.035, scaleY: 1.035)),
                NSValue(point: compensatedPosition(for: view, scaleX: 0.99, scaleY: 0.99)),
                NSValue(point: expandedContentPosition)
            ]
            springPosition.keyTimes = [0, 0.68, 0.86, 1]
            springPosition.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeOut)
            ]
            positionAnimation = springPosition
        } else {
            let shrinkPosition = CABasicAnimation(keyPath: "position")
            shrinkPosition.fromValue = NSValue(point: expandedContentPosition)
            shrinkPosition.toValue = NSValue(point: compensatedPosition(
                for: view,
                scaleX: 44 / view.bounds.width,
                scaleY: 6 / view.bounds.height
            ))
            positionAnimation = shrinkPosition
        }

        let animation = CAAnimationGroup()
        animation.animations = [transformAnimation, opacityAnimation, positionAnimation]
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        layer.transform = endTransform
        layer.opacity = endOpacity
        layer.position = fromCollapsed
            ? expandedContentPosition
            : compensatedPosition(for: view, scaleX: 44 / view.bounds.width, scaleY: 6 / view.bounds.height)
        layer.add(animation, forKey: "catalystToastTransition")
        CATransaction.commit()
    }

    private func collapsedTransform(for view: NSView) -> CATransform3D {
        CATransform3DMakeScale(
            44 / max(view.bounds.width, 1),
            6 / max(view.bounds.height, 1),
            1
        )
    }

    private func compensatedPosition(for view: NSView, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        guard let layer = view.layer else { return expandedContentPosition }
        let topY: CGFloat = layer.isGeometryFlipped ? 0 : 1
        return CGPoint(
            x: expandedContentPosition.x
                + (0.5 - layer.anchorPoint.x) * view.bounds.width * (1 - scaleX),
            y: expandedContentPosition.y
                + (topY - layer.anchorPoint.y) * view.bounds.height * (1 - scaleY)
        )
    }

    private func screenContainingPointer() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }
    }
}
