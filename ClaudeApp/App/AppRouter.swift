import UIKit

final class AppRouter {
    static let shared = AppRouter()

    static var screenshotScreen: String? {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "-screenshot"), idx + 1 < args.count {
            return args[idx + 1]
        }
        return nil
    }

    var window: UIWindow?
    private(set) var rootViewController: RootViewController?
    private var mainNav: ThemedNavigationController?

    var isSidebarPersistent: Bool {
        return rootViewController?.isSidebarPersistent ?? false
    }

    var currentConversationId: String?

    private init() {}

    func start(window: UIWindow) {
        self.window = window
        Theme.setMode(ThemeMode(rawValue: SettingsStore.shared.themeMode) ?? .system)

        let screen = AppRouter.screenshotScreen
        if screen != nil {
            loadDemoData()
            if screen == "dark_chat" || screen == "dark_home" {
                Theme.forcedDark = true
                Theme.setMode(.dark)
            }
            // set userName in memory-ish
            SettingsStore.shared.userName = "みずき"
        }

        let sidebar = SidebarViewController()
        let nav = ThemedNavigationController(rootViewController: UIViewController())
        // placeholder replaced below
        self.mainNav = nav
        let root = RootViewController(mainNavigationController: nav, sidebarViewController: sidebar)
        self.rootViewController = root
        window.rootViewController = root
        window.makeKeyAndVisible()

        // Determine initial content
        if screen == "onboarding" {
            nav.setViewControllers([OnboardingViewController()], animated: false)
        } else if screen == "account_login" {
            nav.setViewControllers([AccountLoginViewController()], animated: false)
        } else if screen == nil && !self.isAuthenticatedForOnboarding() {
            nav.setViewControllers([OnboardingViewController()], animated: false)
        } else {
            nav.setViewControllers([ChatViewController(conversationId: nil, projectId: nil)], animated: false)
        }

        handleScreenshot(screen: screen)
    }

    private func loadDemoData() {
        ConversationStore.shared.loadDemoData(DemoData.conversations, DemoData.projects)
    }

    private func handleScreenshot(screen: String?) {
        guard let screen = screen else { return }
        switch screen {
        case "onboarding", "account_login":
            break
        case "home", "dark_home":
            mainNav?.setViewControllers([ChatViewController(conversationId: nil, projectId: nil)], animated: false)
        case "chat", "dark_chat":
            openConversation(id: "demo-chat")
        case "sidebar":
            mainNav?.setViewControllers([ChatViewController(conversationId: nil, projectId: nil)], animated: false)
            DispatchQueue.main.async { self.rootViewController?.openSidebar(animated: false) }
        case "models":
            mainNav?.setViewControllers([ChatViewController(conversationId: nil, projectId: nil)], animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let picker = ModelPickerViewController(selectedId: SettingsStore.shared.selectedModelId) { _ in }
                BottomSheetController.present(picker, from: self.topViewController ?? self.mainNav!)
            }
        case "settings":
            openSettings()
        case "projects":
            openProjects()
        case "project_detail":
            openProject(id: "demo-project")
        case "search":
            openSearch(initialQuery: "Swift")
        case "artifact":
            let vc = ArtifactViewController(title: "Todo アプリ", language: "html", code: DemoData.sampleHTML)
            mainNav?.pushViewController(vc, animated: false)
        default:
            break
        }
    }

    func startNewChat(projectId: String? = nil) {
        currentConversationId = nil
        let vc = ChatViewController(conversationId: nil, projectId: projectId)
        mainNav?.setViewControllers([vc], animated: true)
        closeSidebar()
    }

    func openConversation(id: String) {
        currentConversationId = id
        let vc = ChatViewController(conversationId: id, projectId: nil)
        mainNav?.setViewControllers([vc], animated: true)
        closeSidebar()
    }

    func openSettings() {
        let vc = SettingsViewController()
        let nav = ThemedNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        topViewController?.present(nav, animated: true, completion: nil)
        closeSidebar()
    }

    func openProjects() {
        let vc = ProjectsListViewController()
        mainNav?.setViewControllers([vc], animated: true)
        closeSidebar()
    }

    func openProject(id: String) {
        let list = ProjectsListViewController()
        let detail = ProjectDetailViewController(projectId: id)
        list.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        mainNav?.setViewControllers([list, detail], animated: true)
        closeSidebar()
    }

    func openArtifacts() {
        let vc = ArtifactsGalleryViewController()
        mainNav?.setViewControllers([vc], animated: true)
        closeSidebar()
    }

    func openSearch(initialQuery: String = "") {
        let vc = SearchViewController()
        vc.initialQuery = initialQuery
        mainNav?.setViewControllers([vc], animated: true)
        closeSidebar()
    }

    func toggleSidebar() {
        rootViewController?.toggleSidebar()
    }

    func closeSidebar() {
        rootViewController?.closeSidebar(animated: true)
    }

    func finishOnboarding() {
        mainNav?.setViewControllers([ChatViewController(conversationId: nil, projectId: nil)], animated: true)
    }

    func signOut() {
        ClaudeAccountAuth.shared.logout()
        SettingsStore.shared.apiKey = ""
        SettingsStore.shared.authMode = "apiKey"
        mainNav?.setViewControllers([OnboardingViewController()], animated: true)
    }

    private func isAuthenticatedForOnboarding() -> Bool {
        if SettingsStore.shared.authMode == "claudeAccount" && ClaudeAccountAuth.shared.isLoggedIn {
            return true
        }
        return !SettingsStore.shared.apiKey.isEmpty
    }

    var topViewController: UIViewController? {
        if let presented = mainNav?.presentedViewController {
            if let nav = presented as? UINavigationController {
                return nav.topViewController ?? presented
            }
            return presented
        }
        return mainNav?.topViewController
    }
}
