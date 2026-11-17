import UIKit

final class SearchViewController: UIViewController {
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var results: [Conversation] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background
        title = L("sidebar.search", "Sidebar")

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = L("sidebar.searchPlaceholder", "Sidebar")
        searchBar.delegate = self
        view.addSubview(searchBar)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    func setQuery(_ query: String) {
        searchBar.text = query
        performSearch(query)
    }

    private func performSearch(_ query: String) {
        results = ConversationStore.shared.search(query: query)
        tableView.reloadData()
    }

    @objc private func dataChanged() {
        if let q = searchBar.text { performSearch(q) }
    }

    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.background
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let conv = results[indexPath.row]
        cell.textLabel?.text = conv.title
        cell.textLabel?.textColor = Theme.current.textPrimary
        cell.backgroundColor = .clear
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conv = results[indexPath.row]
        AppRouter.shared.openConversation(id: conv.id)
    }
}
