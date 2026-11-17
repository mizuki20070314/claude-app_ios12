import UIKit

final class ModelPickerViewController: UIViewController {
    private let selectedId: String
    private let onSelect: (ModelOption) -> Void
    private let tableView = UITableView(frame: .zero, style: .plain)

    private var extendedSwitch: UISwitch?

    init(selectedId: String, onSelect: @escaping (ModelOption) -> Void) {
        self.selectedId = selectedId
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.surface
        title = L("chat.model", "Chat")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.tintColor = Theme.current.accent
        view.addSubview(tableView)

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
        let label = UILabel()
        label.text = L("chat.extendedThinking", "Chat")
        label.font = Fonts.sans(size: 15)
        label.textColor = Theme.current.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        let sw = UISwitch()
        sw.isOn = SettingsStore.shared.extendedThinking
        sw.onTintColor = Theme.current.accent
        sw.addTarget(self, action: #selector(thinkingChanged(_:)), for: .valueChanged)
        sw.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        header.addSubview(sw)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            sw.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            sw.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        extendedSwitch = sw
        tableView.tableHeaderView = header

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        preferredContentSize = CGSize(width: 320, height: 520)

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.surface
        tableView.tintColor = Theme.current.accent
        extendedSwitch?.onTintColor = Theme.current.accent
        tableView.reloadData()
    }

    @objc private func thinkingChanged(_ sw: UISwitch) {
        SettingsStore.shared.extendedThinking = sw.isOn
    }
}

extension ModelPickerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ModelOption.all.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let model = ModelOption.all[indexPath.row]
        cell.textLabel?.text = model.displayName
        cell.detailTextLabel?.text = model.description
        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = (model.id == selectedId) ? .checkmark : .none
        cell.tintColor = Theme.current.accent
        cell.textLabel?.textColor = Theme.current.textPrimary
        cell.detailTextLabel?.textColor = Theme.current.textSecondary
        cell.backgroundColor = Theme.current.surface
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = ModelOption.all[indexPath.row]
        onSelect(model)
        dismiss(animated: true)
    }
}