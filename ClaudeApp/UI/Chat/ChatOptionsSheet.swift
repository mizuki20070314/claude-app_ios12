import UIKit

final class ChatOptionsSheet: UIViewController {
    private let conversation: Conversation
    private var onChange: () -> Void

    init(conversation: Conversation, onChange: @escaping () -> Void) {
        self.conversation = conversation
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.surface
        preferredContentSize = CGSize(width: 320, height: 320)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        func row(title: String, icon: IconName, action: Selector, destructive: Bool = false) -> UIButton {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.setImage(Icons.image(icon, size: 20, color: destructive ? Theme.current.destructive : Theme.current.textPrimary), for: .normal)
            b.contentHorizontalAlignment = .left
            b.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            b.addTarget(self, action: action, for: .touchUpInside)
            if destructive { b.setTitleColor(Theme.current.destructive, for: .normal) }
            else { b.setTitleColor(Theme.current.textPrimary, for: .normal) }
            return b
        }

        let renameBtn = row(title: L("chat.rename", "Chat"), icon: .pencil, action: #selector(renameTapped))
        let starTitle = conversation.isStarred ? L("chat.unstar", "Chat") : L("chat.star", "Chat")
        let starIcon: IconName = conversation.isStarred ? .starFill : .star
        let starBtn = row(title: starTitle, icon: starIcon, action: #selector(starTapped))
        let projectBtn = row(title: L("chat.addToProject", "Chat"), icon: .project, action: #selector(projectTapped))
        let shareBtn = row(title: L("chat.share", "Chat"), icon: .share, action: #selector(shareTapped))
        let deleteBtn = row(title: L("chat.delete", "Chat"), icon: .trash, action: #selector(deleteTapped), destructive: true)

        [renameBtn, starBtn, projectBtn, shareBtn, deleteBtn].forEach { stack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() { view.backgroundColor = Theme.current.surface }

    @objc private func renameTapped() {
        let alert = UIAlertController(title: L("chat.rename", "Chat"), message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = self.conversation.title }
        alert.addAction(UIAlertAction(title: L("common.cancel", "Localizable"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("common.ok", "Localizable"), style: .default, handler: { _ in
            if let t = alert.textFields?.first?.text, !t.isEmpty {
                ConversationStore.shared.rename(id: self.conversation.id, title: t)
                self.onChange()
                self.dismiss(animated: true)
            }
        }))
        present(alert, animated: true)
    }

    @objc private func starTapped() {
        ConversationStore.shared.toggleStar(id: conversation.id)
        onChange()
        dismiss(animated: true)
    }

    @objc private func projectTapped() {
        let projects = ConversationStore.shared.projects
        let alert = UIAlertController(title: L("chat.addToProject", "Chat"), message: nil, preferredStyle: .actionSheet)
        for p in projects {
            alert.addAction(UIAlertAction(title: p.name, style: .default, handler: { _ in
                if var c = ConversationStore.shared.conversation(id: self.conversation.id) {
                    c.projectId = p.id
                    ConversationStore.shared.save(c)
                    self.onChange()
                }
                self.dismiss(animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: L("common.cancel", "Localizable"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func shareTapped() {
        let text = conversation.messages.map { ($0.role == .user ? "User: " : "Claude: ") + $0.text }.joined(separator: "\n\n")
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(vc, animated: true)
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(title: L("chat.delete", "Chat"), message: L("chat.deleteConfirm", "Chat"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.cancel", "Localizable"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("chat.delete", "Chat"), style: .destructive, handler: { _ in
            ConversationStore.shared.delete(id: self.conversation.id)
            self.onChange()
            self.dismiss(animated: true)
        }))
        present(alert, animated: true)
    }
}
