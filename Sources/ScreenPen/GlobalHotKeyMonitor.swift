import AppKit
import Carbon
import ScreenPenCore

final class GlobalHotKeyMonitor {
    private let commandHandler: @MainActor @Sendable (LectureCommand) -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var deactivateHotKeyRef: EventHotKeyRef?
    private var localMonitor: Any?
    private let hotKeySignature: OSType = 0x4C496E6B

    init(commandHandler: @escaping @MainActor @Sendable (LectureCommand) -> Void) {
        self.commandHandler = commandHandler
    }

    func start() {
        installCarbonHotKeyHandler()
        registerCarbonHotKeys()

        let handler = commandHandler
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            Self.performLocalCommand(from: event, commandHandler: handler) ? nil : event
        }
    }

    func stop() {
        setDeactivateHotKeyEnabled(false)

        for hotKeyRef in hotKeyRefs {
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
        }
        hotKeyRefs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
    }

    func setDeactivateHotKeyEnabled(_ isEnabled: Bool) {
        if isEnabled {
            guard deactivateHotKeyRef == nil else { return }

            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 8)
            let status = RegisterEventHotKey(
                UInt32(kVK_Escape),
                0,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                deactivateHotKeyRef = hotKeyRef
            } else {
                NSLog("ScreenPen could not register Escape: %d", status)
            }
        } else if let deactivateHotKeyRef {
            UnregisterEventHotKey(deactivateHotKeyRef)
            self.deactivateHotKeyRef = nil
        }
    }

    private func installCarbonHotKeyHandler() {
        guard eventHandler == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                monitor.performCommand(for: hotKeyID.id)
                return noErr
            },
            1,
            &eventSpec,
            userData,
            &eventHandler
        )
        if installStatus != noErr {
            NSLog("ScreenPen could not install its hot-key handler: %d", installStatus)
        }
    }

    private func registerCarbonHotKeys() {
        let modifierFlags = UInt32(controlKey | optionKey)
        let hotKeys: [(UInt32, UInt32)] = [
            (1, UInt32(kVK_ANSI_1)),
            (2, UInt32(kVK_ANSI_2)),
            (3, UInt32(kVK_ANSI_3)),
            (4, UInt32(kVK_ANSI_4)),
            (5, UInt32(kVK_ANSI_5)),
            (6, UInt32(kVK_ANSI_Grave)),
            (7, UInt32(kVK_ANSI_O))
        ]

        for (id, keyCode) in hotKeys {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: id)
            let status = RegisterEventHotKey(
                keyCode,
                modifierFlags,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            if status == noErr {
                hotKeyRefs.append(hotKeyRef)
            } else {
                NSLog("ScreenPen could not register hot key %d: %d", id, status)
            }
        }
    }

    private func performCommand(for id: UInt32) {
        let command: LectureCommand?

        switch id {
        case 1:
            command = .togglePen
        case 2:
            command = .toggleHighlighter
        case 3:
            command = .toggleSpotlight
        case 4:
            command = .toggleZoom
        case 5:
            command = .toggleEraser
        case 6:
            command = .clear
        case 7:
            command = .toggleHelpOverlay
        case 8:
            command = .deactivate
        default:
            command = nil
        }

        guard let command else { return }
        DispatchQueue.main.async { [commandHandler] in
            commandHandler(command)
        }
    }

    @discardableResult
    private static func performLocalCommand(
        from event: NSEvent,
        commandHandler: @escaping @MainActor @Sendable (LectureCommand) -> Void
    ) -> Bool {
        guard event.keyCode == 53 else { return false }

        DispatchQueue.main.async {
            commandHandler(.deactivate)
        }
        return true
    }
}
