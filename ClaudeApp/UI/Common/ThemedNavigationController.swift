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
        navigationBar.tintColor = t.textPrimary
        navigationBar.titleTextAttributes = [
            .foregroundColor: t.textPrimary,
            .font: Fonts.sans(size: 17, weight: .semibold)
        ]
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        let chevron = Icons.image(.chevronLeft, size: 22, color: t.textPrimary).withRenderingMode(.alwaysTemplate)
        navigationBar.backIndicatorImage = chevron
        navigationBar.backIndicatorTransitionMaskImage = chevron
        navigationBar.tintColor = t.textPrimary
        setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyTheme()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if let top = topViewController {
            top.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }
        super.pushViewController(viewController, animated: animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.current.statusBarStyle
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}