import AppKit
import ScreenPenCore

final class AppState: @unchecked Sendable {
    private(set) var store = DrawingStore()
    private(set) var session = LectureSession()
    private(set) var drawingPreferences = DrawingPreferences()
    private var observers: [() -> Void] = []
    private var lastColorTool: DrawingTool = .pen

    private(set) var cursorLocation: CGPoint = .zero

    var activeTool: DrawingTool? {
        session.activeTool
    }

    var colorTargetTool: DrawingTool {
        switch activeTool {
        case .pen, .highlighter:
            activeTool ?? lastColorTool
        case .eraser, .none:
            lastColorTool
        }
    }

    func addObserver(_ observer: @escaping () -> Void) {
        observers.append(observer)
    }

    func perform(_ command: LectureCommand) {
        session.perform(command, store: &store)

        switch session.activeTool {
        case .pen, .highlighter:
            lastColorTool = session.activeTool ?? lastColorTool
        case .eraser, .none:
            break
        }

        notify()
    }

    func beginStroke(at point: CGPoint) {
        guard let tool = session.activeTool else { return }
        if tool == .eraser {
            erase(at: point)
            return
        }

        store.beginStroke(
            at: DrawingPoint(point),
            tool: tool,
            style: drawingPreferences.style(for: tool)
        )
        notify()
    }

    func appendStrokePoint(_ point: CGPoint) {
        guard let tool = session.activeTool else { return }
        if tool == .eraser {
            erase(at: point)
            return
        }

        store.appendPoint(DrawingPoint(point))
        notify()
    }

    func endStroke() {
        store.endStroke()
        notify()
    }

    func updateCursor(location: CGPoint) {
        cursorLocation = location
        notify()
    }

    func selectColor(_ color: RGBAColor, for tool: DrawingTool) {
        guard tool == .pen || tool == .highlighter else { return }
        drawingPreferences.selectColor(color, for: tool)
        lastColorTool = tool
        notify()
    }

    private func notify() {
        observers.forEach { $0() }
    }

    private func erase(at point: CGPoint) {
        store.erase(at: DrawingPoint(point), radius: 24)
        notify()
    }
}

private extension DrawingPoint {
    init(_ point: CGPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }
}
