import UIKit

final class ArtifactsGalleryViewController: UIViewController {

    private enum Filter: Int {
        case all = 0
        case code = 1
        case docs = 2
    }

    private let segmentedControl = UISegmentedControl(items: [
        NSLocalizedString("artifacts.filter.all", tableName: "Artifacts", comment: ""),
        NSLocalizedString("artifacts.filter.code", tableName: "Artifacts", comment: ""),
        NSLocalizedString("artifacts.filter.docs", tableName: "Artifacts", comment: "")
    ])
    private let collectionView: UICollectionView
    private let emptyLabel = UILabel()
    private let flowLayout = UICollectionViewFlowLayout()

    private var allItems: [ArtifactItem] = []
    private var filteredItems: [ArtifactItem] = []

    init() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("artifacts.title", tableName: "Artifacts", comment: "")
        applyTheme()
        setupNav()
        setupSegmented()
        setupCollection()
        setupEmpty()
        reloadData()

        NotificationCenter.default.addObserver(self, selector: #selector(storeDidChange), name: Notification.Name("ConversationStore.didChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        emptyLabel.textColor = Theme.current.textSecondary
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

    private func setupSegmented() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        view.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func setupCollection() {
        flowLayout.minimumInteritemSpacing = 12
        flowLayout.minimumLineSpacing = 12
        flowLayout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ArtifactCardCell.self, forCellWithReuseIdentifier: ArtifactCardCell.reuseId)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmpty() {
        emptyLabel.text = NSLocalizedString("artifacts.empty", tableName: "Artifacts", comment: "")
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
        reloadData()
    }

    @objc private func themeDidChange() {
        applyTheme()
        collectionView.reloadData()
    }

    @objc private func filterChanged() {
        applyFilter()
        collectionView.reloadData()
        updateEmpty()
    }

    private func reloadData() {
        allItems = ArtifactExtractor.extractArtifacts(from: ConversationStore.shared.allConversations)
        applyFilter()
        collectionView.reloadData()
        updateEmpty()
    }

    private func applyFilter() {
        let filter = Filter(rawValue: segmentedControl.selectedSegmentIndex) ?? .all
        let docLangs: Set<String> = ["html", "svg", "markdown", "md"]
        switch filter {
        case .all:
            filteredItems = allItems
        case .code:
            filteredItems = allItems.filter { item in
                let lang = (item.language ?? "").lowercased()
                return !docLangs.contains(lang)
            }
        case .docs:
            filteredItems = allItems.filter { item in
                let lang = (item.language ?? "").lowercased()
                return docLangs.contains(lang)
            }
        }
    }

    private func updateEmpty() {
        emptyLabel.isHidden = !filteredItems.isEmpty
        collectionView.isHidden = filteredItems.isEmpty
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        let cols: CGFloat = width > 500 ? 2 : 1
        let spacing: CGFloat = 12
        let sectionInset: CGFloat = 16
        let available = width - sectionInset * 2 - spacing * (cols - 1)
        let itemWidth = available / cols
        flowLayout.itemSize = CGSize(width: itemWidth, height: 110)
    }
}

extension ArtifactsGalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ArtifactCardCell.reuseId, for: indexPath) as! ArtifactCardCell
        cell.configure(item: filteredItems[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = filteredItems[indexPath.item]
        let vc = ArtifactViewController(title: item.title, language: item.language, code: item.code)
        navigationController?.pushViewController(vc, animated: true)
    }
}

final class ArtifactCardCell: UICollectionViewCell {
    static let reuseId = "ArtifactCardCell"

    private let card = UIView()
    private let badge = UILabel()
    private let titleLabel = UILabel()
    private let conversationLabel = UILabel()
    private let dateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        badge.font = Fonts.mono(size: 11, weight: .semibold)
        badge.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(badge)

        titleLabel.font = Fonts.sans(size: 15, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        conversationLabel.font = Fonts.sans(size: 12)
        conversationLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(conversationLabel)

        dateLabel.font = Fonts.sans(size: 11)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            badge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            badge.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),

            titleLabel.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            conversationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            conversationLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            conversationLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            dateLabel.topAnchor.constraint(equalTo: conversationLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            dateLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -10)
        ])
    }

    func configure(item: ArtifactItem) {
        let t = Theme.current
        card.backgroundColor = t.surface
        card.layer.borderColor = t.border.cgColor
        badge.textColor = t.accent
        badge.text = (item.language?.isEmpty == false) ? item.language : "code"
        titleLabel.textColor = t.textPrimary
        titleLabel.text = item.title
        conversationLabel.textColor = t.textSecondary
        conversationLabel.text = item.conversationTitle
        dateLabel.textColor = t.textTertiary
        dateLabel.text = relativeDate(item.createdAt)
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "今日" }
        if days == 1 { return "昨日" }
        return "\(days)日前"
    }
}