import UIKit

final class OptionListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var options: [(title: String, subtitle: String?)] = []
    var selectedIndex: Int = 0
    var onSelect: ((Int) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var themeObserver: NSObjectProtocol?

    init(title: String, options: [(String, String?)], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
        self.options = options.map { ($0.0, $0.1) }
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        tableView.dataSource = self
        tableView.delegate = self
        // no registration; created manually for subtitle style
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        themeObserver = NotificationCenter.default.addObserver(forName: Theme.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
            self?.tableView.reloadData()
        }
    }

    deinit {
        if let o = themeObserver { NotificationCenter.default.removeObserver(o) }
    }

    private func applyTheme() {
        let t = Theme.current
        view.backgroundColor = t.background
        tableView.backgroundColor = t.background
        tableView.separatorColor = t.separator
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let reused = tableView.dequeueReusableCell(withIdentifier: "cell") {
            cell = reused
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        }
        let opt = options[indexPath.row]
        cell.textLabel?.text = opt.title
        cell.detailTextLabel?.text = opt.subtitle
        cell.detailTextLabel?.numberOfLines = 0
        let t = Theme.current
        cell.backgroundColor = t.surface
        cell.textLabel?.textColor = t.textPrimary
        cell.detailTextLabel?.textColor = t.textSecondary
        cell.accessoryType = (indexPath.row == selectedIndex) ? .checkmark : .none
        cell.tintColor = t.accent
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndex = indexPath.row
        onSelect?(indexPath.row)
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
