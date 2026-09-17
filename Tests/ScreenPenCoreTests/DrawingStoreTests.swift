import Testing
@testable import ScreenPenCore

@Test func strokeLifecycleStoresFinishedStroke() {
    var store = DrawingStore()

    store.beginStroke(at: DrawingPoint(x: 10, y: 20), tool: .pen)
    store.appendPoint(DrawingPoint(x: 12, y: 25))
    store.appendPoint(DrawingPoint(x: 16, y: 29))
    store.endStroke()

    #expect(store.strokes.count == 1)
    #expect(store.strokes[0].tool == .pen)
    #expect(store.strokes[0].points.map(\.x) == [10, 12, 16])
}

@Test func undoAndClearOnlyAffectFinishedStrokes() {
    var store = DrawingStore()

    store.beginStroke(at: DrawingPoint(x: 1, y: 1), tool: .pen)
    store.endStroke()
    store.beginStroke(at: DrawingPoint(x: 2, y: 2), tool: .highlighter)
    store.endStroke()
    store.beginStroke(at: DrawingPoint(x: 3, y: 3), tool: .pen)

    store.undo()

    #expect(store.strokes.count == 1)
    #expect(store.draftStroke?.points.first == DrawingPoint(x: 3, y: 3))

    store.clear()

    #expect(store.strokes.isEmpty)
    #expect(store.draftStroke == nil)
}

@Test func eraserRemovesStrokesNearPoint() {
    var store = DrawingStore()

    store.beginStroke(at: DrawingPoint(x: 10, y: 10), tool: .pen)
    store.appendPoint(DrawingPoint(x: 40, y: 40))
    store.endStroke()
    store.beginStroke(at: DrawingPoint(x: 200, y: 200), tool: .highlighter)
    store.appendPoint(DrawingPoint(x: 260, y: 260))
    store.endStroke()

    store.erase(at: DrawingPoint(x: 25, y: 25), radius: 12)

    #expect(store.strokes.count == 1)
    #expect(store.strokes[0].tool == .highlighter)
}

@Test func eraserKeepsFarAwayStrokes() {
    var store = DrawingStore()

    store.beginStroke(at: DrawingPoint(x: 10, y: 10), tool: .pen)
    store.appendPoint(DrawingPoint(x: 40, y: 40))
    store.endStroke()

    store.erase(at: DrawingPoint(x: 200, y: 200), radius: 20)

    #expect(store.strokes.count == 1)
}

@Test func toolDefaultsFavorLectureReadability() {
    #expect(DrawingStyle.defaultStyle(for: .pen).lineWidth == 4)
    #expect(DrawingStyle.defaultStyle(for: .pen).opacity == 1)
    #expect(DrawingStyle.defaultStyle(for: .highlighter).lineWidth == 18)
    #expect(DrawingStyle.defaultStyle(for: .highlighter).opacity == 0.32)
}

@Test func drawingToolsUseDistinctArtworkBackedCursors() {
    let pen = ToolCursorPresentation.defaultPresentation(for: .pen)
    let highlighter = ToolCursorPresentation.defaultPresentation(for: .highlighter)
    let eraser = ToolCursorPresentation.defaultPresentation(for: .eraser)

    #expect(pen.assetName == "cursor-pen")
    #expect(highlighter.assetName == "cursor-highlighter")
    #expect(eraser.assetName == "cursor-eraser")
    #expect(pen.assetName != highlighter.assetName)
    #expect(highlighter.assetName != eraser.assetName)
    #expect(pen.pointSize == 32)
    #expect(highlighter.pointSize == 32)
    #expect(eraser.pointSize == 32)
    #expect(pen.hotSpot == DrawingPoint(x: 16, y: 16))
    #expect(highlighter.hotSpot == DrawingPoint(x: 16, y: 16))
    #expect(eraser.hotSpot == DrawingPoint(x: 16, y: 16))
}

@Test func drawingPreferencesKeepSeparatePenAndHighlighterColors() {
    var preferences = DrawingPreferences()
    let bluePen = DrawingPalette.penColors[2]
    let pinkHighlighter = DrawingPalette.highlighterColors[1]

    preferences.selectColor(bluePen, for: .pen)
    preferences.selectColor(pinkHighlighter, for: .highlighter)

    #expect(preferences.style(for: .pen).color == bluePen)
    #expect(preferences.style(for: .pen).lineWidth == 4)
    #expect(preferences.style(for: .pen).opacity == 1)
    #expect(preferences.style(for: .highlighter).color == pinkHighlighter)
    #expect(preferences.style(for: .highlighter).lineWidth == 18)
    #expect(preferences.style(for: .highlighter).opacity == 0.32)
}

