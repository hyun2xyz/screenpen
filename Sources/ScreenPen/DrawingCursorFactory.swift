import AppKit
import ScreenPenCore

@MainActor
enum DrawingCursorFactory {
    private static let pen = makeCursor(for: .pen)
    private static let highlighter = makeCursor(for: .highlighter)
    private static let eraser = makeCursor(for: .eraser)

    static func cursor(for tool: DrawingTool) -> NSCursor {
        switch tool {
        case .pen:
            pen
        case .highlighter:
            highlighter
        case .eraser:
            eraser
        }
    }

    private static func makeCursor(for tool: DrawingTool) -> NSCursor {
        let presentation = ToolCursorPresentation.defaultPresentation(for: tool)
        guard
            let assetName = presentation.assetName,
            let url = AppResources.url(
                forResource: assetName,
                withExtension: "svg",
                subdirectory: "Cursors"
            ),
            let image = NSImage(contentsOf: url)
        else {
            return .crosshair
        }

        image.size = NSSize(width: presentation.pointSize, height: presentation.pointSize)
        return NSCursor(
            image: image,
            hotSpot: NSPoint(x: presentation.hotSpot.x, y: presentation.hotSpot.y)
        )
    }
}
