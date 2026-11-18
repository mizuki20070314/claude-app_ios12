import UIKit

final class CodeSessionsListViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()

    private var sections: [(title: String, items: [CodeSession])] = []
    private var allSessions: [CodeSession] = []
    private var nextCursor: String?
    private var isLoading = false

    private var isAccountMode: Bool {
        return SettingsStore.shared.authMode == "claudeAccount" && ClaudeAccountAuth.shared.isLoggedIn
    }

    private var isDemo: Bool {
        let s = AppRouter.screenshotScreen
        return s == "code_sessions" || s == "code_session"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background
        title = L("code.sessionsTitle", "Code")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        tableView.pinToSuperview()

        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refreshControl

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)

        if isDemo {
            allSessions = DemoData.codeSessions
            rebuildSections()
        } else if isAccountMode {
            loadSessions(reset: true)
        } else {
            showEmptyAccountState()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.background
        tableView.reloadData()
    }

    @objc private func refreshPulled() {
        if isDemo {
            refreshControl.endRefreshing()
            return
        }
        guard isAccountMode else {
            refreshControl.endRefreshing()
            return
        }
        loadSessions(reset: true)
    }

    private func loadSessions(reset: Bool) {
        guard !isLoading else { return }
        isLoading = true
        if reset {
            nextCursor = nil
            allSessions = []
        }
        ClaudeCodeService.shared.listSessions(cursor: nextCursor) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                self.refreshControl.endRefreshing()
                switch result {
                case .success(let (sessions, cursor)):
                    self.allSessions.append(contentsOf: sessions)
                    self.nextCursor = cursor
                    self.rebuildSections()
                case .failure:
                    break
                }
            }
        }
    }

    private func rebuildSections() {
        let remote = allSessions.filter { $0.isRemoteControl }
        let cloud = allSessions.filter { !$0.isRemoteControl }
        var secs: [(title: String, items: [CodeSession])] = []
        if !remote.isEmpty {
            secs.append((L("code.section.remoteControl", "Code"), remote))
        }
        if !cloud.isEmpty {
            secs.append((L("code.section.cloud", "Code"), cloud))
        }
        sections = secs
        tableView.backgroundView = nil
        tableView.reloadData()
    }

    private func showEmptyAccountState() {
        let label = UILabel()
        label.text = L("code.emptyAccount", "Code")
        label.font = Fonts.sans(size: 15)
        label.textColor = Theme.current.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        let v = UIView()
        v.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: v.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -24),
        ])
        tableView.backgroundView = v
    }

    private func session(at indexPath: IndexPath) -> CodeSession? {
        guard indexPath.section < sections.count else { return nil }
        let sec = sections[indexPath.section]
        guard indexPath.row < sec.items.count else { return nil }
        return sec.items[indexPath.row]
    }

    private func badge(for session: CodeSession) -> (String, UIColor) {
        let t = Theme.current
        if session.connectionStatus == "connected" {
            return (L("code.status.connected", "Code"), t.success)
        }
        if session.workerStatus == "running" {
            return (L("code.status.running", "Code"), t.accent)
        }
        if session.workerStatus == "requires_action" {
            return (L("code.status.requiresAction", "Code"), t.destructive)
        }
        if session.workerStatus == "failed" {
            return (L("code.status.failed", "Code"), t.textTertiary)
        }
        if session.statusBucket == "completed" || session.status == "archived" {
            return (L("code.status.completed", "Code"), t.textTertiary)
        }
        return (L("code.status.idle", "Code"), t.textTertiary)
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L("sidebar.today", "Sidebar") }
        if cal.isDateInYesterday(date) { return L("sidebar.yesterday", "Sidebar") }
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return df.string(from: date)
    }
}

extension CodeSessionsListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        if sections.isEmpty { return 0 }
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
        guard let session = session(at: indexPath) else { return cell }
        cell.backgroundColor = .clear
        cell.selectionStyle = .default

        // Build content
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let titleLabel = UILabel()
        titleLabel.text = session.title
        titleLabel.font = Fonts.sans(size: 15, weight: .semibold)
        titleLabel.textColor = Theme.current.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let (badgeText, badgeColor) = badge(for: session)
        let badgeLabel = UILabel()
        badgeLabel.text = badgeText
        badgeLabel.font = Fonts.sans(size: 11, weight: .medium)
        badgeLabel.textColor = badgeColor
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleText = session.statusLine ?? ""
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitleText
        subtitleLabel.font = Fonts.sans(size: 13)
        subtitleLabel.textColor = Theme.current.textSecondary
        subtitleLabel.numberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let dateLabel = UILabel()
        let d = session.lastEventAt ?? session.updatedAt
        dateLabel.text = relativeDate(d)
        dateLabel.font = Fonts.sans(size: 12)
        dateLabel.textColor = Theme.current.textTertiary
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        cell.contentView.addSubview(titleLabel)
        cell.contentView.addSubview(badgeLabel)
        cell.contentView.addSubview(subtitleLabel)
        cell.contentView.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -8),

            badgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),

            dateLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            dateLabel.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
        ])

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let session = session(at: indexPath) else { return }
        AppRouter.shared.openCodeSession(session)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !isDemo, isAccountMode else { return }
        let lastSection = sections.count - 1
        guard indexPath.section == lastSection else { return }
        guard let sec = sections.last else { return }
        guard indexPath.row == sec.items.count - 1 else { return }
        if nextCursor != nil && !isLoading {
            loadSessions(reset: false)
        }
    }
}