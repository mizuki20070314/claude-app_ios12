import UIKit

final class ChatViewController: UIViewController {
    private let conversationIdParam: String?
    private let projectIdParam: String?

    private let tableView = UITableView()
    private let composerView = ComposerView()
    private var composerBottomConstraint: NSLayoutConstraint!

    private var messages: [Message] = []
    private var conversation: Conversation?
    private var isStreaming: Bool = false
    private var streamHandle: StreamHandle?
    private var userCancelled: Bool = false
    private var hasGeneratedTitle: Bool = false

    private var lastTableUpdate: Date = .distantPast
    private var pendingTableUpdate: Bool = false

    // account_live screenshot mode state
    private var accountLiveStarted: Bool = false
    private var accountLiveStep: Int = 0
    private var accountLiveError: String? = nil
    private var accountLiveStage: String = ""

    init(conversationId: String?, projectId: String?) {
        self.conversationIdParam = conversationId
        self.projectIdParam = projectId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background
        setupTableView()
        setupComposer()
        setupNavigation()
        setupEmptyStateIfNeeded()

        if let cid = conversationIdParam {
            loadConversation(id: cid)
        } else {
            // home state
            conversation = nil
            showEmptyState(true)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        composerView.delegate = self
        composerView.selectedModelId = SettingsStore.shared.selectedModelId
        composerView.thinkingEnabled = SettingsStore.shared.extendedThinking

        // screenshot mode: no keyboard auto-focus
        let screenshot = AppRouter.screenshotScreen
        if screenshot == nil {
            // not auto-focus; keep default
        }

        if screenshot != nil {
            // scroll to top after load
            DispatchQueue.main.async { [weak self] in
                self?.tableView.setContentOffset(.zero, animated: false)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        streamHandle?.cancel()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UserMessageCell.self, forCellReuseIdentifier: "user")
        tableView.register(AssistantMessageCell.self, forCellReuseIdentifier: "assistant")
        view.addSubview(tableView)

        let heightSafety = tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        heightSafety.priority = .defaultHigh
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightSafety,
        ])
    }

