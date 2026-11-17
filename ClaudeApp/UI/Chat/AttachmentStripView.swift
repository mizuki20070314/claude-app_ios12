import UIKit

final class AttachmentStripView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    var onRemove: ((Attachment) -> Void)?

    private var attachments: [Attachment] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    func setAttachments(_ attachments: [Attachment]) {
        self.attachments = attachments
        for v in stack.arrangedSubviews { v.removeFromSuperview() }
        for att in attachments {
            let thumb = UIButton(type: .custom)
            thumb.translatesAutoresizingMaskIntoConstraints = false
            thumb.widthAnchor.constraint(equalToConstant: 56).isActive = true
            thumb.heightAnchor.constraint(equalToConstant: 56).isActive = true
            thumb.layer.cornerRadius = 8
            thumb.clipsToBounds = true
            thumb.backgroundColor = Theme.current.surface

            if let img = att.thumbnail {
                thumb.setImage(img, for: .normal)
                thumb.imageView?.contentMode = .scaleAspectFill
            } else {
                thumb.setTitle(att.fileName, for: .normal)
                thumb.titleLabel?.font = Fonts.sans(size: 9)
                thumb.setTitleColor(Theme.current.textPrimary, for: .normal)
            }

            // remove badge
            let badge = UIButton(type: .system)
            badge.setImage(Icons.image(.close, size: 10, color: .white), for: .normal)
            badge.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            badge.layer.cornerRadius = 10
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.widthAnchor.constraint(equalToConstant: 20).isActive = true
            badge.heightAnchor.constraint(equalToConstant: 20).isActive = true
            badge.addTarget(self, action: #selector(removeTapped(_:)), for: .touchUpInside)
            badge.tag = attachments.firstIndex(where: { $0.id == att.id }) ?? 0
            thumb.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: thumb.topAnchor, constant: 2),
                badge.trailingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: -2),
            ])

            stack.addArrangedSubview(thumb)
        }
        isHidden = attachments.isEmpty
    }

    @objc private func removeTapped(_ sender: UIButton) {
        guard sender.tag < attachments.count else { return }
        onRemove?(attachments[sender.tag])
    }
}
