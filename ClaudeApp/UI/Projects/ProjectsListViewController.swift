import UIKit

final class ProjectsListViewController: UIViewController {

    private enum SortMode: Int {
        case recent = 0
        case name = 1
    }

    private let titleLabel = UILabel()
    private let searchField = UITextField()
    private let sortControl = UISegmentedControl(items: [
        NSLocalizedString("projects.sort.recent", tableName: "Projects", comment: ""),
        NSLocalizedString("projects.sort.name", tableName: "Projects", comment: "")
    ])
    private let newButton = UIButton(type: .system)
    private let tableView = UITableView()
    private let emptyLabel = UILabel()

    private var sortMode: SortMode = .recent
    private var searchText: String = ""
    private var projects: [Project] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        setupNav()
        setupTitle()
        setupSearch()
        setupSortAndNew()
        setupTable()
        setupEmpty()
        updateNewButtonTitle()
        reloadProjects()

        NotificationCenter.default.addObserver(self, selector: #selector(storeDidChange), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateNewButtonTitle()
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        titleLabel.textColor = Theme.current.textPrimary
        searchField.textColor = Theme.current.textPrimary
        searchField.backgroundColor = Theme.current.surface
        // placeholder color via attributed placeholder set in setup
        sortControl.tintColor = Theme.current.accent
        emptyLabel.textColor = Theme.current.textSecondary
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
    }

