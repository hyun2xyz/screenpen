import AppKit
import ScreenPenCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem?
    private var overlayWindows: [OverlayWindow] = []
    private var helpPanelWindow: HelpPanelWindow?
    private var toolPaletteWindow: ToolPaletteWindow?
    private var hotKeyMonitor: GlobalHotKeyMonitor?
    private var cursorTimer: Timer?
    private let systemZoom = MacSystemZoomController()

    private weak var penItem: NSMenuItem?
    private weak var highlighterItem: NSMenuItem?
    private weak var eraserItem: NSMenuItem?
    private weak var spotlightItem: NSMenuItem?
    private weak var helpItem: NSMenuItem?
    private weak var paletteItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        rebuildOverlayWindows()
        setupHelpPanel()
        setupToolPalette()
        hotKeyMonitor = GlobalHotKeyMonitor { [weak self] command in
            self?.perform(command)
        }
        hotKeyMonitor?.start()
        startCursorTimer()

        state.addObserver { [weak self] in
            self?.stateDidChange()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        cursorTimer?.invalidate()
        hotKeyMonitor?.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshToolPalette()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: "ScreenPen") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "✎"
        }

        let menu = NSMenu()
        let palette = menu.addItem(
            withTitle: "도움말·도구 패널 보기",
            action: #selector(showToolPalette),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        let pen = menu.addItem(withTitle: "펜    ⌃⌥1", action: #selector(togglePen), keyEquivalent: "")
        let highlighter = menu.addItem(withTitle: "형광펜    ⌃⌥2", action: #selector(toggleHighlighter), keyEquivalent: "")
        let eraser = menu.addItem(withTitle: "지우개    ⌃⌥5", action: #selector(toggleEraser), keyEquivalent: "")
        menu.addItem(.separator())
        let spotlight = menu.addItem(withTitle: "스포트라이트    ⌃⌥3", action: #selector(toggleSpotlight), keyEquivalent: "")
        menu.addItem(withTitle: "macOS 내장 확대    ⌃⌥4", action: #selector(toggleZoom), keyEquivalent: "")
        menu.addItem(withTitle: "macOS 확대 설정 열기", action: #selector(openZoomSettings), keyEquivalent: "")
        let help = menu.addItem(withTitle: "단축키 도움말    ⌃⌥O", action: #selector(toggleHelp), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "되돌리기", action: #selector(undo), keyEquivalent: "")
        menu.addItem(withTitle: "전체 지우기    ⌃⌥~", action: #selector(clear), keyEquivalent: "")
        menu.addItem(withTitle: "도구 끄기    Esc", action: #selector(deactivate), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "ScreenPen 종료", action: #selector(quit), keyEquivalent: "")

        menu.items.forEach { $0.target = self }
        item.menu = menu

        statusItem = item
        penItem = pen
        highlighterItem = highlighter
        eraserItem = eraser
        spotlightItem = spotlight
        helpItem = help
        paletteItem = palette
        refreshMenu()
    }

    private func rebuildOverlayWindows() {
        overlayWindows.forEach { $0.close() }
        overlayWindows = NSScreen.screens.map { OverlayWindow(screen: $0, state: state) }
        refreshOverlayInteractivity()
    }

    private func setupHelpPanel() {
        helpPanelWindow = HelpPanelWindow()
        helpPanelWindow?.onFrameChanged = { [weak self] in
            self?.toolPaletteWindow?.placeBelow(self?.helpPanelWindow)
        }
        refreshHelpPanel()
    }

    private func setupToolPalette() {
        toolPaletteWindow = ToolPaletteWindow(
            state: state,
            commandHandler: { [weak self] command in
                self?.perform(command)
            },
            zoomHandler: { [weak self] in
                self?.toggleNativeZoom()
            },
            zoomSettingsHandler: { [weak self] in
                self?.systemZoom.openZoomSettings()
            }
        )
        toolPaletteWindow?.placeBelow(helpPanelWindow)
        refreshHelpPanel()
        refreshToolPalette()
    }

    private func refreshOverlayInteractivity() {
        let shouldCapturePointer = state.activeTool != nil
        overlayWindows.forEach { $0.setInputCapture(shouldCapturePointer) }
    }

    private func stateDidChange() {
        hotKeyMonitor?.setDeactivateHotKeyEnabled(
            state.activeTool != nil || state.session.isSpotlightEnabled
        )
        refreshMenu()
        refreshOverlayInteractivity()
        refreshHelpPanel()
        refreshToolPalette()
    }

    private func refreshHelpPanel() {
        let isVisible = state.session.isHelpOverlayVisible
        helpPanelWindow?.setVisible(isVisible)
        toolPaletteWindow?.setVisible(isVisible)
    }

    private func refreshMenu() {
        penItem?.state = state.activeTool == .pen ? .on : .off
        highlighterItem?.state = state.activeTool == .highlighter ? .on : .off
        eraserItem?.state = state.activeTool == .eraser ? .on : .off
        spotlightItem?.state = state.session.isSpotlightEnabled ? .on : .off
        helpItem?.state = state.session.isHelpOverlayVisible ? .on : .off
        paletteItem?.state = state.session.isHelpOverlayVisible ? .on : .off
    }

    private func refreshToolPalette() {
        toolPaletteWindow?.refresh(zoomStatus: systemZoom.readinessText)
    }

    private func perform(_ command: LectureCommand) {
        if command == .toggleZoom {
            toggleNativeZoom()
        } else {
            state.perform(command)
        }
    }

    private func toggleNativeZoom() {
        state.perform(.toggleZoom)

        switch systemZoom.toggle() {
        case .triggered:
            toolPaletteWindow?.showNotice("macOS 확대를 전환했어요 · ⌥⌘8")
        case .keyboardShortcutsDisabled:
            toolPaletteWindow?.showNotice("확대 설정에서 ‘키보드 단축키’를 켜 주세요")
        case .accessibilityPermissionRequired:
            toolPaletteWindow?.showNotice("손쉬운 사용에서 ScreenPen를 허용해 주세요")
        case .eventCreationFailed:
            toolPaletteWindow?.showNotice("확대 단축키를 보내지 못했어요")
        }
    }

    private func startCursorTimer() {
        cursorTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 15.0,
            target: self,
            selector: #selector(cursorTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func cursorTimerFired(_ timer: Timer) {
        tickCursor()
    }

    private func tickCursor() {
        if state.session.isSpotlightEnabled {
            state.updateCursor(location: NSEvent.mouseLocation)
        }
    }

    @objc private func screenParametersDidChange() {
        rebuildOverlayWindows()
        helpPanelWindow?.placeAtTopRight()
        toolPaletteWindow?.placeBelow(helpPanelWindow)
    }

    @objc private func togglePen() {
        perform(.togglePen)
    }

    @objc private func toggleHighlighter() {
        perform(.toggleHighlighter)
    }

    @objc private func toggleEraser() {
        perform(.toggleEraser)
    }

    @objc private func toggleSpotlight() {
        perform(.toggleSpotlight)
    }

    @objc private func toggleZoom() {
        perform(.toggleZoom)
    }

    @objc private func toggleHelp() {
        perform(.toggleHelpOverlay)
    }

    @objc private func undo() {
        perform(.undo)
    }

    @objc private func clear() {
        perform(.clear)
    }

    @objc private func deactivate() {
        perform(.deactivate)
    }

    @objc private func showToolPalette() {
        if state.session.isHelpOverlayVisible {
            refreshHelpPanel()
            refreshMenu()
        } else {
            perform(.toggleHelpOverlay)
        }
    }

    @objc private func openZoomSettings() {
        systemZoom.openZoomSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
