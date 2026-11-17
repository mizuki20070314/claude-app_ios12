import UIKit

final class BottomSheetController: UIViewController {
    static func present(_ content: UIViewController, from presenter: UIViewController) {
        let sheet = BottomSheetController(content: content)
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        presenter.present(sheet, animated: false, completion: nil)
    }

    private let contentVC: UIViewController
    private let dimmingView = UIView()
    private let containerView = UIView()
    private let grabber = UIView()

    init(content: UIViewController) {
        self.contentVC = content
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        dimmingView.backgroundColor = Theme.current.dimming
        dimmingView.alpha = 0
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimmingView)
        dimmingView.pinToSuperview()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSheet))
        dimmingView.addGestureRecognizer(tap)

        containerView.backgroundColor = Theme.current.surface
        containerView.layer.cornerRadius = 16
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        grabber.backgroundColor = Theme.current.textTertiary
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(grabber)

        addChild(contentVC)
        contentVC.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentVC.view)
        contentVC.didMove(toParent: self)

        let preferred = contentVC.preferredContentSize.height
        let screenH = UIScreen.main.bounds.height
        let height = min(preferred > 0 ? preferred : 300, screenH * 0.85)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: height),

            grabber.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            grabber.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),

            contentVC.view.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 8),
            contentVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange(_:)), name: Theme.didChange, object: nil)

        // animate in
        containerView.transform = CGAffineTransform(translationX: 0, y: height)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.dimmingView.alpha = 1
            self.containerView.transform = .identity
        }, completion: nil)
    }

    @objc private func dismissSheet() {
        let height = containerView.bounds.height
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            self.dimmingView.alpha = 0
            self.containerView.transform = CGAffineTransform(translationX: 0, y: height)
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @objc private func themeDidChange(_ notification: Notification) {
        dimmingView.backgroundColor = Theme.current.dimming
        containerView.backgroundColor = Theme.current.surface
        grabber.backgroundColor = Theme.current.textTertiary
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
