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

    init() {
        super.init(window: panel)
        setupViews()
        setupPanelEvents()
        setupMouseMonitors()
        setupScreenObserver()
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
    }

    func showInitialWindow() {
        refreshGeometry()
        panel.hasShadow = false
        panel.setFrame(geometry.collapsedFrame, display: false)
        shapeView.showsNotchCutout = false
        terminalVC.view.alphaValue = 0
        titleLabel.alphaValue = 0
        panel.orderFrontRegardless()
    }

    override func showWindow(_ sender: Any?) {
        showInitialWindow()
    }

    // MARK: - Setup

    private func setupViews() {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
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

        titleLabel.frame = titleRect(in: container.bounds)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        titleLabel.alignment = .left
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor(white: 0.88, alpha: 0.92)
        titleLabel.alphaValue = 1
        container.addSubview(titleLabel)

        terminalVC.onTitleChange = { [weak self] title in
            self?.titleLabel.stringValue = title
        }
        terminalVC.onDirectoryChange = { [weak self] directory in
            guard let self, self.titleLabel.stringValue == "MenuTerm" || self.titleLabel.stringValue.hasPrefix("/") else { return }
            if let directory, !directory.isEmpty {
                self.titleLabel.stringValue = directory
            }
        }
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

    private func titleRect(in bounds: NSRect) -> NSRect {
        NSRect(
            x: NotchGeometry.titleHorizontalInset,
            y: bounds.height - geometry.titleTopInset - NotchGeometry.titleHeight,
            width: bounds.width - NotchGeometry.titleHorizontalInset * 2,
            height: NotchGeometry.titleHeight
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
        let targetFrame = isExpanded ? geometry.expandedFrame : geometry.collapsedFrame
        panel.setFrame(targetFrame, display: true)
    }

    // MARK: - Toggle

    func toggle() {
        isExpanded ? collapse() : expand()
    }

    private func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        refreshGeometry()

        let targetFrame = geometry.expandedFrame

        if !terminalVC.isShellRunning {
            terminalVC.startShell()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.hasShadow = true

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(targetFrame, display: true)
            terminalVC.view.animator().alphaValue = 1
            titleLabel.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.updateTerminalFrame()
            self?.terminalVC.focus()
        })
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        shapeView.showsNotchCutout = false

        let targetFrame = geometry.collapsedFrame
        panel.hasShadow = false

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(targetFrame, display: true)
            terminalVC.view.animator().alphaValue = 0
            titleLabel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.makeFirstResponder(nil)
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
        shapeView.showsNotchCutout = isExpanded && geometry.hasNotch
        if let content = panel.contentView {
            titleLabel.frame = titleRect(in: content.bounds)
        }
    }
}
