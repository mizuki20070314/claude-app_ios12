import Foundation
import UIKit
import WebKit

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

    private override init() { super.init() }

    // MARK: - Debug hook

    #if DEBUG
    static func applyDebugSessionFromEnvironment() {
        let env = ProcessInfo.processInfo.environment
        let envSessionPresent = (env["CLAUDE_DEBUG_SESSION_KEY"]?.isEmpty == false)
        let envOrgPresent = (env["CLAUDE_DEBUG_LAST_ACTIVE_ORG"]?.isEmpty == false)
        if let key = env["CLAUDE_DEBUG_SESSION_KEY"], !key.isEmpty {
            // Store session key first so lastStatus reflects the session-key write.
            ClaudeAccountAuth.shared.storeSession(sessionKey: key, lastActiveOrg: nil)
            let keychainSetStatus = KeychainStore.shared.lastStatus
            if let org = env["CLAUDE_DEBUG_LAST_ACTIVE_ORG"], !org.isEmpty {
                ClaudeAccountAuth.shared.storeLastActiveOrg(org)
            }
            SettingsStore.shared.authMode = "claudeAccount"
            let readBackOk = ClaudeAccountAuth.shared.sessionKey != nil
            let authMode = SettingsStore.shared.authMode
            let isLoggedIn = ClaudeAccountAuth.shared.isLoggedIn
            let dict: [String: Any] = [
                "env_session_present": envSessionPresent,
                "env_org_present": envOrgPresent,
                "keychain_set_status": Int(keychainSetStatus),
                "read_back_ok": readBackOk,
                "auth_mode": authMode,
                "is_logged_in": isLoggedIn
            ]
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let url = dir.appendingPathComponent("account_live_diag.json")
                    try? data.write(to: url)
                }
            }
        }
    }
    #endif

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

    // Store a session obtained from the in-app WebView login.
    func storeSession(sessionKey: String, lastActiveOrg: String?) {
        if !sessionKey.isEmpty {
            _ = KeychainStore.shared.set(sessionKey, for: sessionKeyKey)
        }
        if let org = lastActiveOrg, !org.isEmpty {
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

    func startLogin(from presenter: UIViewController, completion: @escaping (Bool, String?) -> Void) {
        let vc = ClaudeWebLoginViewController { success, message in
            completion(success, message)
        }
        let nav = UINavigationController(rootViewController: vc)
        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .formSheet
        }
        presenter.present(nav, animated: true)
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

    // MARK: - Cookie login

    func loginWithCookie(sessionKey rawSessionKey: String, lastActiveOrg rawOrg: String?, completion: @escaping (Bool, String?) -> Void) {
        // Normalize input: trim, accept "sessionKey=..." prefix, drop trailing "; ...".
        var value = rawSessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = value.lowercased()
        if lower.hasPrefix("sessionkey=") {
            value = String(value.dropFirst("sessionkey=".count))
        }
        if let semi = value.firstIndex(of: ";") {
            value = String(value[..<semi])
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            DispatchQueue.main.async {
                completion(false, "sessionKey を入力してください。")
            }
            return
        }

        let hadSkPrefix = value.hasPrefix("sk-ant-")
        let orgTrimmed = rawOrg?.trimmingCharacters(in: .whitespacesAndNewlines)
        let org = (orgTrimmed?.isEmpty == false) ? orgTrimmed : nil

        let url = URL(string: "https://claude.ai/api/organizations")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        var cookie = "sessionKey=\(value)"
        if let o = org, !o.isEmpty {
            cookie += "; lastActiveOrg=\(o)"
        }
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.httpShouldHandleCookies = false
        request.timeoutInterval = 30

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            var success = false
            var message: String? = nil
            var selectedOrg: String? = org

            if let error = error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorNetworkConnectionLost {
                    message = "ネットワークに接続できません。"
                } else {
                    message = "ネットワークエラーが発生しました: \(nsError.localizedDescription)"
                }
            } else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 200 {
                    var orgs: [[String: Any]] = []
                    if let data = data {
                        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            orgs = arr
                        } else if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let a = dict["organizations"] as? [[String: Any]] {
                                orgs = a
                            } else if let a = dict["data"] as? [[String: Any]] {
                                orgs = a
                            }
                        }
                    }

                    if orgs.isEmpty {
                        message = "Claude.ai からの応答を解析できませんでした。"
                    } else {
                        let ids = orgs.map { self.organizationId(from: $0) }
                        if let given = org, !given.isEmpty, ids.contains(given) {
                            selectedOrg = given
                        } else {
                            var chosen: String? = nil
                            for o in orgs {
                                if let caps = o["capabilities"] as? [String], caps.contains("chat") {
                                    chosen = self.organizationId(from: o)
                                    break
                                }
                                if let caps = o["capabilities"] as? [Any] {
                                    let strs = caps.compactMap { $0 as? String }
                                    if strs.contains("chat") {
                                        chosen = self.organizationId(from: o)
                                        break
                                    }
                                }
                            }
                            if chosen == nil || chosen?.isEmpty == true {
                                chosen = orgs.first.map { self.organizationId(from: $0) }
                            }
                            if let c = chosen, !c.isEmpty {
                                selectedOrg = c
                            }
                        }
                        success = true
                    }
                } else if status == 401 || status == 403 {
                    message = "Cookie が無効か期限切れです。PC のブラウザで claude.ai にログインし直して、新しい sessionKey を貼り付けてください。"
                } else {
                    message = "Claude.ai への接続に失敗しました (HTTP \(status))。"
                }
            }

            if !success, !hadSkPrefix, let msg = message {
                message = msg + " sessionKey は通常 sk-ant- で始まります。"
            }

            DispatchQueue.main.async {
                if success {
                    self.storeSession(sessionKey: value, lastActiveOrg: selectedOrg)
                    SettingsStore.shared.authMode = "claudeAccount"
                    completion(true, nil)
                } else {
                    completion(false, message)
                }
            }
        }
        task.resume()
    }

    private func organizationId(from dict: [String: Any]) -> String {
        if let s = dict["uuid"] as? String, !s.isEmpty { return s }
        if let s = dict["id"] as? String, !s.isEmpty { return s }
        if let s = dict["organization_uuid"] as? String, !s.isEmpty { return s }
        if let s = dict["organizationId"] as? String, !s.isEmpty { return s }
        if let nested = dict["organization"] as? [String: Any] {
            return organizationId(from: nested)
        }
        return ""
    }

    // MARK: - Logout

    func logout() {
        // Remove cookies for claude.ai domains from WKWebView store.
        let wkStore = WKWebsiteDataStore.default().httpCookieStore
        wkStore.getAllCookies { cookies in
            for cookie in cookies {
                let domain = cookie.domain.lowercased()
                if domain.contains("claude.ai") {
                    wkStore.delete(cookie, completionHandler: nil)
                }
            }
        }
        // Remove cookies for claude.ai domains from shared HTTP cookie storage.
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
