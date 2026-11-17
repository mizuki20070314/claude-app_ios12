import UIKit

final class SearchViewController: UIViewController {
    private let topBar = UIView()
    private let closeButton = IconButton(icon: .close, size: 22, tint: Theme.current.textPrimary)
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var results: [Conversation] = []
    private var currentQuery: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background
        title = L("sidebar.search", "Sidebar")

        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = L("sidebar.searchPlaceholder", "Sidebar")
        searchBar.delegate = self
        topBar.addSubview(searchBar)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        // cells created with subtitle style manually
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 56),

            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 4),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            searchBar.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -8),
            searchBar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        applyTheme()

        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    func setQuery(_ query: String) {
        currentQuery = query
        searchBar.text = query
        applySearchFieldStyle()
        performSearch(query)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        topBar.backgroundColor = Theme.current.background
        applySearchFieldStyle()
    }

    private func applySearchFieldStyle() {
        let t = Theme.current
        searchBar.barTintColor = t.background
        searchBar.backgroundColor = t.background
        if let tf = searchBar.value(forKey: "searchField") as? UITextField {
            tf.backgroundColor = t.surface
            tf.textColor = t.textPrimary
            tf.layer.cornerRadius = 8
            tf.layer.borderWidth = 1
            tf.layer.borderColor = t.border.cgColor
            tf.layer.masksToBounds = true
        } else {
            // fallback for iOS 12 variants
            searchBar.layer.cornerRadius = 8
        }
    }

    private func performSearch(_ query: String) {
        currentQuery = query
        results = ConversationStore.shared.search(query: query)
        tableView.reloadData()
    }

    @objc private func dataChanged() {
        performSearch(currentQuery.isEmpty ? (searchBar.text ?? "") : currentQuery)
    }

    @objc private func themeChanged() {
        applyTheme()
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            AppRouter.shared.startNewChat()
        }
    }

    private func snippet(for conv: Conversation) -> String {
        let q = currentQuery.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        for m in conv.messages {
            let text = m.text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            if q.isEmpty || text.contains(q) {
                let t = m.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty {
                    return t.count > 90 ? String(t.prefix(90)) + "…" : t
                }
            }
        }
        if let last = conv.messages.last?.text.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            return last.count > 90 ? String(last.prefix(90)) + "…" : last
        }
        return ""
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L("sidebar.today", "Sidebar") }
        if cal.isDateInYesterday(date) { return L("sidebar.yesterday", "Sidebar") }
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return df.string(from: date)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        performSearch(searchText)
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let conv = results[indexPath.row]
        cell.textLabel?.text = conv.title
        cell.textLabel?.font = Fonts.sans(size: 16, weight: .medium)
        cell.textLabel?.textColor = Theme.current.textPrimary
        let snip = snippet(for: conv)
        let date = relativeDate(conv.updatedAt)
        cell.detailTextLabel?.text = snip.isEmpty ? date : "\(snip)\n\(date)"
        cell.detailTextLabel?.font = Fonts.sans(size: 13)
        cell.detailTextLabel?.textColor = Theme.current.textSecondary
        cell.detailTextLabel?.numberOfLines = 2
        cell.backgroundColor = .clear
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conv = results[indexPath.row]
        AppRouter.shared.openConversation(id: conv.id)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
}