import AppKit

final class NotchPanel: NSPanel {
    static let panelLevel: NSWindow.Level = .mainMenu - 1
    static let settingsLevel = NSWindow.Level(rawValue: panelLevel.rawValue + 1)

    var onLeftMouseDown: ((NSEvent) -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = Self.panelLevel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        hidesOnDeactivate = false
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            onLeftMouseDown?(event)
        }
        super.sendEvent(event)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
