import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var windowController: NotchWindowController?
    private var hotkeyManager: HotkeyManager?
    private var settingsWindowController: SettingsWindowController?
    private var localKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)

        windowController = NotchWindowController()
        windowController?.showInitialWindow()

        hotkeyManager = HotkeyManager { [weak self] in
            self?.windowController?.toggle()
        }

        setupSettingsShortcutMonitor()
    }

    deinit {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    @objc func openSettingsWindow(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showAndActivate()
    }

    private func setupSettingsShortcutMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "," else {
                return event
            }

            self?.openSettingsWindow(nil)
            return nil
        }
    }
}
