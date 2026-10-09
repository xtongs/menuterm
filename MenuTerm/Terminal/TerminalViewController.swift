import AppKit
import SwiftTerm

final class TerminalViewController: NSViewController, LocalProcessTerminalViewDelegate {
    private(set) var terminalView: IMEAwareTerminalView?
    var onTitleChange: ((String) -> Void)?
    var onDirectoryChange: ((String?) -> Void)?
    private var currentTitle = "MenuTerm"
    private var settingsObserver: NSObjectProtocol?

    var isShellRunning: Bool {
        terminalView?.process.running ?? false
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.clipsToBounds = true
        view.layer?.backgroundColor = NSColor.black.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installTerminalView()
        setupSettingsObserver()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutTerminalView()
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        stopShell()
    }

    func startShell() {
        guard !isShellRunning else { return }
        guard let terminalView else { return }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let home = NSHomeDirectory()

        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("HOME=\(home)")
        env.append("LANG=en_US.UTF-8")

        terminalView.startProcess(
            executable: shell,
            environment: env,
            execName: "-" + (shell as NSString).lastPathComponent,
            currentDirectory: home
        )

        updateTitle((shell as NSString).lastPathComponent)
    }

    func restartShell() {
        stopShell()
        terminalView?.removeFromSuperview()
        terminalView = nil

        installTerminalView()
        startShell()
    }

    func stopShell() {
        guard isShellRunning else { return }
        terminalView?.terminate()
    }

    func focus() {
        guard let terminalView else { return }
        view.window?.makeFirstResponder(terminalView)
    }

    func handleScrollWheel(with event: NSEvent) -> Bool {
        guard let terminalView,
              let window = terminalView.window,
              event.window === window,
              !terminalView.isHiddenOrHasHiddenAncestor,
              let contentView = window.contentView,
              let hitView = contentView.hitTest(contentView.convert(event.locationInWindow, from: nil)),
              hitView === terminalView || hitView.isDescendant(of: terminalView) else {
            return false
        }
        terminalView.handleScrollWheel(with: event)
        return true
    }

    private func installTerminalView() {
        let terminalView = IMEAwareTerminalView(frame: view.bounds)
        terminalView.autoresizingMask = []
        terminalView.translatesAutoresizingMaskIntoConstraints = true
        terminalView.processDelegate = self

        configureAppearance(for: terminalView)
        view.addSubview(terminalView)
        self.terminalView = terminalView
        layoutTerminalView()
    }

    private func layoutTerminalView() {
        guard let terminalView else { return }
        updateScrollerAppearance(in: terminalView)

        let cellSize = terminalView.caretFrame.size
        let bounds = view.bounds
        guard cellSize.width > 0, cellSize.height > 0,
              bounds.width >= cellSize.width * 2, bounds.height >= cellSize.height else { return }

        let terminal = terminalView.getTerminal()
        // SwiftTerm subtracts a legacy scroller gutter when calculating columns,
        // even when its NSScroller is hidden and has a zero-width constraint.
        // Keep that gutter outside the clipped host, not inside the visible grid.
        let gutterWidth = max(0, terminalView.getOptimalFrameSize().width - CGFloat(terminal.cols) * cellSize.width)
        let columns = Int(bounds.width / cellSize.width)
        let gridWidth = CGFloat(columns) * cellSize.width
        let scale = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let leftPadding = (((bounds.width - gridWidth) / 2) * scale).rounded(.down) / scale
        let frame = NSRect(x: bounds.minX + leftPadding, y: bounds.minY,
                           width: gridWidth + gutterWidth, height: bounds.height)
        if terminalView.frame != frame {
            terminalView.frame = frame
        }

        // A font reset counts the gutter as content, unlike setFrameSize. Force
        // the normal resize path if the frame stayed equal; resize(cols:rows:)
        // would soft-reset terminal modes and must not be used for layout.
        let rows = Int(bounds.height / cellSize.height)
        if terminal.cols != columns || terminal.rows != rows {
            terminalView.setFrameSize(frame.size)
        }
    }

    private func setupSettingsObserver() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .appSettingsDidChange,
            object: AppSettings.shared,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentSettings()
        }
    }

    private func configureAppearance(for terminalView: LocalProcessTerminalView) {
        terminalView.font = AppSettings.shared.terminalFont
        terminalView.wantsLayer = true

        let background = NSColor.black
        let foreground = NSColor(red: 0.80, green: 0.84, blue: 0.96, alpha: 1.0)
        let terminalBackground = Color(red: 0, green: 0, blue: 0)
        let terminalForeground = Color(red: 52428, green: 55050, blue: 62913)
        let cursor = NSColor(white: 0.86, alpha: 1.0)

        // Force the host view and terminal defaults to pure black.
        terminalView.layer?.backgroundColor = background.cgColor
        terminalView.nativeBackgroundColor = background
        terminalView.nativeForegroundColor = foreground
        terminalView.getTerminal().backgroundColor = terminalBackground
        terminalView.getTerminal().foregroundColor = terminalForeground

        // 灰白色光标
        terminalView.caretColor = cursor
        terminalView.caretTextColor = .black
        terminalView.terminal.cursorColor = Color(red: 56360, green: 56360, blue: 56360)

        terminalView.optionAsMetaKey = true
        updateScrollerAppearance(in: terminalView)
    }

    private func applyCurrentSettings() {
        guard let terminalView else { return }
        terminalView.font = AppSettings.shared.terminalFont
        terminalView.needsDisplay = true
        layoutTerminalView()
    }

    private func updateTitle(_ title: String) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTitle = cleanedTitle.isEmpty ? "MenuTerm" : cleanedTitle
        onTitleChange?(currentTitle)
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async { [weak self] in
            self?.updateTitle(title)
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.onDirectoryChange?(directory)
        }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            let suffix = exitCode.map { " (\($0))" } ?? ""
            self?.updateTitle("Shell exited\(suffix)")
        }
    }

    private func updateScrollerAppearance(in terminalView: LocalProcessTerminalView) {
        for scroller in terminalView.subviews.compactMap({ $0 as? NSScroller }) {
            scroller.scrollerStyle = .overlay
            scroller.controlSize = .small
            scroller.alphaValue = 0
            scroller.isHidden = true
            for constraint in terminalView.constraints where constraint.firstItem as AnyObject === scroller && constraint.firstAttribute == .width {
                constraint.constant = 0
            }
        }
    }
}
