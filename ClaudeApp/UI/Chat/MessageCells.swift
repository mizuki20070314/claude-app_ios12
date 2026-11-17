import UIKit

// MARK: - UserMessageCell

final class UserMessageCell: UITableViewCell {
    private let bubble = UIView()
    private let label = UILabel()
    private let attachmentStack = UIStackView()

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

        attachmentStack.axis = .horizontal
        attachmentStack.spacing = 6
        attachmentStack.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(attachmentStack)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),

            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),

            attachmentStack.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            attachmentStack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            attachmentStack.trailingAnchor.constraint(lessThanOrEqualTo: bubble.trailingAnchor, constant: -14),
            attachmentStack.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        bubble.backgroundColor = Theme.current.userBubble
        label.textColor = Theme.current.textPrimary
    }

    func configure(message: Message) {
        label.text = message.text
        for v in attachmentStack.arrangedSubviews { v.removeFromSuperview() }
        for att in message.attachments {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 10
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 120).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 120).isActive = true
            if let img = att.thumbnail {
                iv.image = img
            }
            attachmentStack.addArrangedSubview(iv)
        }
        attachmentStack.isHidden = message.attachments.isEmpty
    }
}

// MARK: - AssistantMessageCell

final class AssistantMessageCell: UITableViewCell {
    private let container = UIView()
    let sparkView = SparkView()
    let thinkingView = ThinkingView()
    let markdownView: MarkdownContentView
    private let actionStack = UIStackView()
    private let copyButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let thumbsUpButton = UIButton(type: .system)
    private let thumbsDownButton = UIButton(type: .system)
    private let artifactStack = UIStackView()
    private let errorStack = UIStackView()
    private let errorLabel = UILabel()
    private let retryErrorButton = UIButton(type: .system)

    var onCopy: ((String) -> Void)?
    var onRetry: (() -> Void)?
    var onFeedback: ((Int) -> Void)?
    var onArtifactTap: ((String, String?, String) -> Void)?
    var onThinkingToggle: (() -> Void)?
    var isLast: Bool = false

