import UIKit

final class ProjectDetailViewController: UIViewController {

    private let projectId: String

    private let tableView = UITableView()
    private let headerContainer = UIView()

    // Header views
    private let nameLabel = UILabel()
    private let descLabel = UILabel()
    private let newChatButton = UIButton(type: .system)
    private let starButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)

    private var knowledgeEditorPresented = false

    init(projectId: String) {
        self.projectId = projectId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.projectId = ""
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        setupNav()
        setupHeader()
        setupTable()
        reload()
        NotificationCenter.default.addObserver(self, selector: #selector(storeDidChange), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private var project: Project? {
        return ConversationStore.shared.project(id: projectId)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        nameLabel.textColor = Theme.current.textPrimary
        descLabel.textColor = Theme.current.textSecondary
        newChatButton.backgroundColor = Theme.current.accent
        newChatButton.setTitleColor(Theme.current.onAccent, for: .normal)
        starButton.tintColor = Theme.current.accent
        moreButton.tintColor = Theme.current.textPrimary
    }

    private func setupNav() {
        if !AppRouter.shared.isSidebarPersistent {
            let menu = IconButton(icon: .menu, size: 22, tint: Theme.current.textPrimary)
            menu.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: menu)
        }
        // back button (custom) when possible
        let back = IconButton(icon: .back, size: 22, tint: Theme.current.textPrimary)
        back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        // place as left after menu? We'll add to navigationItem only if no menu? Keep menu priority.
        // Instead add back button to header.
    }

    @objc private func menuTapped() {
        AppRouter.shared.toggleSidebar()
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func setupHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        // Back button
        let backBtn = IconButton(icon: .back, size: 22, tint: Theme.current.textPrimary)
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(backBtn)

        nameLabel.font = Fonts.serif(size: 24, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(nameLabel)

        descLabel.font = Fonts.sans(size: 14)
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(descLabel)

        starButton.translatesAutoresizingMaskIntoConstraints = false
        starButton.addTarget(self, action: #selector(starTapped), for: .touchUpInside)
        headerContainer.addSubview(starButton)

        moreButton.setImage(Icons.image(.more, size: 20, color: Theme.current.textPrimary), for: .normal)
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        headerContainer.addSubview(moreButton)

        newChatButton.setTitle(NSLocalizedString("project.detail.newChat", tableName: "Projects", comment: ""), for: .normal)
        newChatButton.titleLabel?.font = Fonts.sans(size: 15, weight: .semibold)
        newChatButton.layer.cornerRadius = 10
        newChatButton.translatesAutoresizingMaskIntoConstraints = false
        newChatButton.addTarget(self, action: #selector(newChatTapped), for: .touchUpInside)
        headerContainer.addSubview(newChatButton)

        NSLayoutConstraint.activate([
            backBtn.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            backBtn.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
            backBtn.widthAnchor.constraint(equalToConstant: 44),
            backBtn.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: backBtn.trailingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: starButton.leadingAnchor, constant: -8),

            starButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            starButton.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -4),
            starButton.widthAnchor.constraint(equalToConstant: 40),
            starButton.heightAnchor.constraint(equalToConstant: 40),

            moreButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -8),
            moreButton.widthAnchor.constraint(equalToConstant: 40),
            moreButton.heightAnchor.constraint(equalToConstant: 40),

            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),

            newChatButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 12),
            newChatButton.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            newChatButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            newChatButton.heightAnchor.constraint(equalToConstant: 40),
            newChatButton.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -12)
        ])
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ProjectDetailSectionHeader.self, forHeaderFooterViewReuseIdentifier: ProjectDetailSectionHeader.reuseId)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.tableHeaderView = headerContainer
        // set header frame width
        headerContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 180)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // update header height
        headerContainer.frame.size.width = view.bounds.width
        headerContainer.setNeedsLayout()
        headerContainer.layoutIfNeeded()
        let height = headerContainer.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        if tableView.tableHeaderView?.frame.height != height {
            tableView.tableHeaderView?.frame.size.height = height
            tableView.tableHeaderView = tableView.tableHeaderView
        }
    }

    @objc private func storeDidChange() {
        reload()
    }

    @objc private func themeDidChange() {
        applyTheme()
        tableView.reloadData()
    }

    private func reload() {
        guard let p = project else { return }
        nameLabel.text = p.name
        descLabel.text = p.description
        starButton.setImage(Icons.image(p.isStarred ? .starFill : .star, size: 20, color: Theme.current.accent), for: .normal)
        tableView.reloadData()
    }

    @objc private func starTapped() {
        ConversationStore.shared.toggleStarProject(id: projectId)
    }

    @objc private func moreTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("project.edit.title.edit", tableName: "Projects", comment: ""), style: .default) { [weak self] _ in
            guard let self = self, let p = self.project else { return }
            let vc = ProjectEditViewController(project: p)
            self.navigationController?.pushViewController(vc, animated: true)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("projects.delete", tableName: "Projects", comment: ""), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let confirm = UIAlertController(title: NSLocalizedString("projects.delete.confirm.title", tableName: "Projects", comment: ""), message: NSLocalizedString("projects.delete.confirm.message", tableName: "Projects", comment: ""), preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", tableName: "Projects", comment: ""), style: .cancel, handler: nil))
            confirm.addAction(UIAlertAction(title: NSLocalizedString("common.delete", tableName: "Projects", comment: ""), style: .destructive) { _ in
                ConversationStore.shared.deleteProject(id: self.projectId)
                self.navigationController?.popViewController(animated: true)
            })
            self.present(confirm, animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", tableName: "Projects", comment: ""), style: .cancel, handler: nil))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = moreButton
            pop.sourceRect = moreButton.bounds
        }
        present(alert, animated: true, completion: nil)
    }

    @objc private func newChatTapped() {
        AppRouter.shared.startNewChat(projectId: projectId)
    }

    // MARK: - Section helpers
    private enum Section: Int, CaseIterable {
        case instructions = 0
        case knowledge = 1
        case chats = 2
    }

    private func conversationsInProject() -> [Conversation] {
        return ConversationStore.shared.conversations(inProject: projectId)
    }

    private func knowledgeItems() -> [Attachment] {
        return project?.knowledge ?? []
    }

    private func firstThreeLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        return lines.prefix(3).joined(separator: "\n")
    }
}

