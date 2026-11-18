import UIKit

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let closeButton = IconButton(icon: .close, size: 22, tint: Theme.current.textPrimary)

    private var settingsObserver: NSObjectProtocol?
    private var conversationObserver: NSObjectProtocol?
    private var themeObserver: NSObjectProtocol?
    private var switchHandlers: [Int: (Bool) -> Void] = [:]
    private var nextSwitchTag: Int = 1000

    private let sectionTitles: [String] = [
        L("settings.section.profile", "Settings"),
        L("settings.section.account", "Settings"),
        L("settings.section.appearance", "Settings"),
        L("settings.section.model", "Settings"),
        L("settings.section.style", "Settings"),
        L("settings.section.chat", "Settings"),
        L("settings.section.data", "Settings"),
        L("settings.section.advanced", "Settings"),
        L("settings.section.info", "Settings"),
        "" // sign out (no header)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("settings.title", "Settings")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        buildUI()
        applyTheme()
        registerObservers()
    }

    deinit {
        if let o = settingsObserver { NotificationCenter.default.removeObserver(o) }
        if let o = conversationObserver { NotificationCenter.default.removeObserver(o) }
        if let o = themeObserver { NotificationCenter.default.removeObserver(o) }
    }

    private func buildUI() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyTheme() {
        let t = Theme.current
        view.backgroundColor = t.background
        tableView.backgroundColor = t.background
        tableView.separatorColor = t.separator
        closeButton.tintColor = t.textPrimary
        closeButton.refreshColor()
        navigationItem.leftBarButtonItem?.tintColor = t.textPrimary
    }

    private func registerObservers() {
        settingsObserver = NotificationCenter.default.addObserver(forName: Notification.Name("SettingsStore.didChange"), object: nil, queue: .main) { [weak self] _ in
            self?.tableView.reloadData()
        }
        conversationObserver = NotificationCenter.default.addObserver(forName: Notification.Name("ConversationStore.didChange"), object: nil, queue: .main) { [weak self] _ in
            self?.tableView.reloadData()
        }
        themeObserver = NotificationCenter.default.addObserver(forName: Theme.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
            self?.tableView.reloadData()
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Account rows

    private enum AccountRow {
        case authMode, status, cookie, webLogin, logout, apiKey
    }

    private func accountRows() -> [AccountRow] {
        var rows: [AccountRow] = [.authMode, .status, .cookie]
        if #available(iOS 13.0, *) {
            rows.append(.webLogin)
        }
        rows.append(.logout)
        rows.append(.apiKey)
        return rows
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int { 10 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let t = sectionTitles[section]
        return t.isEmpty ? nil : t
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let t = sectionTitles[section]
        guard !t.isEmpty else { return nil }
        let v = UIView()
        let label = UILabel()
        label.text = t
        label.font = Fonts.sans(size: 13, weight: .semibold)
        label.textColor = Theme.current.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -4)
        ])
        return v
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionTitles[section].isEmpty ? 8 : 28
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // profile
        case 1: return accountRows().count // account/auth
        case 2: return 1 // appearance
        case 3: return 5 // model
        case 4: return 1 // style
        case 5: return 2 // chat
        case 6: return 2 // data
        case 7: return 1 // advanced
        case 8: return 4 // info
        case 9: return 1 // sign out
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let t = Theme.current
        switch indexPath.section {
        case 0:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = t.surface
            let avatar = UIView()
            avatar.backgroundColor = t.accent
            avatar.layer.cornerRadius = 18
            avatar.translatesAutoresizingMaskIntoConstraints = false
            avatar.widthAnchor.constraint(equalToConstant: 36).isActive = true
            avatar.heightAnchor.constraint(equalToConstant: 36).isActive = true
            let initial = UILabel()
            initial.text = String(SettingsStore.shared.userName.prefix(1)).uppercased()
            if initial.text?.isEmpty == true { initial.text = "C" }
            initial.textColor = t.onAccent
            initial.font = Fonts.sans(size: 16, weight: .semibold)
            initial.textAlignment = .center
            initial.translatesAutoresizingMaskIntoConstraints = false
            avatar.addSubview(initial)
            NSLayoutConstraint.activate([
                initial.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
                initial.centerYAnchor.constraint(equalTo: avatar.centerYAnchor)
            ])
            let nameLabel = UILabel()
            nameLabel.text = SettingsStore.shared.userName.isEmpty ? "—" : SettingsStore.shared.userName
            nameLabel.textColor = t.textPrimary
            nameLabel.font = Fonts.sans(size: 16)
            let stack = UIStackView(arrangedSubviews: [avatar, nameLabel])
            stack.spacing = 12
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
            cell.accessoryType = .disclosureIndicator
            return cell

        case 1:
            let rows = accountRows()
            guard indexPath.row < rows.count else { return UITableViewCell() }
            switch rows[indexPath.row] {
            case .authMode:
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.account.authMode", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                cell.detailTextLabel?.text = SettingsStore.shared.authMode == "claudeAccount" ? L("settings.account.authMode.account", "Settings") : L("settings.account.authMode.apiKey", "Settings")
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.accessoryType = .disclosureIndicator
                return cell
            case .status:
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.account.status", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                if SettingsStore.shared.authMode == "claudeAccount" && ClaudeAccountAuth.shared.isLoggedIn {
                    cell.detailTextLabel?.text = ClaudeAccountAuth.shared.accountDisplayName ?? L("settings.account.loggedIn", "Settings")
                } else {
                    cell.detailTextLabel?.text = L("settings.account.loggedOut", "Settings")
                }
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.selectionStyle = .none
                return cell
            case .cookie:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                if SettingsStore.shared.authMode == "claudeAccount" && ClaudeAccountAuth.shared.isLoggedIn {
                    cell.textLabel?.text = L("settings.account.updateCookie", "Settings")
                } else {
                    cell.textLabel?.text = L("settings.account.loginClaude", "Settings")
                }
                cell.textLabel?.textColor = t.accent
                return cell
            case .webLogin:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("onboarding.choice.browserLogin", "Onboarding")
                cell.textLabel?.textColor = t.accent
                return cell
            case .logout:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.account.logout", "Settings")
                cell.textLabel?.textColor = t.destructive
                return cell
            case .apiKey:
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.account.apikey", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                let key = SettingsStore.shared.apiKey
                cell.detailTextLabel?.text = maskKey(key)
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.accessoryType = .disclosureIndicator
                return cell
            }

        case 2:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.backgroundColor = t.surface
            cell.textLabel?.text = L("settings.appearance.theme", "Settings")
            cell.textLabel?.textColor = t.textPrimary
            cell.detailTextLabel?.text = themeDisplayName(SettingsStore.shared.themeMode)
            cell.detailTextLabel?.textColor = t.textSecondary
            cell.accessoryType = .disclosureIndicator
            return cell

        case 3:
            if indexPath.row == 0 {
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.model.default", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                let m = ModelOption.find(id: SettingsStore.shared.selectedModelId)
                cell.detailTextLabel?.text = m?.displayName ?? SettingsStore.shared.selectedModelId
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.accessoryType = .disclosureIndicator
                return cell
            } else if indexPath.row == 1 {
                return makeSwitchCell(title: L("settings.model.extendedThinking", "Settings"), isOn: SettingsStore.shared.extendedThinking) { v in
                    SettingsStore.shared.extendedThinking = v
                }
            } else if indexPath.row == 2 {
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.model.thinkingBudget", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                cell.detailTextLabel?.text = "\(SettingsStore.shared.thinkingBudget)"
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.accessoryType = .disclosureIndicator
                return cell
            } else if indexPath.row == 3 {
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.model.maxTokens", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                cell.detailTextLabel?.text = "\(SettingsStore.shared.maxTokens)"
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.accessoryType = .disclosureIndicator
                return cell
            } else {
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.model.effort", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                let current = SettingsStore.shared.effort
                cell.detailTextLabel?.text = current.isEmpty ? L("chat.effort.default", "Chat") : SettingsStore.effortDisplayName(current)
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.accessoryType = .disclosureIndicator
                return cell
            }

        case 4:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.backgroundColor = t.surface
            cell.textLabel?.text = L("settings.section.style", "Settings")
            cell.textLabel?.textColor = t.textPrimary
            cell.detailTextLabel?.text = styleDisplayName(SettingsStore.shared.style)
            cell.detailTextLabel?.textColor = t.textSecondary
            cell.accessoryType = .disclosureIndicator
            return cell

        case 5:
            if indexPath.row == 0 {
                return makeSwitchCell(title: L("settings.chat.sendWithReturn", "Settings"), isOn: SettingsStore.shared.sendWithReturn) { v in
                    SettingsStore.shared.sendWithReturn = v
                }
            } else {
                return makeSwitchCell(title: L("settings.chat.haptics", "Settings"), isOn: SettingsStore.shared.haptics) { v in
                    SettingsStore.shared.haptics = v
                }
            }

        case 6:
            if indexPath.row == 0 {
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.data.chatCount", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                cell.detailTextLabel?.text = "\(ConversationStore.shared.allConversations.count)"
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.selectionStyle = .none
                return cell
            } else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.data.deleteAll", "Settings")
                cell.textLabel?.textColor = t.destructive
                return cell
            }

        case 7:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.backgroundColor = t.surface
            cell.textLabel?.text = L("settings.advanced.apiBaseURL", "Settings")
            cell.textLabel?.textColor = t.textPrimary
            cell.detailTextLabel?.text = SettingsStore.shared.apiBaseURL
            cell.detailTextLabel?.textColor = t.textSecondary
            cell.accessoryType = .disclosureIndicator
            return cell

        case 8:
            switch indexPath.row {
            case 0:
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.info.version", "Settings")
                cell.textLabel?.textColor = t.textPrimary
                cell.detailTextLabel?.text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                cell.detailTextLabel?.textColor = t.textSecondary
                cell.selectionStyle = .none
                return cell
            case 1:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.info.description", "Settings")
                cell.textLabel?.textColor = t.textSecondary
                cell.textLabel?.numberOfLines = 0
                cell.selectionStyle = .none
                return cell
            case 2:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.info.terms", "Settings")
                cell.textLabel?.textColor = t.accent
                cell.accessoryType = .disclosureIndicator
                return cell
            default:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = t.surface
                cell.textLabel?.text = L("settings.info.privacy", "Settings")
                cell.textLabel?.textColor = t.accent
                cell.accessoryType = .disclosureIndicator
                return cell
            }

        case 9:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = t.surface
            cell.textLabel?.text = L("settings.signout", "Settings")
            cell.textLabel?.textColor = t.destructive
            cell.textLabel?.textAlignment = .center
            return cell

        default:
            return UITableViewCell()
        }
    }

    private func makeSwitchCell(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> UITableViewCell {
        let t = Theme.current
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = t.surface
        cell.textLabel?.text = title
        cell.textLabel?.textColor = t.textPrimary
        let sw = UISwitch()
        sw.isOn = isOn
        sw.onTintColor = t.accent
        let tag = nextSwitchTag
        nextSwitchTag += 1
        sw.tag = tag
        switchHandlers[tag] = onChange
        sw.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        cell.accessoryView = sw
        cell.selectionStyle = .none
        return cell
    }

    @objc private func switchChanged(_ sender: UISwitch) {
        switchHandlers[sender.tag]?(sender.isOn)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            editName()
        case 1:
            let rows = accountRows()
            guard indexPath.row < rows.count else { break }
            switch rows[indexPath.row] {
            case .authMode:
                let opts: [(String,String?)] = [
                    (L("settings.account.authMode.account", "Settings"), nil),
                    (L("settings.account.authMode.apiKey", "Settings"), nil)
                ]
                let raws = ["claudeAccount", "apiKey"]
                let idx = raws.firstIndex(of: SettingsStore.shared.authMode) ?? 1
                let vc = OptionListViewController(title: L("settings.account.authMode", "Settings"), options: opts, selectedIndex: idx) { i in
                    SettingsStore.shared.authMode = raws[i]
                }
                pushOrPresent(vc)
            case .status:
                break
            case .cookie:
                let vc = CookieLoginViewController()
                vc.onSuccess = { [weak self] in
                    self?.tableView.reloadData()
                }
                if let nav = navigationController {
                    nav.pushViewController(vc, animated: true)
                } else {
                    let nav = ThemedNavigationController(rootViewController: vc)
                    present(nav, animated: true)
                }
            case .webLogin:
                ClaudeAccountAuth.shared.startLogin(from: self) { [weak self] success, message in
                    guard let self = self else { return }
                    if !success {
                        let alert = UIAlertController(title: nil, message: message ?? "ログインに失敗しました。", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                    self.tableView.reloadData()
                }
            case .logout:
                ClaudeAccountAuth.shared.logout()
                self.tableView.reloadData()
            case .apiKey:
                push(ApiKeyViewController())
            }
        case 2:
            showThemePicker()
        case 3:
            if indexPath.row == 0 { showModelPicker() }
            else if indexPath.row == 2 { showThinkingBudgetPicker() }
            else if indexPath.row == 3 { showMaxTokensPicker() }
            else if indexPath.row == 4 { showEffortPicker() }
        case 4:
            showStylePicker()
        case 6:
            if indexPath.row == 1 { confirmDeleteAll() }
        case 7:
            editApiBaseURL()
        case 8:
            if indexPath.row == 2 { openURL("https://www.anthropic.com/legal/consumer-terms") }
            if indexPath.row == 3 { openURL("https://www.anthropic.com/legal/privacy") }
        case 9:
            confirmSignOut()
        default:
            break
        }
    }

    // MARK: - Actions

    private func editName() {
        let vc = TextEditViewController(title: L("settings.profile.editName.title", "Settings"), initialText: SettingsStore.shared.userName, multiline: false, placeholder: L("settings.profile.name", "Settings")) { text in
            SettingsStore.shared.userName = text
        }
        pushOrPresent(vc)
    }

    private func showThemePicker() {
        let opts: [(String,String?)] = [
            (L("settings.appearance.theme.system","Settings"), nil),
            (L("settings.appearance.theme.light","Settings"), nil),
            (L("settings.appearance.theme.dark","Settings"), nil)
        ]
        let raws = ["system","light","dark"]
        let idx = raws.firstIndex(of: SettingsStore.shared.themeMode) ?? 0
        let vc = OptionListViewController(title: L("settings.appearance.theme","Settings"), options: opts, selectedIndex: idx) { i in
            let raw = raws[i]
            SettingsStore.shared.themeMode = raw
            if let mode = ThemeMode(rawValue: raw) { Theme.setMode(mode) }
        }
        pushOrPresent(vc)
    }

    private func showModelPicker() {
        let opts = ModelOption.all.map { ($0.displayName, $0.description) }
        let idx = ModelOption.all.firstIndex { $0.id == SettingsStore.shared.selectedModelId } ?? 0
        let vc = OptionListViewController(title: L("settings.model.default","Settings"), options: opts, selectedIndex: idx) { i in
            SettingsStore.shared.selectedModelId = ModelOption.all[i].id
        }
        pushOrPresent(vc)
    }

    private func showThinkingBudgetPicker() {
        let values = [4000,8000,16000,32000]
        let opts = values.map { ("\($0)", nil as String?) }
        let idx = values.firstIndex(of: SettingsStore.shared.thinkingBudget) ?? 1
        let vc = OptionListViewController(title: L("settings.model.thinkingBudget","Settings"), options: opts, selectedIndex: idx) { i in
            SettingsStore.shared.thinkingBudget = values[i]
        }
        pushOrPresent(vc)
    }

    private func showMaxTokensPicker() {
        let values = [4096,8192,16384,32000]
        let opts = values.map { ("\($0)", nil as String?) }
        let idx = values.firstIndex(of: SettingsStore.shared.maxTokens) ?? 1
        let vc = OptionListViewController(title: L("settings.model.maxTokens","Settings"), options: opts, selectedIndex: idx) { i in
            SettingsStore.shared.maxTokens = values[i]
        }
        pushOrPresent(vc)
    }

    private func showEffortPicker() {
        let keys = ["", "low", "medium", "high", "xhigh", "max"]
        let titles = [
            L("chat.effort.default", "Chat"),
            L("chat.effort.low", "Chat"),
            L("chat.effort.medium", "Chat"),
            L("chat.effort.high", "Chat"),
            L("chat.effort.xhigh", "Chat"),
            L("chat.effort.max", "Chat")
        ]
        let opts = titles.map { ($0, nil as String?) }
        let idx = keys.firstIndex(of: SettingsStore.shared.effort) ?? 0
        let vc = OptionListViewController(title: L("settings.model.effort", "Settings"), options: opts, selectedIndex: idx) { i in
            SettingsStore.shared.effort = keys[i]
        }
        pushOrPresent(vc)
    }

    private func showStylePicker() {
        let keys = ["normal","concise","explanatory","formal"]
        let titles = [
            L("settings.style.normal","Settings"),
            L("settings.style.concise","Settings"),
            L("settings.style.explanatory","Settings"),
            L("settings.style.formal","Settings")
        ]
        let descs = [
            L("settings.style.normal.desc","Settings"),
            L("settings.style.concise.desc","Settings"),
            L("settings.style.explanatory.desc","Settings"),
            L("settings.style.formal.desc","Settings")
        ]
        let opts = zip(titles, descs).map { ($0.0, Optional($0.1)) }
        let idx = keys.firstIndex(of: SettingsStore.shared.style) ?? 0
        let vc = OptionListViewController(title: L("settings.section.style","Settings"), options: opts, selectedIndex: idx) { i in
            SettingsStore.shared.style = keys[i]
        }
        pushOrPresent(vc)
    }

    private func editApiBaseURL() {
        let vc = TextEditViewController(title: L("settings.advanced.apiBaseURL","Settings"), initialText: SettingsStore.shared.apiBaseURL, multiline: false, placeholder: "https://api.anthropic.com") { text in
            SettingsStore.shared.apiBaseURL = text
        }
        pushOrPresent(vc)
    }

    private func confirmDeleteAll() {
        let alert = UIAlertController(title: nil, message: L("settings.data.deleteAllConfirm", "Settings"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.cancel", "Localizable"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("common.delete", "Settings"), style: .destructive) { _ in
            let ids = ConversationStore.shared.allConversations.map { $0.id }
            for id in ids { ConversationStore.shared.delete(id: id) }
        })
        present(alert, animated: true)
    }

    private func confirmSignOut() {
        let alert = UIAlertController(title: nil, message: L("settings.signout.confirm", "Settings"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.cancel", "Localizable"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("settings.signout", "Settings"), style: .destructive) { _ in
            AppRouter.shared.signOut()
        })
        present(alert, animated: true)
    }

    private func openURL(_ s: String) {
        if let url = URL(string: s) { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
    }

    private func pushOrPresent(_ vc: UIViewController) {
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = ThemedNavigationController(rootViewController: vc)
            present(nav, animated: true)
        }
    }

    private func push(_ vc: UIViewController) {
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            present(vc, animated: true)
        }
    }

    // MARK: - Helpers

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return key.isEmpty ? "—" : "••••" }
        return "\(key.prefix(6))…\(key.suffix(4))"
    }

    private func themeDisplayName(_ raw: String) -> String {
        switch raw {
        case "light": return L("settings.appearance.theme.light","Settings")
        case "dark": return L("settings.appearance.theme.dark","Settings")
        default: return L("settings.appearance.theme.system","Settings")
        }
    }

    private func styleDisplayName(_ raw: String) -> String {
        switch raw {
        case "concise": return L("settings.style.concise","Settings")
        case "explanatory": return L("settings.style.explanatory","Settings")
        case "formal": return L("settings.style.formal","Settings")
        default: return L("settings.style.normal","Settings")
        }
    }
}


