import UIKit

protocol ComposerViewDelegate: AnyObject {
    func composerDidTapSend(_ composer: ComposerView, text: String, attachments: [Attachment])
    func composerDidTapStop(_ composer: ComposerView)
    func composerDidTapAttach(_ composer: ComposerView)
    func composerDidTapModel(_ composer: ComposerView)
    func composerDidToggleThinking(_ composer: ComposerView)
}

final class ComposerView: UIView {
    weak var delegate: ComposerViewDelegate?

    private let card = UIView()
    private let attachmentStrip = AttachmentStripView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let attachButton = UIButton(type: .system)
    private let thinkingButton = UIButton(type: .system)
    private let modelButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)

    private var textViewHeightConstraint: NSLayoutConstraint?
    private var attachmentStripHeightConstraint: NSLayoutConstraint?
    private let maxLines: CGFloat = 6
    private let minTextHeight: CGFloat = 36
    private var lastTextViewWidth: CGFloat = 0

    var attachments: [Attachment] = [] {
        didSet {
            attachmentStrip.setAttachments(attachments)
            attachmentStrip.isHidden = attachments.isEmpty
            attachmentStripHeightConstraint?.constant = attachments.isEmpty ? 0 : 64
            updateTextViewHeight()
        }
    }

    var isStreaming: Bool = false {
        didSet { updateSendStop() }
    }

    var selectedModelId: String = ModelOption.default.id {
        didSet { updateModelTitle() }
    }

    var thinkingEnabled: Bool = false {
        didSet { updateThinkingAppearance() }
    }

    var text: String {
        get { textView.text ?? "" }
        set {
            textView.text = newValue
            updatePlaceholder()
            updateSendState()
            updateTextViewHeight()
        }
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
        backgroundColor = .clear

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        card.backgroundColor = Theme.current.composerBackground
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.current.border.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        attachmentStrip.translatesAutoresizingMaskIntoConstraints = false
        attachmentStrip.onRemove = { [weak self] att in
            self?.removeAttachment(att)
        }
        card.addSubview(attachmentStrip)

        textView.font = Fonts.sans(size: 16)
        textView.textColor = Theme.current.textPrimary
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.delegate = self
        textView.keyboardAppearance = Theme.current.keyboardAppearance
        textView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(textView)

        placeholderLabel.text = L("chat.placeholder", "Chat")
        placeholderLabel.font = Fonts.sans(size: 16)
        placeholderLabel.textColor = Theme.current.textTertiary
        placeholderLabel.textAlignment = .left
        placeholderLabel.numberOfLines = 1
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(placeholderLabel)

        attachButton.setImage(Icons.image(.plus, size: 20, color: Theme.current.textSecondary), for: .normal)
        attachButton.addTarget(self, action: #selector(attachTapped), for: .touchUpInside)
        attachButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(attachButton)

        thinkingButton.setImage(Icons.image(.thinking, size: 20, color: Theme.current.textSecondary), for: .normal)
        thinkingButton.addTarget(self, action: #selector(thinkingTapped), for: .touchUpInside)
        thinkingButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(thinkingButton)

        modelButton.titleLabel?.font = Fonts.sans(size: 13, weight: .medium)
        modelButton.layer.cornerRadius = 12
        modelButton.layer.borderWidth = 1
        modelButton.layer.borderColor = Theme.current.border.cgColor
        modelButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        modelButton.addTarget(self, action: #selector(modelTapped), for: .touchUpInside)
        modelButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(modelButton)

        sendButton.layer.cornerRadius = 16
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        sendButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        card.addSubview(sendButton)

        let hConstraint = textView.heightAnchor.constraint(equalToConstant: minTextHeight)
        textViewHeightConstraint = hConstraint

        let aConstraint = attachmentStrip.heightAnchor.constraint(equalToConstant: 0)
        attachmentStripHeightConstraint = aConstraint

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            attachmentStrip.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            attachmentStrip.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            attachmentStrip.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            aConstraint,

            textView.topAnchor.constraint(equalTo: attachmentStrip.bottomAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            hConstraint,
            textView.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -52),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 4),

            attachButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            attachButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            attachButton.widthAnchor.constraint(equalToConstant: 36),
            attachButton.heightAnchor.constraint(equalToConstant: 36),

            thinkingButton.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 4),
            thinkingButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            thinkingButton.widthAnchor.constraint(equalToConstant: 36),
            thinkingButton.heightAnchor.constraint(equalToConstant: 36),

            modelButton.leadingAnchor.constraint(equalTo: thinkingButton.trailingAnchor, constant: 8),
            modelButton.centerYAnchor.constraint(equalTo: attachButton.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            sendButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
        ])

        attachmentStrip.isHidden = true
        updateModelTitle()
        updateThinkingAppearance()
        updateSendStop()
        updateSendState()

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Theme.didChange, object: nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if textView.bounds.width > 0 && textView.bounds.width != lastTextViewWidth {
            lastTextViewWidth = textView.bounds.width
            updateTextViewHeight()
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        card.backgroundColor = Theme.current.composerBackground
        card.layer.borderColor = Theme.current.border.cgColor
        textView.textColor = Theme.current.textPrimary
        textView.keyboardAppearance = Theme.current.keyboardAppearance
        placeholderLabel.textColor = Theme.current.textTertiary
        attachButton.setImage(Icons.image(.plus, size: 20, color: Theme.current.textSecondary), for: .normal)
        thinkingButton.setImage(Icons.image(.thinking, size: 20, color: thinkingEnabled ? Theme.current.accent : Theme.current.textSecondary), for: .normal)
        modelButton.layer.borderColor = Theme.current.border.cgColor
        modelButton.setTitleColor(Theme.current.textPrimary, for: .normal)
        sendButton.backgroundColor = canSend ? Theme.current.sendButton : Theme.current.sendButtonDisabled
    }

    private func removeAttachment(_ att: Attachment) {
        attachments.removeAll { $0.id == att.id }
    }

    @objc private func attachTapped() { delegate?.composerDidTapAttach(self) }
    @objc private func thinkingTapped() {
        thinkingEnabled.toggle()
        delegate?.composerDidToggleThinking(self)
    }
    @objc private func modelTapped() { delegate?.composerDidTapModel(self) }
    @objc private func sendTapped() {
        if isStreaming {
            delegate?.composerDidTapStop(self)
            return
        }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty || !attachments.isEmpty else { return }
        delegate?.composerDidTapSend(self, text: t, attachments: attachments)
        // clear
        text = ""
        attachments = []
        updateTextViewHeight()
    }

    private var canSend: Bool {
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    private func updateSendState() {
        sendButton.isEnabled = canSend || isStreaming
        sendButton.backgroundColor = (canSend || isStreaming) ? Theme.current.sendButton : Theme.current.sendButtonDisabled
        let iconName: IconName = isStreaming ? .stop : .send
        sendButton.setImage(Icons.image(iconName, size: 16, color: .white), for: .normal)
        placeholderLabel.isHidden = !text.isEmpty
    }

    private func updateSendStop() {
        updateSendState()
    }

    private func updateModelTitle() {
        let short = shortName(for: selectedModelId)
        modelButton.setTitle(short, for: .normal)
        modelButton.setTitleColor(Theme.current.textPrimary, for: .normal)
    }

    private func shortName(for id: String) -> String {
        if let m = ModelOption.find(id: id) {
            // "Claude Sonnet 5.5" -> "Sonnet 5.5"
            return m.displayName.replacingOccurrences(of: "Claude ", with: "")
        }
        return id
    }

    private func updateThinkingAppearance() {
        thinkingButton.setImage(Icons.image(.thinking, size: 20, color: thinkingEnabled ? Theme.current.accent : Theme.current.textSecondary), for: .normal)
    }

    private func updateTextViewHeight() {
        let width = textView.bounds.width
        guard width > 0 else { return }
        let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let lineHeight = textView.font?.lineHeight ?? 20
        let maxHeight = lineHeight * maxLines + textView.textContainerInset.top + textView.textContainerInset.bottom
        let newHeight = min(max(size.height, minTextHeight), maxHeight)
        if textViewHeightConstraint?.constant != newHeight {
            textViewHeightConstraint?.constant = newHeight
        }
        let shouldScroll = size.height > maxHeight + 0.5
        if textView.isScrollEnabled != shouldScroll {
            textView.isScrollEnabled = shouldScroll
        }
    }
}

extension ComposerView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        updateTextViewHeight()
        updateSendState()
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}