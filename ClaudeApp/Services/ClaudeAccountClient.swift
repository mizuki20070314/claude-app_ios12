import Foundation

// MARK: - Errors

enum ClaudeAccountError: Error, LocalizedError {
    case notLoggedIn
    case missingSession
    case missingOrganization
    case attachmentsUnsupported
    case invalidResponse
    case cancelled
    case network(String)
    case serverError(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Claude.ai アカウントにログインしていません。"
        case .missingSession:
            return "セッションキーが見つかりません。再度ログインしてください。"
        case .missingOrganization:
            return "組織情報を取得できませんでした。"
        case .attachmentsUnsupported:
            return "Claude.ai アカウントモードでは画像添付はまだサポートされていません。テキストのみ送信してください。"
        case .invalidResponse:
            return "サーバー応答を解析できませんでした。"
        case .cancelled:
            return "キャンセルしました。"
        case .network(let m):
            return m.isEmpty ? "ネットワークエラーが発生しました。" : m
        case .serverError(let m):
            return m.isEmpty ? "エラーが発生しました。" : m
        case .decoding(let m):
            return "応答の解析に失敗しました: \(m)"
        }
    }
}

// MARK: - Client

final class ClaudeAccountClient {
    static let shared = ClaudeAccountClient()
    private init() {}

    private(set) var lastOrgId: String?
    private(set) var lastChatId: String?

    // MARK: - Organization resolution

