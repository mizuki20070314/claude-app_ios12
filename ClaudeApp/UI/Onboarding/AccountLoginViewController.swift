import UIKit

// Deterministic account-login screen (no browser is opened until the user taps the button).
final class AccountLoginViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .gray)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        applyTheme()
        registerThemeObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func buildUI() {
        view.backgroundColor = Theme.current.background

        titleLabel.text = L("onboarding.choice.accountLogin", "Onboarding")
        titleLabel.font = Fonts.serif(size: 24, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = L("onboarding.choice.subtitle", "Onboarding")
        subtitleLabel.font = Fonts.sans(size: 14)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        loginButton.setTitle(L("onboarding.choice.accountLogin", "Onboarding"), for: .normal)
        loginButton.titleLabel?.font = Fonts.sans(size: 17, weight: .semibold)
        loginButton.layer.cornerRadius = 12
        loginButton.clipsToBounds = true
        loginButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        loginButton.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: loginButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loginButton.centerYAnchor)
        ])

        statusLabel.font = Fonts.sans(size: 13)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        [titleLabel, subtitleLabel, loginButton, statusLabel].forEach { content.addSubview($0) }
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            titleLabel.topAnchor.constraint(equalTo: content.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            loginButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            loginButton.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func applyTheme() {
        let t = Theme.current
        view.backgroundColor = t.background
        titleLabel.textColor = t.textPrimary
        subtitleLabel.textColor = t.textSecondary
        loginButton.backgroundColor = t.textPrimary
        loginButton.setTitleColor(t.background, for: .normal)
        statusLabel.textColor = t.destructive
        spinner.style = t.isDark ? .white : .gray
    }

    private func registerThemeObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange(_:)), name: Theme.didChange, object: nil)
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyTheme()
    }

    @objc private func loginTapped() {
        setValidating(true)
        ClaudeAccountAuth.shared.startLogin(from: self) { [weak self] success, message in
            guard let self = self else { return }
            self.setValidating(false)
            if success {
                AppRouter.shared.finishOnboarding()
            } else {
                self.statusLabel.text = message ?? "ログインに失敗しました。"
                self.statusLabel.isHidden = false
            }
        }
    }

    private func setValidating(_ validating: Bool) {
        loginButton.isEnabled = !validating
        if validating {
            loginButton.setTitle("", for: .normal)
            spinner.startAnimating()
        } else {
            loginButton.setTitle(L("onboarding.choice.accountLogin", "Onboarding"), for: .normal)
            spinner.stopAnimating()
        }
    }
}