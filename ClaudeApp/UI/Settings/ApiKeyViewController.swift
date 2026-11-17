import UIKit

final class ApiKeyViewController: UIViewController {

    private let maskedLabel = UILabel()
    private let textField = UITextField()
    private let showHideButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private let verifyButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .gray)
    private let errorLabel = UILabel()

    private var previousApiKey: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("settings.account.apikey.title", "Settings")
        buildUI()
        applyTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange(_:)), name: Theme.didChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func buildUI() {
        view.backgroundColor = Theme.current.background

        maskedLabel.font = Fonts.mono(size: 13)
        maskedLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(maskedLabel)

        textField.isSecureTextEntry = true
        textField.placeholder = "sk-ant-..."
        textField.font = Fonts.mono(size: 14)
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.layer.cornerRadius = 10
        textField.layer.borderWidth = 1
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        view.addSubview(textField)

        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: 88, height: 44))
        showHideButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        pasteButton.frame = CGRect(x: 44, y: 0, width: 44, height: 44)
        showHideButton.setTitle(L("onboarding.apikey.show", "Onboarding"), for: .normal)
        pasteButton.setTitle(L("onboarding.apikey.paste", "Onboarding"), for: .normal)
        showHideButton.addTarget(self, action: #selector(toggleShowHide), for: .touchUpInside)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        rightView.addSubview(showHideButton)
        rightView.addSubview(pasteButton)
        textField.rightView = rightView
        textField.rightViewMode = .always

        verifyButton.setTitle(L("settings.account.apikey.verify", "Settings"), for: .normal)
        verifyButton.titleLabel?.font = Fonts.sans(size: 16, weight: .semibold)
        verifyButton.layer.cornerRadius = 10
        verifyButton.clipsToBounds = true
        verifyButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(verifyButton)

        deleteButton.setTitle(L("settings.account.apikey.delete", "Settings"), for: .normal)
        deleteButton.titleLabel?.font = Fonts.sans(size: 16, weight: .semibold)
        deleteButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(deleteButton)

        activity.hidesWhenStopped = true
        activity.translatesAutoresizingMaskIntoConstraints = false
        verifyButton.addSubview(activity)

        errorLabel.font = Fonts.sans(size: 13)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            maskedLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            maskedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            maskedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            textField.topAnchor.constraint(equalTo: maskedLabel.bottomAnchor, constant: 16),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            verifyButton.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 20),
            verifyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            verifyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            activity.centerXAnchor.constraint(equalTo: verifyButton.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: verifyButton.centerYAnchor),

            deleteButton.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 12),
            deleteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            errorLabel.topAnchor.constraint(equalTo: deleteButton.bottomAnchor, constant: 12),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        refreshMasked()
    }

    private func refreshMasked() {
        let key = SettingsStore.shared.apiKey
        maskedLabel.text = mask(key)
    }

    private func mask(_ key: String) -> String {
        guard key.count > 8 else { return key.isEmpty ? "—" : "••••" }
        let prefix = key.prefix(6)
        let suffix = key.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    private func applyTheme() {
        let t = Theme.current
        view.backgroundColor = t.background
        maskedLabel.textColor = t.textSecondary
        textField.backgroundColor = t.surface
        textField.textColor = t.textPrimary
        textField.layer.borderColor = t.border.cgColor
        textField.keyboardAppearance = t.keyboardAppearance
        verifyButton.backgroundColor = t.accent
        verifyButton.setTitleColor(t.onAccent, for: .normal)
        deleteButton.setTitleColor(t.destructive, for: .normal)
        errorLabel.textColor = t.destructive
        activity.style = t.isDark ? .white : .gray
        showHideButton.setTitleColor(t.accent, for: .normal)
        pasteButton.setTitleColor(t.accent, for: .normal)
    }

    @objc private func themeDidChange(_ n: Notification) { applyTheme() }

    @objc private func toggleShowHide() {
        textField.isSecureTextEntry.toggle()
        showHideButton.setTitle(textField.isSecureTextEntry ? L("onboarding.apikey.show", "Onboarding") : L("onboarding.apikey.hide", "Onboarding"), for: .normal)
    }

    @objc private func pasteTapped() {
        if let s = UIPasteboard.general.string { textField.text = s }
    }

    @objc private func verifyTapped() {
        let newKey = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let keyToVerify = newKey.isEmpty ? SettingsStore.shared.apiKey : newKey
        guard !keyToVerify.isEmpty else {
            errorLabel.text = L("onboarding.apikey.errorEmpty", "Onboarding")
            errorLabel.isHidden = false
            return
        }
        errorLabel.isHidden = true
        setVerifying(true)
        previousApiKey = SettingsStore.shared.apiKey
        if !newKey.isEmpty { SettingsStore.shared.apiKey = newKey }
        AnthropicClient.shared.validateKey { [weak self] result in
            guard let self = self else { return }
            self.setVerifying(false)
            switch result {
            case .success:
                self.refreshMasked()
                self.textField.text = ""
            case .failure(let err):
                if !newKey.isEmpty { SettingsStore.shared.apiKey = self.previousApiKey }
                self.errorLabel.text = (err as? LocalizedError)?.errorDescription ?? err.localizedDescription
                self.errorLabel.isHidden = false
            }
        }
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(title: nil, message: L("settings.account.apikey.deleteConfirm", "Settings"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.cancel", "Localizable"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("common.delete", "Settings"), style: .destructive) { _ in
            SettingsStore.shared.apiKey = ""
            self.refreshMasked()
        })
        present(alert, animated: true)
    }

    private func setVerifying(_ v: Bool) {
        verifyButton.isEnabled = !v
        if v {
            verifyButton.setTitle("", for: .normal)
            activity.startAnimating()
        } else {
            verifyButton.setTitle(L("settings.account.apikey.verify", "Settings"), for: .normal)
            activity.stopAnimating()
        }
    }
}
