import AppKit
import ScreenPenCore

@MainActor
final class ToolPaletteWindow: NSPanel {
    private let panelSize = NSSize(
        width: CGFloat(CompactPanelLayout.panelWidth),
        height: 238
    )
    private let paletteView: ToolPaletteView

    init(
        state: AppState,
        commandHandler: @escaping (LectureCommand) -> Void,
        zoomHandler: @escaping () -> Void,
        zoomSettingsHandler: @escaping () -> Void
    ) {
        paletteView = ToolPaletteView(
            frame: NSRect(origin: .zero, size: panelSize),
            state: state,
            commandHandler: commandHandler,
            zoomHandler: zoomHandler,
            zoomSettingsHandler: zoomSettingsHandler
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
        contentView = paletteView
        placeBelow(nil)
    }

    func refresh(zoomStatus: String) {
        paletteView.refresh(zoomStatus: zoomStatus)
    }

    func showNotice(_ text: String) {
        paletteView.showNotice(text)
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            placeOnVisibleScreenIfNeeded()
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    func placeBelow(_ anchorWindow: NSWindow?) {
        guard let screen = anchorWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let rightEdge = anchorWindow?.frame.maxX ?? visibleFrame.maxX - 18
        let proposedY = (anchorWindow?.frame.minY ?? visibleFrame.maxY) - panelSize.height - 8

        setFrameOrigin(NSPoint(
            x: min(
                max(visibleFrame.minX + 12, rightEdge - panelSize.width),
                visibleFrame.maxX - panelSize.width - 12
            ),
            y: max(visibleFrame.minY + 12, proposedY)
        ))
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    private func placeOnVisibleScreenIfNeeded() {
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) else { return }
        placeBelow(nil)
    }
}

@MainActor
private final class ToolPaletteView: NSView {
    private enum Layout {
        static let horizontalInset = CGFloat(CompactPanelLayout.horizontalInset)
        static let contentMaxX = CGFloat(CompactPanelLayout.contentMaxX)
        static let columnWidth = CGFloat(CompactPanelLayout.columnWidth)
        static let swatchSize: CGFloat = 27
        static let swatchGap: CGFloat = 8
        static let swatchStartX = CGFloat(
            CompactPanelLayout.trailingAlignedRowStart(
                itemCount: 6,
                itemWidth: Double(swatchSize),
                gap: Double(swatchGap)
            )
        )
    }

    private enum ActionTag: Int {
        case pen = 1
        case highlighter
        case eraser
        case spotlight
        case zoom
        case deactivate
        case undo
        case clear
        case zoomSettings
    }

    private let state: AppState
    private let commandHandler: (LectureCommand) -> Void
    private let zoomHandler: () -> Void
    private let zoomSettingsHandler: () -> Void

    private let titleLabel = NSTextField(labelWithString: "ScreenPen 도구")
    private let colorLabel = NSTextField(labelWithString: "펜 색상")
    private let statusLabel = NSTextField(labelWithString: "")
    private let hideButton = NSButton(title: "", target: nil, action: nil)
    private var toolButtons: [ActionTag: PaletteToolButton] = [:]
    private var swatchButtons: [ColorSwatchButton] = []
    private var latestZoomStatus = ""
    private var hasTransientNotice = false

    private let gridFrames: [(ActionTag, CGFloat, CGFloat)] = [
        (.pen, CGFloat(CompactPanelLayout.columnX(0)), 42),
        (.highlighter, CGFloat(CompactPanelLayout.columnX(1)), 42),
        (.eraser, CGFloat(CompactPanelLayout.columnX(2)), 42),
        (.spotlight, CGFloat(CompactPanelLayout.columnX(0)), 90),
        (.zoom, CGFloat(CompactPanelLayout.columnX(1)), 90),
        (.deactivate, CGFloat(CompactPanelLayout.columnX(2)), 90),
        (.undo, CGFloat(CompactPanelLayout.columnX(0)), 138),
        (.clear, CGFloat(CompactPanelLayout.columnX(1)), 138),
        (.zoomSettings, CGFloat(CompactPanelLayout.columnX(2)), 138)
    ]

    init(
        frame frameRect: NSRect,
        state: AppState,
        commandHandler: @escaping (LectureCommand) -> Void,
        zoomHandler: @escaping () -> Void,
        zoomSettingsHandler: @escaping () -> Void
    ) {
        self.state = state
        self.commandHandler = commandHandler
        self.zoomHandler = zoomHandler
        self.zoomSettingsHandler = zoomSettingsHandler
        super.init(frame: frameRect)

        wantsLayer = true
        setupLabels()
        setupToolButtons()
        setupColorSwatches()
        setupHideButton()
        refresh(zoomStatus: "")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func layout() {
        super.layout()

        titleLabel.frame = NSRect(
            x: Layout.horizontalInset,
            y: 12,
            width: 106,
            height: 20
        )
        statusLabel.frame = NSRect(x: 124, y: 13, width: 166, height: 18)
        hideButton.frame = NSRect(x: 294, y: 8, width: 28, height: 28)

        for (tag, x, y) in gridFrames {
            toolButtons[tag]?.frame = NSRect(
                x: x,
                y: y,
                width: Layout.columnWidth,
                height: 40
            )
        }

        colorLabel.frame = NSRect(
            x: Layout.horizontalInset,
            y: 203,
            width: 86,
            height: 18
        )
        for (index, button) in swatchButtons.enumerated() {
            button.frame = NSRect(
                x: Layout.swatchStartX + CGFloat(index) * (Layout.swatchSize + Layout.swatchGap),
                y: 198,
                width: Layout.swatchSize,
                height: Layout.swatchSize
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let card = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 2, dy: 2),
            xRadius: 14,
            yRadius: 14
        )
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        card.fill()
        NSColor.separatorColor.withAlphaComponent(0.8).setStroke()
        card.lineWidth = 1
        card.stroke()

        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: Layout.horizontalInset, y: 35))
        separator.line(to: NSPoint(x: Layout.contentMaxX, y: 35))
        NSColor.separatorColor.setStroke()
        separator.lineWidth = 1
        separator.stroke()

        let colorSeparator = NSBezierPath()
        colorSeparator.move(to: NSPoint(x: Layout.horizontalInset, y: 190))
        colorSeparator.line(to: NSPoint(x: Layout.contentMaxX, y: 190))
        NSColor.separatorColor.setStroke()
        colorSeparator.lineWidth = 1
        colorSeparator.stroke()
    }

    func refresh(zoomStatus: String) {
        latestZoomStatus = zoomStatus
        toolButtons[.pen]?.isSelected = state.activeTool == .pen
        toolButtons[.highlighter]?.isSelected = state.activeTool == .highlighter
        toolButtons[.eraser]?.isSelected = state.activeTool == .eraser
        toolButtons[.spotlight]?.isSelected = state.session.isSpotlightEnabled
        toolButtons[.zoom]?.isSelected = false
        toolButtons[.deactivate]?.isSelected = false
        toolButtons[.undo]?.isSelected = false
        toolButtons[.clear]?.isSelected = false
        toolButtons[.zoomSettings]?.isSelected = false

        rebuildColorSwatches()
        if !hasTransientNotice {
            statusLabel.stringValue = zoomStatus
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    func showNotice(_ text: String) {
        hasTransientNotice = true
        statusLabel.stringValue = text
        statusLabel.textColor = .controlAccentColor

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            hasTransientNotice = false
            statusLabel.stringValue = latestZoomStatus
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    private func setupLabels() {
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        colorLabel.font = .systemFont(ofSize: 11, weight: .medium)
        colorLabel.textColor = .secondaryLabelColor

        statusLabel.font = .systemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        statusLabel.lineBreakMode = .byTruncatingHead

        [titleLabel, colorLabel, statusLabel].forEach(addSubview)
    }

    private func setupToolButtons() {
        addToolButton(.pen, title: "펜", symbol: "pencil.tip")
        addToolButton(.highlighter, title: "형광펜", symbol: "highlighter")
        addToolButton(.eraser, title: "지우개", symbol: "eraser")
        addToolButton(.spotlight, title: "스포트", symbol: "flashlight.on.fill")
        addToolButton(.zoom, title: "맥 확대", symbol: "plus.magnifyingglass")
        addToolButton(.deactivate, title: "도구 끄기", symbol: "xmark.circle")
        addToolButton(.undo, title: "되돌림", symbol: "arrow.uturn.backward")
        addToolButton(.clear, title: "전체 지움", symbol: "trash")
        addToolButton(.zoomSettings, title: "확대 설정", symbol: "gearshape")
    }

    private func addToolButton(_ tag: ActionTag, title: String, symbol: String) {
        let button = PaletteToolButton(title: title, symbolName: symbol)
        button.tag = tag.rawValue
        button.target = self
        button.action = #selector(toolButtonPressed(_:))
        button.toolTip = tooltip(for: tag)
        toolButtons[tag] = button
        addSubview(button)
    }

    private func setupColorSwatches() {
        rebuildColorSwatches()
    }

    private func rebuildColorSwatches() {
        swatchButtons.forEach { $0.removeFromSuperview() }
        swatchButtons.removeAll()

        let tool = state.colorTargetTool
        colorLabel.stringValue = tool == .highlighter ? "형광 색상" : "펜 색상"
        let selected = state.drawingPreferences.style(for: tool).color

        for (index, color) in DrawingPalette.colors(for: tool).enumerated() {
            let button = ColorSwatchButton(color: color)
            button.tag = index
            button.isSelected = color == selected
            button.target = self
            button.action = #selector(colorSwatchPressed(_:))
            button.toolTip = "\(colorLabel.stringValue) \(index + 1)"
            swatchButtons.append(button)
            addSubview(button)
        }
        needsLayout = true
    }

    private func setupHideButton() {
        hideButton.target = self
        hideButton.action = #selector(hidePalette)
        hideButton.isBordered = false
        hideButton.image = NSImage(
            systemSymbolName: "xmark",
            accessibilityDescription: "도움말과 도구 패널 숨기기"
        )
        hideButton.contentTintColor = .secondaryLabelColor
        hideButton.toolTip = "도움말과 도구 패널 숨기기"
        addSubview(hideButton)
    }

    @objc private func toolButtonPressed(_ sender: NSButton) {
        guard let tag = ActionTag(rawValue: sender.tag) else { return }

        switch tag {
        case .pen:
            commandHandler(.togglePen)
        case .highlighter:
            commandHandler(.toggleHighlighter)
        case .eraser:
            commandHandler(.toggleEraser)
        case .spotlight:
            commandHandler(.toggleSpotlight)
        case .zoom:
            zoomHandler()
        case .deactivate:
            commandHandler(.deactivate)
        case .undo:
            commandHandler(.undo)
        case .clear:
            commandHandler(.clear)
        case .zoomSettings:
            zoomSettingsHandler()
        }
    }

    @objc private func colorSwatchPressed(_ sender: ColorSwatchButton) {
        let tool = state.colorTargetTool
        let colors = DrawingPalette.colors(for: tool)
        guard colors.indices.contains(sender.tag) else { return }
        state.selectColor(colors[sender.tag], for: tool)
    }

    @objc private func hidePalette() {
        commandHandler(.toggleHelpOverlay)
    }

    private func tooltip(for tag: ActionTag) -> String {
        switch tag {
        case .pen:
            "펜 · Control + Option + 1"
        case .highlighter:
            "형광펜 · Control + Option + 2"
        case .eraser:
            "지우개 · Control + Option + 5"
        case .spotlight:
            "스포트라이트 · Control + Option + 3"
        case .zoom:
            "macOS 내장 확대 · Control + Option + 4"
        case .deactivate:
            "도구 끄기 · Esc"
        case .undo:
            "마지막 획 되돌리기"
        case .clear:
            "화면의 모든 잉크 지우기"
        case .zoomSettings:
            "macOS 손쉬운 사용 > 확대 설정 열기"
        }
    }
}

@MainActor
private final class PaletteToolButton: NSButton {
    var isSelected = false {
        didSet { updateAppearance() }
    }

    init(title: String, symbolName: String) {
        super.init(frame: .zero)

        self.title = title
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        imagePosition = .imageLeading
        imageScaling = .scaleProportionallyDown
        isBordered = false
        font = .systemFont(ofSize: 10, weight: .medium)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet { updateAppearance() }
    }

    private func updateAppearance() {
        let active = isSelected || isHighlighted
        layer?.backgroundColor = active
            ? NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            : NSColor.controlBackgroundColor.withAlphaComponent(0.20).cgColor
        layer?.borderColor = active
            ? NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
            : NSColor.separatorColor.withAlphaComponent(0.75).cgColor
        contentTintColor = active ? .controlAccentColor : .labelColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: active ? NSColor.controlAccentColor : NSColor.labelColor
            ]
        )
    }
}

@MainActor
private final class ColorSwatchButton: NSButton {
    let color: RGBAColor
    var isSelected = false {
        didSet { updateAppearance() }
    }

    init(color: RGBAColor) {
        self.color = color
        super.init(frame: .zero)
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 13.5
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet { updateAppearance() }
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor(rgba: color).cgColor
        layer?.borderWidth = isSelected ? 3 : 1
        layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor
        alphaValue = isHighlighted ? 0.72 : 1
    }
}

private extension NSColor {
    convenience init(rgba: RGBAColor) {
        self.init(
            calibratedRed: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            alpha: rgba.alpha
        )
    }
}
