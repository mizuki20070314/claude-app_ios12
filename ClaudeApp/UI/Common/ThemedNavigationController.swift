import UIKit

final class ThemedNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(themeDidChange(_:)),
                                             name: Theme.didChange,
                                             object: nil)
    }

    private func applyTheme() {
        let t = Theme.current
        navigationBar.isTranslucent = false
        navigationBar.barTintColor = t.background
        navigationBar.backgroundColor = t.background
        navigationBar.titleTextAttributes = [
            .foregroundColor: t.textPrimary,
            .font: Fonts.sans(size: 17, weight: .semibold)
        ]
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyTheme()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.current.statusBarStyle
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
