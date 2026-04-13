import AppKit

struct NotchGeometry {
    let screenFrame: NSRect
    let hasNotch: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let menuBarHeight: CGFloat

    static let maximumExpandedWidth: CGFloat = 960
    static let minimumExpandedWidth: CGFloat = 720
    static let fallbackExpandedWidth: CGFloat = 820
    static let preferredSideWingWidth: CGFloat = 300
    static let maximumExpandedHeight: CGFloat = 572
    static let minimumExpandedHeight: CGFloat = 360
    static let screenHorizontalMargin: CGFloat = 18
    static let screenBottomMargin: CGFloat = 28
    static let fallbackCollapsedWidth: CGFloat = 200
    static let fallbackCollapsedHeight: CGFloat = 22
    static let cornerRadius: CGFloat = 14
    static let contentInset: CGFloat = 8
    static let titleHorizontalInset: CGFloat = 20
    static let titleHeight: CGFloat = 18
    static let titleSpacingBelowNotch: CGFloat = 12
    static let titleSpacingAboveTerminal: CGFloat = 10

    init(screen: NSScreen = .main ?? NSScreen.screens[0]) {
        screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        menuBarHeight = screenFrame.maxY - visibleFrame.maxY

        if #available(macOS 12.0, *),
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            let gapWidth = max(0, rightArea.minX - leftArea.maxX)
            hasNotch = gapWidth > 0
            notchWidth = hasNotch ? gapWidth : 0

            let safeBandFloor = max(leftArea.minY, rightArea.minY)
            let detectedHeight = screenFrame.maxY - safeBandFloor
            notchHeight = hasNotch ? max(menuBarHeight, detectedHeight) : 0
        } else {
            hasNotch = false
            notchWidth = 0
            notchHeight = 0
        }
    }

    var expandedWidth: CGFloat {
        let availableWidth = max(420, screenFrame.width - Self.screenHorizontalMargin * 2)
        let preferredWidth = hasNotch ? notchWidth + Self.preferredSideWingWidth * 2 : Self.fallbackExpandedWidth
        let boundedPreferredWidth = min(Self.maximumExpandedWidth, preferredWidth)
        return min(availableWidth, max(Self.minimumExpandedWidth, boundedPreferredWidth))
    }

    var expandedHeight: CGFloat {
        let availableHeight = max(260, screenFrame.height - menuBarHeight - Self.screenBottomMargin)
        if availableHeight <= Self.minimumExpandedHeight {
            return availableHeight
        }
        return min(Self.maximumExpandedHeight, availableHeight)
    }

    var collapsedWidth: CGFloat {
        guard hasNotch else { return Self.fallbackCollapsedWidth }
        return max(120, notchWidth - 10)
    }

    var collapsedHeight: CGFloat {
        guard hasNotch else { return Self.fallbackCollapsedHeight }
        return max(10, round(notchHeight * 0.45))
    }

    var titleTopInset: CGFloat {
        (hasNotch ? notchHeight : 0) + Self.titleSpacingBelowNotch
    }

    /// Panel frame when expanded, anchored to screen top center.
    var expandedFrame: NSRect {
        let x = screenFrame.midX - expandedWidth / 2
        let y = screenFrame.maxY - expandedHeight
        return NSRect(x: x, y: y, width: expandedWidth, height: expandedHeight)
    }

    /// Panel frame when collapsed and tucked into the notch area.
    var collapsedFrame: NSRect {
        let x = screenFrame.midX - collapsedWidth / 2
        let y = screenFrame.maxY - collapsedHeight
        return NSRect(x: x, y: y, width: collapsedWidth, height: collapsedHeight)
    }

    /// Inset for terminal content, leaving room for the notch cutout and title row.
    var terminalTopInset: CGFloat {
        titleTopInset + Self.titleHeight + Self.titleSpacingAboveTerminal
    }
}
