import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Theme.setMode(ThemeMode(rawValue: SettingsStore.shared.themeMode) ?? .system)
        UISwitch.appearance().onTintColor = Theme.current.accent
        let win = UIWindow(frame: UIScreen.main.bounds)
        self.window = win
        win.tintColor = Theme.current.textPrimary
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
        AppRouter.shared.start(window: win)
        return true
    }

    @objc private func themeDidChange() {
        window?.tintColor = Theme.current.textPrimary
        UISwitch.appearance().onTintColor = Theme.current.accent
    }
}
