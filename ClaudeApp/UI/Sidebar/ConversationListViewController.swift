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

    private func rebuild() {
        let all = ConversationStore.shared.allConversations
        let cal = Calendar.current
        var groups: [String: [Conversation]] = [:]
        var order: [String] = []
        for conv in all {
            let key: String
            if cal.isDateInToday(conv.updatedAt) { key = L("sidebar.today", "Sidebar") }
            else if cal.isDateInYesterday(conv.updatedAt) { key = L("sidebar.yesterday", "Sidebar") }
            else { key = L("sidebar.older", "Sidebar") }
            if groups[key] == nil { groups[key] = []; order.append(key) }
            groups[key]?.append(conv)
        }
        sections = order.map { (title: $0, items: groups[$0] ?? []) }
        // dedupe order preserving
        var seen = Set<String>()
        var unique: [(String,[Conversation])] = []
        for s in sections {
            if seen.contains(s.title) { continue }
            seen.insert(s.title)
            unique.append((s.title, s.items))
        }
        // merge duplicates
        var merged: [String: [Conversation]] = [:]
        var mergedOrder: [String] = []
        for s in sections {
            if merged[s.title] == nil { merged[s.title] = []; mergedOrder.append(s.title) }
            merged[s.title]?.append(contentsOf: s.items)
        }
        sections = mergedOrder.map { (title: $0, items: merged[$0] ?? []) }
        tableView.reloadData()
    }

    @objc private func dataChanged() { rebuild() }
    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.background
        tableView.reloadData()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        // find conv
        var row = indexPath.row
        for section in sections {
            if row < section.items.count {
                let conv = section.items[row]
                let rect = tableView.rectForRow(at: indexPath)
                showConversationActions(for: conv, sourceView: tableView, sourceRect: rect, in: self)
                return
            }
            row -= section.items.count
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ConversationListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
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
        guard indexPath.section < sections.count, indexPath.row < sections[indexPath.section].items.count else { return cell }
        let conv = sections[indexPath.section].items[indexPath.row]
        cell.textLabel?.text = conv.title
        cell.textLabel?.textColor = Theme.current.textPrimary
        cell.backgroundColor = .clear
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section < sections.count, indexPath.row < sections[indexPath.section].items.count else { return }
        let conv = sections[indexPath.section].items[indexPath.row]
        AppRouter.shared.openConversation(id: conv.id)
    }
}
