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
    static let cornerRadius: CGFloat = 14
    static let contentInset: CGFloat = 8

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
        let preferredWidth = AppSettings.shared.preferredWindowWidth
        let boundedPreferredWidth = min(Self.maximumExpandedWidth, max(Self.minimumExpandedWidth, preferredWidth))
        return min(availableWidth, boundedPreferredWidth)
    }

    var expandedHeight: CGFloat {
        let availableHeight = max(260, screenFrame.height - menuBarHeight - Self.screenBottomMargin)
        if availableHeight <= Self.minimumExpandedHeight {
            return availableHeight
        }
        let preferredHeight = max(Self.minimumExpandedHeight, AppSettings.shared.preferredWindowHeight)
        return min(availableHeight, min(Self.maximumExpandedHeight, preferredHeight))
    }

    /// Panel frame when expanded, anchored to screen top center.
    var expandedFrame: NSRect {
        let x = screenFrame.midX - expandedWidth / 2
        let y = screenFrame.maxY - expandedHeight
        return NSRect(x: x, y: y, width: expandedWidth, height: expandedHeight)
    }

    /// Inset for terminal content, leaving room for the notch area.
    var terminalTopInset: CGFloat {
        (hasNotch ? notchHeight : 0) + Self.contentInset
    }
}
