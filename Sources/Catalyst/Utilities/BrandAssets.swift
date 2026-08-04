import AppKit

enum BrandAssets {
    static func catalystGlyph(accessibilityDescription: String = "Catalyst") -> NSImage {
        if let glyphURL = Bundle.main.url(forResource: "CatalystGlyph", withExtension: "svg"),
           let glyph = NSImage(contentsOf: glyphURL) {
            glyph.isTemplate = true
            glyph.accessibilityDescription = accessibilityDescription
            return glyph
        }

        return NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: accessibilityDescription
        ) ?? NSImage()
    }

    static func catalystIcon(accessibilityDescription: String = "Catalyst") -> NSImage {
        if let iconURL = Bundle.main.url(forResource: "Catalyst", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.accessibilityDescription = accessibilityDescription
            return icon
        }

        return NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: accessibilityDescription
        ) ?? NSImage()
    }
}
