public enum CompactPanelLayout {
    public static let panelWidth = 340.0
    public static let horizontalInset = 18.0
    public static let columnCount = 3
    public static let columnGap = 8.0

    public static var contentMaxX: Double {
        panelWidth - horizontalInset
    }

    public static var columnWidth: Double {
        let totalGap = Double(columnCount - 1) * columnGap
        return (panelWidth - (horizontalInset * 2) - totalGap) / Double(columnCount)
    }

    public static func columnX(_ index: Int) -> Double {
        precondition((0..<columnCount).contains(index))
        return horizontalInset + (Double(index) * (columnWidth + columnGap))
    }

    public static func columnMaxX(_ index: Int) -> Double {
        columnX(index) + columnWidth
    }

    public static func trailingAlignedRowStart(
        itemCount: Int,
        itemWidth: Double,
        gap: Double
    ) -> Double {
        precondition(itemCount > 0)
        let rowWidth = (Double(itemCount) * itemWidth) + (Double(itemCount - 1) * gap)
        return contentMaxX - rowWidth
    }
}
