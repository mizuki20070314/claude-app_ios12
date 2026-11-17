import Foundation
import UIKit
import AuthenticationServices
import SafariServices

enum ClaudeAccountAuthError: Error, LocalizedError {
    case accountChatUnsupported
    case cancelled
    case networkError(String)
    case invalidSession

    var errorDescription: String? {
        switch self {
        case .accountChatUnsupported:
            return "Claude.ai アカウントログインは完了しましたが、このクライアントのチャット送信は API キー方式を使用します。設定で API キーを設定してください。"
        case .cancelled:
            return "ログインがキャンセルされました。"
        case .networkError(let m):
            return m.isEmpty ? "ネットワークエラーが発生しました。" : m
        case .invalidSession:
            return "Claude.ai セッションを確認できませんでした。もう一度ログインしてください。"
        }
    }
}

final class ClaudeAccountAuth: NSObject {
    static let shared = ClaudeAccountAuth()

    private let sessionKeyKey = "claudeSessionKey"
    private let lastActiveOrgKey = "claudeLastActiveOrg"
    private let callbackScheme = "claudeios12"
    private let callbackURL = "claudeios12://auth/callback"

    private var currentWebSession: Any?
    private var fallbackContainer: UIViewController?
    private var isFallbackValidating = false

    private override init() { super.init() }

    // MARK: - Public state

    var sessionKey: String? {
        let v = KeychainStore.shared.get(sessionKeyKey)
        if let v = v, !v.isEmpty { return v }
        return nil
    }

    var lastActiveOrg: String? {
        let v = KeychainStore.shared.get(lastActiveOrgKey)
        if let v = v, !v.isEmpty { return v }
        return nil
    }

    // Public storage helper for organization UUID (Keychain).
    func storeLastActiveOrg(_ org: String) {
        if !org.isEmpty {
            _ = KeychainStore.shared.set(org, for: lastActiveOrgKey)
        }
    }

    // Clear a stored account session after an explicit 401/403 from claude.ai.
    func clearSession() {
        _ = KeychainStore.shared.delete(sessionKeyKey)
        _ = KeychainStore.shared.delete(lastActiveOrgKey)
        SettingsStore.shared.accountEmail = ""
        SettingsStore.shared.authMode = "apiKey"
    }

    var isLoggedIn: Bool {
        return sessionKey != nil && SettingsStore.shared.authMode == "claudeAccount"
    }

    var accountDisplayName: String? {
        if !SettingsStore.shared.accountEmail.isEmpty { return SettingsStore.shared.accountEmail }
        return lastActiveOrg
    }

    // MARK: - Login

