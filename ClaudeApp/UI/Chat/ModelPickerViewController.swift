import UIKit

final class ModelPickerViewController: UIViewController {
    private var selectedId: String
    private let onSelect: (ModelOption) -> Void
    private let tableView = UITableView(frame: .zero, style: .plain)

    private var effortSegmentedControl: UISegmentedControl?
    private var effortRowView: UIView?
    private var effortRowHeightConstraint: NSLayoutConstraint?
    private var settingsObserver: NSObjectProtocol?

    private var availableModels: [ModelOption] {
        if SettingsStore.shared.authMode == "claudeAccount" {
            let ids = ClaudeAccountClient.shared.claudeAccountModelIds
            if !ids.isEmpty {
                let filtered = ModelOption.all.filter { ids.contains($0.id) }
                if !filtered.isEmpty { return filtered }
            }
        }
        return ModelOption.all
    }

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

        buildHeader()

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        updatePreferredContentSize()

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
        settingsObserver = NotificationCenter.default.addObserver(forName: SettingsStore.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.refreshEffortRow()
        }
    }

    private func buildHeader() {
        let header = UIView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8),
        ])

        // Extended thinking row
        let thinkingRow = UIView()
        thinkingRow.translatesAutoresizingMaskIntoConstraints = false
        thinkingRow.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let tLabel = UILabel()
        tLabel.text = L("chat.extendedThinking", "Chat")
        tLabel.font = Fonts.sans(size: 15)
        tLabel.textColor = Theme.current.textPrimary
        tLabel.translatesAutoresizingMaskIntoConstraints = false
        let sw = UISwitch()
        sw.isOn = SettingsStore.shared.extendedThinking
        sw.onTintColor = Theme.current.accent
        sw.addTarget(self, action: #selector(thinkingChanged(_:)), for: .valueChanged)
        sw.translatesAutoresizingMaskIntoConstraints = false
        thinkingRow.addSubview(tLabel)
        thinkingRow.addSubview(sw)
        NSLayoutConstraint.activate([
            tLabel.leadingAnchor.constraint(equalTo: thinkingRow.leadingAnchor, constant: 16),
            tLabel.centerYAnchor.constraint(equalTo: thinkingRow.centerYAnchor),
            sw.trailingAnchor.constraint(equalTo: thinkingRow.trailingAnchor, constant: -16),
            sw.centerYAnchor.constraint(equalTo: thinkingRow.centerYAnchor),
        ])
        extendedSwitch = sw
        stack.addArrangedSubview(thinkingRow)

        // Effort row
        let effortRow = UIView()
        effortRow.translatesAutoresizingMaskIntoConstraints = false
        let effortRowHeight = effortRow.heightAnchor.constraint(equalToConstant: 84)
        effortRowHeight.isActive = true
        effortRowHeightConstraint = effortRowHeight
        let eLabel = UILabel()
        eLabel.text = L("chat.effort", "Chat")
        eLabel.font = Fonts.sans(size: 15)
        eLabel.textColor = Theme.current.textPrimary
        eLabel.translatesAutoresizingMaskIntoConstraints = false
        effortRow.addSubview(eLabel)
        NSLayoutConstraint.activate([
            eLabel.leadingAnchor.constraint(equalTo: effortRow.leadingAnchor, constant: 16),
            eLabel.topAnchor.constraint(equalTo: effortRow.topAnchor, constant: 8),
        ])

        let seg = UISegmentedControl(items: [])
        seg.apportionsSegmentWidthsByContent = true
        seg.tintColor = Theme.current.accent
        seg.addTarget(self, action: #selector(effortChanged(_:)), for: .valueChanged)
        seg.translatesAutoresizingMaskIntoConstraints = false
        effortRow.addSubview(seg)
        NSLayoutConstraint.activate([
            seg.leadingAnchor.constraint(equalTo: effortRow.leadingAnchor, constant: 16),
            seg.trailingAnchor.constraint(lessThanOrEqualTo: effortRow.trailingAnchor, constant: -16),
            seg.topAnchor.constraint(equalTo: eLabel.bottomAnchor, constant: 6),
        ])
        effortSegmentedControl = seg
        effortRowView = effortRow
        stack.addArrangedSubview(effortRow)

        tableView.tableHeaderView = header

        // size header
        header.frame = CGRect(x: 0, y: 0, width: 320, height: 0)
        header.layoutIfNeeded()
        let h = stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        header.frame = CGRect(x: 0, y: 0, width: 320, height: h)
        tableView.tableHeaderView = header

        refreshEffortRow()
    }

    private func updatePreferredContentSize() {
        let base: CGFloat = 60
        let perModel: CGFloat = 60
        let effortExtra: CGFloat = (effortRowView?.isHidden == false) ? 90 : 0
        let h = base + CGFloat(availableModels.count) * perModel + effortExtra
        preferredContentSize = CGSize(width: 320, height: max(320, h))
    }

    private func refreshEffortRow() {
        guard let seg = effortSegmentedControl, let row = effortRowView else { return }
        let opts = ClaudeAccountClient.shared.effortOptions(for: selectedId)
        if opts.isEmpty {
            row.isHidden = true
            effortRowHeightConstraint?.constant = 0
            seg.removeAllSegments()
        } else {
            row.isHidden = false
            effortRowHeightConstraint?.constant = 84
            // rebuild segments
            seg.removeAllSegments()
            seg.insertSegment(withTitle: L("chat.effort.default", "Chat"), at: 0, animated: false)
            for (i, opt) in opts.enumerated() {
                seg.insertSegment(withTitle: effortLabel(for: opt), at: i + 1, animated: false)
            }
            // selection: saved effort if supported else default (0); don't erase saved value
            let saved = SettingsStore.shared.effort
            if !saved.isEmpty, let idx = opts.firstIndex(of: saved) {
                seg.selectedSegmentIndex = idx + 1
            } else {
                seg.selectedSegmentIndex = 0
            }
        }
        // resize header
        if let header = tableView.tableHeaderView {
            let stack = header.subviews.first as? UIStackView
            header.frame = CGRect(x: 0, y: 0, width: 320, height: 0)
            header.layoutIfNeeded()
            let h = stack?.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height ?? 120
            header.frame = CGRect(x: 0, y: 0, width: 320, height: h)
            tableView.tableHeaderView = header
        }
        updatePreferredContentSize()
    }

    private func effortLabel(for id: String) -> String {
        switch id {
        case "low": return L("chat.effort.low", "Chat")
        case "medium": return L("chat.effort.medium", "Chat")
        case "high": return L("chat.effort.high", "Chat")
        case "xhigh": return L("chat.effort.xhigh", "Chat")
        case "max": return L("chat.effort.max", "Chat")
        default: return id
        }
    }

    @objc private func effortChanged(_ seg: UISegmentedControl) {
        let opts = ClaudeAccountClient.shared.effortOptions(for: selectedId)
        if seg.selectedSegmentIndex == 0 {
            SettingsStore.shared.effort = ""
        } else {
            let idx = seg.selectedSegmentIndex - 1
            if idx >= 0 && idx < opts.count {
                SettingsStore.shared.effort = opts[idx]
            }
        }
    }

    deinit {
        if let o = settingsObserver { NotificationCenter.default.removeObserver(o) }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.surface
        tableView.tintColor = Theme.current.accent
        extendedSwitch?.onTintColor = Theme.current.accent
        effortSegmentedControl?.tintColor = Theme.current.accent
        tableView.reloadData()
    }

    @objc private func thinkingChanged(_ sw: UISwitch) {
        SettingsStore.shared.extendedThinking = sw.isOn
    }
}

extension ModelPickerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let model = availableModels[indexPath.row]
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
        let model = availableModels[indexPath.row]
        selectedId = model.id
        refreshEffortRow()
        onSelect(model)
        dismiss(animated: true)
    }
}