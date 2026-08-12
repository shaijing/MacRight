import Foundation

enum TerminalApp: String, CaseIterable, Identifiable {
    case ghostty = "Ghostty"
    case terminal = "Terminal"
    case iterm = "iTerm"

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .ghostty: return "com.mitchellh.ghostty"
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iterm2"
        }
    }

    var displayName: String { rawValue }
}

final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    var preferredTerminal: TerminalApp {
        get {
            let raw = defaults.string(forKey: "preferredTerminal") ?? TerminalApp.terminal.rawValue
            return TerminalApp(rawValue: raw) ?? .terminal
        }
        set {
            defaults.set(newValue.rawValue, forKey: "preferredTerminal")
        }
    }

    var enableDocx: Bool {
        get { defaults.object(forKey: "enableDocx") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableDocx") }
    }

    var enableXlsx: Bool {
        get { defaults.object(forKey: "enableXlsx") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableXlsx") }
    }

    var enablePptx: Bool {
        get { defaults.object(forKey: "enablePptx") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enablePptx") }
    }

    var enableMarkdown: Bool {
        get { defaults.object(forKey: "enableMarkdown") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableMarkdown") }
    }

    var enableJson: Bool {
        get { defaults.object(forKey: "enableJson") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableJson") }
    }

    var enableCsv: Bool {
        get { defaults.object(forKey: "enableCsv") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableCsv") }
    }

    func fileName(for key: String, defaultValue: String) -> String {
        let value = defaults.string(forKey: "fileName.\(key)")?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value! : defaultValue
    }

    func setFileName(_ value: String, for key: String) {
        defaults.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "fileName.\(key)")
    }
}
