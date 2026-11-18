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
        if screen != nil && screen != "account_live" && screen != "account_history" && screen != "account_code" && screen != "cookie_login" && screen != "cookie_login_live" {
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
        } else if screen == "cookie_login" {
            nav.setViewControllers([CookieLoginViewController()], animated: false)
        } else if screen == "cookie_login_live" {
            nav.setViewControllers([CookieLoginViewController()], animated: false)
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
        case "onboarding", "account_login", "cookie_login":
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
        case "account_live":
            mainNav?.setViewControllers([ChatViewController(conversationId: nil, projectId: nil)], animated: false)
        case "code_sessions":
            mainNav?.setViewControllers([CodeSessionsListViewController()], animated: false)
        case "code_session":
            if let s = DemoData.codeSessions.first(where: { $0.isRemoteControl }) ?? DemoData.codeSessions.first {
                openCodeSession(s)
            }
        #if DEBUG
        case "account_history":
            DispatchQueue.main.async { self.runAccountHistoryLive() }
        case "account_code":
            DispatchQueue.main.async { self.runAccountCodeLive() }
        case "cookie_login_live":
            DispatchQueue.main.async { self.runCookieLoginLive() }
        #endif
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

    func openCodeSessions() {
        let vc = CodeSessionsListViewController()
        mainNav?.setViewControllers([vc], animated: true)
        closeSidebar()
    }

    func openCodeSession(_ session: CodeSession) {
        let vc = CodeSessionViewController(session: session)
        if let nav = mainNav {
            if nav.viewControllers.isEmpty {
                nav.setViewControllers([vc], animated: false)
            } else {
                nav.pushViewController(vc, animated: true)
            }
        }
        closeSidebar()
    }

    #if DEBUG
    private func liveProgress(_ step: String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("account_live_progress.txt")
        let line = "\(Date().timeIntervalSince1970) \(step)\n"
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); h.closeFile() } else { try? Data(line.utf8).write(to: url) }
    }

    private func runAccountHistoryLive() {
        liveProgress("history: start")
        var stage = "sync"
        var error: String? = nil
        var counts: [String: Int] = ["conversations": 0, "messages": 0]
        ClaudeHistoryService.shared.syncRecents(maxPages: 3) { err in
            DispatchQueue.main.async {
                self.liveProgress("history: sync done error=\(err != nil)")
                if let err = err {
                    error = err.localizedDescription
                    self.writeLiveResult(ok: false, error: error ?? "", stage: "sync", counts: counts, extraFiles: [])
                    return
                }
                self.rootViewController?.openSidebar(animated: false)
                counts["conversations"] = ConversationStore.shared.allConversations.filter { $0.origin == "claudeAi" }.count

                let remotes = ConversationStore.shared.allConversations.filter { $0.origin == "claudeAi" }
                guard let newest = remotes.sorted(by: { $0.updatedAt > $1.updatedAt }).first else {
                    self.writeLiveResult(ok: true, error: "", stage: "sync", counts: counts, extraFiles: [])
                    return
                }
                stage = "load"
                self.liveProgress("history: load start (remotes=\(remotes.count))")
                ClaudeHistoryService.shared.loadConversation(id: newest.id) { result in
                    DispatchQueue.main.async {
                        self.liveProgress("history: load done")
                        switch result {
                        case .success(let conv):
                            counts["conversations"] = ConversationStore.shared.allConversations.filter { $0.origin == "claudeAi" }.count
                            counts["messages"] = conv.messages.count
                            self.currentConversationId = conv.id
                            let vc = ChatViewController(conversationId: conv.id, projectId: nil)
                            self.mainNav?.setViewControllers([vc], animated: false)
                            self.writeLiveResult(ok: true, error: "", stage: "load", counts: counts, extraFiles: [])
                        case .failure(let e):
                            error = e.localizedDescription
                            counts["messages"] = 0
                            self.writeLiveResult(ok: false, error: error ?? "", stage: "load", counts: counts, extraFiles: [])
                        }
                    }
                }
            }
        }
    }

    private func runAccountCodeLive() {
        ClaudeCodeService.shared.listSessions { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let e):
                    let counts: [String: Int] = ["sessions": 0, "remote_control": 0, "items": 0]
                    self.writeLiveResult(ok: false, error: e.localizedDescription, stage: "list", counts: counts, extraFiles: ["account_code_result.json"])
                case .success(let (sessions, _)):
                    let rc = sessions.filter { $0.isRemoteControl }.count
                    let first = sessions.first(where: { $0.isRemoteControl }) ?? sessions.first
                    guard let s = first else {
                        self.openCodeSessions()
                        let counts: [String: Int] = ["sessions": sessions.count, "remote_control": rc, "items": 0]
                        self.writeLiveResult(ok: true, error: "", stage: "list", counts: counts, extraFiles: ["account_code_result.json"])
                        return
                    }
                    ClaudeCodeService.shared.loadTranscript(sessionId: s.id) { res in
                        DispatchQueue.main.async {
                            switch res {
                            case .failure(let e):
                                let counts: [String: Int] = ["sessions": sessions.count, "remote_control": rc, "items": 0]
                                self.writeLiveResult(ok: false, error: e.localizedDescription, stage: "load", counts: counts, extraFiles: ["account_code_result.json"])
                            case .success(let (items, _)):
                                self.openCodeSession(s)
                                let counts: [String: Int] = ["sessions": sessions.count, "remote_control": rc, "items": items.count]
                                self.writeLiveResult(ok: true, error: "", stage: "load", counts: counts, extraFiles: ["account_code_result.json"])
                            }
                        }
                    }
                }
            }
        }
    }

    private func writeLiveResult(ok: Bool, error: String, stage: String, counts: [String: Int], extraFiles: [String]) {
        let dict: [String: Any] = ["ok": ok, "error": error, "stage": stage, "counts": counts]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: dir.appendingPathComponent("account_live_result.json"))
            for f in extraFiles {
                try? data.write(to: dir.appendingPathComponent(f))
            }
        }
    }
    
    private func runCookieLoginLive() {
        ClaudeAccountAuth.shared.logout()
        let vc = CookieLoginViewController()
        self.mainNav?.setViewControllers([vc], animated: false)
        if let key = ProcessInfo.processInfo.environment["CLAUDE_DEBUG_SESSION_KEY"], !key.isEmpty {
            vc.sessionKeyTextField.text = key
        }
        vc.onLoginResult = { [weak self] success, message in
            guard let self = self else { return }
            let loggedIn = (SettingsStore.shared.authMode == "claudeAccount" && ClaudeAccountAuth.shared.isLoggedIn) ? 1 : 0
            let counts: [String: Int] = ["logged_in": loggedIn]
            self.writeLiveResult(ok: success, error: message ?? "", stage: "cookie_login", counts: counts, extraFiles: [])
            if success {
                self.finishOnboarding()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            vc.loginTapped()
        }
    }
    #endif

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
