import AppKit
import SwiftTerm

final class IMEAwareTerminalView: LocalProcessTerminalView {
    private var markedTextStorage: NSAttributedString?
    private var markedTextSelection = NSRange(location: NSNotFound, length: 0)
    private var restoredWindowLevel: NSWindow.Level?

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
