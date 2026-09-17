public struct SystemZoomShortcut: Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Set<HotKeyModifier>

    public init(keyCode: UInt16, modifiers: Set<HotKeyModifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let toggle = SystemZoomShortcut(
        keyCode: 28,
        modifiers: [.command, .option]
    )
}
