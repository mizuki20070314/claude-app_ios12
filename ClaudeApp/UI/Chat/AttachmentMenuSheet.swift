import UIKit

final class AttachmentMenuSheet: UIViewController {
    var onPhoto: (() -> Void)?
    var onCamera: (() -> Void)?
    var onFile: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.surface
        preferredContentSize = CGSize(width: 320, height: 220)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        func addButton(title: String, icon: IconName, action: Selector) -> UIButton {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.setImage(Icons.image(icon, size: 20, color: Theme.current.textPrimary), for: .normal)
            b.contentHorizontalAlignment = .left
            b.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
            b.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            b.addTarget(self, action: action, for: .touchUpInside)
            return b
        }

        let photoBtn = addButton(title: L("chat.photoLibrary", "Chat"), icon: .image, action: #selector(photoTapped))
        let cameraBtn = addButton(title: L("chat.camera", "Chat"), icon: .camera, action: #selector(cameraTapped))
        let fileBtn = addButton(title: L("chat.file", "Chat"), icon: .file, action: #selector(fileTapped))

        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            cameraBtn.isHidden = true
        }

        stack.addArrangedSubview(photoBtn)
        stack.addArrangedSubview(cameraBtn)
        stack.addArrangedSubview(fileBtn)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        view.backgroundColor = Theme.current.surface
    }

    @objc private func photoTapped() {
        dismiss(animated: true) { [weak self] in self?.onPhoto?() }
    }

    @objc private func cameraTapped() {
        dismiss(animated: true) { [weak self] in self?.onCamera?() }
    }

    @objc private func fileTapped() {
        dismiss(animated: true) { [weak self] in self?.onFile?() }
    }
}
