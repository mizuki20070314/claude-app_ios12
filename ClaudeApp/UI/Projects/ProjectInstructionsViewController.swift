import UIKit

final class ProjectInstructionsViewController: UIViewController {

    private let projectId: String
    private let textView = UITextView()
    private let saveButton = UIButton(type: .system)

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
        navigationItem.title = NSLocalizedString("project.instructions.title", tableName: "Projects", comment: "")
        applyTheme()
        setupUI()
        if let p = ConversationStore.shared.project(id: projectId) {
            textView.text = p.instructions
        }
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        textView.backgroundColor = Theme.current.surface
        textView.textColor = Theme.current.textPrimary
        textView.layer.borderColor = Theme.current.border.cgColor
        saveButton.backgroundColor = Theme.current.accent
        saveButton.setTitleColor(Theme.current.onAccent, for: .normal)
    }

    private func setupUI() {
        textView.font = Fonts.sans(size: 15)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        saveButton.setTitle(NSLocalizedString("common.save", tableName: "Projects", comment: ""), for: .normal)
        saveButton.titleLabel?.font = Fonts.sans(size: 16, weight: .semibold)
        saveButton.layer.cornerRadius = 10
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func saveTapped() {
        guard var p = ConversationStore.shared.project(id: projectId) else { return }
        p.instructions = textView.text ?? ""
        ConversationStore.shared.saveProject(p)
        navigationController?.popViewController(animated: true)
    }

    @objc private func themeDidChange() {
        applyTheme()
    }
}