    func resolveOrganizationId(completion: @escaping (Result<String, Error>) -> Void) {
        if let org = ClaudeAccountAuth.shared.lastActiveOrg, !org.isEmpty {
            ClaudeAccountAuth.shared.storeLastActiveOrg(org)
            self.lastOrgId = org
            // Best-effort bootstrap (non-blocking for chat).
            self.bootstrapOrganization(org: org) { _ in }
            completion(.success(org))
            return
        }

        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            completion(.failure(ClaudeAccountError.invalidResponse))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(self.cookieHeader(org: nil), forHTTPHeaderField: "Cookie")

        let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(ClaudeAccountError.network(error.localizedDescription)))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 || status == 403 {
                ClaudeAccountAuth.shared.clearSession()
                completion(.failure(ClaudeAccountError.missingSession))
                return
            }
            if status >= 400 {
                completion(.failure(ClaudeAccountError.serverError("HTTP \(status)")))
                return
            }
            guard let data = data else {
                completion(.failure(ClaudeAccountError.invalidResponse))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) else {
                completion(.failure(ClaudeAccountError.decoding("organizations")))
                return
            }
            guard let org = self.extractOrganizationId(from: json), !org.isEmpty else {
                completion(.failure(ClaudeAccountError.missingOrganization))
                return
            }
            ClaudeAccountAuth.shared.storeLastActiveOrg(org)
            self.lastOrgId = org
            self.bootstrapOrganization(org: org) { _ in }
            completion(.success(org))
        }
        task.resume()
    }

    func bootstrapOrganization(org: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://claude.ai/api/bootstrap/\(org)/app_start?growthbook_format=sdk&include_system_prompts=false") else {
            completion(false)
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")
        let task = URLSession.shared.dataTask(with: req) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            completion(ok)
        }
        task.resume()
    }

    // MARK: - Streaming

    func streamMessage(
        model: String,
        messages: [Message],
        system: String?,
        maxTokens: Int,
        thinkingEnabled: Bool,
        thinkingBudget: Int,
        conversationId: String? = nil,
        parentMessageUuid: String? = nil,
        isNewConversation: Bool = false,
        onThinkingDelta: @escaping (String) -> Void,
        onTextDelta: @escaping (String) -> Void,
        onComplete: @escaping (String?) -> Void,
        onError: @escaping (Error) -> Void
    ) -> StreamHandle {
        // Account-mode guard.
        guard SettingsStore.shared.authMode == "claudeAccount",
              ClaudeAccountAuth.shared.isLoggedIn,
              let sessionKey = ClaudeAccountAuth.shared.sessionKey, !sessionKey.isEmpty else {
            let session = URLSession(configuration: .ephemeral)
            let dummyTask = session.dataTask(with: URL(string: "https://claude.ai")!)
            let handle = StreamHandle(task: dummyTask, session: session)
            DispatchQueue.main.async { onError(ClaudeAccountError.notLoggedIn) }
            return handle
        }

        // Attachment handling: images unsupported; text files prefixed into prompt.
        let lastUserMessage = messages.last(where: { $0.role == .user })
        var hasImage = false
        if let msg = lastUserMessage {
            for att in msg.attachments where att.kind == .image { hasImage = true }
        }
        if hasImage {
            let session = URLSession(configuration: .ephemeral)
            let dummyTask = session.dataTask(with: URL(string: "https://claude.ai")!)
            let handle = StreamHandle(task: dummyTask, session: session)
            DispatchQueue.main.async { onError(ClaudeAccountError.attachmentsUnsupported) }
            return handle
        }

        var prompt = lastUserMessage?.text ?? ""
        if let msg = lastUserMessage {
            var prefix = ""
            for att in msg.attachments where att.kind == .textFile {
                if let text = att.textContent {
                    var t = text
                    if t.count > 32000 { t = String(t.prefix(32000)) }
                    prefix += "[\(att.fileName)]\n\(t)\n\n"
                }
            }
            if !prefix.isEmpty { prompt = prefix + prompt }
        }

        let chatId = (conversationId ?? UUID().uuidString).lowercased()
        self.lastChatId = chatId
        let completionRequestId = UUID().uuidString.lowercased()

        let extendedThinking = SettingsStore.shared.extendedThinking

        let handle = StreamHandle()
        var cancelled = false
        handle.onCancel = { [weak self] in
            cancelled = true
            guard let self = self else { return }
            let org = self.lastOrgId ?? ClaudeAccountAuth.shared.lastActiveOrg
            if let org = org, !org.isEmpty {
                if let url = URL(string: "https://claude.ai/api/organizations/\(org)/chat_conversations/\(chatId)/stop_response") {
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")
                    let body: [String: Any] = ["completion_request_id": completionRequestId]
                    req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
                    let t = URLSession.shared.dataTask(with: req) { _, _, _ in }
                    t.resume()
                }
            }
        }

        var didFinish = false
        let parser = SSEParser()
        var currentStopReason: String? = nil

        let finishComplete: () -> Void = {
            if didFinish || cancelled { return }
            didFinish = true
            DispatchQueue.main.async { onComplete(currentStopReason) }
        }
        let fail: (Error) -> Void = { err in
            if didFinish || cancelled { return }
            didFinish = true
            DispatchQueue.main.async { onError(err) }
        }

        // Resolve org, then send.
        self.resolveOrganizationId { result in
            if cancelled { return }
            switch result {
            case .failure(let err):
                fail(err)
                return
            case .success(let org):
                self.lastOrgId = org
                ClaudeAccountAuth.shared.storeLastActiveOrg(org)

                // Build body.
                var body: [String: Any] = [:]
                body["prompt"] = prompt
                body["timezone"] = TimeZone.current.identifier
                body["model"] = model
                body["attachments"] = [] as [Any]
                body["files"] = [] as [Any]
                body["rendering_mode"] = "messages"
                body["input_mode"] = "text"
                // parent_message_uuid optional
                if let pmu = parentMessageUuid, !pmu.isEmpty {
                    body["parent_message_uuid"] = pmu
                } else {
                    body["parent_message_uuid"] = NSNull()
                }
                if isNewConversation {
                    body["create_conversation_params"] = [
                        "uuid": chatId,
                        "name": "",
                        "model": model
                    ] as [String: Any]
                } else {
                    body["create_conversation_params"] = NSNull()
                }
                body["tools"] = [] as [Any]
                body["effort"] = NSNull()
                body["thinking_mode"] = extendedThinking ? "adaptive" : NSNull()
                body["completion_request_id"] = completionRequestId
                body["turn_message_uuids"] = NSNull()
                body["tool_allowlist"] = [] as [Any]
                body["skip_completion_notification"] = false

                guard let url = URL(string: "https://claude.ai/api/organizations/\(org)/chat_conversations/\(chatId)/completion") else {
                    fail(ClaudeAccountError.invalidResponse)
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
                req.setValue("https://claude.ai/", forHTTPHeaderField: "Referer")
                req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 300

                let delegate = AccountStreamDelegate()
                let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

                delegate.onData = { data in
                    if cancelled { return }
                    let events = parser.feed(data)
                    for ev in events {
                        self.handleAccountEvent(
                            ev,
                            onThinkingDelta: onThinkingDelta,
                            onTextDelta: onTextDelta,
                            currentStopReasonSetter: { currentStopReason = $0 },
                            finishComplete: finishComplete,
                            fail: fail,
                            cancelled: { cancelled }
                        )
                    }
                }
                delegate.onHTTPError = { status, data in
                    if cancelled { return }
                    if status == 401 || status == 403 {
                        ClaudeAccountAuth.shared.clearSession()
                    }
                    var message = ""
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let err = json["error"] as? [String: Any], let m = err["message"] as? String {
                            message = m
                        } else if let m = json["message"] as? String {
                            message = m
                        }
                    }
                    if message.isEmpty {
                        if status == 401 || status == 403 {
                            message = "セッションが無効です。再度ログインしてください。"
                        } else {
                            message = "HTTP \(status)"
                        }
                    }
                    fail(ClaudeAccountError.serverError(message))
                }
                delegate.onTransportError = { err in
                    if cancelled { return }
                    if (err as NSError).code == NSURLErrorCancelled {
                        // silent on cancel
                        return
                    } else if (err as NSError).code == NSURLErrorNotConnectedToInternet || (err as NSError).code == NSURLErrorNetworkConnectionLost {
                        fail(ClaudeAccountError.network("ネットワークに接続できません。"))
                    } else {
                        fail(err)
                    }
                }
                delegate.onFinish = {
                    if cancelled { return }
                    let events = parser.finish()
                    for ev in events {
                        self.handleAccountEvent(
                            ev,
                            onThinkingDelta: onThinkingDelta,
                            onTextDelta: onTextDelta,
                            currentStopReasonSetter: { currentStopReason = $0 },
                            finishComplete: finishComplete,
                            fail: fail,
                            cancelled: { cancelled }
                        )
                    }
                    if !didFinish && !cancelled {
                        finishComplete()
                    }
                }

                if cancelled {
                    session.invalidateAndCancel()
                    return
                }
                handle.task = session.dataTask(with: req)
                handle.session = session
                // Re-point delegate task? not needed.
                handle.task?.resume()
            }
        }

        return handle
    }

    // MARK: - Event handling

    private func handleAccountEvent(
        _ ev: SSEEvent,
        onThinkingDelta: @escaping (String) -> Void,
        onTextDelta: @escaping (String) -> Void,
        currentStopReasonSetter: @escaping (String) -> Void,
        finishComplete: @escaping () -> Void,
        fail: @escaping (Error) -> Void,
        cancelled: @escaping () -> Bool
    ) {
        if cancelled() { return }
        guard !ev.data.isEmpty else { return }
        guard let json = try? JSONSerialization.jsonObject(with: Data(ev.data.utf8)) as? [String: Any] else { return }

        let type = (ev.event?.isEmpty == false ? ev.event : nil) ?? (json["type"] as? String)

        if type == "ping" || type == "mutation_accepted" || type == "message_limit" { return }

        switch type {
        case "message_start":
            break
        case "content_block_start":
            break
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any] {
                var sentText = false
                var sentThinking = false
                if let text = delta["text"] as? String {
                    DispatchQueue.main.async { onTextDelta(text) }
                    sentText = true
                }
                if let thinking = delta["thinking"] as? String {
                    DispatchQueue.main.async { onThinkingDelta(thinking) }
                    sentThinking = true
                }
                if let dtype = delta["type"] as? String {
                    if !sentText, dtype == "text_delta", let text = delta["text"] as? String {
                        DispatchQueue.main.async { onTextDelta(text) }
                    }
                    if !sentThinking, dtype == "thinking_delta", let thinking = delta["thinking"] as? String {
                        DispatchQueue.main.async { onThinkingDelta(thinking) }
                    }
                }
                // Nested delta forms
                if let nested = delta["delta"] as? [String: Any] {
                    if let text = nested["text"] as? String {
                        DispatchQueue.main.async { onTextDelta(text) }
                    }
                    if let thinking = nested["thinking"] as? String {
                        DispatchQueue.main.async { onThinkingDelta(thinking) }
                    }
                }
            }
        case "text_delta":
            if let text = json["text"] as? String ?? (json["delta"] as? [String: Any])?["text"] as? String {
                DispatchQueue.main.async { onTextDelta(text) }
            }
        case "thinking_delta":
            if let thinking = json["thinking"] as? String ?? (json["delta"] as? [String: Any])?["thinking"] as? String {
                DispatchQueue.main.async { onThinkingDelta(thinking) }
            }
        case "content_block_stop":
            break
        case "message_delta":
            if let delta = json["delta"] as? [String: Any], let sr = delta["stop_reason"] as? String {
                currentStopReasonSetter(sr)
            }
            if let sr = json["stop_reason"] as? String {
                currentStopReasonSetter(sr)
            }
        case "message_stop":
            finishComplete()
        case "error":
            let errObj = json["error"] as? [String: Any]
            let msg = errObj?["message"] as? String ?? json["message"] as? String ?? ""
            fail(ClaudeAccountError.serverError(msg.isEmpty ? "エラーが発生しました。" : msg))
        default:
            break
        }
    }

    // MARK: - Title generation

    func generateTitle(for firstUserText: String, assistantText: String, conversationId: String? = nil, completion: @escaping (String?) -> Void) {
        guard SettingsStore.shared.authMode == "claudeAccount",
              ClaudeAccountAuth.shared.isLoggedIn,
              let sessionKey = ClaudeAccountAuth.shared.sessionKey, !sessionKey.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        self.resolveOrganizationId { result in
            guard case .success(let org) = result else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let chatId = (conversationId ?? self.lastChatId ?? "").lowercased()
            guard !chatId.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let url = URL(string: "https://claude.ai/api/organizations/\(org)/chat_conversations/\(chatId)/title") else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")
            let body: [String: Any] = ["message_content": firstUserText, "recent_titles": [] as [Any]]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            let task = URLSession.shared.dataTask(with: req) { data, response, _ in
                var title: String? = nil
                defer { DispatchQueue.main.async { completion(title) } }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 401 || status == 403 {
                    ClaudeAccountAuth.shared.clearSession()
                    return
                }
                guard let data = data else { return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    title = json["title"] as? String
                }
            }
            task.resume()
        }
    }

    // MARK: - Helpers

    func cookieHeader(org: String?) -> String {
        let sk = ClaudeAccountAuth.shared.sessionKey ?? ""
        var parts = ["sessionKey=\(sk)"]
        let orgValue = org ?? ClaudeAccountAuth.shared.lastActiveOrg
        if let o = orgValue, !o.isEmpty {
            parts.append("lastActiveOrg=\(o)")
        }
        return parts.joined(separator: "; ")
    }

    private func extractOrganizationId(from json: Any) -> String? {
        if let arr = json as? [[String: Any]] {
            if let first = arr.first {
                return self.extractOrgFromDict(first)
            }
            return nil
        }
        if let dict = json as? [String: Any] {
            if let account = dict["account"] as? [String: Any],
               let memberships = account["memberships"] as? [[String: Any]] {
                for m in memberships {
                    if let org = m["organization"] as? [String: Any] {
                        if let u = org["uuid"] as? String ?? org["organization_uuid"] as? String ?? org["organizationId"] as? String {
                            return u
                        }
                    }
                    if let u = m["organization_uuid"] as? String ?? m["organizationId"] as? String {
                        return u
                    }
                }
            }
            if let memberships = dict["memberships"] as? [[String: Any]] {
                for m in memberships {
                    if let org = m["organization"] as? [String: Any] {
                        if let u = org["uuid"] as? String ?? org["organization_uuid"] as? String ?? org["organizationId"] as? String {
                            return u
                        }
                    }
                    if let u = m["organization_uuid"] as? String ?? m["organizationId"] as? String {
                        return u
                    }
                }
            }
            if let orgs = dict["organizations"] as? [[String: Any]], let first = orgs.first {
                return self.extractOrgFromDict(first)
            }
            if let u = dict["uuid"] as? String ?? dict["organization_uuid"] as? String ?? dict["organizationId"] as? String {
                return u
            }
        }
        return nil
    }

    private func extractOrgFromDict(_ dict: [String: Any]) -> String? {
        if let org = dict["organization"] as? [String: Any] {
            return org["uuid"] as? String ?? org["organization_uuid"] as? String ?? org["organizationId"] as? String
        }
        return dict["uuid"] as? String ?? dict["organization_uuid"] as? String ?? dict["organizationId"] as? String
    }
}

// MARK: - Delegate

private final class AccountStreamDelegate: NSObject, URLSessionDataDelegate {
    var onData: ((Data) -> Void)?
    var onHTTPError: ((Int, Data) -> Void)?
    var onTransportError: ((Error) -> Void)?
    var onFinish: (() -> Void)?

    private var statusCode: Int = 0
    private var receivedData = Data()

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse { statusCode = http.statusCode }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if statusCode >= 400 { receivedData.append(data) } else { onData?(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error { onTransportError?(error) }
        else if statusCode >= 400 { onHTTPError?(statusCode, receivedData) }
        else { onFinish?() }
        session.finishTasksAndInvalidate()
    }
}
