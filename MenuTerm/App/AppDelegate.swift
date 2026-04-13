import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private var hotkeyManager: HotkeyManager?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        windowController = NotchWindowController()
        windowController?.showInitialWindow()

        hotkeyManager = HotkeyManager { [weak self] in
            self?.windowController?.toggle()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 30)
        if let button = statusItem?.button {
            button.image = makeStatusItemImage()
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Terminal  ⌃`", action: #selector(doToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let newSessionItem = NSMenuItem(title: "New Session", action: #selector(newSession), keyEquivalent: "n")
        newSessionItem.target = self
        menu.addItem(newSessionItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func doToggle() {
        windowController?.toggle()
    }

    @objc private func newSession() {
        windowController?.restartShell()
    }

    private func makeStatusItemImage() -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let backgroundRect = rect.insetBy(dx: 1, dy: 1)
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 4.5, yRadius: 4.5)
        NSColor.black.setFill()
        backgroundPath.fill()

        let glyphColor = NSColor(white: 0.98, alpha: 1)
        glyphColor.setStroke()
        glyphColor.setFill()

        let chevron = NSBezierPath()
        chevron.lineWidth = 1.5
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        chevron.move(to: NSPoint(x: 8, y: 7.25))
        chevron.line(to: NSPoint(x: 10, y: 9))
        chevron.line(to: NSPoint(x: 8, y: 10.75))
        chevron.stroke()

        let prompt = NSBezierPath()
        prompt.lineWidth = 1.5
        prompt.lineCapStyle = .round
        prompt.move(to: NSPoint(x: 11.25, y: 7.6))
        prompt.line(to: NSPoint(x: 13.5, y: 7.6))
        prompt.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
