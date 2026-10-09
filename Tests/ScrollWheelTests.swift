import AppKit
import SwiftTerm

// In-process events: no Accessibility permission or physical input is needed.
private final class ScrollEvent: NSEvent {
    var verticalDelta: CGFloat = 0
    var precise = false
    var gesturePhase: NSEvent.Phase = []
    var inertiaPhase: NSEvent.Phase = []
    var point = NSPoint.zero
    var modifiers: NSEvent.ModifierFlags = []
    weak var hostWindow: NSWindow?

    override var type: NSEvent.EventType { .scrollWheel }
    override var scrollingDeltaY: CGFloat { verticalDelta }
    override var deltaY: CGFloat { 0 } // Precise input must not depend on legacy deltaY.
    override var hasPreciseScrollingDeltas: Bool { precise }
    override var phase: NSEvent.Phase { gesturePhase }
    override var momentumPhase: NSEvent.Phase { inertiaPhase }
    override var locationInWindow: NSPoint { point }
    override var modifierFlags: NSEvent.ModifierFlags { modifiers }
    override var window: NSWindow? { hostWindow }
}

private final class OutputRecorder: TerminalViewDelegate {
    var output = [UInt8]()
    var text: String { String(decoding: output, as: UTF8.self) }

    func send(source: TerminalView, data: ArraySlice<UInt8>) { output.append(contentsOf: data) }
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func clipboardCopy(source: TerminalView, content: Data) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}

@main
private enum ScrollWheelTests {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let panel = NotchPanel()
        panel.setFrame(NSRect(x: 0, y: 0, width: 800, height: 400), display: false)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        panel.contentView = container
        let controller = TerminalViewController()
        controller.view.frame = NSRect(x: 20, y: 20, width: 760, height: 360)
        container.addSubview(controller.view)
        container.layoutSubtreeIfNeeded()
        let view = controller.terminalView!
        let terminal = view.getTerminal()
        let recorder = OutputRecorder()
        // No process is started; only capture the bytes intended for the PTY.
        view.terminalDelegate = recorder
        panel.onScrollWheel = { controller.handleScrollWheel(with: $0) }

