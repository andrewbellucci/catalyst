import AppKit

func adaptiveColor(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    }
}

@MainActor
func liquidGlassSurface(containing content: NSView, cornerRadius: CGFloat) -> NSView {
    if #available(macOS 26.0, *) {
        if let view = content as? AdaptiveBackgroundView {
            view.fillColor = .clear
        } else if let button = content as? AdaptiveBackgroundButton {
            button.fillColor = .clear
        }
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = cornerRadius
        if #available(macOS 27.0, *) {
            glass.effectIsInteractive = true
        }
        glass.contentView = content
        return glass
    }
    return content
}

final class CommandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class LauncherShadowView: NSView {
    static let requiredClearance: CGFloat = 60

    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        configureShadow()
    }

    override func makeBackingLayer() -> CALayer {
        let backingLayer = CALayer()
        configureShadow(backingLayer)
        return backingLayer
    }

    private func configureShadow(_ targetLayer: CALayer? = nil) {
        let targetLayer = targetLayer ?? layer
        targetLayer?.masksToBounds = false
        targetLayer?.shadowColor = NSColor.black.cgColor
        targetLayer?.shadowOpacity = 0.22
        targetLayer?.shadowRadius = 18
        targetLayer?.shadowOffset = CGSize(width: 0, height: -5)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        configureShadow()
        updateShadowPath()
    }

    override func layout() {
        super.layout()
        configureShadow()
        updateShadowPath()
    }

    private func updateShadowPath() {
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }
}

final class SearchTextField: NSTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            window?.makeFirstResponder(self)
            currentEditor()?.selectAll(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class AdaptiveBackgroundView: NSView {
    var fillColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fillColor.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

class AdaptiveBackgroundButton: NSButton {
    var fillColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fillColor.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class CircularBackButton: AdaptiveBackgroundButton {
    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

@MainActor
func makeKeycap(_ text: String) -> NSView {
    let keycap = AdaptiveBackgroundView()
    keycap.fillColor = adaptiveColor(
        light: NSColor.white.withAlphaComponent(0.22),
        dark: NSColor.black.withAlphaComponent(0.18)
    )
    keycap.wantsLayer = true
    keycap.layer?.cornerRadius = 6
    keycap.layer?.borderWidth = 1
    keycap.layer?.borderColor = NSColor.separatorColor.cgColor

    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 11, weight: .regular)
    label.textColor = .secondaryLabelColor
    label.alignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    keycap.addSubview(label)

    let width = max(20, CGFloat(text.count * 7 + 10))
    NSLayoutConstraint.activate([
        keycap.widthAnchor.constraint(equalToConstant: width),
        keycap.heightAnchor.constraint(equalToConstant: 20),
        label.centerXAnchor.constraint(equalTo: keycap.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: keycap.centerYAnchor)
    ])
    return keycap
}

@MainActor
func makeShortcutPreview(_ shortcut: String) -> NSStackView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 2
    for character in shortcut {
        stack.addArrangedSubview(makeKeycap(String(character)))
    }
    return stack
}
