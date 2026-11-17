import UIKit

final class RootViewController: UIViewController {
    private let mainNav: ThemedNavigationController
    private let sidebar: SidebarViewController

    private let dimmingView = UIView()
    private var sidebarOpen = false
    private var isPersistentCached = false

    var isSidebarPersistent: Bool {
        return view.bounds.width >= 700
    }

    init(mainNavigationController: ThemedNavigationController, sidebarViewController: SidebarViewController) {
        self.mainNav = mainNavigationController
        self.sidebar = sidebarViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.current.background

        addChild(mainNav)
        mainNav.view.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(mainNav.view)
        mainNav.didMove(toParent: self)

        addChild(sidebar)
        sidebar.view.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(sidebar.view)
        sidebar.didMove(toParent: self)

        dimmingView.backgroundColor = Theme.current.dimming
        dimmingView.alpha = 0
        dimmingView.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(dimmingView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dimmingTapped))
        dimmingView.addGestureRecognizer(tap)

        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edgePan.edges = .left
        view.addGestureRecognizer(edgePan)

        let sidebarPan = UIPanGestureRecognizer(target: self, action: #selector(handleSidebarPan(_:)))
        sidebar.view.addGestureRecognizer(sidebarPan)

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange(_:)), name: Theme.didChange, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutAll(animated: false)
    }

    private func drawerWidth() -> CGFloat {
        return min(view.bounds.width * 0.82, 320)
    }

    private func layoutAll(animated: Bool) {
        let bounds = view.bounds
        let persistent = bounds.width >= 700
        isPersistentCached = persistent

        if persistent {
            let sw: CGFloat = 300
            sidebar.view.frame = CGRect(x: 0, y: 0, width: sw, height: bounds.height)
            mainNav.view.frame = CGRect(x: sw, y: 0, width: bounds.width - sw, height: bounds.height)
            dimmingView.frame = .zero
            dimmingView.alpha = 0
            sidebar.view.transform = .identity
            sidebarOpen = false
        } else {
            let sw = drawerWidth()
            mainNav.view.frame = bounds
            dimmingView.frame = bounds
            let x = sidebarOpen ? 0 : -sw
            if animated {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                    self.sidebar.view.frame = CGRect(x: x, y: 0, width: sw, height: bounds.height)
                    self.dimmingView.alpha = self.sidebarOpen ? 1 : 0
                }, completion: nil)
            } else {
                sidebar.view.frame = CGRect(x: x, y: 0, width: sw, height: bounds.height)
                dimmingView.alpha = sidebarOpen ? 1 : 0
            }
        }
    }

    func openSidebar(animated: Bool = true) {
        guard !isPersistentCached else { return }
        sidebarOpen = true
        Haptics.light()
        layoutAll(animated: animated)
    }

    func closeSidebar(animated: Bool = true) {
        guard !isPersistentCached else { return }
        sidebarOpen = false
        layoutAll(animated: animated)
    }

    func toggleSidebar() {
        if isPersistentCached { return }
        if sidebarOpen { closeSidebar() } else { openSidebar() }
    }

    @objc private func dimmingTapped() {
        closeSidebar()
    }

    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard !isPersistentCached else { return }
        let sw = drawerWidth()
        let translation = gesture.translation(in: view).x
        switch gesture.state {
        case .began, .changed:
            let x = min(0, -sw + translation)
            let clamped = max(-sw, x)
            sidebar.view.frame = CGRect(x: clamped, y: 0, width: sw, height: view.bounds.height)
            let progress = (clamped + sw) / sw
            dimmingView.alpha = max(0, min(1, progress))
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).x
            if translation > sw * 0.4 || velocity > 500 {
                openSidebar()
            } else {
                closeSidebar()
            }
        default:
            break
        }
    }

    @objc private func handleSidebarPan(_ gesture: UIPanGestureRecognizer) {
        guard !isPersistentCached else { return }
        let sw = drawerWidth()
        let translation = gesture.translation(in: view).x
        switch gesture.state {
        case .began, .changed:
            let x = min(0, translation)
            let clamped = max(-sw, x)
            sidebar.view.frame = CGRect(x: clamped, y: 0, width: sw, height: view.bounds.height)
            let progress = (clamped + sw) / sw
            dimmingView.alpha = max(0, min(1, progress))
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).x
            if translation < -sw * 0.3 || velocity < -500 {
                closeSidebar()
            } else {
                openSidebar()
            }
        default:
            break
        }
    }

    @objc private func themeDidChange(_ notification: Notification) {
        view.backgroundColor = Theme.current.background
        dimmingView.backgroundColor = Theme.current.dimming
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.current.statusBarStyle
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
