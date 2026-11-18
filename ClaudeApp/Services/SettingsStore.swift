import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    static let didChange = Notification.Name("SettingsStore.didChange")

    private let defaults = UserDefaults.standard

    private init() {}

    private func postChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SettingsStore.didChange, object: self)
        }
    }

    static func effortDisplayName(_ id: String) -> String {
        switch id {
        case "": return L("chat.effort.default", "Chat")
        case "low": return L("chat.effort.low", "Chat")
        case "medium": return L("chat.effort.medium", "Chat")
        case "high": return L("chat.effort.high", "Chat")
        case "xhigh": return L("chat.effort.xhigh", "Chat")
        case "max": return L("chat.effort.max", "Chat")
        default: return id
        }
    }

    var selectedModelId: String {
        get { defaults.string(forKey: "selectedModelId") ?? ModelOption.default.id }
        set { defaults.set(newValue, forKey: "selectedModelId"); postChange() }
    }

    var extendedThinking: Bool {
        get { defaults.object(forKey: "extendedThinking") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "extendedThinking"); postChange() }
    }

    var thinkingBudget: Int {
        get { let v = defaults.integer(forKey: "thinkingBudget"); return v == 0 ? 8000 : v }
        set { defaults.set(newValue, forKey: "thinkingBudget"); postChange() }
    }

    var maxTokens: Int {
        get { let v = defaults.integer(forKey: "maxTokens"); return v == 0 ? 8192 : v }
        set { defaults.set(newValue, forKey: "maxTokens"); postChange() }
    }

    var themeMode: String {
        get { defaults.string(forKey: "themeMode") ?? "system" }
        set { defaults.set(newValue, forKey: "themeMode"); postChange() }
    }

    var userName: String {
        get { defaults.string(forKey: "userName") ?? "" }
        set { defaults.set(newValue, forKey: "userName"); postChange() }
    }

    var style: String {
        get { defaults.string(forKey: "style") ?? "normal" }
        set { defaults.set(newValue, forKey: "style"); postChange() }
    }

    var sendWithReturn: Bool {
        get { defaults.bool(forKey: "sendWithReturn") }
        set { defaults.set(newValue, forKey: "sendWithReturn"); postChange() }
    }

    var haptics: Bool {
        get { defaults.object(forKey: "haptics") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "haptics"); postChange() }
    }

    var apiBaseURL: String {
        get { defaults.string(forKey: "apiBaseURL") ?? "https://api.anthropic.com" }
        set { defaults.set(newValue, forKey: "apiBaseURL"); postChange() }
    }

    var apiKey: String {
        get { KeychainStore.shared.get("apiKey") ?? "" }
        set {
            if newValue.isEmpty {
                _ = KeychainStore.shared.delete("apiKey")
            } else {
                _ = KeychainStore.shared.set(newValue, for: "apiKey")
            }
            postChange()
        }
    }

    var authMode: String {
        get { defaults.string(forKey: "authMode") ?? "apiKey" }
        set { defaults.set(newValue, forKey: "authMode"); postChange() }
    }

    var accountEmail: String {
        get { defaults.string(forKey: "accountEmail") ?? "" }
        set { defaults.set(newValue, forKey: "accountEmail"); postChange() }
    }

    var effort: String {
        get { defaults.string(forKey: "effort") ?? "" }
        set { defaults.set(newValue, forKey: "effort"); postChange() }
    }
}
