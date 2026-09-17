import Foundation

public enum DrawingTool: String, CaseIterable, Equatable, Sendable {
    case pen
    case highlighter
    case eraser
}

public struct DrawingPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct RGBAColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let markerYellow = RGBAColor(red: 1, green: 0.86, blue: 0.12, alpha: 1)
    public static let inkRed = RGBAColor(red: 1, green: 0.16, blue: 0.12, alpha: 1)
}

public struct DrawingStyle: Equatable, Sendable {
    public var color: RGBAColor
    public var lineWidth: Double
    public var opacity: Double

    public init(color: RGBAColor, lineWidth: Double, opacity: Double) {
        self.color = color
        self.lineWidth = lineWidth
        self.opacity = opacity
    }

    public static func defaultStyle(for tool: DrawingTool) -> DrawingStyle {
        switch tool {
        case .pen:
            DrawingStyle(color: .inkRed, lineWidth: 4, opacity: 1)
        case .highlighter:
            DrawingStyle(color: .markerYellow, lineWidth: 18, opacity: 0.32)
        case .eraser:
            DrawingStyle(color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1), lineWidth: 28, opacity: 1)
        }
    }
}

public struct DrawingStroke: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var tool: DrawingTool
    public var style: DrawingStyle
    public var points: [DrawingPoint]

    public init(
        id: UUID = UUID(),
        tool: DrawingTool,
        style: DrawingStyle,
        points: [DrawingPoint]
    ) {
        self.id = id
        self.tool = tool
        self.style = style
        self.points = points
    }
}

public struct DrawingStore: Equatable, Sendable {
    public private(set) var strokes: [DrawingStroke]
    public private(set) var draftStroke: DrawingStroke?

    public init(strokes: [DrawingStroke] = [], draftStroke: DrawingStroke? = nil) {
        self.strokes = strokes
        self.draftStroke = draftStroke
    }

    public mutating func beginStroke(at point: DrawingPoint, tool: DrawingTool) {
        beginStroke(
            at: point,
            tool: tool,
            style: DrawingStyle.defaultStyle(for: tool)
        )
    }

    public mutating func beginStroke(
        at point: DrawingPoint,
        tool: DrawingTool,
        style: DrawingStyle
    ) {
        draftStroke = DrawingStroke(
            tool: tool,
            style: style,
            points: [point]
        )
    }

    public mutating func appendPoint(_ point: DrawingPoint) {
        draftStroke?.points.append(point)
    }

    public mutating func endStroke() {
        guard let draftStroke, !draftStroke.points.isEmpty else {
            self.draftStroke = nil
            return
        }

        strokes.append(draftStroke)
        self.draftStroke = nil
    }

    public mutating func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
    }

    public mutating func clear() {
        strokes.removeAll()
        draftStroke = nil
    }

    public mutating func erase(at point: DrawingPoint, radius: Double) {
        strokes.removeAll { stroke in
            stroke.intersects(point: point, radius: radius)
        }
    }
}

public enum LectureCommand: Equatable, Sendable {
    case togglePen
    case toggleHighlighter
    case toggleEraser
    case toggleSpotlight
    case toggleZoom
    case toggleHelpOverlay
    case undo
    case clear
    case deactivate
}

public enum HotKeyModifier: Hashable, Sendable {
    case control
    case option
    case command
    case shift
}

public struct HotKeyStroke: Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Set<HotKeyModifier>

    public init(keyCode: UInt16, modifiers: Set<HotKeyModifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum HotKeyMapper {
    private static let requiredModifiers: Set<HotKeyModifier> = [.control, .option]

    public static func command(for stroke: HotKeyStroke) -> LectureCommand? {
        if stroke.keyCode == 53 && stroke.modifiers.isEmpty {
            return .deactivate
        }

        guard stroke.modifiers == requiredModifiers else { return nil }

        switch stroke.keyCode {
        case 18:
            return .togglePen
        case 19:
            return .toggleHighlighter
        case 20:
            return .toggleSpotlight
        case 21:
            return .toggleZoom
        case 23:
            return .toggleEraser
        case 31:
            return .toggleHelpOverlay
        case 50:
            return .clear
        default:
            return nil
        }
    }
}

public struct LectureSession: Equatable, Sendable {
    public var activeTool: DrawingTool?
    public var isSpotlightEnabled: Bool
    public var isHelpOverlayVisible: Bool

    public init(
        activeTool: DrawingTool? = nil,
        isSpotlightEnabled: Bool = false,
        isHelpOverlayVisible: Bool = true
    ) {
        self.activeTool = activeTool
        self.isSpotlightEnabled = isSpotlightEnabled
        self.isHelpOverlayVisible = isHelpOverlayVisible
    }

    public mutating func perform(_ command: LectureCommand, store: inout DrawingStore) {
        switch command {
        case .togglePen:
            toggleTool(.pen)
        case .toggleHighlighter:
            toggleTool(.highlighter)
        case .toggleEraser:
            toggleTool(.eraser)
        case .toggleSpotlight:
            isSpotlightEnabled.toggle()
        case .toggleZoom:
            activeTool = nil
            isSpotlightEnabled = false
        case .toggleHelpOverlay:
            isHelpOverlayVisible.toggle()
        case .undo:
            store.undo()
        case .clear:
            store.clear()
        case .deactivate:
            activeTool = nil
            isSpotlightEnabled = false
        }
    }

    private mutating func toggleTool(_ tool: DrawingTool) {
        activeTool = activeTool == tool ? nil : tool
    }
}

private extension DrawingStroke {
    func intersects(point: DrawingPoint, radius: Double) -> Bool {
        guard !points.isEmpty else { return false }
        guard points.count > 1 else {
            return points[0].distance(to: point) <= radius
        }

        for index in 0..<(points.count - 1) {
            if point.distance(toSegmentFrom: points[index], to: points[index + 1]) <= radius {
                return true
            }
        }

        return false
    }
}

private extension DrawingPoint {
    func distance(to other: DrawingPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    func distance(toSegmentFrom start: DrawingPoint, to end: DrawingPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return distance(to: start)
        }

        let t = max(0, min(1, ((x - start.x) * dx + (y - start.y) * dy) / lengthSquared))
        let projection = DrawingPoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(to: projection)
    }
}