@Test func customDrawingStyleIsStoredWithTheStroke() {
    var store = DrawingStore()
    let style = DrawingStyle(
        color: DrawingPalette.penColors[3],
        lineWidth: 4,
        opacity: 1
    )

    store.beginStroke(
        at: DrawingPoint(x: 4, y: 8),
        tool: .pen,
        style: style
    )
    store.appendPoint(DrawingPoint(x: 12, y: 16))
    store.endStroke()

    #expect(store.strokes.first?.style == style)
}

@Test func nativeZoomShortcutUsesTheMacAccessibilityZoomToggle() {
    #expect(SystemZoomShortcut.toggle.keyCode == 28)
    #expect(SystemZoomShortcut.toggle.modifiers == [.command, .option])
}

@Test func hotKeyMapperUsesControlOptionShortcuts() {
    let required: Set<HotKeyModifier> = [.control, .option]

    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 18, modifiers: required)) == .togglePen)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 19, modifiers: required)) == .toggleHighlighter)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 20, modifiers: required)) == .toggleSpotlight)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 21, modifiers: required)) == .toggleZoom)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 23, modifiers: required)) == .toggleEraser)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 50, modifiers: required)) == .clear)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 31, modifiers: required)) == .toggleHelpOverlay)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 53, modifiers: [])) == .deactivate)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 2, modifiers: required)) == nil)
    #expect(HotKeyMapper.command(for: HotKeyStroke(keyCode: 18, modifiers: [.control])) == nil)
}

@Test func lectureSessionTogglesExclusiveDrawingTools() {
    var session = LectureSession()
    var store = DrawingStore()

    session.perform(.togglePen, store: &store)
    #expect(session.activeTool == .pen)

    session.perform(.toggleHighlighter, store: &store)
    #expect(session.activeTool == .highlighter)

    session.perform(.toggleEraser, store: &store)
    #expect(session.activeTool == .eraser)

    session.perform(.toggleEraser, store: &store)
    #expect(session.activeTool == nil)
}

@Test func lectureSessionClearsFocusModesWhenDeactivated() {
    var session = LectureSession()
    var store = DrawingStore()

    session.perform(.togglePen, store: &store)
    session.perform(.toggleSpotlight, store: &store)
    session.perform(.deactivate, store: &store)

    #expect(session.activeTool == nil)
    #expect(session.isSpotlightEnabled == false)
}

@Test func lectureSessionTogglesHelpOverlay() {
    var session = LectureSession()
    var store = DrawingStore()

    #expect(session.isHelpOverlayVisible == true)

    session.perform(.toggleHelpOverlay, store: &store)
    #expect(session.isHelpOverlayVisible == false)

    session.perform(.toggleHelpOverlay, store: &store)
    #expect(session.isHelpOverlayVisible == true)
}

@Test func compactPanelGridUsesEqualMarginsAndSpacing() {
    #expect(CompactPanelLayout.horizontalInset == 18)
    #expect(CompactPanelLayout.columnWidth == 96)
    #expect(CompactPanelLayout.columnX(0) == 18)
    #expect(CompactPanelLayout.columnX(1) == 122)
    #expect(CompactPanelLayout.columnX(2) == 226)
    #expect(CompactPanelLayout.columnMaxX(2) == 322)

    let leftMargin = CompactPanelLayout.columnX(0)
    let rightMargin = CompactPanelLayout.panelWidth - CompactPanelLayout.columnMaxX(2)
    #expect(leftMargin == rightMargin)
}

@Test func compactPanelSwatchesAlignWithTheGridTrailingEdge() {
    let startX = CompactPanelLayout.trailingAlignedRowStart(
        itemCount: 6,
        itemWidth: 27,
        gap: 8
    )

    #expect(startX == 120)
    #expect(startX + (6 * 27) + (5 * 8) == CompactPanelLayout.contentMaxX)
}

@Test func nativeZoomCommandReleasesOverlayInputBeforeMacOSZooms() {
    var session = LectureSession()
    var store = DrawingStore()

    session.perform(.togglePen, store: &store)
    session.perform(.toggleSpotlight, store: &store)
    session.perform(.toggleZoom, store: &store)

    #expect(session.activeTool == nil)
    #expect(session.isSpotlightEnabled == false)
}
