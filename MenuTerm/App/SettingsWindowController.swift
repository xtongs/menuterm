import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let hostingController: NSHostingController<SettingsView>

    init() {
        hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.level = NotchPanel.settingsLevel
        window.isMovableByWindowBackground = false
        window.center()

        super.init(window: window)
        shouldCascadeWindows = true
        updateWindowSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        guard let window else { return }
        updateWindowSize()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func updateWindowSize() {
        guard let window else { return }

        hostingController.view.layoutSubtreeIfNeeded()

        let fittingSize = hostingController.view.fittingSize
        let contentSize = NSSize(
            width: max(520, fittingSize.width),
            height: max(320, fittingSize.height)
        )

        window.contentMinSize = contentSize
        window.setContentSize(contentSize)
    }
}
