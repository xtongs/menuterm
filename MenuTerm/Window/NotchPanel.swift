import AppKit

final class NotchPanel: NSPanel {
    var onLeftMouseDown: ((NSEvent) -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .mainMenu + 2
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
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

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
