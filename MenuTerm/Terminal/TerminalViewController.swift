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
        view.layer?.backgroundColor = NSColor.black.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installTerminalView()
        setupSettingsObserver()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let terminalView {
            updateScrollerAppearance(in: terminalView)
        }
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

    private func installTerminalView() {
        let terminalView = IMEAwareTerminalView(frame: view.bounds)
        terminalView.autoresizingMask = [.width, .height]
        terminalView.translatesAutoresizingMaskIntoConstraints = true
        terminalView.processDelegate = self

        configureAppearance(for: terminalView)
        view.addSubview(terminalView)
        self.terminalView = terminalView
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
        updateScrollerAppearance(in: terminalView)
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
