import AppKit

enum LauncherScreenSelector {
    static func targetIndex(
        screenFrames: [CGRect],
        mouseLocation: CGPoint,
        preference: CatalystSearchDisplay
    ) -> Int? {
        guard !screenFrames.isEmpty else { return nil }
        switch preference {
        case .active:
            return screenFrames.firstIndex { $0.contains(mouseLocation) } ?? 0
        case .main:
            return 0
        }
    }
}
