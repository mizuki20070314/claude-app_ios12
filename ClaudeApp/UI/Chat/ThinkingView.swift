import UIKit

final class ThinkingView: UIView {
    var onToggle: (() -> Void)?
    var thinkingText: String = "" {
        didSet { updateContent() }
    }
    var isStreaming: Bool = false {
        didSet { updateHeader() }
    }

    private let stack = UIStackView()
    private let headerStack = UIStackView()
    private let iconView = UIImageView()
    private let sparkView = SparkView()
    private let label = UILabel()
    private let spacer = UIView()
    private let chevron = UIImageView()
    private let contentLabel = UILabel()

    private var expanded = false

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

        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = Icons.image(.thinking, size: 14, color: Theme.current.textSecondary)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true

        sparkView.translatesAutoresizingMaskIntoConstraints = false
        sparkView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        sparkView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        sparkView.isHidden = true

        label.font = Fonts.sans(size: 13)
        label.textColor = Theme.current.textSecondary
        label.text = L("chat.thinkingProcess", "Chat")

        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        chevron.image = Icons.image(.chevronRight, size: 12, color: Theme.current.textSecondary)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true
        chevron.heightAnchor.constraint(equalToConstant: 12).isActive = true

        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(sparkView)
        headerStack.addArrangedSubview(label)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(chevron)

        headerStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true

        contentLabel.font = Fonts.sans(size: 13)
        contentLabel.textColor = Theme.current.textSecondary
        contentLabel.numberOfLines = 0
        contentLabel.isHidden = true

        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(contentLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggle))
        headerStack.isUserInteractionEnabled = true
        headerStack.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
        updateHeader()
        updateContent()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        backgroundColor = Theme.current.thinkingBackground
        layer.borderColor = Theme.current.border.cgColor
        iconView.image = Icons.image(.thinking, size: 14, color: Theme.current.textSecondary)
        label.textColor = Theme.current.textSecondary
        chevron.image = expanded ? Icons.image(.chevronDown, size: 12, color: Theme.current.textSecondary) : Icons.image(.chevronRight, size: 12, color: Theme.current.textSecondary)
        contentLabel.textColor = Theme.current.textSecondary
        updateContent()
    }

    private func updateHeader() {
        if isStreaming {
            label.text = L("chat.thinking", "Chat") + "…"
            iconView.isHidden = true
            sparkView.isHidden = false
            sparkView.startPulsing()
            sparkView.color = Theme.current.accent
        } else {
            label.text = L("chat.thinkingProcess", "Chat")
            iconView.isHidden = false
            sparkView.isHidden = true
            sparkView.stopPulsing()
        }
    }

    private func updateContent() {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 3
        contentLabel.attributedText = NSAttributedString(string: thinkingText, attributes: [
            .font: Fonts.sans(size: 13),
            .foregroundColor: Theme.current.textSecondary,
            .paragraphStyle: para
        ])
    }

    @objc private func toggle() {
        expanded.toggle()
        contentLabel.isHidden = !expanded
        chevron.image = expanded ? Icons.image(.chevronDown, size: 12, color: Theme.current.textSecondary) : Icons.image(.chevronRight, size: 12, color: Theme.current.textSecondary)
        onToggle?()
    }

    func append(_ delta: String) {
        thinkingText += delta
    }
}