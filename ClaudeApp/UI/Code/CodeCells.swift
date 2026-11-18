import UIKit

// MARK: - CodeUserCell

final class CodeUserCell: UITableViewCell {
    private let bubble = UIView()
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubble.backgroundColor = Theme.current.userBubble
        bubble.layer.cornerRadius = 18
        bubble.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubble)

        label.font = Fonts.sans(size: 16)
        label.textColor = Theme.current.textPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(label)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        bubble.backgroundColor = Theme.current.userBubble
        label.textColor = Theme.current.textPrimary
    }

    func configure(text: String) {
        label.text = text
    }
}

// MARK: - CodeAssistantCell

final class CodeAssistantCell: UITableViewCell {
    let markdownView: MarkdownContentView

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        markdownView = MarkdownContentView(style: MarkdownStyle.standard(textColor: Theme.current.textPrimary, secondary: Theme.current.textSecondary, accent: Theme.current.accent, codeBackground: Theme.current.codeBackground, isDark: Theme.current.isDark))
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        markdownView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(markdownView)
        NSLayoutConstraint.activate([
            markdownView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            markdownView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            markdownView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            markdownView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() { }

    func configure(text: String) {
        markdownView.update(markdown: text)
    }
}

// MARK: - CodeThinkingCell

final class CodeThinkingCell: UITableViewCell {
    private let thinkingView = ThinkingView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        thinkingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thinkingView)
        NSLayoutConstraint.activate([
            thinkingView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            thinkingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thinkingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            thinkingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    func configure(text: String) {
        thinkingView.thinkingText = text
        thinkingView.isStreaming = false
    }
}

// MARK: - CodeToolUseCell

final class CodeToolUseCell: UITableViewCell {
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        label.font = Fonts.mono(size: 13)
        label.textColor = Theme.current.textSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        label.textColor = Theme.current.textSecondary
    }

    func configure(name: String, summary: String) {
        if summary.isEmpty {
            label.text = "⏺ \(name)"
        } else {
            label.text = "⏺ \(name)(\(summary))"
        }
    }
}

// MARK: - CodeToolResultCell

final class CodeToolResultCell: UITableViewCell {
    private let container = UIView()
    private let headerButton = UIButton(type: .system)
    private let contentLabel = UILabel()
    private var expanded = true

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        container.backgroundColor = Theme.current.surface
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.current.border.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        headerButton.setTitle("Result  ▾", for: .normal)
        headerButton.titleLabel?.font = Fonts.mono(size: 12, weight: .semibold)
        headerButton.setTitleColor(Theme.current.textSecondary, for: .normal)
        headerButton.contentHorizontalAlignment = .left
        headerButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerButton)

        contentLabel.font = Fonts.mono(size: 12)
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            headerButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            headerButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            headerButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            headerButton.heightAnchor.constraint(equalToConstant: 20),

            contentLabel.topAnchor.constraint(equalTo: headerButton.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            contentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            contentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        container.backgroundColor = Theme.current.surface
        container.layer.borderColor = Theme.current.border.cgColor
    }

    @objc private func toggle() {
        expanded.toggle()
        contentLabel.isHidden = !expanded
        headerButton.setTitle(expanded ? "Result  ▾" : "Result  ▸", for: .normal)
    }

    func configure(text: String, isError: Bool) {
        contentLabel.text = String(text.prefix(2000))
        contentLabel.textColor = isError ? Theme.current.destructive : Theme.current.textSecondary
        expanded = true
        contentLabel.isHidden = false
        headerButton.setTitle("Result  ▾", for: .normal)
    }
}

// MARK: - CodeStatusCell

final class CodeStatusCell: UITableViewCell {
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        label.font = Fonts.sans(size: 12, weight: .medium)
        label.textColor = Theme.current.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
    }

    func configure(text: String) {
        label.text = text
    }
}