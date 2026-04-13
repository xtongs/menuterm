import AppKit

final class NotchWindowController: NSWindowController {
    private let panel = NotchPanel()
    private let terminalVC = TerminalViewController()
    private let shapeView = NotchShapeView()
    private let titleLabel = NSTextField(labelWithString: "MenuTerm")
    private var isExpanded = false
    private var geometry = NotchGeometry()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var sleepWakeObserver: NSObjectProtocol?
    private var isAnimating = false

    init() {
        super.init(window: panel)
        setupViews()
        setupPanelEvents()
        setupMouseMonitors()
        setupScreenObserver()
        setupSettingsObserver()
        setupSleepWakeObserver()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = sleepWakeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func showInitialWindow() {
        refreshGeometry()
        let frame = geometry.expandedFrame
        let hiddenFrame = NSRect(x: frame.origin.x, y: frame.origin.y + frame.height, width: frame.width, height: frame.height)
        panel.setFrame(hiddenFrame, display: false)
        panel.alphaValue = 1
        // Don't orderFront - keep window hidden until expand is called
    }

    override func showWindow(_ sender: Any?) {
        showInitialWindow()
    }

    // MARK: - Setup

    private func setupViews() {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        if let layer = container.layer {
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.5
            layer.shadowRadius = 12
            layer.shadowOffset = CGSize(width: 0, height: -4)
        }
        panel.contentView = container

        // Background shape
        shapeView.frame = container.bounds
        shapeView.autoresizingMask = [.width, .height]
        container.addSubview(shapeView)
        syncShapeView()

        // Terminal
        terminalVC.view.frame = terminalContentRect(in: container.bounds)
        terminalVC.view.autoresizingMask = [.width, .height]
        terminalVC.view.alphaValue = 1
        container.addSubview(terminalVC.view)

        terminalVC.onTitleChange = { _ in }
        terminalVC.onDirectoryChange = { _ in }
    }

    private func terminalContentRect(in bounds: NSRect) -> NSRect {
        let inset = NotchGeometry.contentInset
        let topInset = geometry.terminalTopInset
        return NSRect(
            x: inset,
            y: inset,
            width: bounds.width - inset * 2,
            height: bounds.height - topInset - inset
        )
    }

    private func setupPanelEvents() {
        panel.onLeftMouseDown = { [weak self] event in
            self?.handlePanelMouseDown(event)
        }
    }

    // MARK: - Mouse Monitoring

    private func setupMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleOutsideMouseDown(event)
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleOutsideMouseDown(event)
            return event
        }
    }

    private func setupScreenObserver() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenConfigurationChange()
        }
    }

    private func setupSettingsObserver() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .appSettingsDidChange,
            object: AppSettings.shared,
            queue: .main
        ) { [weak self] _ in
            self?.handleSettingsChange()
        }
    }

    private func setupSleepWakeObserver() {
        sleepWakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Hide window when screen sleeps to prevent flash on wake
            self?.panel.orderOut(nil)
        }
    }

    private func handlePanelMouseDown(_ event: NSEvent) {
        guard event.type == .leftMouseDown, !isExpanded else { return }
        expand()
    }

    private func handleOutsideMouseDown(_ event: NSEvent) {
        guard isExpanded else { return }
        guard event.window !== panel else { return }

        let screenPoint = screenLocation(for: event)
        if !panel.frame.contains(screenPoint) {
            collapse()
        }
    }

    private func screenLocation(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return event.locationInWindow
    }

    private func handleScreenConfigurationChange() {
        refreshGeometry()
        panel.setFrame(geometry.expandedFrame, display: true)
    }

    private func handleSettingsChange() {
        refreshGeometry()

        let targetFrame = geometry.expandedFrame
        if isExpanded {
            panel.setFrame(targetFrame, display: true)
        } else {
            let hiddenFrame = NSRect(
                x: targetFrame.origin.x,
                y: targetFrame.origin.y + targetFrame.height,
                width: targetFrame.width,
                height: targetFrame.height
            )
            panel.setFrame(hiddenFrame, display: true)
        }
    }

    // MARK: - Toggle

    func toggle() {
        isExpanded ? collapse() : expand()
    }

    private func expand() {
        guard !isExpanded, !isAnimating else { return }
        isAnimating = true
        isExpanded = true
        refreshGeometry()

        if !terminalVC.isShellRunning {
            terminalVC.startShell()
        }

        let targetFrame = geometry.expandedFrame
        // Start from above the screen (hidden)
        let hiddenFrame = NSRect(x: targetFrame.origin.x, y: targetFrame.origin.y + targetFrame.height, width: targetFrame.width, height: targetFrame.height)
        panel.setFrame(hiddenFrame, display: false)
        panel.alphaValue = 1

        // Order front before animation
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        panel.makeKey()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1) // easeOutExpo
            self.panel.animator().setFrame(targetFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.updateTerminalFrame()
            self?.terminalVC.focus()
        })
    }

    private func collapse() {
        guard isExpanded, !isAnimating else { return }
        isAnimating = true
        isExpanded = false

        let currentFrame = panel.frame
        let hiddenFrame = NSRect(x: currentFrame.origin.x, y: currentFrame.origin.y + currentFrame.height, width: currentFrame.width, height: currentFrame.height)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.7, 0, 0.84, 0) // easeInExpo
            self.panel.animator().setFrame(hiddenFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.panel.makeFirstResponder(nil)
            // Actually hide the window after animation completes
            self?.panel.orderOut(nil)
        })
    }

    private func updateTerminalFrame() {
        guard let content = panel.contentView else { return }
        terminalVC.view.frame = terminalContentRect(in: content.bounds)
    }

    func restartShell() {
        terminalVC.restartShell()
        if !isExpanded { expand() }
    }

    private func refreshGeometry() {
        if let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first {
            geometry = NotchGeometry(screen: screen)
        } else {
            geometry = NotchGeometry()
        }

        syncShapeView()
        updateTerminalFrame()
    }

    private func syncShapeView() {
        shapeView.notchWidth = geometry.notchWidth
        shapeView.notchHeight = geometry.notchHeight
        shapeView.showsNotchCutout = false
    }
}
