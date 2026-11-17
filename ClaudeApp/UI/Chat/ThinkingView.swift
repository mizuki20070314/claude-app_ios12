import UIKit

final class ThinkingView: UIView {
    private let headerButton = UIButton(type: .system)
    private let contentLabel = UILabel()
    private let chevron = UIImageView()
    private var expanded = false
    private var contentHeightConstraint: NSLayoutConstraint?

    var thinkingText: String = "" {
        didSet {
            contentLabel.text = thinkingText
        }
    }

    var isStreaming: Bool = false {
        didSet { updateHeader() }
    }

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = Theme.current.thinkingBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = Theme.current.border.cgColor
        clipsToBounds = true

        headerButton.setTitle(L("chat.thinkingProcess", "Chat"), for: .normal)
        headerButton.titleLabel?.font = Fonts.sans(size: 13, weight: .medium)
        headerButton.contentHorizontalAlignment = .left
        headerButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerButton)

        chevron.image = Icons.image(.chevronDown, size: 12, color: Theme.current.textSecondary)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevron)

        contentLabel.font = Fonts.sans(size: 13)
        contentLabel.textColor = Theme.current.textSecondary
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)

        contentHeightConstraint = contentLabel.heightAnchor.constraint(equalToConstant: 0)
        // We'll manage visibility via isHidden instead.

        NSLayoutConstraint.activate([
            headerButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            headerButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            headerButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            headerButton.heightAnchor.constraint(equalToConstant: 20),

            chevron.centerYAnchor.constraint(equalTo: headerButton.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12),

            contentLabel.topAnchor.constraint(equalTo: headerButton.bottomAnchor, constant: 6),
            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            contentLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        contentLabel.isHidden = true
        updateHeader()

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggle))
        addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        backgroundColor = Theme.current.thinkingBackground
        layer.borderColor = Theme.current.border.cgColor
        headerButton.setTitleColor(Theme.current.textSecondary, for: .normal)
        contentLabel.textColor = Theme.current.textSecondary
        chevron.image = Icons.image(.chevronDown, size: 12, color: Theme.current.textSecondary)
    }

    private func updateHeader() {
        let title = isStreaming ? L("chat.thinking", "Chat") + "..." : L("chat.thinkingProcess", "Chat")
        headerButton.setTitle(title, for: .normal)
        headerButton.setTitleColor(Theme.current.textSecondary, for: .normal)
    }

    @objc private func toggle() {
        expanded.toggle()
        contentLabel.isHidden = !expanded
        let img = expanded ? Icons.image(.chevronDown, size: 12, color: Theme.current.textSecondary) : Icons.image(.chevronRight, size: 12, color: Theme.current.textSecondary)
        // rotate chevron not available easily; swap icon
        chevron.image = img
        setNeedsLayout()
    }

    func append(_ delta: String) {
        thinkingText += delta
        contentLabel.text = thinkingText
    }
}
