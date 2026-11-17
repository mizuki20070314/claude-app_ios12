import UIKit

final class HomeViewController: UIViewController {
    private let greetingLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()

        greetingLabel.text = L("home.greeting")
        greetingLabel.font = Fonts.serif(size: 28)
        greetingLabel.textAlignment = .center
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(greetingLabel)

        NSLayoutConstraint.activate([
            greetingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            greetingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        NotificationCenter.default.addObserver(self,
                                             selector: #selector(themeDidChange(_:)),
                                             name: Theme.didChange,
                                             object: nil)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        greetingLabel.textColor = Theme.current.textPrimary
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyTheme()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
