import AppKit

final class HelpPanelWindow: NSPanel {
    private let panelSize = NSSize(width: 340, height: 248)
    private var dragStartMouseLocation: NSPoint?
    private var dragStartFrameOrigin: NSPoint?
    var onFrameChanged: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        contentView = HelpPanelView(frame: NSRect(origin: .zero, size: panelSize))
        placeAtTopRight()
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    func placeAtTopRight() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        setFrameOrigin(NSPoint(
            x: visibleFrame.maxX - panelSize.width - 18,
            y: visibleFrame.maxY - panelSize.height - 18
        ))
        onFrameChanged?()
    }

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartFrameOrigin = frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartMouseLocation, let dragStartFrameOrigin else { return }
        let current = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(
            x: dragStartFrameOrigin.x + current.x - dragStartMouseLocation.x,
            y: dragStartFrameOrigin.y + current.y - dragStartMouseLocation.y
        ))
        onFrameChanged?()
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        dragStartFrameOrigin = nil
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class HelpPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        card.fill()
        NSColor.separatorColor.withAlphaComponent(0.8).setStroke()
        card.lineWidth = 1
        card.stroke()

        drawText(
            "ScreenPen 단축키",
            in: NSRect(x: 18, y: 212, width: 304, height: 22),
            font: .systemFont(ofSize: 15, weight: .semibold),
            color: .labelColor
        )

        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: 18, y: 204))
        separator.line(to: NSPoint(x: 322, y: 204))
        NSColor.separatorColor.setStroke()
        separator.lineWidth = 1
        separator.stroke()

        let rows = [
            ("⌃⌥1", "펜"),
            ("⌃⌥2", "형광펜"),
            ("⌃⌥5", "지우개"),
            ("⌃⌥3", "스포트라이트"),
            ("⌃⌥4", "macOS 내장 확대"),
            ("⌃⌥~", "전체 지우기"),
            ("⌃⌥O", "도움말 켜기/끄기"),
            ("Esc", "도구 끄기")
        ]

        for (index, row) in rows.enumerated() {
            let y = 177 - CGFloat(index) * 19
            drawText(
                row.0,
                in: NSRect(x: 18, y: y, width: 62, height: 17),
                font: .monospacedSystemFont(ofSize: 11, weight: .medium),
                color: .secondaryLabelColor,
                alignment: .right
            )
            drawText(
                row.1,
                in: NSRect(x: 94, y: y, width: 220, height: 17),
                font: .systemFont(ofSize: 11, weight: .regular),
                color: .labelColor
            )
        }

        drawText(
            "색상은 아래 도구 팔레트의 원을 누르면 바뀝니다.",
            in: NSRect(x: 18, y: 12, width: 304, height: 17),
            font: .systemFont(ofSize: 10, weight: .regular),
            color: .tertiaryLabelColor
        )
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        text.draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}
