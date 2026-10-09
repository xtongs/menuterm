import AppKit
import SwiftTerm

final class IMEAwareTerminalView: LocalProcessTerminalView {
    private var markedTextStorage: NSAttributedString?
    private var markedTextSelection = NSRange(location: NSNotFound, length: 0)
    private var restoredWindowLevel: NSWindow.Level?
    private var pendingScrollDelta: CGFloat = 0

    // Called by NotchPanel because SwiftTerm's scrollWheel override is not open.
    func handleScrollWheel(with event: NSEvent) {
        let terminal = getTerminal()
        guard let cellSize = cellSizeInPixels(source: terminal) else { return }
        let scale = window?.backingScaleFactor ?? 1
        let cellWidth = max(CGFloat(cellSize.width) / scale, 1)
        let cellHeight = max(CGFloat(cellSize.height) / scale, 1)
        let lines = scrollLineCount(for: event, rowHeight: cellHeight)
        guard lines != 0 else { return }

        // SwiftTerm's macOS handler only scrolls history, even when an application
        // has enabled mouse tracking. Wheel presses must go to that application.
        let reportsMouse = allowMouseReporting && terminal.mouseMode != .off && terminal.mouseMode != .x10
        if reportsMouse {
            let point = convert(event.locationInWindow, from: nil)
            let x = min(max(point.x, 0), max(bounds.width - 1, 0))
            let y = min(max(bounds.height - point.y, 0), max(bounds.height - 1, 0))
            let column = min(Int(x / cellWidth), terminal.cols - 1)
            let row = min(Int(y / cellHeight), terminal.rows - 1)
            let modifiers = event.modifierFlags
            let button = terminal.encodeButton(
                button: lines > 0 ? 4 : 5,
                release: false,
                shift: modifiers.contains(.shift),
                meta: modifiers.contains(.option),
                control: modifiers.contains(.control)
            )
            for _ in 0..<abs(lines) {
                terminal.sendEvent(buttonFlags: button, x: column, y: row, pixelX: Int(x), pixelY: Int(y))
            }
        } else if terminal.isCurrentBufferAlternate {
            // Full-screen programs without mouse tracking (e.g. less) have no
            // scrollback. Use cursor keys, respecting application cursor mode.
            let sequence: [UInt8]
            if lines > 0 {
                sequence = terminal.applicationCursor ? EscapeSequences.moveUpApp : EscapeSequences.moveUpNormal
            } else {
                sequence = terminal.applicationCursor ? EscapeSequences.moveDownApp : EscapeSequences.moveDownNormal
            }
            for _ in 0..<abs(lines) {
                send(sequence)
            }
        } else if canScroll {
            if lines > 0 {
                scrollUp(lines: lines)
            } else {
                scrollDown(lines: -lines)
            }
        }
    }

    private func scrollLineCount(for event: NSEvent, rowHeight: CGFloat) -> Int {
        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            pendingScrollDelta = 0
        }
        defer {
            if event.phase.contains(.cancelled) || event.momentumPhase.contains(.ended) {
                pendingScrollDelta = 0
            }
        }

        let delta = event.scrollingDeltaY
        guard delta != 0 else { return 0 }
        guard event.hasPreciseScrollingDeltas else {
            pendingScrollDelta = 0
            return Int((delta * 3).rounded(.awayFromZero))
        }

        // Trackpad deltas are in points. Keep sub-row movement rather than
        // dropping small events or scrolling a whole line for every pixel.
        if pendingScrollDelta * delta < 0 {
            pendingScrollDelta = 0
        }
        pendingScrollDelta += delta / rowHeight
        let lines = Int(pendingScrollDelta)
        pendingScrollDelta -= CGFloat(lines)
        return lines
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        clearMarkedTextState()
        super.insertText(string, replacementRange: replacementRange)
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        if let attributed = attributedString(from: string), attributed.length > 0 {
            markedTextStorage = attributed
            markedTextSelection = clampedRange(selectedRange, upperBound: attributed.length)
            lowerHostWindowForIMEIfNeeded()
        } else {
            clearMarkedTextState()
        }

        inputContext?.invalidateCharacterCoordinates()
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    override func unmarkText() {
        clearMarkedTextState()
        super.unmarkText()
    }

    override func selectedRange() -> NSRange {
        if hasMarkedText() {
            return markedTextSelection
        }
        return super.selectedRange()
    }

    override func markedRange() -> NSRange {
        guard let markedTextStorage, markedTextStorage.length > 0 else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: 0, length: markedTextStorage.length)
    }

    override func hasMarkedText() -> Bool {
        (markedTextStorage?.length ?? 0) > 0
    }

    override func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard let markedTextStorage, hasMarkedText() else {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }

        let available = NSRange(location: 0, length: markedTextStorage.length)
        let intersection = NSIntersectionRange(range, available)
        guard intersection.length > 0 else {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }

        actualRange?.pointee = intersection
        return markedTextStorage.attributedSubstring(from: intersection)
    }

    override func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        [.foregroundColor, .backgroundColor, .underlineStyle]
    }

    private func lowerHostWindowForIMEIfNeeded() {
        guard let window else { return }
        if restoredWindowLevel == nil {
            restoredWindowLevel = window.level
        }
        if window.level != .normal {
            window.level = .normal
            window.orderFront(nil)
        }
    }

    private func clearMarkedTextState() {
        markedTextStorage = nil
        markedTextSelection = NSRange(location: NSNotFound, length: 0)
        restoreHostWindowLevelIfNeeded()
        inputContext?.invalidateCharacterCoordinates()
    }

    private func restoreHostWindowLevelIfNeeded() {
        guard let window, let restoredWindowLevel else { return }
        window.level = restoredWindowLevel
        self.restoredWindowLevel = nil
    }

    private func attributedString(from string: Any) -> NSAttributedString? {
        if let attributed = string as? NSAttributedString {
            return attributed
        }
        if let text = string as? String {
            return NSAttributedString(string: text)
        }
        if let text = string as? NSString {
            return NSAttributedString(string: text as String)
        }
        return nil
    }

    private func clampedRange(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = min(max(range.location, 0), upperBound)
        let maxLength = max(upperBound - location, 0)
        let length = min(max(range.length, 0), maxLength)
        return NSRange(location: location, length: length)
    }
}
