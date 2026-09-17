public struct ToolCursorPresentation: Equatable, Sendable {
    public var assetName: String?
    public var pointSize: Double
    public var hotSpot: DrawingPoint

    public init(assetName: String?, pointSize: Double, hotSpot: DrawingPoint) {
        self.assetName = assetName
        self.pointSize = pointSize
        self.hotSpot = hotSpot
    }

    public static func defaultPresentation(for tool: DrawingTool) -> ToolCursorPresentation {
        switch tool {
        case .pen:
            ToolCursorPresentation(
                assetName: "cursor-pen",
                pointSize: 32,
                hotSpot: DrawingPoint(x: 16, y: 16)
            )
        case .highlighter:
            ToolCursorPresentation(
                assetName: "cursor-highlighter",
                pointSize: 32,
                hotSpot: DrawingPoint(x: 16, y: 16)
            )
        case .eraser:
            ToolCursorPresentation(
                assetName: "cursor-eraser",
                pointSize: 32,
                hotSpot: DrawingPoint(x: 16, y: 16)
            )
        }
    }
}

public enum ZoomDefaults {
    public static let activationScale = 2.0
    public static let maximumScale = 6.0
}
