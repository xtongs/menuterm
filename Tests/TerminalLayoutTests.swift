import AppKit
import SwiftTerm

@main
private enum TerminalLayoutTests {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let panel = NotchPanel()
        panel.setFrame(NSRect(x: 0, y: 0, width: 820, height: 400), display: false)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 820, height: 400))
        panel.contentView = container
        let controller = TerminalViewController()
        container.addSubview(controller.view)
        let terminalView = controller.terminalView!
        let terminal = terminalView.getTerminal()
        let inset = NotchGeometry.contentInset
        var checks = 0

        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            checks += 1
        }
        func layout(width: CGFloat, height: CGFloat = 400) {
            panel.setContentSize(NSSize(width: width, height: height))
            controller.view.frame = NSRect(x: inset, y: inset,
                                           width: width - inset * 2, height: height - inset * 2)
            container.layoutSubtreeIfNeeded()
        }
        func checkGrid(_ context: String) {
            let cellWidth = terminalView.caretFrame.width
            let gridWidth = CGFloat(terminal.cols) * cellWidth
            let origin = terminalView.convert(NSPoint.zero, to: container)
            let left = origin.x
            let right = container.bounds.width - origin.x - gridWidth
            let pixel = 1 / panel.backingScaleFactor
            check(abs(left - right) <= pixel + 0.001,
                  "\(context): unequal content margins, left=\(left), right=\(right)")
            check(left >= inset && right >= inset, "\(context): content stays inside window padding")
            check(terminal.cols == Int(controller.view.bounds.width / cellWidth),
                  "\(context): hidden scroller must not consume terminal columns")
            check(controller.view.clipsToBounds, "\(context): hidden scroller gutter must be clipped")
            check(!terminalView.hasAmbiguousLayout, "\(context): terminal layout is unambiguous")
            check(terminalView.subviews.compactMap { $0 as? NSScroller }.allSatisfy { $0.isHidden },
                  "\(context): native scroller remains hidden")
        }

        for fontSize: CGFloat in [11, 13, 18, 24] {
            terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            for width: CGFloat in [720, 721, 820, 821, 960, 820] {
                layout(width: width)
                checkGrid("width=\(width), font=\(fontSize)")
            }
        }

        // A font reset uses SwiftTerm's full frame width, unlike a frame resize.
        // Repair the column count even when the desired frame hasn't changed.
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        controller.view.needsLayout = true
        layout(width: 820)
        let frame = terminalView.frame
        terminalView.font = terminalView.font
        controller.view.needsLayout = true
        layout(width: 820)
        check(terminalView.frame == frame, "Unchanged font keeps the same centered frame")
        checkGrid("same-font reset")
        NotificationCenter.default.post(name: .appSettingsDidChange, object: AppSettings.shared)
        checkGrid("settings notification")

        // Resizing must preserve the application's input modes.
        terminalView.feed(text: "\u{1b}[?1049h\u{1b}[?1000h\u{1b}[?1h")
        layout(width: 960, height: 500)
        checkGrid("alternate screen resize")
        check(terminal.isCurrentBufferAlternate, "Layout must not leave the alternate screen")
        check(terminal.mouseMode == .vt200, "Layout must not reset mouse tracking")
        check(terminal.applicationCursor, "Layout must not reset application cursor mode")

        // Hit testing at the last column uses the same origin as rendering.
        let lastCell = NSPoint(x: (CGFloat(terminal.cols) - 0.5) * terminalView.caretFrame.width,
                               y: terminalView.bounds.height / 2)
        let hitPoint = terminalView.convert(lastCell, to: container)
        let hit = container.hitTest(hitPoint)
        check(hit === terminalView || hit?.isDescendant(of: terminalView) == true,
              "Rightmost cell remains interactive")

        // Zero-sized hosts occur during initial window setup.
        controller.view.frame = .zero
        container.layoutSubtreeIfNeeded()
        check(terminalView.frame.width >= 0 && terminalView.frame.height >= 0,
              "Initial zero-sized host must not produce negative dimensions")
        layout(width: 820)
        checkGrid("restored from zero size")

        // Verify the real window hierarchy too, without showing it or starting a shell.
        let windowController = NotchWindowController()
        windowController.showInitialWindow()
        let actualWindow = windowController.window!
        let actualContent = actualWindow.contentView!
        let host = actualContent.subviews.first { child in
            child.subviews.contains { $0 is IMEAwareTerminalView }
        }!
        let actualTerminal = host.subviews.compactMap { $0 as? IMEAwareTerminalView }.first!
        for width: CGFloat in [720, 820, 960] {
            actualWindow.setContentSize(NSSize(width: width, height: 400))
            actualContent.layoutSubtreeIfNeeded()
            let origin = actualTerminal.convert(NSPoint.zero, to: actualContent)
            let gridWidth = CGFloat(actualTerminal.getTerminal().cols) * actualTerminal.caretFrame.width
            let right = actualContent.bounds.width - origin.x - gridWidth
            check(abs(origin.x - right) <= 1 / actualWindow.backingScaleFactor + 0.001,
                  "Real panel width=\(width) must have symmetric grid margins")
            check(abs(host.frame.minX - inset) < 0.001 &&
                  abs(actualContent.bounds.width - host.frame.maxX - inset) < 0.001,
                  "Real panel must keep equal outer content insets: host=\(host.frame), content=\(actualContent.bounds)")
            check(abs(host.frame.minY - inset) < 0.001,
                  "Real panel must preserve bottom padding: host=\(host.frame), content=\(actualContent.bounds)")
            let topInset = NotchGeometry(screen: actualWindow.screen ?? NSScreen.main!).terminalTopInset
            check(abs(actualContent.bounds.height - host.frame.maxY - topInset) < 0.001,
                  "Real panel must preserve notch clearance above the terminal")
            check(!host.hasAmbiguousLayout, "Real panel's content constraints are unambiguous")
        }

        print("Passed \(checks) terminal-layout checks")
    }
}
