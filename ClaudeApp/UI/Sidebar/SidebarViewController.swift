import UIKit

final class SidebarViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var starred: [Conversation] = []
    private var recent: [Conversation] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.sidebarBackground

        // Header
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let titleLabel = UILabel()
        titleLabel.text = "Claude"
        titleLabel.font = Fonts.serif(size: 24, weight: .bold)
        titleLabel.textColor = Theme.current.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let searchButton = IconButton(icon: .search, size: 20, tint: Theme.current.textPrimary)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        header.addSubview(searchButton)

        // New chat button
        let newChatButton = UIButton(type: .system)
        newChatButton.translatesAutoresizingMaskIntoConstraints = false
        let icon = Icons.image(.plus, size: 18, color: Theme.current.onAccent)
        newChatButton.setImage(icon, for: .normal)
        newChatButton.setTitle("  " + L("sidebar.newChat", "Sidebar"), for: .normal)
        newChatButton.setTitleColor(Theme.current.accent, for: .normal)
        newChatButton.titleLabel?.font = Fonts.sans(size: 16, weight: .medium)
        newChatButton.contentHorizontalAlignment = .left
        newChatButton.addTarget(self, action: #selector(newChatTapped), for: .touchUpInside)
        view.addSubview(newChatButton)

        // Nav items
        let navStack = UIStackView()
        navStack.axis = .vertical
        navStack.spacing = 4
        navStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navStack)

        let chatItem = makeNavItem(icon: .chat, title: L("sidebar.chats", "Sidebar"))
        chatItem.addTarget(self, action: #selector(chatsTapped), for: .touchUpInside)
        navStack.addArrangedSubview(chatItem)

        let projItem = makeNavItem(icon: .project, title: L("sidebar.projects", "Sidebar"))
        projItem.addTarget(self, action: #selector(projectsTapped), for: .touchUpInside)
        navStack.addArrangedSubview(projItem)

        let artItem = makeNavItem(icon: .artifact, title: L("sidebar.artifacts", "Sidebar"))
        artItem.addTarget(self, action: #selector(artifactsTapped), for: .touchUpInside)
        navStack.addArrangedSubview(artItem)

        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(lp)

        // User row
        let userRow = UIView()
        userRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(userRow)

        let avatar = UIView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.backgroundColor = Theme.current.accent
        avatar.layer.cornerRadius = 16
        userRow.addSubview(avatar)
        let initialLabel = UILabel()
        initialLabel.translatesAutoresizingMaskIntoConstraints = false
        initialLabel.textColor = .white
        initialLabel.font = Fonts.sans(size: 14, weight: .semibold)
        initialLabel.textAlignment = .center
        avatar.addSubview(initialLabel)

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = Fonts.sans(size: 15, weight: .medium)
        nameLabel.textColor = Theme.current.textPrimary
        userRow.addSubview(nameLabel)

        let settingsButton = IconButton(icon: .settings, size: 20, tint: Theme.current.textSecondary)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        userRow.addSubview(settingsButton)

        // Constraints
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            header.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            searchButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            searchButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            newChatButton.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            newChatButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            newChatButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            newChatButton.heightAnchor.constraint(equalToConstant: 40),

            navStack.topAnchor.constraint(equalTo: newChatButton.bottomAnchor, constant: 12),
            navStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            navStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: navStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: userRow.topAnchor),

            userRow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            userRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            userRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            userRow.heightAnchor.constraint(equalToConstant: 56),

            avatar.leadingAnchor.constraint(equalTo: userRow.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: userRow.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 32),
            avatar.heightAnchor.constraint(equalToConstant: 32),

            initialLabel.centerInSuperview(),

            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: userRow.centerYAnchor),

            settingsButton.trailingAnchor.constraint(equalTo: userRow.trailingAnchor, constant: -8),
            settingsButton.centerYAnchor.constraint(equalTo: userRow.centerYAnchor)
        ])

        updateUserName(nameLabel: nameLabel, initialLabel: initialLabel)

        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: Notification.Name("SettingsStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)

        reloadData()
    }

    private func makeNavItem(icon: IconName, title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.contentHorizontalAlignment = .left
        b.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        b.titleEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        b.setImage(Icons.image(icon, size: 20, color: Theme.current.textSecondary), for: .normal)
        b.setTitle(title, for: .normal)
        b.setTitleColor(Theme.current.textPrimary, for: .normal)
        b.titleLabel?.font = Fonts.sans(size: 15)
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return b
    }

    private func updateUserName(nameLabel: UILabel, initialLabel: UILabel) {
        let name = SettingsStore.shared.userName
        nameLabel.text = name.isEmpty ? L("sidebar.user", "Sidebar") : name
        let initial = name.isEmpty ? "C" : String(name.prefix(1)).uppercased()
        initialLabel.text = initial
    }

    @objc private func dataChanged() { reloadData() }
    @objc private func settingsChanged() {
        // refresh user row by re-viewDidLoad? Instead find labels
        reloadData()
    }
    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.sidebarBackground
        reloadData()
    }

    private func reloadData() {
        let all = ConversationStore.shared.allConversations
        starred = all.filter { $0.isStarred }
        recent = all.filter { !$0.isStarred }
        tableView.reloadData()
    }

    @objc private func searchTapped() { AppRouter.shared.openSearch() }
    @objc private func newChatTapped() { AppRouter.shared.startNewChat(projectId: nil) }
    @objc private func chatsTapped() { /* already here */ }
    @objc private func projectsTapped() { AppRouter.shared.openProjects() }
    @objc private func artifactsTapped() { AppRouter.shared.openArtifacts() }
    @objc private func settingsTapped() { AppRouter.shared.openSettings() }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        let hasStarred = !starred.isEmpty
        let conv: Conversation
        if hasStarred {
            conv = (indexPath.section == 0) ? starred[indexPath.row] : recent[indexPath.row]
        } else {
            conv = recent[indexPath.row]
        }
        let cell = tableView.cellForRow(at: indexPath) ?? tableView
        let rect = tableView.rectForRow(at: indexPath)
        showConversationActions(for: conv, sourceView: tableView, sourceRect: rect, in: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension SidebarViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        var count = 0
        if !starred.isEmpty { count += 1 }
        if !recent.isEmpty { count += 1 }
        return max(count, 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let hasStarred = !starred.isEmpty
        if hasStarred {
            if section == 0 { return L("sidebar.starred", "Sidebar") }
            return L("sidebar.recent", "Sidebar")
        } else {
            if section == 0 { return L("sidebar.recent", "Sidebar") }
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let hasStarred = !starred.isEmpty
        if hasStarred {
            if section == 0 { return starred.count }
            return recent.count
        } else {
            if section == 0 { return recent.count }
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let hasStarred = !starred.isEmpty
        let conv: Conversation
        if hasStarred {
            conv = (indexPath.section == 0) ? starred[indexPath.row] : recent[indexPath.row]
        } else {
            conv = recent[indexPath.row]
        }
        cell.textLabel?.text = conv.title
        cell.textLabel?.font = Fonts.sans(size: 15)
        cell.textLabel?.textColor = Theme.current.textPrimary
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        let selectedBg = UIView()
        selectedBg.backgroundColor = Theme.current.sidebarSelected
        cell.selectedBackgroundView = selectedBg
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let hasStarred = !starred.isEmpty
        let conv: Conversation
        if hasStarred {
            conv = (indexPath.section == 0) ? starred[indexPath.row] : recent[indexPath.row]
        } else {
            conv = recent[indexPath.row]
        }
        AppRouter.shared.openConversation(id: conv.id)
        Haptics.light()
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // not used
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return nil
    }

    // Long press
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool { return true }

    // Use gesture for long press
}
// Long press via delegate not enough; add in viewDidLoad? We'll add gesture.
extension SidebarViewController {
    // Add long press handling by overriding? Use a separate setup.
}
