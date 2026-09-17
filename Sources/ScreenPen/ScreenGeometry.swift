import AppKit

enum ScreenGeometry {
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func overlayFrame(for screen: NSScreen) -> CGRect {
        var frame = screen.frame
        frame.size.height -= menuBarHeight(for: screen)
        return frame
    }

    private static func menuBarHeight(for screen: NSScreen) -> CGFloat {
        max(0, screen.frame.maxY - screen.visibleFrame.maxY)
    }
}
