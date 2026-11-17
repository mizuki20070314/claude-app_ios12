import UIKit

final class SidebarViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let newChatButton = UIButton(type: .system)
    private var sections: [(title: String, items: [Conversation])] = []

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
        newChatButton.translatesAutoresizingMaskIntoConstraints = false
        let circleImage = makePlusCircleImage(size: 28)
        newChatButton.setImage(circleImage, for: .normal)
        newChatButton.setTitle("  " + L("sidebar.newChat", "Sidebar"), for: .normal)
        newChatButton.setTitleColor(Theme.current.accent, for: .normal)
        newChatButton.titleLabel?.font = Fonts.sans(size: 16, weight: .medium)
        newChatButton.contentHorizontalAlignment = .left
        newChatButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
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
        tableView.rowHeight = 44
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

            initialLabel.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            initialLabel.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),

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

    private func makePlusCircleImage(size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { ctx in
            Theme.current.accent.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
            let plus = UIBezierPath()
            let pad = size * 0.28
            plus.move(to: CGPoint(x: pad, y: size / 2))
            plus.addLine(to: CGPoint(x: size - pad, y: size / 2))
            plus.move(to: CGPoint(x: size / 2, y: pad))
            plus.addLine(to: CGPoint(x: size / 2, y: size - pad))
            plus.lineWidth = size * 0.12
            plus.lineCapStyle = .round
            UIColor.white.setStroke()
            plus.stroke()
        }
        return img.withRenderingMode(.alwaysOriginal)
    }

    @objc private func dataChanged() { reloadData() }
    @objc private func settingsChanged() { reloadData() }
    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.sidebarBackground
        newChatButton.setImage(makePlusCircleImage(size: 28), for: .normal)
        reloadData()
    }

    private func bucket(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L("sidebar.today", "Sidebar") }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 7 { return L("sidebar.past7", "Sidebar") }
        if days <= 30 { return L("sidebar.past30", "Sidebar") }
        return L("sidebar.older", "Sidebar")
    }

    private func reloadData() {
        let all = ConversationStore.shared.allConversations
        let starred = all.filter { $0.isStarred }
        let recent = all.filter { !$0.isStarred }

        var newSections: [(title: String, items: [Conversation])] = []
        if !starred.isEmpty {
            newSections.append((L("sidebar.starred", "Sidebar"), starred))
        }
        // group recent by date buckets in fixed order
        var buckets: [String: [Conversation]] = [:]
        for conv in recent {
            let key = bucket(for: conv.updatedAt)
            if buckets[key] == nil { buckets[key] = [] }
            buckets[key]?.append(conv)
        }
        let fixedOrder = [L("sidebar.today", "Sidebar"), L("sidebar.past7", "Sidebar"), L("sidebar.past30", "Sidebar"), L("sidebar.older", "Sidebar")]
        for key in fixedOrder {
            if let items = buckets[key], !items.isEmpty {
                newSections.append((key, items))
            }
        }
        sections = newSections
        tableView.reloadData()
    }

    @objc private func searchTapped() { AppRouter.shared.openSearch() }
    @objc private func newChatTapped() { AppRouter.shared.startNewChat(projectId: nil) }
    @objc private func chatsTapped() { /* already here */ }
    @objc private func projectsTapped() { AppRouter.shared.openProjects() }
    @objc private func artifactsTapped() { AppRouter.shared.openArtifacts() }
    @objc private func settingsTapped() { AppRouter.shared.openSettings() }

    private func conversation(at indexPath: IndexPath) -> Conversation? {
        guard indexPath.section < sections.count else { return nil }
        let sec = sections[indexPath.section]
        guard indexPath.row < sec.items.count else { return nil }
        return sec.items[indexPath.row]
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        guard let conv = conversation(at: indexPath) else { return }
        let rect = tableView.rectForRow(at: indexPath)
        showConversationActions(for: conv, sourceView: tableView, sourceRect: rect, in: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension SidebarViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return max(sections.count, 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < sections.count else { return nil }
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = sections[section].title
        label.font = Fonts.sans(size: 13, weight: .semibold)
        label.textColor = Theme.current.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section < sections.count else { return 0 }
        return 28
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < sections.count else { return 0 }
        return sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let conv = conversation(at: indexPath) else { return cell }
        cell.textLabel?.text = conv.title
        cell.textLabel?.font = Fonts.sans(size: 15)
        cell.textLabel?.textColor = Theme.current.textPrimary
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        let selectedBg = UIView()
        selectedBg.backgroundColor = Theme.current.sidebarSelected
        selectedBg.layer.cornerRadius = 8
        selectedBg.layer.masksToBounds = true
        cell.selectedBackgroundView = selectedBg

        let isCurrent = (conv.id == AppRouter.shared.currentConversationId)
        if isCurrent {
            cell.backgroundColor = Theme.current.sidebarSelected
            cell.layer.cornerRadius = 8
            cell.layer.masksToBounds = true
        } else {
            cell.layer.cornerRadius = 0
            cell.layer.masksToBounds = false
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let conv = conversation(at: indexPath) else { return }
        AppRouter.shared.openConversation(id: conv.id)
        Haptics.light()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}