import UIKit

final class OnboardingViewController: UIViewController {

    // MARK: - Paging

    private let scrollView = UIScrollView()
    private let pageContainer = UIView()
    private var pageViews: [UIView] = []
    private var currentPage: Int = 0

    // Welcome
    private let sparkView = SparkView()
    private let welcomeTitleLabel = UILabel()
    private let welcomeSubtitleLabel = UILabel()
    private let startButton = UIButton(type: .system)

    // API key
    private let apiKeyTitleLabel = UILabel()
    private let apiKeyExplanationLabel = UILabel()
    private let apiKeyTextField = UITextField()
    private let showHideButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private let continueButton = UIButton(type: .system)
    private let apiKeyActivityIndicator = UIActivityIndicatorView(style: .gray)
    private let apiKeyErrorLabel = UILabel()

    // Name
    private let nameTitleLabel = UILabel()
    private let nameTextField = UITextField()
    private let doneButton = UIButton(type: .system)

    private var contentWidthConstraint: NSLayoutConstraint?
    private var scrollViewBottomConstraint: NSLayoutConstraint?

    private var previousApiKey: String = ""

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        applyTheme()
        registerThemeObserver()
        registerKeyboardObservers()
        showPage(0, animated: false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI

    private func buildUI() {
        view.backgroundColor = Theme.current.background

        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        pageContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(pageContainer)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            pageContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            pageContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            pageContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            pageContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            pageContainer.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        let welcome = buildWelcomePage()
        let apiKey = buildApiKeyPage()
        let name = buildNamePage()
        pageViews = [welcome, apiKey, name]

        for (idx, p) in pageViews.enumerated() {
            p.translatesAutoresizingMaskIntoConstraints = false
            pageContainer.addSubview(p)
            NSLayoutConstraint.activate([
                p.topAnchor.constraint(equalTo: pageContainer.topAnchor),
                p.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor),
                p.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
            if idx == 0 {
                p.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor).isActive = true
            } else {
                p.leadingAnchor.constraint(equalTo: pageViews[idx - 1].trailingAnchor).isActive = true
            }
            if idx == pageViews.count - 1 {
                p.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor).isActive = true
            }
        }

        // Welcome
        sparkView.color = Theme.current.accent
        sparkView.translatesAutoresizingMaskIntoConstraints = false
        welcome.addSubview(sparkView)

        welcomeTitleLabel.text = L("onboarding.welcome.title", "Onboarding")
        welcomeTitleLabel.font = Fonts.serif(size: 30)
        welcomeTitleLabel.textAlignment = .center
        welcomeTitleLabel.numberOfLines = 0
        welcomeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        welcome.addSubview(welcomeTitleLabel)

        welcomeSubtitleLabel.text = L("onboarding.welcome.subtitle", "Onboarding")
        welcomeSubtitleLabel.font = Fonts.sans(size: 16)
        welcomeSubtitleLabel.textAlignment = .center
        welcomeSubtitleLabel.numberOfLines = 0
        welcomeSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        welcome.addSubview(welcomeSubtitleLabel)

        startButton.setTitle(L("onboarding.welcome.start", "Onboarding"), for: .normal)
        startButton.titleLabel?.font = Fonts.sans(size: 17, weight: .semibold)
        startButton.layer.cornerRadius = 12
        startButton.clipsToBounds = true
        startButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        welcome.addSubview(startButton)

        // API key page
        apiKeyTitleLabel.text = L("onboarding.apikey.title", "Onboarding")
        apiKeyTitleLabel.font = Fonts.serif(size: 24, weight: .semibold)
        apiKeyTitleLabel.textAlignment = .center
        apiKeyTitleLabel.numberOfLines = 0
        apiKeyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        apiKey.addSubview(apiKeyTitleLabel)

        apiKeyExplanationLabel.text = L("onboarding.apikey.explanation", "Onboarding")
        apiKeyExplanationLabel.font = Fonts.sans(size: 14)
        apiKeyExplanationLabel.textAlignment = .center
        apiKeyExplanationLabel.numberOfLines = 0
        apiKeyExplanationLabel.translatesAutoresizingMaskIntoConstraints = false
        apiKey.addSubview(apiKeyExplanationLabel)

        apiKeyTextField.isSecureTextEntry = true
        apiKeyTextField.placeholder = L("onboarding.apikey.placeholder", "Onboarding")
        apiKeyTextField.font = Fonts.mono(size: 14)
        apiKeyTextField.autocapitalizationType = .none
        apiKeyTextField.autocorrectionType = .no
        apiKeyTextField.spellCheckingType = .no
        apiKeyTextField.layer.cornerRadius = 10
        apiKeyTextField.layer.borderWidth = 1
        apiKeyTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        apiKeyTextField.leftViewMode = .always
        apiKeyTextField.rightView = makeRightView()
        apiKeyTextField.rightViewMode = .always
        apiKeyTextField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        apiKey.addSubview(apiKeyTextField)

        showHideButton.setTitle(L("onboarding.apikey.show", "Onboarding"), for: .normal)
        showHideButton.titleLabel?.font = Fonts.sans(size: 13)
        showHideButton.addTarget(self, action: #selector(toggleShowHide), for: .touchUpInside)

        pasteButton.setTitle(L("onboarding.apikey.paste", "Onboarding"), for: .normal)
        pasteButton.titleLabel?.font = Fonts.sans(size: 13, weight: .semibold)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        apiKey.addSubview(pasteButton)

        continueButton.setTitle(L("onboarding.apikey.continue", "Onboarding"), for: .normal)
        continueButton.titleLabel?.font = Fonts.sans(size: 17, weight: .semibold)
        continueButton.layer.cornerRadius = 12
        continueButton.clipsToBounds = true
        continueButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        apiKey.addSubview(continueButton)

        apiKeyActivityIndicator.hidesWhenStopped = true
        apiKeyActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addSubview(apiKeyActivityIndicator)

        apiKeyErrorLabel.textColor = Theme.current.destructive
        apiKeyErrorLabel.font = Fonts.sans(size: 13)
        apiKeyErrorLabel.textAlignment = .center
        apiKeyErrorLabel.numberOfLines = 0
        apiKeyErrorLabel.isHidden = true
        apiKeyErrorLabel.translatesAutoresizingMaskIntoConstraints = false
        apiKey.addSubview(apiKeyErrorLabel)

        // Name page
        nameTitleLabel.text = L("onboarding.name.title", "Onboarding")
        nameTitleLabel.font = Fonts.serif(size: 24, weight: .semibold)
        nameTitleLabel.textAlignment = .center
        nameTitleLabel.numberOfLines = 0
        nameTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        name.addSubview(nameTitleLabel)

        nameTextField.placeholder = L("onboarding.name.placeholder", "Onboarding")
        nameTextField.font = Fonts.sans(size: 16)
        nameTextField.layer.cornerRadius = 10
        nameTextField.layer.borderWidth = 1
        nameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        nameTextField.leftViewMode = .always
        nameTextField.returnKeyType = .done
        nameTextField.delegate = self
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        name.addSubview(nameTextField)

        doneButton.setTitle(L("onboarding.name.done", "Onboarding"), for: .normal)
        doneButton.titleLabel?.font = Fonts.sans(size: 17, weight: .semibold)
        doneButton.layer.cornerRadius = 12
        doneButton.clipsToBounds = true
        doneButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        name.addSubview(doneButton)

        // Layout each page content with max width 480 centered.
        layoutWelcome(welcome)
        layoutApiKey(apiKey)
        layoutName(name)
    }

    private func makeRightView() -> UIView {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 88, height: 44))
        showHideButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        pasteButton.frame = CGRect(x: 44, y: 0, width: 44, height: 44)
        v.addSubview(showHideButton)
        v.addSubview(pasteButton)
        return v
    }

    private func buildWelcomePage() -> UIView { let v = UIView(); return v }
    private func buildApiKeyPage() -> UIView { let v = UIView(); return v }
    private func buildNamePage() -> UIView { let v = UIView(); return v }

    private func layoutWelcome(_ page: UIView) {
        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(content)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: page.centerYAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: page.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(lessThanOrEqualTo: page.trailingAnchor, constant: -24)
        ])
        // move spark/title/subtitle/button into content? They already added to page. Re-parent.
        [sparkView, welcomeTitleLabel, welcomeSubtitleLabel, startButton].forEach { $0.removeFromSuperview(); content.addSubview($0) }
        NSLayoutConstraint.activate([
            sparkView.topAnchor.constraint(equalTo: content.topAnchor),
            sparkView.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            sparkView.widthAnchor.constraint(equalToConstant: 120),
            sparkView.heightAnchor.constraint(equalToConstant: 120),

            welcomeTitleLabel.topAnchor.constraint(equalTo: sparkView.bottomAnchor, constant: 24),
            welcomeTitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            welcomeTitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            welcomeSubtitleLabel.topAnchor.constraint(equalTo: welcomeTitleLabel.bottomAnchor, constant: 12),
            welcomeSubtitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            welcomeSubtitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            startButton.topAnchor.constraint(equalTo: welcomeSubtitleLabel.bottomAnchor, constant: 32),
            startButton.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            startButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            startButton.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func layoutApiKey(_ page: UIView) {
        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(content)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: page.centerYAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: page.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(lessThanOrEqualTo: page.trailingAnchor, constant: -24)
        ])
        [apiKeyTitleLabel, apiKeyExplanationLabel, apiKeyTextField, pasteButton, continueButton, apiKeyErrorLabel].forEach { $0.removeFromSuperview(); content.addSubview($0) }
        NSLayoutConstraint.activate([
            apiKeyTitleLabel.topAnchor.constraint(equalTo: content.topAnchor),
            apiKeyTitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            apiKeyTitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            apiKeyExplanationLabel.topAnchor.constraint(equalTo: apiKeyTitleLabel.bottomAnchor, constant: 12),
            apiKeyExplanationLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            apiKeyExplanationLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            apiKeyTextField.topAnchor.constraint(equalTo: apiKeyExplanationLabel.bottomAnchor, constant: 20),
            apiKeyTextField.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            apiKeyTextField.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            pasteButton.topAnchor.constraint(equalTo: apiKeyTextField.bottomAnchor, constant: 8),
            pasteButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            continueButton.topAnchor.constraint(equalTo: pasteButton.bottomAnchor, constant: 20),
            continueButton.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            continueButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            apiKeyActivityIndicator.centerXAnchor.constraint(equalTo: continueButton.centerXAnchor),
            apiKeyActivityIndicator.centerYAnchor.constraint(equalTo: continueButton.centerYAnchor),

            apiKeyErrorLabel.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 12),
            apiKeyErrorLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            apiKeyErrorLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            apiKeyErrorLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func layoutName(_ page: UIView) {
        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(content)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: page.centerYAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: page.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(lessThanOrEqualTo: page.trailingAnchor, constant: -24)
        ])
        [nameTitleLabel, nameTextField, doneButton].forEach { $0.removeFromSuperview(); content.addSubview($0) }
        NSLayoutConstraint.activate([
            nameTitleLabel.topAnchor.constraint(equalTo: content.topAnchor),
            nameTitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            nameTitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            nameTextField.topAnchor.constraint(equalTo: nameTitleLabel.bottomAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            nameTextField.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            doneButton.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 24),
            doneButton.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            doneButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            doneButton.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    // MARK: - Theme

    private func applyTheme() {
        let t = Theme.current
        view.backgroundColor = t.background
        sparkView.color = t.accent

        welcomeTitleLabel.textColor = t.textPrimary
        welcomeSubtitleLabel.textColor = t.textSecondary
        stylePrimaryButton(startButton, theme: t)

        apiKeyTitleLabel.textColor = t.textPrimary
        apiKeyExplanationLabel.textColor = t.textSecondary
        styleTextField(apiKeyTextField, theme: t)
        styleSecondaryButton(pasteButton, theme: t)
        stylePrimaryButton(continueButton, theme: t)
        apiKeyErrorLabel.textColor = t.destructive

        // spinner style
        apiKeyActivityIndicator.style = t.isDark ? .white : .gray

        nameTitleLabel.textColor = t.textPrimary
        styleTextField(nameTextField, theme: t)
        stylePrimaryButton(doneButton, theme: t)
    }

    private func stylePrimaryButton(_ b: UIButton, theme: Theme) {
        b.backgroundColor = theme.textPrimary
        b.setTitleColor(theme.background, for: .normal)
    }

    private func styleSecondaryButton(_ b: UIButton, theme: Theme) {
        b.setTitleColor(theme.accent, for: .normal)
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

    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frameEnd = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = max(0, view.bounds.height - frameEnd.origin.y)
        scrollView.contentInset.bottom = keyboardHeight + 16
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight + 16
    }

    // MARK: - Actions

    @objc private func startTapped() {
        showPage(1, animated: true)
    }

    @objc private func toggleShowHide() {
        apiKeyTextField.isSecureTextEntry.toggle()
        let title = apiKeyTextField.isSecureTextEntry ? L("onboarding.apikey.show", "Onboarding") : L("onboarding.apikey.hide", "Onboarding")
        showHideButton.setTitle(title, for: .normal)
    }

    @objc private func pasteTapped() {
        if let s = UIPasteboard.general.string {
            apiKeyTextField.text = s
        }
    }

    @objc private func continueTapped() {
        let key = apiKeyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            apiKeyErrorLabel.text = L("onboarding.apikey.errorEmpty", "Onboarding")
            apiKeyErrorLabel.isHidden = false
            return
        }
        apiKeyErrorLabel.isHidden = true
        setValidating(true)
        previousApiKey = SettingsStore.shared.apiKey
        SettingsStore.shared.apiKey = key
        AnthropicClient.shared.validateKey { [weak self] result in
            guard let self = self else { return }
            self.setValidating(false)
            switch result {
            case .success:
                self.showPage(2, animated: true)
            case .failure(let err):
                SettingsStore.shared.apiKey = self.previousApiKey
                self.apiKeyErrorLabel.text = (err as? LocalizedError)?.errorDescription ?? err.localizedDescription
                self.apiKeyErrorLabel.isHidden = false
            }
        }
    }

    private func setValidating(_ validating: Bool) {
        continueButton.isEnabled = !validating
        if validating {
            continueButton.setTitle("", for: .normal)
            apiKeyActivityIndicator.startAnimating()
        } else {
            continueButton.setTitle(L("onboarding.apikey.continue", "Onboarding"), for: .normal)
            apiKeyActivityIndicator.stopAnimating()
        }
    }

    @objc private func doneTapped() {
        SettingsStore.shared.userName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        AppRouter.shared.finishOnboarding()
    }

    private func showPage(_ index: Int, animated: Bool) {
        guard index >= 0 && index < pageViews.count else { return }
        currentPage = index
        let offset = CGPoint(x: CGFloat(index) * scrollView.bounds.width, y: 0)
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.scrollView.setContentOffset(offset, animated: false)
            }
        } else {
            scrollView.setContentOffset(offset, animated: false)
        }
        if index == 1 {
            apiKeyTextField.becomeFirstResponder()
        } else if index == 2 {
            nameTextField.becomeFirstResponder()
        }
    }
}

extension OnboardingViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameTextField {
            doneTapped()
        }
        return true
    }
}
