import SwiftUI

@main
struct MenuTermApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    AppDelegate.shared?.openSettingsWindow(nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