        func event(_ delta: CGFloat, precise: Bool = false,
                   phase: NSEvent.Phase = [], momentum: NSEvent.Phase = []) -> ScrollEvent {
            let event = ScrollEvent()
            event.verticalDelta = delta
            event.precise = precise
            event.gesturePhase = phase
            event.inertiaPhase = momentum
            event.hostWindow = panel
            event.point = view.convert(NSPoint(x: 100, y: 100), to: nil)
            return event
        }
        func rowHeight() -> CGFloat {
            CGFloat(view.cellSizeInPixels(source: terminal)!.height) / panel.backingScaleFactor
        }
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            checks += 1
        }

        // Ordinary shell history works with the deliberately hidden scrollbar.
        view.feed(text: (1...200).map { "line \($0)\r\n" }.joined())
        let bottom = terminal.buffer.yDisp
        check(bottom > 100, "Fixture must contain scrollback")
        check(view.subviews.compactMap { $0 as? NSScroller }.allSatisfy { $0.isHidden },
              "Exercise MenuTerm's hidden-scrollbar configuration")
        panel.sendEvent(event(1))
        check(terminal.buffer.yDisp == bottom - 3, "Wheel up scrolls history once, not twice")
        panel.sendEvent(event(-1))
        check(terminal.buffer.yDisp == bottom, "Wheel down restores bottom")
        panel.sendEvent(event(-1000))
        check(terminal.buffer.yDisp == bottom, "History clamps at bottom")
        panel.sendEvent(event(1000))
        check(terminal.buffer.yDisp == 0, "History clamps at top")
        panel.sendEvent(event(-1000))
        check(recorder.output.isEmpty, "History scrolling must not send keys to the shell")
        panel.sendEvent(event(0))
        check(terminal.buffer.yDisp == bottom, "Horizontal/zero-delta events do not scroll vertically")
        panel.sendEvent(event(0.1))
        check(terminal.buffer.yDisp == bottom - 1, "Fractional wheel detents are not discarded")

        // Accumulate sub-row trackpad input, retain momentum, reset each gesture.
        view.scroll(toPosition: 1)
        let halfRow = rowHeight() / 2
        panel.sendEvent(event(halfRow, precise: true, phase: .began))
        check(terminal.buffer.yDisp == bottom, "Half a row should accumulate")
        panel.sendEvent(event(halfRow, precise: true, phase: .changed))
        check(terminal.buffer.yDisp == bottom - 1, "Two half-rows scroll one line")
        panel.sendEvent(event(halfRow, precise: true, phase: .changed))
        panel.sendEvent(event(0, precise: true, phase: .ended))
        panel.sendEvent(event(halfRow, precise: true, momentum: .began))
        check(terminal.buffer.yDisp == bottom - 2, "Momentum continues the same gesture")
        panel.sendEvent(event(halfRow, precise: true, momentum: .changed))
        panel.sendEvent(event(0, precise: true, momentum: .ended))
        panel.sendEvent(event(halfRow, precise: true, phase: .began))
        check(terminal.buffer.yDisp == bottom - 2, "New gestures discard old fractional movement")
        panel.sendEvent(event(-halfRow, precise: true, phase: .changed))
        panel.sendEvent(event(-halfRow, precise: true, phase: .changed))
        check(terminal.buffer.yDisp == bottom - 1, "Direction reversal discards the opposite remainder")
        panel.sendEvent(event(halfRow, precise: true, phase: .changed))
        panel.sendEvent(event(0, precise: true, phase: .cancelled))
        panel.sendEvent(event(halfRow, precise: true, phase: .changed))
        check(terminal.buffer.yDisp == bottom - 1, "Cancelled gestures discard the remainder")

        // Mouse-aware applications receive wheel button presses, not history changes.
        for mode in [1000, 1002, 1003] {
            view.feed(text: "\u{1b}[?\(mode)h\u{1b}[?1006h")
            let position = terminal.buffer.yDisp
            let up = event(1)
            let size = view.cellSizeInPixels(source: terminal)!
            let scale = panel.backingScaleFactor
            up.point = view.convert(NSPoint(x: CGFloat(size.width) / scale * 4.5,
                                           y: view.bounds.height - CGFloat(size.height) / scale * 2.5), to: nil)
            recorder.output = []
            panel.sendEvent(up)
            check(recorder.text == String(repeating: "\u{1b}[<64;5;3M", count: 3),
                  "Mode \(mode) reports wheel up at screen-relative coordinates")
            check(terminal.buffer.yDisp == position, "Mouse tracking must not scroll local history")
            recorder.output = []
            up.verticalDelta = -1
            up.modifiers = [.shift, .option, .control]
            panel.sendEvent(up)
            check(recorder.text == String(repeating: "\u{1b}[<93;5;3M", count: 3),
                  "Wheel down preserves Shift/Option/Control modifiers")
            view.feed(text: "\u{1b}[?\(mode)l")
        }

        view.feed(text: "\u{1b}[?1000h")
        view.allowMouseReporting = false
        view.scroll(toPosition: 1)
        recorder.output = []
        panel.sendEvent(event(1))
        check(recorder.output.isEmpty && terminal.buffer.yDisp == bottom - 3,
              "Disabling mouse reporting restores local history scrolling")
        view.allowMouseReporting = true
        view.feed(text: "\u{1b}[?1000l\u{1b}[?9h")
        recorder.output = []
        panel.sendEvent(event(1))
        check(recorder.output.isEmpty, "X10 compatibility tracking does not support wheel reports")
        view.feed(text: "\u{1b}[?9l")

        // Alternate-screen programs without mouse support use cursor-key fallback.
        view.feed(text: "\u{1b}[?1049h")
        check(terminal.isCurrentBufferAlternate, "Fixture must enter alternate screen")
        recorder.output = []
        panel.sendEvent(event(1))
        check(recorder.text == String(repeating: "\u{1b}[A", count: 3), "Alternate screen uses up keys")
        recorder.output = []
        panel.sendEvent(event(-1))
        check(recorder.text == String(repeating: "\u{1b}[B", count: 3), "Alternate screen uses down keys")
        view.feed(text: "\u{1b}[?1h")
        recorder.output = []
        panel.sendEvent(event(rowHeight(), precise: true, phase: .began))
        panel.sendEvent(event(-rowHeight(), precise: true, phase: .began))
        check(recorder.text == "\u{1b}OA\u{1b}OB", "Fallback respects application cursor mode")
        view.feed(text: "\u{1b}[?1000h")
        recorder.output = []
        panel.sendEvent(event(1))
        check(recorder.text.contains("[<64;") && !recorder.text.contains("OA"),
              "Mouse tracking takes priority over alternate-screen key fallback")
        view.feed(text: "\u{1b}[?1000l\u{1b}[?1049l")

        // Window interception is limited to this terminal, including its child views.
        let outside = event(1)
        outside.point = NSPoint(x: 5, y: 5)
        check(!controller.handleScrollWheel(with: outside), "Panel padding is not intercepted")
        let wrongWindow = event(1)
        wrongWindow.hostWindow = nil
        check(!controller.handleScrollWheel(with: wrongWindow), "Other windows are not intercepted")
        controller.view.isHidden = true
        check(!controller.handleScrollWheel(with: event(1)), "Hidden terminal is not intercepted")
        controller.view.isHidden = false
        let child = NSView(frame: NSRect(x: 80, y: 80, width: 40, height: 40))
        view.addSubview(child)
        check(controller.handleScrollWheel(with: event(1)), "Events over terminal children are intercepted")
        child.removeFromSuperview()

        print("Passed \(checks) scroll-wheel checks")
    }
}
