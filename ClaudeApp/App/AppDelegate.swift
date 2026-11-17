import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Theme.setMode(ThemeMode(rawValue: SettingsStore.shared.themeMode) ?? .system)
        let win = UIWindow(frame: UIScreen.main.bounds)
        self.window = win
        AppRouter.shared.start(window: win)
        return true
    }
}