    private var currentMessage: Message?

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

        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        sparkView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sparkView)

        thinkingView.translatesAutoresizingMaskIntoConstraints = false
        thinkingView.onToggle = { [weak self] in self?.onThinkingToggle?() }
        container.addSubview(thinkingView)

        markdownView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(markdownView)

        actionStack.axis = .horizontal
        actionStack.spacing = 4
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(actionStack)

        copyButton.setImage(Icons.image(.copy, size: 18, color: Theme.current.textSecondary), for: .normal)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        retryButton.setImage(Icons.image(.retry, size: 18, color: Theme.current.textSecondary), for: .normal)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        thumbsUpButton.setImage(Icons.image(.thumbsUp, size: 18, color: Theme.current.textSecondary), for: .normal)
        thumbsUpButton.addTarget(self, action: #selector(thumbsUpTapped), for: .touchUpInside)
        thumbsDownButton.setImage(Icons.image(.thumbsDown, size: 18, color: Theme.current.textSecondary), for: .normal)
        thumbsDownButton.addTarget(self, action: #selector(thumbsDownTapped), for: .touchUpInside)

        [copyButton, retryButton, thumbsUpButton, thumbsDownButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 32).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
            actionStack.addArrangedSubview(btn)
        }

        artifactStack.axis = .vertical
        artifactStack.spacing = 8
        artifactStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(artifactStack)

        errorStack.axis = .horizontal
        errorStack.spacing = 8
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.isHidden = true
        container.addSubview(errorStack)

        errorLabel.font = Fonts.sans(size: 14)
        errorLabel.textColor = Theme.current.destructive
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorStack.addSubview(errorLabel)

        retryErrorButton.setTitle(L("chat.retry", "Chat"), for: .normal)
        retryErrorButton.setTitleColor(Theme.current.accent, for: .normal)
        retryErrorButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryErrorButton.translatesAutoresizingMaskIntoConstraints = false
        errorStack.addSubview(retryErrorButton)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            sparkView.topAnchor.constraint(equalTo: container.topAnchor),
            sparkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sparkView.widthAnchor.constraint(equalToConstant: 24),
            sparkView.heightAnchor.constraint(equalToConstant: 24),

            thinkingView.topAnchor.constraint(equalTo: sparkView.bottomAnchor, constant: 4),
            thinkingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thinkingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            markdownView.topAnchor.constraint(equalTo: thinkingView.bottomAnchor, constant: 8),
            markdownView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            markdownView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            actionStack.topAnchor.constraint(equalTo: markdownView.bottomAnchor, constant: 8),
            actionStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            artifactStack.topAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 8),
            artifactStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            artifactStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            errorStack.topAnchor.constraint(equalTo: artifactStack.bottomAnchor, constant: 8),
            errorStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            errorStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            errorStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: errorStack.leadingAnchor),
            errorLabel.topAnchor.constraint(equalTo: errorStack.topAnchor),
            errorLabel.bottomAnchor.constraint(equalTo: errorStack.bottomAnchor),

            retryErrorButton.leadingAnchor.constraint(equalTo: errorLabel.trailingAnchor, constant: 8),
            retryErrorButton.centerYAnchor.constraint(equalTo: errorLabel.centerYAnchor),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        // Style changes are handled by ChatViewController (reload).
    }

    func configure(message: Message, isStreaming: Bool) {
        currentMessage = message
        thinkingView.isHidden = (message.thinking?.isEmpty ?? true) && !isStreaming
        if let t = message.thinking {
            thinkingView.thinkingText = t
        }
        thinkingView.isStreaming = isStreaming
        sparkView.isHidden = !isStreaming
        if isStreaming { sparkView.startPulsing(); sparkView.color = Theme.current.accent }
        else { sparkView.stopPulsing() }

        markdownView.update(markdown: message.text)

        // action row visibility
        actionStack.isHidden = isStreaming || message.isError
        retryButton.isHidden = !isLast

        // error row
        errorStack.isHidden = !message.isError
        if message.isError {
            errorLabel.text = message.text.isEmpty ? L("chat.error", "Chat") : message.text
        }

        // artifact cards
        rebuildArtifacts(for: message.text)

        // feedback state
        updateFeedbackAppearance(message.feedback)
    }

    func updateMarkdown(_ text: String) {
        markdownView.update(markdown: text)
    }

    func setStreaming(_ streaming: Bool) {
        sparkView.isHidden = !streaming
        if streaming { sparkView.startPulsing() } else { sparkView.stopPulsing() }
        actionStack.isHidden = streaming
        thinkingView.isStreaming = streaming
    }

    private func updateFeedbackAppearance(_ feedback: Int?) {
        let upColor = feedback == 1 ? Theme.current.textPrimary : Theme.current.textSecondary
        let downColor = feedback == -1 ? Theme.current.textPrimary : Theme.current.textSecondary
        thumbsUpButton.setImage(Icons.image(.thumbsUp, size: 16, color: upColor), for: .normal)
        thumbsDownButton.setImage(Icons.image(.thumbsDown, size: 16, color: downColor), for: .normal)
    }

    private func rebuildArtifacts(for text: String) {
        for v in artifactStack.arrangedSubviews { v.removeFromSuperview() }
        let blocks = MarkdownParser.parse(text)
        for block in blocks {
            if case .codeBlock(let lang, let code) = block {
                let lines = code.components(separatedBy: "\n").count
                let isHtml = (lang?.lowercased() == "html" || lang?.lowercased() == "svg")
                if isHtml || lines >= 15 {
                    let card = makeArtifactCard(title: artifactTitle(code: code), subtitle: "コード · \(lang ?? "code")", language: lang, code: code)
                    artifactStack.addArrangedSubview(card)
                }
            }
        }
        artifactStack.isHidden = artifactStack.arrangedSubviews.isEmpty
    }

    private func artifactTitle(code: String) -> String {
        let first = code.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? ""
        if first.isEmpty { return "Code" }
        return String(first.prefix(40))
    }

    private func makeArtifactCard(title: String, subtitle: String, language: String?, code: String) -> UIView {
        let card = ArtifactCardView()
        card.backgroundColor = Theme.current.surface
        card.layer.cornerRadius = 10
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.current.border.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.onTap = { [weak self] in
            self?.onArtifactTap?(title, language, code)
        }

        let titleLabel = UILabel()
        titleLabel.text = "</> \(title)"
        titleLabel.font = Fonts.sans(size: 14, weight: .medium)
        titleLabel.textColor = Theme.current.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = Fonts.sans(size: 12)
        subtitleLabel.textColor = Theme.current.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let openLabel = UILabel()
        openLabel.text = L("chat.openArtifact", "Chat")
        openLabel.font = Fonts.sans(size: 12, weight: .medium)
        openLabel.textColor = Theme.current.accent
        openLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(openLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),

            openLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 6),
            openLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            openLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        return card
    }

    @objc private func copyTapped() {
        if let msg = currentMessage { onCopy?(msg.text) }
    }

    @objc private func retryTapped() { onRetry?() }

    @objc private func thumbsUpTapped() {
        if let msg = currentMessage {
            let new = (msg.feedback == 1) ? nil : 1
            onFeedback?(new ?? 1) // toggle? contract set feedback; keep simple
        }
    }

    @objc private func thumbsDownTapped() {
        onFeedback?(-1)
    }
}

// MARK: - ArtifactCardView

final class ArtifactCardView: UIView {
    var onTap: (() -> Void)?

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?() }
}
