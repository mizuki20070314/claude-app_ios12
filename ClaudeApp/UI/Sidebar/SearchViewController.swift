import UIKit

final class SearchViewController: UIViewController {
    var initialQuery: String = ""

    private let searchField = UITextField()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var results: [Conversation] = []
    private var currentQuery: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background
        title = L("sidebar.search", "Sidebar")

        let close = IconButton(icon: .close, size: 22, tint: Theme.current.textPrimary)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: close)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholder = L("sidebar.searchPlaceholder", "Sidebar")
        searchField.font = Fonts.sans(size: 15)
        searchField.backgroundColor = Theme.current.surface
        searchField.textColor = Theme.current.textPrimary
        searchField.layer.cornerRadius = 10
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = Theme.current.border.cgColor
        searchField.layer.masksToBounds = true
        searchField.leftView = UIImageView(image: Icons.image(.search, size: 16, color: Theme.current.textTertiary))
        searchField.leftViewMode = .always
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .search
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.delegate = self
        view.addSubview(searchField)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseId)
        tableView.rowHeight = 72
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 40),

            tableView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        applyTheme()

        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)

        if !initialQuery.isEmpty {
            searchField.text = initialQuery
        }
        performSearch(searchField.text ?? "")
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        searchField.backgroundColor = Theme.current.surface
        searchField.textColor = Theme.current.textPrimary
        searchField.layer.borderColor = Theme.current.border.cgColor
        if let leftView = searchField.leftView as? UIImageView {
            leftView.image = Icons.image(.search, size: 16, color: Theme.current.textTertiary)
        }
        tableView.backgroundColor = .clear
        tableView.reloadData()
    }

    private func performSearch(_ query: String) {
        currentQuery = query
        results = ConversationStore.shared.search(query: query)
        tableView.reloadData()
    }

    @objc private func searchChanged() {
        performSearch(searchField.text ?? "")
    }

    @objc private func dataChanged() {
        performSearch(currentQuery.isEmpty ? (searchField.text ?? "") : currentQuery)
    }

    @objc private func themeChanged() {
        applyTheme()
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

extension SearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseId, for: indexPath) as! SearchResultCell
        let conv = results[indexPath.row]
        let snip = snippet(for: conv)
        cell.configure(title: conv.title, snippet: snip, date: relativeDate(conv.updatedAt), query: currentQuery)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conv = results[indexPath.row]
        AppRouter.shared.openConversation(id: conv.id)
    }
}

final class SearchResultCell: UITableViewCell {
    static let reuseId = "SearchResultCell"

    private let titleLabel = UILabel()
    private let snippetLabel = UILabel()
    private let dateLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        titleLabel.font = Fonts.sans(size: 15, weight: .semibold)
        titleLabel.textColor = Theme.current.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        dateLabel.font = Fonts.sans(size: 12)
        dateLabel.textColor = Theme.current.textTertiary
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)

        snippetLabel.font = Fonts.sans(size: 13)
        snippetLabel.textColor = Theme.current.textSecondary
        snippetLabel.numberOfLines = 2
        snippetLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(snippetLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            snippetLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            snippetLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            snippetLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            snippetLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(title: String, snippet: String, date: String, query: String) {
        let t = Theme.current
        titleLabel.text = title
        titleLabel.textColor = t.textPrimary
        dateLabel.text = date
        dateLabel.textColor = t.textTertiary
        snippetLabel.attributedText = SearchResultCell.highlighted(snippet, query: query, baseColor: t.textSecondary, accent: t.accent)
    }

    static func highlighted(_ text: String, query: String, baseColor: UIColor, accent: UIColor) -> NSAttributedString {
        let attr = NSMutableAttributedString(string: text, attributes: [.font: Fonts.sans(size: 13), .foregroundColor: baseColor])
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return attr }
        let ns = text as NSString
        var searchRange = NSRange(location: 0, length: ns.length)
        while true {
            let r = ns.range(of: q, options: .caseInsensitive, range: searchRange)
            if r.location == NSNotFound { break }
            attr.addAttribute(.font, value: Fonts.sans(size: 13, weight: .bold), range: r)
            attr.addAttribute(.foregroundColor, value: accent, range: r)
            let nextLoc = r.location + r.length
            if nextLoc >= ns.length { break }
            searchRange = NSRange(location: nextLoc, length: ns.length - nextLoc)
        }
        return attr
    }
}