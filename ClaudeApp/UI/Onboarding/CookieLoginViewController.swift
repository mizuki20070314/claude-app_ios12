import UIKit

final class CookieLoginViewController: UIViewController {

    // MARK: - Public

    var onSuccess: (() -> Void)?
    var onLoginResult: ((Bool, String?) -> Void)?

    // MARK: - Views

    let sessionKeyTextField = UITextField()
    let lastActiveOrgTextField = UITextField()

    private let scrollView = UIScrollView()
    private let content = UIView()

    private let explanationLabel = UILabel()
    private let stepsStack = UIStackView()

    private let showHideButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)

    private let orgHintLabel = UILabel()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .gray)
    private let errorLabel = UILabel()
    private let warningLabel = UILabel()

    private var keyboardObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("cookieLogin.title", "Onboarding")
        buildUI()
        applyTheme()
        registerThemeObserver()
        registerKeyboardObserver()
    }

    deinit {
        if let o = keyboardObserver { NotificationCenter.default.removeObserver(o) }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI

    private func buildUI() {
        view.backgroundColor = Theme.current.background

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            content.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480)
        ])
        let widthConstraint = content.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        widthConstraint.priority = .defaultHigh
        widthConstraint.isActive = true

        // Explanation
        explanationLabel.text = L("cookieLogin.explanation", "Onboarding")
        explanationLabel.font = Fonts.sans(size: 14)
        explanationLabel.numberOfLines = 0
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(explanationLabel)

        // Steps
        stepsStack.axis = .vertical
        stepsStack.spacing = 6
        stepsStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stepsStack)

        let steps = [
            L("cookieLogin.step1", "Onboarding"),
            L("cookieLogin.step2", "Onboarding"),
            L("cookieLogin.step3", "Onboarding"),
            L("cookieLogin.step4", "Onboarding")
        ]
        for s in steps {
            let l = UILabel()
            l.text = s
            l.font = Fonts.sans(size: 13)
            l.numberOfLines = 0
            l.translatesAutoresizingMaskIntoConstraints = false
            stepsStack.addArrangedSubview(l)
        }

        // Session key field
        sessionKeyTextField.isSecureTextEntry = true
        sessionKeyTextField.placeholder = L("cookieLogin.sessionKey.placeholder", "Onboarding")
        sessionKeyTextField.font = Fonts.mono(size: 14)
        sessionKeyTextField.autocapitalizationType = .none
        sessionKeyTextField.autocorrectionType = .no
        sessionKeyTextField.spellCheckingType = .no
        // textContentType intentionally not set
        sessionKeyTextField.layer.cornerRadius = 10
        sessionKeyTextField.layer.borderWidth = 1
        sessionKeyTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        sessionKeyTextField.leftViewMode = .always
        sessionKeyTextField.rightView = makeRightView()
        sessionKeyTextField.rightViewMode = .always
        sessionKeyTextField.translatesAutoresizingMaskIntoConstraints = false
        sessionKeyTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        content.addSubview(sessionKeyTextField)

        showHideButton.setTitle(L("onboarding.apikey.show", "Onboarding"), for: .normal)
        showHideButton.titleLabel?.font = Fonts.sans(size: 13)
        showHideButton.addTarget(self, action: #selector(toggleShowHide), for: .touchUpInside)

        pasteButton.setTitle(L("onboarding.apikey.paste", "Onboarding"), for: .normal)
        pasteButton.titleLabel?.font = Fonts.sans(size: 13, weight: .semibold)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)

        // lastActiveOrg field
        lastActiveOrgTextField.placeholder = L("cookieLogin.org.placeholder", "Onboarding")
        lastActiveOrgTextField.font = Fonts.sans(size: 14)
        lastActiveOrgTextField.autocapitalizationType = .none
        lastActiveOrgTextField.autocorrectionType = .no
        lastActiveOrgTextField.spellCheckingType = .no
        lastActiveOrgTextField.layer.cornerRadius = 10
        lastActiveOrgTextField.layer.borderWidth = 1
        lastActiveOrgTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        lastActiveOrgTextField.leftViewMode = .always
        lastActiveOrgTextField.translatesAutoresizingMaskIntoConstraints = false
        lastActiveOrgTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        content.addSubview(lastActiveOrgTextField)

        orgHintLabel.text = L("cookieLogin.org.hint", "Onboarding")
        orgHintLabel.font = Fonts.sans(size: 12)
        orgHintLabel.numberOfLines = 0
        orgHintLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(orgHintLabel)

        // Login button (pill)
        loginButton.setTitle(L("cookieLogin.login", "Onboarding"), for: .normal)
        loginButton.titleLabel?.font = Fonts.sans(size: 17, weight: .semibold)
        loginButton.layer.cornerRadius = 25
        loginButton.clipsToBounds = true
        loginButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(loginButton)

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        loginButton.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: loginButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loginButton.centerYAnchor)
        ])

        // Error label
        errorLabel.textColor = Theme.current.destructive
        errorLabel.font = Fonts.sans(size: 13)
        errorLabel.textAlignment = .left
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(errorLabel)

        // Warning
        warningLabel.text = L("cookieLogin.warning", "Onboarding")
        warningLabel.font = Fonts.sans(size: 12)
        warningLabel.numberOfLines = 0
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(warningLabel)

        // Layout
        NSLayoutConstraint.activate([
            explanationLabel.topAnchor.constraint(equalTo: content.topAnchor),
            explanationLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            explanationLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            stepsStack.topAnchor.constraint(equalTo: explanationLabel.bottomAnchor, constant: 16),
            stepsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stepsStack.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            sessionKeyTextField.topAnchor.constraint(equalTo: stepsStack.bottomAnchor, constant: 20),
            sessionKeyTextField.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sessionKeyTextField.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            lastActiveOrgTextField.topAnchor.constraint(equalTo: sessionKeyTextField.bottomAnchor, constant: 12),
            lastActiveOrgTextField.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            lastActiveOrgTextField.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            orgHintLabel.topAnchor.constraint(equalTo: lastActiveOrgTextField.bottomAnchor, constant: 4),
            orgHintLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            orgHintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            loginButton.topAnchor.constraint(equalTo: orgHintLabel.bottomAnchor, constant: 20),
            loginButton.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            errorLabel.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 12),
            errorLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            warningLabel.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 16),
            warningLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            warningLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            warningLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func makeRightView() -> UIView {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 88, height: 44))
        showHideButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        pasteButton.frame = CGRect(x: 44, y: 0, width: 44, height: 44)
        v.addSubview(showHideButton)
        v.addSubview(pasteButton)
        return v
    }

    // MARK: - Theme

    private func applyTheme() {
        let t = Theme.current
        view.backgroundColor = t.background
        scrollView.backgroundColor = t.background
        content.backgroundColor = t.background

        explanationLabel.textColor = t.textSecondary
        for case let l as UILabel in stepsStack.arrangedSubviews {
            l.textColor = t.textPrimary
        }
        styleTextField(sessionKeyTextField, theme: t)
        styleTextField(lastActiveOrgTextField, theme: t)
        orgHintLabel.textColor = t.textSecondary
        loginButton.backgroundColor = t.textPrimary
        loginButton.setTitleColor(t.background, for: .normal)
        errorLabel.textColor = t.destructive
        warningLabel.textColor = t.textSecondary
        spinner.style = t.isDark ? .white : .gray
        showHideButton.setTitleColor(t.accent, for: .normal)
        pasteButton.setTitleColor(t.accent, for: .normal)
    }

    private func styleTextField(_ tf: UITextField, theme: Theme) {
        tf.backgroundColor = theme.surface
        tf.textColor = theme.textPrimary
        tf.layer.borderColor = theme.border.cgColor
        tf.keyboardAppearance = theme.keyboardAppearance
    }

    private func registerThemeObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange(_:)), name: Theme.didChange, object: nil)
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyTheme()
    }

    // MARK: - Keyboard

    private func registerKeyboardObserver() {
        keyboardObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] notification in
            self?.keyboardWillChangeFrame(notification)
        }
    }

    private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frameEnd = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = max(0, view.bounds.height - frameEnd.origin.y)
        scrollView.contentInset.bottom = keyboardHeight + 16
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight + 16
    }

    // MARK: - Actions

    @objc func toggleShowHide() {
        sessionKeyTextField.isSecureTextEntry.toggle()
        let title = sessionKeyTextField.isSecureTextEntry ? L("onboarding.apikey.show", "Onboarding") : L("onboarding.apikey.hide", "Onboarding")
        showHideButton.setTitle(title, for: .normal)
    }

    @objc func pasteTapped() {
        if let s = UIPasteboard.general.string {
            sessionKeyTextField.text = s
        }
    }

    @objc func loginTapped() {
        errorLabel.isHidden = true
        let sk = sessionKeyTextField.text ?? ""
        let org = lastActiveOrgTextField.text
        setLoggingIn(true)
        ClaudeAccountAuth.shared.loginWithCookie(sessionKey: sk, lastActiveOrg: org) { [weak self] success, message in
            guard let self = self else { return }
            self.setLoggingIn(false)
            if success {
                self.onLoginResult?(true, nil)
                self.onSuccess?()
            } else {
                self.errorLabel.text = message
                self.errorLabel.isHidden = false
                self.onLoginResult?(false, message)
            }
        }
    }

    private func setLoggingIn(_ loggingIn: Bool) {
        loginButton.isEnabled = !loggingIn
        if loggingIn {
            loginButton.setTitle("", for: .normal)
            spinner.startAnimating()
        } else {
            loginButton.setTitle(L("cookieLogin.login", "Onboarding"), for: .normal)
            spinner.stopAnimating()
        }
    }
}
