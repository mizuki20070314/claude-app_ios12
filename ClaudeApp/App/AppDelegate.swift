import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        ClaudeAccountAuth.applyDebugSessionFromEnvironment()
        #endif
        Theme.setMode(ThemeMode(rawValue: SettingsStore.shared.themeMode) ?? .system)
        UISwitch.appearance().onTintColor = Theme.current.accent
        let win = UIWindow(frame: UIScreen.main.bounds)
        self.window = win
        win.tintColor = Theme.current.textPrimary
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
        AppRouter.shared.start(window: win)
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.scheme == "claudeios12" {
            NotificationCenter.default.post(name: Notification.Name("ClaudeAccountAuth.callback"), object: url)
            return true
        }
        return false
    }

    @objc private func themeDidChange() {
        window?.tintColor = Theme.current.textPrimary
        UISwitch.appearance().onTintColor = Theme.current.accent
    }
}
