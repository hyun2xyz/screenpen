import AppKit
import ScreenPenCore

final class OverlayView: NSView {
    private let displayID: CGDirectDisplayID?
    private let state: AppState
    private var lastDragPoint: CGPoint?

    init(frame frameRect: NSRect, screen: NSScreen, state: AppState) {
        displayID = ScreenGeometry.displayID(for: screen)
        self.state = state
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        state.addObserver { [weak self] in
            guard let self else { return }
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
            applyActiveCursor()
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let tool = state.activeTool else { return }
        addCursorRect(bounds, cursor: DrawingCursorFactory.cursor(for: tool))
    }

    override func cursorUpdate(with event: NSEvent) {
        applyActiveCursor()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawSpotlightIfNeeded()
        drawStrokes()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            state.perform(.deactivate)
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 53 {
            return
        }

        super.keyUp(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        lastDragPoint = point

        guard state.activeTool != nil else { return }
        state.beginStroke(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        guard state.activeTool != nil else { return }
        state.appendStrokePoint(point)
    }

    override func mouseUp(with event: NSEvent) {
        defer { lastDragPoint = nil }
        guard state.activeTool != nil else { return }
        state.appendStrokePoint(convert(event.locationInWindow, from: nil))
        state.endStroke()
    }

    override func rightMouseDown(with event: NSEvent) {
        state.perform(.deactivate)
    }

    private func drawStrokes() {
        for stroke in state.store.strokes {
            draw(stroke)
        }

        if let draft = state.store.draftStroke {
            draw(draft)
        }
    }

    private func draw(_ stroke: DrawingStroke) {
        guard stroke.points.count > 1 else { return }

        let path = NSBezierPath()
        path.lineWidth = CGFloat(stroke.style.lineWidth)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let points = stroke.points.map { NSPoint(x: $0.x, y: $0.y) }
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.line(to: point)
        }

        nsColor(from: stroke.style.color)
            .withAlphaComponent(CGFloat(stroke.style.opacity))
            .setStroke()
        path.stroke()
    }

    private func drawSpotlightIfNeeded() {
        guard state.session.isSpotlightEnabled, let cursor = localCursorPoint() else { return }

        let path = NSBezierPath(rect: bounds)
        let radius: CGFloat = 115
        path.appendOval(in: NSRect(
            x: cursor.x - radius,
            y: cursor.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        path.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.48).setFill()
        path.fill()
    }

    private func localCursorPoint() -> NSPoint? {
        guard let window else { return nil }
        let windowPoint = window.convertPoint(fromScreen: state.cursorLocation)
        return convert(windowPoint, from: nil)
    }

    private func nsColor(from color: RGBAColor) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.alpha)
        )
    }

    private func helpFont(size: CGFloat) -> NSFont {
        for fontName in ["Apple SD Gothic Neo", "AppleSDGothicNeo-Regular", "AppleSDGothicNeo-Medium"] {
            if let font = NSFont(name: fontName, size: size) {
                return font
            }
        }

        return NSFont.systemFont(ofSize: size, weight: .medium)
    }

    func applyActiveCursor() {
        if let tool = state.activeTool, window?.ignoresMouseEvents == false {
            DrawingCursorFactory.cursor(for: tool).set()
        } else if state.activeTool == nil {
            NSCursor.arrow.set()
        }
    }
}
