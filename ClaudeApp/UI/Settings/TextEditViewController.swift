import UIKit

final class TextEditViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {

    var initialText: String = ""
    var multiline: Bool = false
    var placeholder: String = ""
    var onSave: ((String) -> Void)?

    private let textField = UITextField()
    private let textView = UITextView()
    private let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: nil, action: nil)
    private var themeObserver: NSObjectProtocol?

    init(title: String, initialText: String, multiline: Bool, placeholder: String = "", onSave: @escaping (String) -> Void) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
        self.initialText = initialText
        self.multiline = multiline
        self.placeholder = placeholder
        self.onSave = onSave
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("common.save", "Settings"), style: .done, target: self, action: #selector(saveTapped))
        // fallback if common.save missing
        if navigationItem.rightBarButtonItem?.title == nil { navigationItem.rightBarButtonItem?.title = "保存" }

        if multiline {
            textView.text = initialText
            textView.font = Fonts.sans(size: 16)
            textView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(textView)
            NSLayoutConstraint.activate([
                textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
                textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
            ])
            textView.delegate = self
        } else {
            textField.text = initialText
            textField.placeholder = placeholder
            textField.font = Fonts.sans(size: 16)
            textField.borderStyle = .roundedRect
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
            view.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
            textField.delegate = self
        }
        themeObserver = NotificationCenter.default.addObserver(forName: Theme.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
        }
    }

    deinit {
        if let o = themeObserver { NotificationCenter.default.removeObserver(o) }
    }

    private func applyTheme() {
        let t = Theme.current
        view.backgroundColor = t.background
        textField.backgroundColor = t.surface
        textField.textColor = t.textPrimary
        textView.backgroundColor = t.surface
        textView.textColor = t.textPrimary
        textView.keyboardAppearance = t.keyboardAppearance
        textField.keyboardAppearance = t.keyboardAppearance
    }

    @objc private func saveTapped() {
        let text = multiline ? textView.text ?? "" : textField.text ?? ""
        onSave?(text)
        if let nav = navigationController { nav.popViewController(animated: true) } else { dismiss(animated: true) }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveTapped()
        return true
    }
}