    private func setupComposer() {
        composerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(composerView)
        composerBottomConstraint = composerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
        NSLayoutConstraint.activate([
            composerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerBottomConstraint,
            tableView.bottomAnchor.constraint(equalTo: composerView.topAnchor),
        ])
        composerView.setContentHuggingPriority(.required, for: .vertical)
        composerView.setContentCompressionResistancePriority(.required, for: .vertical)
        tableView.setContentHuggingPriority(.defaultLow, for: .vertical)
        tableView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if composerBottomConstraint.constant == 0 {
            composerBottomConstraint.constant = -view.safeAreaInsets.bottom
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if AppRouter.screenshotScreen == "account_live" && !accountLiveStarted {
            accountLiveStarted = true
            accountLiveStep = 1
            send(text: "日本語で一言あいさつしてください。", attachments: [])
        }
    }

    private var emptyStateView: UIView?

    private func setupEmptyStateIfNeeded() {
        // built lazily
    }

    private func showEmptyState(_ show: Bool) {
        if show {
            if emptyStateView == nil { createEmptyStateView() }
            tableView.backgroundView = emptyStateView
        } else {
            tableView.backgroundView = nil
        }
    }

    private func createEmptyStateView() {
        let v = UIView()
        let spark = SparkView()
        spark.color = Theme.current.accent
        spark.startPulsing()
        spark.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(spark)

        let greeting = UILabel()
        greeting.font = Fonts.serif(size: 28)
        greeting.textColor = Theme.current.textPrimary
        greeting.textAlignment = .center
        greeting.numberOfLines = 0
        greeting.translatesAutoresizingMaskIntoConstraints = false
        let name = SettingsStore.shared.userName
        if name.isEmpty {
            greeting.text = L("chat.emptySubtitle", "Chat")
        } else {
            greeting.text = String(format: L("chat.emptyTitle", "Chat"), name)
        }
        v.addSubview(greeting)

        var chip: UIView?
        if let pid = projectIdParam, let project = ConversationStore.shared.project(id: pid) {
            let c = UIView()
            c.backgroundColor = Theme.current.surface
            c.layer.cornerRadius = 12
            c.translatesAutoresizingMaskIntoConstraints = false
            let l = UILabel()
            l.text = project.name
            l.font = Fonts.sans(size: 13, weight: .medium)
            l.textColor = Theme.current.textPrimary
            l.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(l)
            NSLayoutConstraint.activate([
                l.topAnchor.constraint(equalTo: c.topAnchor, constant: 6),
                l.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -6),
                l.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 12),
                l.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -12),
            ])
            v.addSubview(c)
            chip = c
        }

        NSLayoutConstraint.activate([
            spark.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            spark.centerYAnchor.constraint(equalTo: v.centerYAnchor, constant: -32),
            spark.widthAnchor.constraint(equalToConstant: 48),
            spark.heightAnchor.constraint(equalToConstant: 48),

            greeting.topAnchor.constraint(equalTo: spark.bottomAnchor, constant: 44),
            greeting.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            greeting.leadingAnchor.constraint(greaterThanOrEqualTo: v.leadingAnchor, constant: 24),
            greeting.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -24),
        ])

        if let c = chip {
            NSLayoutConstraint.activate([
                c.topAnchor.constraint(equalTo: greeting.bottomAnchor, constant: 12),
                c.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            ])
        }

        emptyStateView = v
    }

    private func setupNavigation() {
        // left menu button if not persistent
        if !AppRouter.shared.isSidebarPersistent {
            let menu = IconButton(icon: .menu, size: 22, tint: Theme.current.textPrimary)
            menu.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: menu)
        }
        // right new chat
        let newChat = IconButton(icon: .newChat, size: 22, tint: Theme.current.textPrimary)
        newChat.addTarget(self, action: #selector(newChatTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: newChat)

        updateTitleView()
    }

    @objc private func menuTapped() { AppRouter.shared.toggleSidebar() }
    @objc private func newChatTapped() { AppRouter.shared.startNewChat(projectId: nil) }

    private func updateTitleView() {
        if conversation == nil {
            navigationItem.titleView = nil
            navigationItem.title = nil
            return
        }
        let btn = UIButton(type: .system)
        btn.setTitle((conversation?.title ?? "") + "  ", for: .normal)
        btn.setImage(Icons.image(.chevronDown, size: 12, color: Theme.current.textPrimary), for: .normal)
        btn.semanticContentAttribute = .forceRightToLeft
        btn.titleLabel?.font = Fonts.sans(size: 17, weight: .semibold)
        btn.setTitleColor(Theme.current.textPrimary, for: .normal)
        btn.addTarget(self, action: #selector(titleTapped), for: .touchUpInside)
        navigationItem.titleView = btn
    }

    @objc private func titleTapped() {
        guard let conv = conversation else { return }
        let sheet = ChatOptionsSheet(conversation: conv, onChange: { [weak self] in
            self?.reloadConversationFromStore()
        })
        BottomSheetController.present(sheet, from: self)
    }

    private func reloadConversationFromStore() {
        if let id = conversation?.id, let c = ConversationStore.shared.conversation(id: id) {
            conversation = c
            messages = c.messages
            tableView.reloadData()
            updateTitleView()
        }
    }

    private func loadConversation(id: String) {
        if let c = ConversationStore.shared.conversation(id: id) {
            conversation = c
            messages = c.messages
            hasGeneratedTitle = !c.title.isEmpty && c.title != "新規チャット"
            showEmptyState(messages.isEmpty)
            tableView.reloadData()
            updateTitleView()
            if AppRouter.screenshotScreen != nil {
                DispatchQueue.main.async { [weak self] in
                    self?.tableView.setContentOffset(.zero, animated: false)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.scrollToBottom(animated: false)
                }
            }
        }
    }

    // MARK: - Theme

    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.background
        tableView.reloadData()
        applyComposerTheme()
    }

    private func applyComposerTheme() {
        // ComposerView handles its own
    }

    // MARK: - Keyboard

    @objc private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        let keyboardHeight = max(0, view.bounds.height - converted.origin.y)
        composerBottomConstraint.constant = -max(keyboardHeight, view.safeAreaInsets.bottom)
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    // MARK: - Sending

    private func send(text: String, attachments: [Attachment]) {
        let isNewConversation = (conversation == nil)
        // create conversation if nil
        if conversation == nil {
            let model = SettingsStore.shared.selectedModelId
            var conv = Conversation(title: "新規チャット", projectId: projectIdParam, model: model, messages: [])
            conversation = conv
            // ensure id
            ConversationStore.shared.save(conv)
        }
        guard var conv = conversation else { return }

        // user message
        let userMsg = Message(role: .user, text: text, attachments: attachments)
        messages.append(userMsg)
        conv.messages.append(userMsg)
        conversation = conv
        ConversationStore.shared.save(conv)

        showEmptyState(false)
        tableView.reloadData()
        scrollToBottom(animated: true)

        // assistant placeholder
        let assistantMsg = Message(role: .assistant, text: "", model: conv.model)
        messages.append(assistantMsg)
        conv.messages.append(assistantMsg)
        conversation = conv

        let assistantIndex = messages.count - 1
        let userIndex = messages.count - 2
        tableView.reloadData()
        scrollToBottom(animated: false)

        isStreaming = true
        composerView.isStreaming = true
        userCancelled = false

        // system prompt
        let project = projectIdParam.flatMap { ConversationStore.shared.project(id: $0) } ?? conv.projectId.flatMap { ConversationStore.shared.project(id: $0) }
        let system = AnthropicClient.buildSystemPrompt(style: SettingsStore.shared.style, userName: SettingsStore.shared.userName, project: project)

        let apiMessages = Array(conv.messages.dropLast()) // exclude assistant placeholder

        streamHandle = AnthropicClient.shared.streamMessage(
            model: conv.model,
            messages: apiMessages,
            system: system,
            maxTokens: SettingsStore.shared.maxTokens,
            thinkingEnabled: SettingsStore.shared.extendedThinking,
            thinkingBudget: SettingsStore.shared.thinkingBudget,
            conversationId: conv.id,
            isNewConversation: isNewConversation,
            onThinkingDelta: { [weak self] delta in
                guard let self = self else { return }
                self.messages[assistantIndex].thinking = (self.messages[assistantIndex].thinking ?? "") + delta
                if let cell = self.tableView.cellForRow(at: IndexPath(row: assistantIndex, section: 0)) as? AssistantMessageCell {
                    cell.thinkingView.append(delta)
                }
            },
            onTextDelta: { [weak self] delta in
                guard let self = self else { return }
                self.messages[assistantIndex].text += delta
                if let cell = self.tableView.cellForRow(at: IndexPath(row: assistantIndex, section: 0)) as? AssistantMessageCell {
                    cell.updateMarkdown(self.messages[assistantIndex].text)
                }
                self.scheduleTableUpdate()
            },
            onComplete: { [weak self] _ in
                guard let self = self else { return }
                self.isStreaming = false
                self.composerView.isStreaming = false
                self.streamHandle = nil
                if let cell = self.tableView.cellForRow(at: IndexPath(row: assistantIndex, section: 0)) as? AssistantMessageCell {
                    cell.setStreaming(false)
                    cell.configure(message: self.messages[assistantIndex], isStreaming: false)
                }
                self.messages[assistantIndex].model = self.conversation?.model ?? conv.model
                var c = self.conversation!
                c.messages = self.messages
                c.updatedAt = Date()
                self.conversation = c
                ConversationStore.shared.save(c)
                self.updateTitleView()

                if AppRouter.screenshotScreen == "account_live" {
                    if self.accountLiveStep == 1 {
                        self.accountLiveStep = 2
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.send(text: "今の返事を英語に訳してください。", attachments: [])
                        }
                    } else if self.accountLiveStep == 2 {
                        self.accountLiveStep = 3
                        self.accountLiveStage = "second"
                        self.writeAccountLiveResult()
                    }
                }

                // generate title after first exchange
                if !self.hasGeneratedTitle {
                    self.hasGeneratedTitle = true
                    let firstUserText = self.messages.first(where: { $0.role == .user })?.text ?? ""
                    let assistantText = self.messages[assistantIndex].text
                    AnthropicClient.shared.generateTitle(for: firstUserText, assistantText: assistantText, conversationId: self.conversation?.id, completion: { title in
                        guard let title = title, !title.isEmpty else { return }
                        if var c2 = self.conversation {
                            c2.title = title
                            self.conversation = c2
                            ConversationStore.shared.save(c2)
                            self.updateTitleView()
                        }
                    })
                }

                self.finalTableUpdate()
            },
            onError: { [weak self] error in
                guard let self = self else { return }
                self.isStreaming = false
                self.composerView.isStreaming = false
                self.streamHandle = nil

                var cancelled = self.userCancelled
                if let e = error as? AnthropicError {
                    if case .cancelled = e { cancelled = true }
                }
                if let e = error as? ClaudeAccountError {
                    if case .cancelled = e { cancelled = true }
                }

                if cancelled {
                    // Keep partial text after a user cancel or an account-cancel event.
                    if var c = self.conversation {
                        c.messages = self.messages
                        self.conversation = c
                        ConversationStore.shared.save(c)
                    }
                    self.userCancelled = false
                } else {
                    self.messages[assistantIndex].isError = true
                    let desc = (error as NSError).localizedDescription
                    self.messages[assistantIndex].errorText = desc
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: assistantIndex, section: 0)) as? AssistantMessageCell {
                        cell.configure(message: self.messages[assistantIndex], isStreaming: false)
                    }
                    if var c = self.conversation {
                        c.messages = self.messages
                        self.conversation = c
                        ConversationStore.shared.save(c)
                    }
                }

                if let cell = self.tableView.cellForRow(at: IndexPath(row: assistantIndex, section: 0)) as? AssistantMessageCell {
                    cell.setStreaming(false)
                }

                if AppRouter.screenshotScreen == "account_live" {
                    self.accountLiveError = (error as NSError).localizedDescription
                    if self.accountLiveStep == 1 {
                        self.accountLiveStage = "first"
                    } else if self.accountLiveStep == 2 {
                        self.accountLiveStage = "second"
                    }
                    if self.accountLiveStep == 1 || self.accountLiveStep == 2 {
                        self.accountLiveStep = 3
                        self.writeAccountLiveResult()
                    }
                }

                self.finalTableUpdate()
            },
            onMessageStart: { [weak self] humanUuid, assistantUuid in
                guard let self = self else { return }
                if let hu = humanUuid, !hu.isEmpty, userIndex >= 0, userIndex < self.messages.count {
                    self.messages[userIndex].serverUuid = hu
                }
                if let au = assistantUuid, !au.isEmpty, assistantIndex >= 0, assistantIndex < self.messages.count {
                    self.messages[assistantIndex].serverUuid = au
                }
                if var c = self.conversation {
                    c.messages = self.messages
                    self.conversation = c
                    ConversationStore.shared.save(c)
                }
            }
        )
    }

    private func scheduleTableUpdate() {
        let now = Date()
        if now.timeIntervalSince(lastTableUpdate) >= 0.05 {
            lastTableUpdate = now
            updateTableHeight()
        } else if !pendingTableUpdate {
            pendingTableUpdate = true
            let delay = 0.05 - now.timeIntervalSince(lastTableUpdate)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.pendingTableUpdate = false
                self?.lastTableUpdate = Date()
                self?.updateTableHeight()
            }
        }
    }

    private func updateTableHeight() {
        tableView.beginUpdates()
        tableView.endUpdates()
        scrollToBottomIfNeeded()
    }

    private func finalTableUpdate() {
        tableView.beginUpdates()
        tableView.endUpdates()
        scrollToBottom(animated: true)
    }

    private func scrollToBottomIfNeeded() {
        guard isNearBottom() else { return }
        scrollToBottom(animated: false)
    }

    private func isNearBottom() -> Bool {
        let threshold: CGFloat = 80
        let contentOffset = tableView.contentOffset.y
        let visibleHeight = tableView.bounds.height
        let contentHeight = tableView.contentSize.height
        return contentOffset + visibleHeight >= contentHeight - threshold
    }

    private func scrollToBottom(animated: Bool) {
        guard messages.count > 0 else { return }
        let last = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: last, at: .bottom, animated: animated)
    }

    // MARK: - Retry

    private func retry() {
        guard !isStreaming else { return }
        // remove last assistant message
        if messages.last?.role == .assistant {
            messages.removeLast()
            if var c = conversation {
                if c.messages.last?.role == .assistant { c.messages.removeLast() }
                conversation = c
            }
            tableView.reloadData()
        }
        // find last user message
        guard let lastUser = messages.last(where: { $0.role == .user }) else { return }
        // remove it too? We want regenerate: keep user? Contract retry regenerates last assistant. We already removed assistant. Re-send last user would duplicate user. So instead re-trigger streaming using existing last user without appending.
        // Simpler: remove last user as well, then send again (re-adds user)
        if messages.last?.role == .user {
            messages.removeLast()
            if var c = conversation {
                if c.messages.last?.role == .user { c.messages.removeLast() }
                conversation = c
            }
            tableView.reloadData()
        }
        send(text: lastUser.text, attachments: lastUser.attachments)
    }

    // MARK: - Feedback

    private func setFeedback(_ value: Int, for message: Message) {
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx].feedback = value == 0 ? nil : value
            if var c = conversation {
                if let ci = c.messages.firstIndex(where: { $0.id == message.id }) {
                    c.messages[ci].feedback = messages[idx].feedback
                }
                conversation = c
                ConversationStore.shared.save(c)
            }
            tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
        }
    }

    // MARK: - Toast

    private func writeAccountLiveResult() {
        let chatId = self.conversation?.id ?? ""
        let ok = (self.accountLiveError == nil)
        let dict: [String: Any] = [
            "chat_id": chatId,
            "ok": ok,
            "stage": self.accountLiveStage,
            "error": self.accountLiveError ?? ""
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) {
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let url = dir.appendingPathComponent("account_live_result.json")
                try? data.write(to: url)
            }
        }
    }

    private func showToast(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = Fonts.sans(size: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: composerView.topAnchor, constant: -12),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            label.heightAnchor.constraint(equalToConstant: 32),
        ])
        UIView.animate(withDuration: 0.3, delay: 1.2, options: .curveEaseOut, animations: {
            label.alpha = 0
        }, completion: { _ in label.removeFromSuperview() })
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        if msg.role == .user {
            let cell = tableView.dequeueReusableCell(withIdentifier: "user", for: indexPath) as! UserMessageCell
            cell.configure(message: msg)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "assistant", for: indexPath) as! AssistantMessageCell
            let streaming = isStreaming && indexPath.row == messages.count - 1
            let isLast = (indexPath.row == messages.count - 1)
            cell.isLast = isLast
            cell.onThinkingToggle = { [weak self, weak tableView] in
                tableView?.beginUpdates()
                tableView?.endUpdates()
            }
            cell.configure(message: msg, isStreaming: streaming)
            cell.onCopy = { [weak self] text in
                UIPasteboard.general.string = text
                self?.showToast(L("chat.copied", "Chat"))
            }
            cell.onRetry = { [weak self] in self?.retry() }
            cell.onFeedback = { [weak self] value in
                self?.setFeedback(value, for: msg)
            }
            cell.onArtifactTap = { [weak self] title, language, code in
                let vc = ArtifactViewController(title: title, language: language, code: code)
                self?.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {
}

// MARK: - ComposerViewDelegate

extension ChatViewController: ComposerViewDelegate {
    func composerDidTapSend(_ composer: ComposerView, text: String, attachments: [Attachment]) {
        // max 5 check
        if attachments.count > 5 {
            let alert = UIAlertController(title: L("chat.attachmentLimitReached", "Chat"), message: String(format: L("chat.maxAttachments", "Chat"), 5), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("common.ok", "Localizable"), style: .default))
            present(alert, animated: true)
            return
        }
        send(text: text, attachments: attachments)
    }

    func composerDidTapStop(_ composer: ComposerView) {
        userCancelled = true
        streamHandle?.cancel()
        streamHandle = nil
        isStreaming = false
        composerView.isStreaming = false
        if var c = conversation {
            c.messages = messages
            conversation = c
            ConversationStore.shared.save(c)
        }
        if let cell = tableView.cellForRow(at: IndexPath(row: messages.count - 1, section: 0)) as? AssistantMessageCell {
            cell.setStreaming(false)
        }
        finalTableUpdate()
    }

    func composerDidTapAttach(_ composer: ComposerView) {
        if composer.attachments.count >= 5 {
            let alert = UIAlertController(title: L("chat.attachmentLimitReached", "Chat"), message: String(format: L("chat.maxAttachments", "Chat"), 5), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("common.ok", "Localizable"), style: .default))
            present(alert, animated: true)
            return
        }
        let sheet = AttachmentMenuSheet()
        sheet.onPhoto = { [weak self] in self?.pickPhoto() }
        sheet.onCamera = { [weak self] in self?.pickCamera() }
        sheet.onFile = { [weak self] in self?.pickFile() }
        BottomSheetController.present(sheet, from: self)
    }

    func composerDidTapModel(_ composer: ComposerView) {
        let picker = ModelPickerViewController(selectedId: SettingsStore.shared.selectedModelId, onSelect: { [weak self] option in
            SettingsStore.shared.selectedModelId = option.id
            self?.composerView.selectedModelId = option.id
            if var c = self?.conversation {
                c.model = option.id
                self?.conversation = c
                ConversationStore.shared.save(c)
            }
        })
        BottomSheetController.present(picker, from: self)
    }

    func composerDidToggleThinking(_ composer: ComposerView) {
        SettingsStore.shared.extendedThinking = composer.thinkingEnabled
    }
}

// MARK: - Image/File picking

extension ChatViewController {
    private func pickPhoto() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pickCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pickFile() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.text","public.plain-text","public.source-code","public.json","public.comma-separated-values-text"], in: .import)
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        guard let (data, mediaType) = ImageUtil.resizeAndJPEG(image) else { return }
        let b64 = data.base64EncodedString()
        let att = Attachment(kind: .image, fileName: "image.jpg", mediaType: mediaType, base64Data: b64)
        composerView.attachments = composerView.attachments + [att]
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension ChatViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
            let att = Attachment(kind: .textFile, fileName: url.lastPathComponent, mediaType: "text/plain", textContent: text)
            composerView.attachments = composerView.attachments + [att]
        }
    }
}