extension ProjectDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .instructions:
            return 1
        case .knowledge:
            return knowledgeItems().count
        case .chats:
            return conversationsInProject().count
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let s = Section(rawValue: section)!
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ProjectDetailSectionHeader.reuseId) as! ProjectDetailSectionHeader
        switch s {
        case .instructions:
            header.configure(title: NSLocalizedString("project.detail.instructions", tableName: "Projects", comment: ""), showAdd: false)
            header.onAdd = nil
        case .knowledge:
            header.configure(title: NSLocalizedString("project.detail.knowledge", tableName: "Projects", comment: ""), showAdd: true)
            header.onAdd = { [weak self] in self?.showKnowledgeAddSheet() }
        case .chats:
            header.configure(title: NSLocalizedString("project.detail.chats", tableName: "Projects", comment: ""), showAdd: false)
            header.onAdd = nil
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let s = Section(rawValue: indexPath.section)!
        switch s {
        case .instructions:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .default
            let text = project?.instructions ?? ""
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cell.textLabel?.text = NSLocalizedString("project.detail.instructions.placeholder", tableName: "Projects", comment: "")
                cell.textLabel?.textColor = Theme.current.textTertiary
            } else {
                cell.textLabel?.text = firstThreeLines(text)
                cell.textLabel?.textColor = Theme.current.textPrimary
            }
            cell.textLabel?.numberOfLines = 3
            cell.textLabel?.font = Fonts.sans(size: 14)
            cell.backgroundColor = .clear
            return cell
        case .knowledge:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            let item = knowledgeItems()[indexPath.row]
            cell.textLabel?.text = item.fileName
            cell.textLabel?.textColor = Theme.current.textPrimary
            cell.detailTextLabel?.text = formattedSize(item)
            cell.detailTextLabel?.textColor = Theme.current.textSecondary
            cell.imageView?.image = Icons.image(.file, size: 20, color: Theme.current.textSecondary)
            cell.backgroundColor = .clear
            return cell
        case .chats:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            let conv = conversationsInProject()[indexPath.row]
            cell.textLabel?.text = conv.title
            cell.textLabel?.textColor = Theme.current.textPrimary
            cell.detailTextLabel?.text = relativeDate(conv.updatedAt)
            cell.backgroundColor = .clear
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = Section(rawValue: indexPath.section)!
        switch s {
        case .instructions:
            let vc = ProjectInstructionsViewController(projectId: projectId)
            navigationController?.pushViewController(vc, animated: true)
        case .knowledge:
            break
        case .chats:
            let conv = conversationsInProject()[indexPath.row]
            AppRouter.shared.openConversation(id: conv.id)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .instructions: return 64
        case .knowledge: return 44
        case .chats: return 44
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return Section(rawValue: indexPath.section) == .knowledge
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard var p = project else { return }
            p.knowledge.remove(at: indexPath.row)
            ConversationStore.shared.saveProject(p)
        }
    }

    // MARK: - Knowledge add
    private func showKnowledgeAddSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("project.knowledge.paste", tableName: "Projects", comment: ""), style: .default) { [weak self] _ in
            self?.showPasteEditor()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("project.knowledge.file", tableName: "Projects", comment: ""), style: .default) { [weak self] _ in
            self?.showDocumentPicker()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", tableName: "Projects", comment: ""), style: .cancel, handler: nil))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true, completion: nil)
    }

    private func showPasteEditor() {
        let editor = KnowledgePasteEditorViewController { [weak self] title, body in
            guard let self = self else { return }
            guard var p = self.project else { return }
            let attachment = Attachment(kind: .textFile, fileName: title.isEmpty ? "Untitled.txt" : title, mediaType: "text/plain", textContent: body)
            p.knowledge.append(attachment)
            ConversationStore.shared.saveProject(p)
        }
        let nav = UINavigationController(rootViewController: editor)
        present(nav, animated: true, completion: nil)
    }

    private func showDocumentPicker() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.text", "public.plain-text"], in: .import)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    private func formattedSize(_ attachment: Attachment) -> String {
        let bytes: Int
        if let text = attachment.textContent {
            bytes = text.data(using: .utf8)?.count ?? 0
        } else {
            bytes = 0
        }
        if bytes < 1024 {
            return "\(bytes) B"
        }
        return String(format: "%.1f KB", Double(bytes) / 1024.0)
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "今日" }
        if days == 1 { return "昨日" }
        return "\(days)日前"
    }
}

