public enum DrawingPalette {
    public static let penColors: [RGBAColor] = [
        RGBAColor(red: 1.00, green: 0.36, blue: 0.54, alpha: 1),
        RGBAColor(red: 1.00, green: 0.32, blue: 0.29, alpha: 1),
        RGBAColor(red: 0.29, green: 0.66, blue: 1.00, alpha: 1),
        RGBAColor(red: 0.17, green: 0.79, blue: 0.66, alpha: 1),
        RGBAColor(red: 0.55, green: 0.44, blue: 0.97, alpha: 1),
        RGBAColor(red: 0.14, green: 0.18, blue: 0.29, alpha: 1)
    ]

    public static let highlighterColors: [RGBAColor] = [
        RGBAColor(red: 1.00, green: 0.85, blue: 0.30, alpha: 1),
        RGBAColor(red: 1.00, green: 0.55, blue: 0.80, alpha: 1),
        RGBAColor(red: 0.40, green: 0.85, blue: 1.00, alpha: 1),
        RGBAColor(red: 0.45, green: 0.89, blue: 0.65, alpha: 1),
        RGBAColor(red: 0.72, green: 0.61, blue: 1.00, alpha: 1),
        RGBAColor(red: 1.00, green: 0.67, blue: 0.40, alpha: 1)
    ]

    public static func colors(for tool: DrawingTool) -> [RGBAColor] {
        switch tool {
        case .pen:
            penColors
        case .highlighter:
            highlighterColors
        case .eraser:
            []
        }
    }
}

public struct DrawingPreferences: Equatable, Sendable {
    public private(set) var penColor: RGBAColor
    public private(set) var highlighterColor: RGBAColor

    public init(
        penColor: RGBAColor = DrawingPalette.penColors[0],
        highlighterColor: RGBAColor = DrawingPalette.highlighterColors[0]
    ) {
        self.penColor = penColor
        self.highlighterColor = highlighterColor
    }

    public mutating func selectColor(_ color: RGBAColor, for tool: DrawingTool) {
        switch tool {
        case .pen:
            penColor = color
        case .highlighter:
            highlighterColor = color
        case .eraser:
            break
        }
    }

    public func style(for tool: DrawingTool) -> DrawingStyle {
        var style = DrawingStyle.defaultStyle(for: tool)

        switch tool {
        case .pen:
            style.color = penColor
        case .highlighter:
            style.color = highlighterColor
        case .eraser:
            break
        }

        return style
    }
}
