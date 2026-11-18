import UIKit

final class ConversationListViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var sections: [(title: String, items: [Conversation])] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background
        title = L("sidebar.chats", "Sidebar")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 44
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        tableView.pinToSuperview()

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(lp)

        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)

        rebuild()
    }

    private func bucket(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L("sidebar.today", "Sidebar") }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 7 { return L("sidebar.past7", "Sidebar") }
        if days <= 30 { return L("sidebar.past30", "Sidebar") }
        return L("sidebar.older", "Sidebar")
    }

    private func rebuild() {
        let all = ConversationStore.shared.allConversations
        // pinned section
        let pinned = all.filter { $0.isStarred }
        let recent = all.filter { !$0.isStarred }
        var newSections: [(title: String, items: [Conversation])] = []
        if !pinned.isEmpty {
            newSections.append((L("sidebar.pinned", "Sidebar"), pinned))
        }
        var buckets: [String: [Conversation]] = [:]
        for conv in recent {
            let key = bucket(for: conv.sortDate)
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

    @objc private func dataChanged() { rebuild() }
    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.background
        tableView.reloadData()
    }

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

extension ConversationListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return max(sections.count, 1)
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < sections.count else { return nil }
        return sections[section].title
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
        let selectedBg = UIView()
        selectedBg.backgroundColor = Theme.current.sidebarSelected
        selectedBg.layer.cornerRadius = 8
        cell.selectedBackgroundView = selectedBg
        if conv.id == AppRouter.shared.currentConversationId {
            cell.backgroundColor = Theme.current.sidebarSelected
            cell.layer.cornerRadius = 8
            cell.layer.masksToBounds = true
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let conv = conversation(at: indexPath) else { return }
        AppRouter.shared.openConversation(id: conv.id)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}