extension ProjectDetailViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() || true else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        let text = String(data: data, encoding: .utf8) ?? ""
        guard var p = project else { return }
        let attachment = Attachment(kind: .textFile, fileName: url.lastPathComponent, mediaType: "text/plain", textContent: text)
        p.knowledge.append(attachment)
        ConversationStore.shared.saveProject(p)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
}

final class ProjectDetailSectionHeader: UITableViewHeaderFooterView {
    static let reuseId = "ProjectDetailSectionHeader"

    private let titleLabel = UILabel()
    private let addButton = UIButton(type: .system)
    var onAdd: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        titleLabel.font = Fonts.sans(size: 14, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        addButton.setTitle("+", for: .normal)
        addButton.titleLabel?.font = Fonts.sans(size: 20, weight: .medium)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        contentView.addSubview(addButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            addButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            addButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 32),
            addButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    func configure(title: String, showAdd: Bool) {
        titleLabel.text = title
        titleLabel.textColor = Theme.current.textSecondary
        addButton.isHidden = !showAdd
        addButton.tintColor = Theme.current.accent
    }

    @objc private func addTapped() {
        onAdd?()
    }
}

final class KnowledgePasteEditorViewController: UIViewController {
    private let onSave: (String, String) -> Void
    private let titleField = UITextField()
    private let bodyView = UITextView()

    init(onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.onSave = { _, _ in }
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("project.knowledge.paste", tableName: "Projects", comment: "")
        applyTheme()
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        titleField.backgroundColor = Theme.current.surface
        titleField.textColor = Theme.current.textPrimary
        titleField.layer.borderColor = Theme.current.border.cgColor
        bodyView.backgroundColor = Theme.current.surface
        bodyView.textColor = Theme.current.textPrimary
        bodyView.layer.borderColor = Theme.current.border.cgColor
    }

    private func setupUI() {
        titleField.placeholder = NSLocalizedString("project.knowledge.title", tableName: "Projects", comment: "")
        titleField.font = Fonts.sans(size: 15)
        titleField.layer.cornerRadius = 8
        titleField.layer.borderWidth = 1
        titleField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleField)

        bodyView.font = Fonts.sans(size: 15)
        bodyView.layer.cornerRadius = 8
        bodyView.layer.borderWidth = 1
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bodyView)

        let save = UIBarButtonItem(title: NSLocalizedString("common.save", tableName: "Projects", comment: ""), style: .done, target: self, action: #selector(saveTapped))
        let cancel = UIBarButtonItem(title: NSLocalizedString("common.cancel", tableName: "Projects", comment: ""), style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = save
        navigationItem.leftBarButtonItem = cancel

        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleField.heightAnchor.constraint(equalToConstant: 44),

            bodyView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 12),
            bodyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bodyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bodyView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func saveTapped() {
        onSave(titleField.text ?? "", bodyView.text ?? "")
        dismiss(animated: true, completion: nil)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func themeDidChange() {
        applyTheme()
    }
}