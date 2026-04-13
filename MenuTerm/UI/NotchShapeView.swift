import AppKit

/// Draws the expanded terminal container with rounded corners on all sides.
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
        let outerRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: outerRadius, yRadius: outerRadius)

        if showsNotchCutout {
            let maxCutoutWidth = max(0, rect.width - outerRadius * 2 - 40)
            let cutoutWidth = min(notchWidth, maxCutoutWidth)
            let cutoutDepth = min(notchHeight, max(0, rect.height - outerRadius - 8))

            if cutoutWidth > 40, cutoutDepth > 6 {
                let innerRadius = min(12, cutoutWidth / 6, cutoutDepth - 1)
                let cutoutLeft = rect.midX - cutoutWidth / 2
                let cutoutRight = cutoutLeft + cutoutWidth
                let cutoutBottom = cutoutDepth

                let cutout = NSBezierPath()
                cutout.move(to: NSPoint(x: cutoutLeft, y: 0))
                cutout.line(to: NSPoint(x: cutoutLeft, y: cutoutBottom - innerRadius))
                cutout.curve(
                    to: NSPoint(x: cutoutLeft + innerRadius, y: cutoutBottom),
                    controlPoint1: NSPoint(x: cutoutLeft, y: cutoutBottom - innerRadius * 0.45),
                    controlPoint2: NSPoint(x: cutoutLeft + innerRadius * 0.45, y: cutoutBottom)
                )
                cutout.line(to: NSPoint(x: cutoutRight - innerRadius, y: cutoutBottom))
                cutout.curve(
                    to: NSPoint(x: cutoutRight, y: cutoutBottom - innerRadius),
                    controlPoint1: NSPoint(x: cutoutRight - innerRadius * 0.45, y: cutoutBottom),
                    controlPoint2: NSPoint(x: cutoutRight, y: cutoutBottom - innerRadius * 0.45)
                )
                cutout.line(to: NSPoint(x: cutoutRight, y: 0))
                cutout.close()

                path.append(cutout)
                path.windingRule = .evenOdd
            }
        }

        fillColor.setFill()
        path.fill()
    }
}
