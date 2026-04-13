import AppKit

/// Draws the terminal container with square top corners and rounded bottom corners.
final class NotchShapeView: NSView {
    var notchWidth: CGFloat = 180 {
        didSet { needsDisplay = true }
    }

    var notchHeight: CGFloat = 38 {
        didSet { needsDisplay = true }
    }

    var cornerRadius: CGFloat = NotchGeometry.cornerRadius {
        didSet { needsDisplay = true }
    }

    var showsNotchCutout = false {
        didSet { needsDisplay = true }
    }

    private let fillColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1.0)

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)

        // Top corners square, bottom corners rounded
        let path = NSBezierPath()
        // Top-left (square)
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        // Top-right (square)
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        // Right side down to bottom-right curve
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - r))
        // Bottom-right (rounded)
        path.curve(
            to: NSPoint(x: rect.maxX - r, y: rect.maxY),
            controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - r * 0.45),
            controlPoint2: NSPoint(x: rect.maxX - r * 0.45, y: rect.maxY)
        )
        // Bottom side
        path.line(to: NSPoint(x: rect.minX + r, y: rect.maxY))
        // Bottom-left (rounded)
        path.curve(
            to: NSPoint(x: rect.minX, y: rect.maxY - r),
            controlPoint1: NSPoint(x: rect.minX + r * 0.45, y: rect.maxY),
            controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - r * 0.45)
        )
        path.close()

        fillColor.setFill()
        path.fill()
    }
}