    private func setupNav() {
        if !AppRouter.shared.isSidebarPersistent {
            let menu = IconButton(icon: .menu, size: 22, tint: Theme.current.textPrimary)
            menu.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: menu)
        }
    }

    @objc private func menuTapped() {
        AppRouter.shared.toggleSidebar()
    }

    private func setupTitle() {
        titleLabel.text = NSLocalizedString("projects.title", tableName: "Projects", comment: "")
        titleLabel.font = Fonts.serif(size: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }

    private func setupSearch() {
        searchField.placeholder = NSLocalizedString("projects.search.placeholder", tableName: "Projects", comment: "")
        searchField.font = Fonts.sans(size: 15)
        searchField.layer.cornerRadius = 10
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = Theme.current.border.cgColor
        searchField.leftView = UIImageView(image: Icons.image(.search, size: 16, color: Theme.current.textTertiary))
        searchField.leftViewMode = .always
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .search
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        view.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setupSortAndNew() {
        sortControl.selectedSegmentIndex = 0
        sortControl.translatesAutoresizingMaskIntoConstraints = false
        sortControl.addTarget(self, action: #selector(sortChanged), for: .valueChanged)
        view.addSubview(sortControl)

        newButton.setTitle(NSLocalizedString("projects.new", tableName: "Projects", comment: ""), for: .normal)
        // plus icon
        let plusImg = Icons.image(.plus, size: 14, color: .white)
        newButton.setImage(plusImg, for: .normal)
        newButton.tintColor = .white
        newButton.backgroundColor = Theme.current.textPrimary
        newButton.setTitleColor(.white, for: .normal)
        newButton.titleLabel?.font = Fonts.sans(size: 14, weight: .semibold)
        newButton.layer.cornerRadius = 16
        newButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        newButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        newButton.translatesAutoresizingMaskIntoConstraints = false
        newButton.addTarget(self, action: #selector(newProjectTapped), for: .touchUpInside)
        view.addSubview(newButton)

        NSLayoutConstraint.activate([
            sortControl.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            sortControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sortControl.heightAnchor.constraint(equalToConstant: 30),

            newButton.centerYAnchor.constraint(equalTo: sortControl.centerYAnchor),
            newButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            newButton.leadingAnchor.constraint(greaterThanOrEqualTo: sortControl.trailingAnchor, constant: 8),
            newButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ProjectCardCell.self, forCellReuseIdentifier: ProjectCardCell.reuseId)
        tableView.rowHeight = 100
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: sortControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmpty() {
        emptyLabel.text = NSLocalizedString("projects.empty", tableName: "Projects", comment: "")
        emptyLabel.font = Fonts.sans(size: 16)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func storeDidChange() {
        reloadProjects()
    }

    @objc private func themeDidChange() {
        applyTheme()
        tableView.reloadData()
    }

    @objc private func searchChanged() {
        searchText = searchField.text ?? ""
        reloadProjects()
    }

    @objc private func sortChanged() {
        sortMode = SortMode(rawValue: sortControl.selectedSegmentIndex) ?? .recent
        reloadProjects()
    }

    @objc private func newProjectTapped() {
        let vc = ProjectEditViewController(project: nil)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func updateNewButtonTitle() {
        let narrow = view.bounds.width < 360
        if narrow {
            newButton.setTitle("＋ 新規", for: .normal)
            newButton.setImage(nil, for: .normal)
        } else {
            newButton.setTitle(NSLocalizedString("projects.new", tableName: "Projects", comment: ""), for: .normal)
            let plusImg = Icons.image(.plus, size: 14, color: .white)
            newButton.setImage(plusImg, for: .normal)
        }
    }

    private func reloadProjects() {
        var list = ConversationStore.shared.projects
        // search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter { p in
                p.name.localizedCaseInsensitiveContains(q) || p.description.localizedCaseInsensitiveContains(q)
            }
        }
        // sort
        switch sortMode {
        case .recent:
            list.sort { $0.updatedAt > $1.updatedAt }
        case .name:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        projects = list
        tableView.reloadData()
        emptyLabel.isHidden = !projects.isEmpty
        tableView.isHidden = projects.isEmpty
    }

    private func relativeUpdatedText(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 {
            return NSLocalizedString("projects.updated.today", tableName: "Projects", comment: "")
        }
        if days == 1 {
            return NSLocalizedString("projects.updated.yesterday", tableName: "Projects", comment: "")
        }
        return String(format: NSLocalizedString("projects.updated.days", tableName: "Projects", comment: ""), days)
    }
}

extension ProjectsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return projects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProjectCardCell.reuseId, for: indexPath) as! ProjectCardCell
        let project = projects[indexPath.row]
        cell.configure(project: project, updatedText: relativeUpdatedText(for: project.updatedAt))
        // long press
        cell.gestureRecognizers?.forEach { if $0 is UILongPressGestureRecognizer { cell.removeGestureRecognizer($0) } }
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        lp.minimumPressDuration = 0.5
        cell.addGestureRecognizer(lp)
        // store project id via tag? use associated? We'll use cell's property
        cell.projectId = project.id
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let project = projects[indexPath.row]
        AppRouter.shared.openProject(id: project.id)
    }

    @objc private func longPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard let cell = gesture.view as? ProjectCardCell, let pid = cell.projectId else { return }
        guard let project = ConversationStore.shared.project(id: pid) else { return }
        let alert = UIAlertController(title: project.name, message: nil, preferredStyle: .actionSheet)
        // star
        let starTitle = project.isStarred ? NSLocalizedString("projects.unstar", tableName: "Projects", comment: "") : NSLocalizedString("projects.star", tableName: "Projects", comment: "")
        alert.addAction(UIAlertAction(title: starTitle, style: .default) { _ in
            ConversationStore.shared.toggleStarProject(id: pid)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("projects.edit", tableName: "Projects", comment: ""), style: .default) { [weak self] _ in
            let vc = ProjectEditViewController(project: project)
            self?.navigationController?.pushViewController(vc, animated: true)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("projects.delete", tableName: "Projects", comment: ""), style: .destructive) { [weak self] _ in
            let confirm = UIAlertController(title: NSLocalizedString("projects.delete.confirm.title", tableName: "Projects", comment: ""), message: NSLocalizedString("projects.delete.confirm.message", tableName: "Projects", comment: ""), preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", tableName: "Projects", comment: ""), style: .cancel, handler: nil))
            confirm.addAction(UIAlertAction(title: NSLocalizedString("common.delete", tableName: "Projects", comment: ""), style: .destructive) { _ in
                ConversationStore.shared.deleteProject(id: pid)
            })
            self?.present(confirm, animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", tableName: "Projects", comment: ""), style: .cancel, handler: nil))
        // iPad popover
        if let pop = alert.popoverPresentationController {
            pop.sourceView = cell
            pop.sourceRect = cell.bounds
        }
        present(alert, animated: true, completion: nil)
    }
}

final class ProjectCardCell: UITableViewCell {
    static let reuseId = "ProjectCardCell"

    var projectId: String?

    private let card = UIView()
    private let nameLabel = UILabel()
    private let descLabel = UILabel()
    private let dateLabel = UILabel()
    private let starIcon = UIImageView()

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

        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])

        nameLabel.font = Fonts.sans(size: 16, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        descLabel.font = Fonts.sans(size: 13)
        descLabel.numberOfLines = 2
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descLabel)

        dateLabel.font = Fonts.sans(size: 12)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(dateLabel)

        starIcon.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(starIcon)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: starIcon.leadingAnchor, constant: -8),

            starIcon.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            starIcon.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            starIcon.widthAnchor.constraint(equalToConstant: 16),
            starIcon.heightAnchor.constraint(equalToConstant: 16),

            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            dateLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 6),
            dateLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            dateLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    func configure(project: Project, updatedText: String) {
        let t = Theme.current
        card.backgroundColor = t.surface
        card.layer.borderColor = t.border.cgColor
        nameLabel.textColor = t.textPrimary
        descLabel.textColor = t.textSecondary
        dateLabel.textColor = t.textTertiary
        nameLabel.text = project.name
        descLabel.text = project.description
        dateLabel.text = updatedText
        if project.isStarred {
            starIcon.image = Icons.image(.starFill, size: 16, color: t.accent)
            starIcon.isHidden = false
        } else {
            starIcon.isHidden = true
        }
    }
}