import AppKit
import Foundation
import ServiceManagement

extension Notification.Name {
    static let appSettingsDidChange = Notification.Name("MenuTerm.AppSettingsDidChange")
}

struct TerminalFontOption: Identifiable, Hashable {
    static let systemMonospacedID = "__system_monospaced__"

    let id: String
    let displayName: String
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let minimumWindowWidth: Double = Double(NotchGeometry.minimumExpandedWidth)
    static let maximumWindowWidth: Double = Double(NotchGeometry.maximumExpandedWidth)
    static let defaultWindowWidth: Double = Double(NotchGeometry.fallbackExpandedWidth)

    static let minimumWindowHeight: Double = Double(NotchGeometry.minimumExpandedHeight)
    static let maximumWindowHeight: Double = Double(NotchGeometry.maximumExpandedHeight)
    static let defaultWindowHeight: Double = Double(NotchGeometry.maximumExpandedHeight)

    static let minimumFontSize: Double = 11
    static let maximumFontSize: Double = 24
    static let defaultFontSize: Double = 13

    @Published var windowWidth: Double {
        didSet {
            let clampedValue = Self.clamp(windowWidth, min: Self.minimumWindowWidth, max: Self.maximumWindowWidth)
            if windowWidth != clampedValue {
                windowWidth = clampedValue
                return
            }
            persist(windowWidth, forKey: Keys.windowWidth)
            broadcastChange()
        }
    }

    @Published var windowHeight: Double {
        didSet {
            let clampedValue = Self.clamp(windowHeight, min: Self.minimumWindowHeight, max: Self.maximumWindowHeight)
            if windowHeight != clampedValue {
                windowHeight = clampedValue
                return
            }
            persist(windowHeight, forKey: Keys.windowHeight)
            broadcastChange()
        }
    }

    @Published var fontIdentifier: String {
        didSet {
            if availableFontOptions.contains(where: { $0.id == fontIdentifier }) == false {
                fontIdentifier = TerminalFontOption.systemMonospacedID
                return
            }
            persist(fontIdentifier, forKey: Keys.fontIdentifier)
            broadcastChange()
        }
    }

    @Published var fontSize: Double {
        didSet {
            let clampedValue = Self.clamp(fontSize, min: Self.minimumFontSize, max: Self.maximumFontSize)
            if fontSize != clampedValue {
                fontSize = clampedValue
                return
            }
            persist(fontSize, forKey: Keys.fontSize)
            broadcastChange()
        }
    }

    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginErrorMessage: String?

    let availableFontOptions: [TerminalFontOption]

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let windowWidth = "settings.windowWidth"
        static let windowHeight = "settings.windowHeight"
        static let fontIdentifier = "settings.fontIdentifier"
        static let fontSize = "settings.fontSize"
    }

    private init() {
        availableFontOptions = Self.buildFontOptions()

        let storedWindowWidth = defaults.object(forKey: Keys.windowWidth) as? Double ?? Self.defaultWindowWidth
        let storedWindowHeight = defaults.object(forKey: Keys.windowHeight) as? Double ?? Self.defaultWindowHeight
        let storedFontIdentifier = defaults.string(forKey: Keys.fontIdentifier) ?? TerminalFontOption.systemMonospacedID
        let storedFontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? Self.defaultFontSize

        windowWidth = Self.clamp(storedWindowWidth, min: Self.minimumWindowWidth, max: Self.maximumWindowWidth)
        windowHeight = Self.clamp(storedWindowHeight, min: Self.minimumWindowHeight, max: Self.maximumWindowHeight)
        fontIdentifier = availableFontOptions.contains(where: { $0.id == storedFontIdentifier }) ? storedFontIdentifier : TerminalFontOption.systemMonospacedID
        fontSize = Self.clamp(storedFontSize, min: Self.minimumFontSize, max: Self.maximumFontSize)

        launchAtLoginEnabled = Self.currentLaunchAtLoginState()
    }

    var preferredWindowWidth: CGFloat { CGFloat(windowWidth) }
    var preferredWindowHeight: CGFloat { CGFloat(windowHeight) }

    var terminalFont: NSFont {
        let pointSize = CGFloat(fontSize)
        if fontIdentifier == TerminalFontOption.systemMonospacedID {
            return NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
        }
        return NSFont(name: fontIdentifier, size: pointSize) ?? NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            let service = SMAppService.mainApp
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            launchAtLoginEnabled = enabled
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginEnabled = Self.currentLaunchAtLoginState()
            launchAtLoginErrorMessage = error.localizedDescription
        }
    }

    private func persist<T>(_ value: T, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func broadcastChange() {
        NotificationCenter.default.post(name: .appSettingsDidChange, object: self)
    }

    private static func clamp(_ value: Double, min lowerBound: Double, max upperBound: Double) -> Double {
        Swift.max(lowerBound, Swift.min(upperBound, value))
    }

    private static func currentLaunchAtLoginState() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private static func buildFontOptions() -> [TerminalFontOption] {
        var options: [TerminalFontOption] = [
            TerminalFontOption(id: TerminalFontOption.systemMonospacedID, displayName: "System Monospaced")
        ]

        let manager = NSFontManager.shared
        let fixedPitchFonts = manager.availableFontFamilies.compactMap { family -> TerminalFontOption? in
            guard let members = manager.availableMembers(ofFontFamily: family) else { return nil }
            for member in members {
                guard let fontName = member[safe: 0] as? String,
                      let font = NSFont(name: fontName, size: CGFloat(Self.defaultFontSize)),
                      font.isFixedPitch else {
                    continue
                }
                return TerminalFontOption(id: fontName, displayName: family)
            }
            return nil
        }

        options.append(contentsOf: fixedPitchFonts.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        })
        return options
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
