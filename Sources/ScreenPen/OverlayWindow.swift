import AppKit

final class OverlayWindow: NSPanel {
    let displayID: CGDirectDisplayID?

    init(screen: NSScreen, state: AppState) {
        displayID = ScreenGeometry.displayID(for: screen)
        let overlayFrame = Self.overlayFrame(for: screen)
        super.init(
            contentRect: overlayFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        becomesKeyOnlyIfNeeded = true

        let view = OverlayView(frame: NSRect(origin: .zero, size: overlayFrame.size), screen: screen, state: state)
        contentView = view
        setFrame(overlayFrame, display: true)
        orderFrontRegardless()
    }

    func setInputCapture(_ shouldCapture: Bool) {
        ignoresMouseEvents = !shouldCapture

        if shouldCapture {
            makeKeyAndOrderFront(nil)
            if let overlayView = contentView as? OverlayView {
                makeFirstResponder(overlayView)
            }
        } else {
            orderFrontRegardless()
        }

        if let overlayView = contentView as? OverlayView {
            invalidateCursorRects(for: overlayView)
            overlayView.applyActiveCursor()
        }
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    private static func overlayFrame(for screen: NSScreen) -> NSRect {
        ScreenGeometry.overlayFrame(for: screen)
    }
}
