import AppKit
import ApplicationServices
import CoreFoundation
import ScreenPenCore

enum MacSystemZoomResult: Equatable {
    case triggered
    case keyboardShortcutsDisabled
    case accessibilityPermissionRequired
    case eventCreationFailed
}

@MainActor
final class MacSystemZoomController {
    private let universalAccessDomain = "com.apple.universalaccess" as CFString
    private let zoomHotkeysKey = "closeViewHotkeysEnabled" as CFString

    var readinessText: String {
        if !isKeyboardZoomEnabled {
            return "확대 설정이 필요해요"
        }
        if !AXIsProcessTrusted() {
            return "손쉬운 사용 권한이 필요해요"
        }
        return "macOS 내장 확대 준비됨"
    }

    var isKeyboardZoomEnabled: Bool {
        CFPreferencesAppSynchronize(universalAccessDomain)
        let value = CFPreferencesCopyValue(
            zoomHotkeysKey,
            universalAccessDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        return (value as? NSNumber)?.boolValue ?? false
    }

    func toggle() -> MacSystemZoomResult {
        guard isKeyboardZoomEnabled else {
            openZoomSettings()
            return .keyboardShortcutsDisabled
        }

        guard AXIsProcessTrusted() else {
            requestAccessibilityPermission()
            return .accessibilityPermissionRequired
        }

        let shortcut = SystemZoomShortcut.toggle
        guard
            let keyDown = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: false
            )
        else {
            return .eventCreationFailed
        }

        let flags = eventFlags(for: shortcut.modifiers)
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return .triggered
    }

    func openZoomSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Seeing_Zoom"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openAccessibilityPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func requestAccessibilityPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func eventFlags(for modifiers: Set<HotKeyModifier>) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
        }
        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
        }
        if modifiers.contains(.control) {
            flags.insert(.maskControl)
        }
        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
        }
        return flags
    }
}
