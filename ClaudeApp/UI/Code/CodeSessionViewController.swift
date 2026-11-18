import UIKit

final class CodeSessionViewController: UIViewController {
    private let initialSession: CodeSession
    private var session: CodeSession
    private var items: [CodeTranscriptItem] = []

    private let tableView = UITableView()
    private let footerLabel = UILabel()
    private var headerView: UIView!

    private var subscription: CodeSessionSubscription?
    private var lastSequence: Int = 0

    private var isDemo: Bool {
        let s = AppRouter.screenshotScreen
        return s == "code_sessions" || s == "code_session"
    }

    init(session: CodeSession) {
        self.initialSession = session
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background
        title = session.title

        setupTable()
        setupFooter()
        buildHeader()
        tableView.tableHeaderView = headerView

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)

        if isDemo {
            items = DemoData.codeTranscript
            tableView.reloadData()
            updateHeader()
        } else {
            loadTranscript()
        }
    }

    deinit {
        subscription?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.background
        tableView.reloadData()
        updateHeader()
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.register(CodeUserCell.self, forCellReuseIdentifier: "user")
        tableView.register(CodeAssistantCell.self, forCellReuseIdentifier: "assistant")
        tableView.register(CodeThinkingCell.self, forCellReuseIdentifier: "thinking")
        tableView.register(CodeToolUseCell.self, forCellReuseIdentifier: "toolUse")
        tableView.register(CodeToolResultCell.self, forCellReuseIdentifier: "toolResult")
        tableView.register(CodeStatusCell.self, forCellReuseIdentifier: "status")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor),
        ])
    }

    private func setupFooter() {
        footerLabel.text = L("code.footerNotice", "Code")
        footerLabel.font = Fonts.sans(size: 12)
        footerLabel.textColor = Theme.current.textTertiary
        footerLabel.textAlignment = .center
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerLabel)
        NSLayoutConstraint.activate([
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            footerLabel.heightAnchor.constraint(equalToConstant: 20),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(footerThemeChanged), name: Theme.didChange, object: nil)
    }

    @objc private func footerThemeChanged() {
        footerLabel.textColor = Theme.current.textTertiary
    }

    private func buildHeader() {
        let v = UIView()
        v.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = session.title
        titleLabel.font = Fonts.sans(size: 17, weight: .semibold)
        titleLabel.textColor = Theme.current.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let envText = session.isRemoteControl ? L("code.environment.remote", "Code") : L("code.environment.cloud", "Code")
        let envLabel = UILabel()
        envLabel.text = envText
        envLabel.font = Fonts.sans(size: 13)
        envLabel.textColor = Theme.current.textSecondary
        envLabel.translatesAutoresizingMaskIntoConstraints = false

        let modelLabel = UILabel()
        modelLabel.text = session.model ?? ""
        modelLabel.font = Fonts.sans(size: 12)
        modelLabel.textColor = Theme.current.textTertiary
        modelLabel.translatesAutoresizingMaskIntoConstraints = false

        let (badgeText, badgeColor) = badge(for: session)
        let badgeLabel = UILabel()
        badgeLabel.text = badgeText
        badgeLabel.font = Fonts.sans(size: 12, weight: .medium)
        badgeLabel.textColor = badgeColor
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(titleLabel)
        v.addSubview(envLabel)
        v.addSubview(modelLabel)
        v.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),

            badgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            badgeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),

            envLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            envLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),

            modelLabel.topAnchor.constraint(equalTo: envLabel.bottomAnchor, constant: 2),
            modelLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            modelLabel.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -8),
        ])

        v.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 80)
        headerView = v
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

    private func updateHeader() {
        guard let v = headerView else { return }
        // rebuild
        v.subviews.forEach { $0.removeFromSuperview() }
        // simpler: reload by rebuilding
        buildHeader()
        tableView.tableHeaderView = headerView
    }

    private func loadTranscript() {
        let spinner = UIActivityIndicatorView(style: Theme.current.isDark ? .white : .gray)
        spinner.startAnimating()
        spinner.center = view.center
        view.addSubview(spinner)

        ClaudeCodeService.shared.loadTranscript(sessionId: session.id) { [weak self] result in
            guard let self = self else { return }
            spinner.removeFromSuperview()
            switch result {
            case .success(let (items, lastSeq)):
                self.items = items
                self.lastSequence = lastSeq
                self.tableView.reloadData()
                self.scrollToBottom(false)
                if self.session.isLive {
                    self.subscribe()
                }
            case .failure:
                let label = UILabel()
                label.text = L("code.error", "Code")
                label.textColor = Theme.current.destructive
                label.textAlignment = .center
                label.frame = self.view.bounds
                self.view.addSubview(label)
                let btn = UIButton(type: .system)
                btn.setTitle(L("code.retry", "Code"), for: .normal)
                btn.addTarget(self, action: #selector(self.retryLoad), for: .touchUpInside)
                btn.sizeToFit()
                btn.center = CGPoint(x: self.view.center.x, y: self.view.center.y + 30)
                self.view.addSubview(btn)
            }
        }
    }

    @objc private func retryLoad() {
        // remove error views
        for v in view.subviews where (v is UILabel || v is UIButton) {
            if v !== footerLabel { v.removeFromSuperview() }
        }
        loadTranscript()
    }

    private func subscribe() {
        subscription?.cancel()
        subscription = ClaudeCodeService.shared.subscribe(sessionId: session.id, fromSequence: lastSequence + 1, onItems: { [weak self] newItems in
            guard let self = self else { return }
            self.items.append(contentsOf: newItems)
            self.tableView.reloadData()
            self.scrollToBottom(true)
        }, onSessionUpdate: { [weak self] sess in
            self?.session = sess
            self?.updateHeader()
        })
    }

    private func scrollToBottom(_ animated: Bool) {
        guard items.count > 0 else { return }
        let last = IndexPath(row: items.count - 1, section: 0)
        tableView.scrollToRow(at: last, at: .bottom, animated: animated)
    }

    private func isNearBottom() -> Bool {
        let threshold: CGFloat = 80
        let contentOffset = tableView.contentOffset.y
        let visibleHeight = tableView.bounds.height
        let contentHeight = tableView.contentSize.height
        return contentOffset + visibleHeight >= contentHeight - threshold
    }
}

extension CodeSessionViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        switch item {
        case .user(let text, let isSynthetic, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "user", for: indexPath) as! CodeUserCell
            cell.configure(text: text)
            cell.contentView.alpha = isSynthetic ? 0.5 : 1.0
            return cell
        case .assistant(let text, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "assistant", for: indexPath) as! CodeAssistantCell
            cell.configure(text: text)
            return cell
        case .thinking(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: "thinking", for: indexPath) as! CodeThinkingCell
            cell.configure(text: text)
            return cell
        case .toolUse(_, let name, let summary):
            let cell = tableView.dequeueReusableCell(withIdentifier: "toolUse", for: indexPath) as! CodeToolUseCell
            cell.configure(name: name, summary: summary)
            return cell
        case .toolResult(_, let text, let isError):
            let cell = tableView.dequeueReusableCell(withIdentifier: "toolResult", for: indexPath) as! CodeToolResultCell
            cell.configure(text: text, isError: isError)
            return cell
        case .status(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath) as! CodeStatusCell
            cell.configure(text: text)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}