    func startLogin(from viewController: UIViewController, completion: ((Bool, String?) -> Void)? = nil) {
        let loginURL = URL(string: "https://claude.ai/login")!

        if #available(iOS 12.0, *) {
            let session = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                guard let self = self else { return }
                self.currentWebSession = nil
                if let error = error as NSError? {
                    if error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        // Still try to validate in case cookies were set before cancel.
                        self.validate { success, message in
                            completion?(success, message)
                        }
                        return
                    }
                }
                self.validate { success, message in
                    completion?(success, message)
                }
            }
            self.currentWebSession = session
            if session.start() {
                return
            }
            // Fall through to Safari fallback if start fails.
        }

        presentSafariFallback(from: viewController, completion: completion)
    }

    private func presentSafariFallback(from viewController: UIViewController, completion: ((Bool, String?) -> Void)?) {
        let loginURL = URL(string: "https://claude.ai/login")!
        let container = UIViewController()
        container.view.backgroundColor = .white

        let safari = SFSafariViewController(url: loginURL)
        safari.delegate = self

        container.addChild(safari)
        safari.view.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(safari.view)
        safari.didMove(toParent: container)

        let button = UIButton(type: .system)
        button.setTitle("ログイン完了", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(button)

        NSLayoutConstraint.activate([
            safari.view.topAnchor.constraint(equalTo: container.view.topAnchor),
            safari.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            safari.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            safari.view.bottomAnchor.constraint(equalTo: button.topAnchor),

            button.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.view.safeAreaLayoutGuide.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])

        // Validate when the user taps "done"; SFSafariViewController cannot detect login completion.
        button.addTarget(self, action: #selector(fallbackDoneTapped(_:)), for: .touchUpInside)

        self.fallbackContainer = container
        self.isFallbackValidating = false
        self.fallbackCompletion = completion

        if let nav = viewController.navigationController {
            nav.present(container, animated: true)
        } else {
            viewController.present(container, animated: true)
        }
    }

    private var fallbackCompletion: ((Bool, String?) -> Void)?

    @objc private func fallbackDoneTapped(_ sender: UIButton) {
        guard !isFallbackValidating else { return }
        isFallbackValidating = true
        validate { [weak self] success, message in
            guard let self = self else { return }
            self.dismissFallback()
            self.fallbackCompletion?(success, message)
            self.fallbackCompletion = nil
        }
    }

    private func dismissFallback() {
        fallbackContainer?.dismiss(animated: true, completion: nil)
        fallbackContainer = nil
    }

    // MARK: - Validation

    func validate(completion: @escaping (Bool, String?) -> Void) {
        // Extract cookies first (only claude.ai HTTPS cookies are considered).
        extractCookies()

        let sessionKeyValue = self.sessionKey

        func finish(_ success: Bool, _ message: String?) {
            DispatchQueue.main.async {
                if success {
                    SettingsStore.shared.authMode = "claudeAccount"
                }
                completion(success, message)
            }
        }

        // Reject empty sessions up front; never claim login success without a session key.
        guard let sk = sessionKeyValue, !sk.isEmpty else {
            DispatchQueue.main.async {
                completion(false, ClaudeAccountAuthError.invalidSession.errorDescription)
            }
            return
        }

        let endpoints = ["https://claude.ai/api/organizations", "https://claude.ai/api/account"]
        tryEndpoints(endpoints, sessionKeyValue: sk) { success, message in
            if success {
                finish(true, nil)
            } else {
                finish(false, message ?? ClaudeAccountAuthError.invalidSession.errorDescription)
            }
        }
    }

    private func tryEndpoints(_ endpoints: [String], sessionKeyValue: String?, index: Int = 0, completion: @escaping (Bool, String?) -> Void) {
        guard index < endpoints.count else {
            completion(false, ClaudeAccountAuthError.invalidSession.errorDescription)
            return
        }
        guard let url = URL(string: endpoints[index]) else {
            tryEndpoints(endpoints, sessionKeyValue: sessionKeyValue, index: index + 1, completion: completion)
            return
        }
        // Only HTTPS claude.ai endpoints are ever contacted with the session cookie.
        guard url.scheme?.lowercased() == "https", (url.host ?? "").lowercased().contains("claude.ai") else {
            tryEndpoints(endpoints, sessionKeyValue: sessionKeyValue, index: index + 1, completion: completion)
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.httpShouldHandleCookies = true
        if let sk = sessionKeyValue, !sk.isEmpty {
            req.setValue("sessionKey=\(sk)", forHTTPHeaderField: "Cookie")
        }
        // Also include lastActiveOrg cookie if available.
        if let org = lastActiveOrg, !org.isEmpty {
            let existing = req.value(forHTTPHeaderField: "Cookie") ?? ""
            let cookie = existing.isEmpty ? "lastActiveOrg=\(org)" : existing + "; lastActiveOrg=\(org)"
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                // Network errors must not clear stored credentials; just report.
                let msg: String
                if (error as NSError).code == NSURLErrorNotConnectedToInternet || (error as NSError).code == NSURLErrorNetworkConnectionLost {
                    msg = ClaudeAccountAuthError.networkError("ネットワークに接続できません。").errorDescription ?? ""
                } else {
                    msg = ClaudeAccountAuthError.networkError(error.localizedDescription).errorDescription ?? ""
                }
                completion(false, msg)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status >= 200 && status < 300 {
                // Best-effort parse profile fields.
                if let data = data {
                    self.parseProfile(data: data)
                }
                completion(true, nil)
                return
            }
            if status == 401 || status == 403 {
                // Explicitly unauthorized: clear the account session.
                _ = KeychainStore.shared.delete(self.sessionKeyKey)
                _ = KeychainStore.shared.delete(self.lastActiveOrgKey)
                SettingsStore.shared.accountEmail = ""
                SettingsStore.shared.authMode = "apiKey"
                completion(false, ClaudeAccountAuthError.invalidSession.errorDescription)
                return
            }
            // Try next endpoint on other statuses.
            self.tryEndpoints(endpoints, sessionKeyValue: sessionKeyValue, index: index + 1, completion: completion)
        }
        task.resume()
    }

    private func parseProfile(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return }
        var email: String?
        var name: String?
        var org: String?

        func orgFromDict(_ dict: [String: Any]) -> String? {
            if let account = dict["account"] as? [String: Any],
               let memberships = account["memberships"] as? [[String: Any]] {
                for m in memberships {
                    if let o = m["organization"] as? [String: Any] {
                        if let u = o["uuid"] as? String ?? o["organization_uuid"] as? String ?? o["organizationId"] as? String { return u }
                    }
                    if let u = m["organization_uuid"] as? String ?? m["organizationId"] as? String { return u }
                }
            }
            if let memberships = dict["memberships"] as? [[String: Any]] {
                for m in memberships {
                    if let o = m["organization"] as? [String: Any] {
                        if let u = o["uuid"] as? String ?? o["organization_uuid"] as? String ?? o["organizationId"] as? String { return u }
                    }
                    if let u = m["organization_uuid"] as? String ?? m["organizationId"] as? String { return u }
                }
            }
            if let orgs = dict["organizations"] as? [[String: Any]], let first = orgs.first {
                if let o = first["organization"] as? [String: Any] {
                    if let u = o["uuid"] as? String ?? o["organization_uuid"] as? String ?? o["organizationId"] as? String { return u }
                }
                if let u = first["uuid"] as? String ?? first["organization_uuid"] as? String ?? first["organizationId"] as? String { return u }
            }
            return dict["uuid"] as? String ?? dict["organization_uuid"] as? String ?? dict["organizationId"] as? String
        }

        if let dict = json as? [String: Any] {
            email = dict["email"] as? String ?? dict["user_email"] as? String
            name = dict["name"] as? String ?? dict["display_name"] as? String
            if email == nil, let user = dict["user"] as? [String: Any] {
                email = user["email"] as? String
                name = name ?? (user["name"] as? String)
            }
            if let orgs = dict["organizations"] as? [[String: Any]], let first = orgs.first {
                if name == nil { name = first["name"] as? String }
            }
            org = orgFromDict(dict)
        } else if let arr = json as? [[String: Any]], let first = arr.first {
            name = first["name"] as? String
            email = first["email"] as? String
            org = orgFromDict(first)
        }
        if let e = email, !e.isEmpty {
            SettingsStore.shared.accountEmail = e
        } else if let n = name, !n.isEmpty {
            SettingsStore.shared.accountEmail = n
        }
        if let o = org, !o.isEmpty {
            self.storeLastActiveOrg(o)
        }
    }

    private func extractCookies() {
        let allCookies = HTTPCookieStorage.shared.cookies ?? []
        var sessionKeyValue: String?
        var orgValue: String?
        for cookie in allCookies {
            let domain = cookie.domain.lowercased()
            guard domain.contains("claude.ai") else { continue }
            let nameLower = cookie.name.lowercased()
            if nameLower.contains("sessionkey") {
                if cookie.name == "sessionKey" {
                    sessionKeyValue = cookie.value
                } else if sessionKeyValue == nil {
                    sessionKeyValue = cookie.value
                }
            }
            if cookie.name == "lastActiveOrg" {
                orgValue = cookie.value
            }
        }
        if let sk = sessionKeyValue, !sk.isEmpty {
            _ = KeychainStore.shared.set(sk, for: sessionKeyKey)
        }
        if let org = orgValue, !org.isEmpty {
            _ = KeychainStore.shared.set(org, for: lastActiveOrgKey)
        }
    }

    // MARK: - Logout

    func logout() {
        // Remove cookies for claude.ai domains.
        let storage = HTTPCookieStorage.shared
        let cookies = storage.cookies ?? []
        for cookie in cookies {
            let domain = cookie.domain.lowercased()
            if domain.contains("claude.ai") {
                storage.deleteCookie(cookie)
            }
        }
        _ = KeychainStore.shared.delete(sessionKeyKey)
        _ = KeychainStore.shared.delete(lastActiveOrgKey)
        SettingsStore.shared.accountEmail = ""
        SettingsStore.shared.authMode = "apiKey"
    }
}

// MARK: - SFSafariViewControllerDelegate

extension ClaudeAccountAuth: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        guard !isFallbackValidating else { return }
        // Only validate if fallback container not handling.
        if fallbackContainer == nil {
            validate { _, _ in }
        }
    }
}