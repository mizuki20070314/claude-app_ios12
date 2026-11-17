import UIKit

final class ProjectEditViewController: UIViewController {

    private let project: Project?
    private let nameField = UITextField()
    private let descView = UITextView()
    private let saveButton = UIButton(type: .system)

    init(project: Project?) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.project = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        setupNav()
        setupFields()
        if let p = project {
            nameField.text = p.name
            descView.text = p.description
        }
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
        nameField.backgroundColor = Theme.current.surface
        nameField.textColor = Theme.current.textPrimary
        nameField.layer.borderColor = Theme.current.border.cgColor
        descView.backgroundColor = Theme.current.surface
        descView.textColor = Theme.current.textPrimary
        descView.layer.borderColor = Theme.current.border.cgColor
        saveButton.backgroundColor = Theme.current.accent
        saveButton.setTitleColor(Theme.current.onAccent, for: .normal)
    }

    private func setupNav() {
        let isEdit = (project != nil)
        navigationItem.title = isEdit
            ? NSLocalizedString("project.edit.title.edit", tableName: "Projects", comment: "")
            : NSLocalizedString("project.edit.title.create", tableName: "Projects", comment: "")
        let cancel = UIBarButtonItem(title: NSLocalizedString("common.cancel", tableName: "Projects", comment: ""), style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem = cancel
    }

    private func setupFields() {
        nameField.placeholder = NSLocalizedString("project.edit.name", tableName: "Projects", comment: "")
        nameField.font = Fonts.sans(size: 16)
        nameField.layer.cornerRadius = 8
        nameField.layer.borderWidth = 1
        nameField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameField)

        descView.font = Fonts.sans(size: 15)
        descView.layer.cornerRadius = 8
        descView.layer.borderWidth = 1
        descView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descView)

        saveButton.setTitle(NSLocalizedString("common.save", tableName: "Projects", comment: ""), for: .normal)
        saveButton.titleLabel?.font = Fonts.sans(size: 16, weight: .semibold)
        saveButton.layer.cornerRadius = 10
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            nameField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nameField.heightAnchor.constraint(equalToConstant: 44),

            descView.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            descView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            descView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            descView.heightAnchor.constraint(equalToConstant: 160),

            saveButton.topAnchor.constraint(equalTo: descView.bottomAnchor, constant: 16),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func cancelTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func saveTapped() {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let desc = descView.text ?? ""
        if let p = project {
            var updated = p
            updated.name = name
            updated.description = desc
            ConversationStore.shared.saveProject(updated)
            navigationController?.popViewController(animated: true)
        } else {
            let newProject = Project(name: name, description: desc)
            ConversationStore.shared.addProject(newProject)
            AppRouter.shared.openProject(id: newProject.id)
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func themeDidChange() {
        applyTheme()
    }
}