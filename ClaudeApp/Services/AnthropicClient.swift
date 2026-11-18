import Foundation

enum AnthropicError: Error, LocalizedError {
    case invalidKey
    case rateLimit
    case overloaded
    case networkOffline
    case serverError(String)
    case decoding(String)
    case cancelled
    case accountChatUnsupported
    case accountNotLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "APIキーが無効です。設定を確認してください。"
        case .rateLimit: return "レート制限に達しました。しばらく待ってください。"
        case .overloaded: return "サーバーが過負荷です。しばらく待ってください。"
        case .networkOffline: return "ネットワークに接続できません。"
        case .serverError(let m): return m.isEmpty ? "エラーが発生しました。" : m
        case .decoding(let m): return "応答の解析に失敗しました: \(m)"
        case .cancelled: return "キャンセルしました。"
        case .accountChatUnsupported: return "Claude.ai アカウントログインは完了しましたが、このクライアントのチャット送信は API キー方式を使用します。設定で API キーを設定してください。"
    case .accountNotLoggedIn: return "Claude.ai のセッションがありません。設定から claude.ai に再ログインしてください。"
        }
    }
}

final class StreamHandle {
    var task: URLSessionDataTask?
    var session: URLSession?
    var onCancel: (() -> Void)?
    private var cancelled: Bool = false
    init(task: URLSessionDataTask? = nil, session: URLSession? = nil) {
        self.task = task
        self.session = session
    }
    func cancel() {
        if cancelled { return }
        cancelled = true
        onCancel?()
        task?.cancel()
        session?.invalidateAndCancel()
    }
}

final class AnthropicClient {
    static let shared = AnthropicClient()
    private init() {}

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
        onError: @escaping (Error) -> Void,
        onMessageStart: ((_ humanUuid: String?, _ assistantUuid: String?) -> Void)? = nil
    ) -> StreamHandle {
        let settings = SettingsStore.shared
        if settings.authMode == "claudeAccount" {
            if ClaudeAccountAuth.shared.isLoggedIn, let sk = ClaudeAccountAuth.shared.sessionKey, !sk.isEmpty {
                return ClaudeAccountClient.shared.streamMessage(
                    model: model,
                    messages: messages,
                    system: system,
                    maxTokens: maxTokens,
                    thinkingEnabled: thinkingEnabled,
                    thinkingBudget: thinkingBudget,
                    conversationId: conversationId,
                    parentMessageUuid: parentMessageUuid,
                    isNewConversation: isNewConversation,
                    onThinkingDelta: onThinkingDelta,
                    onTextDelta: onTextDelta,
                    onComplete: onComplete,
                    onError: onError,
                    onMessageStart: onMessageStart
                )
            }
            let session = URLSession(configuration: .ephemeral)
            let dummyTask = session.dataTask(with: URL(string: "https://claude.ai")!)
            let handle = StreamHandle(task: dummyTask, session: session)
            DispatchQueue.main.async { onError(AnthropicError.accountNotLoggedIn) }
            return handle
        }
        let base = settings.apiBaseURL
        let apiKey = settings.apiKey

        let url = URL(string: "\(base)/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = buildBody(model: model, messages: messages, system: system, maxTokens: maxTokens, thinkingEnabled: thinkingEnabled, thinkingBudget: thinkingBudget)
        req.httpBody = body

        let parser = SSEParser()
        var currentStopReason: String? = nil
        var didFinish = false

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300

        let delegate = StreamDelegate()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let finishComplete: () -> Void = {
            if didFinish { return }
            didFinish = true
            DispatchQueue.main.async { onComplete(currentStopReason) }
        }
        let fail: (Error) -> Void = { err in
            if didFinish { return }
            didFinish = true
            DispatchQueue.main.async { onError(err) }
        }

        delegate.onData = { data in
            let events = parser.feed(data)
            for ev in events {
                self.handleEvent(ev, onThinkingDelta: onThinkingDelta, onTextDelta: onTextDelta, onStopReason: { sr in currentStopReason = sr }, onError: { err in fail(err) }, onMessageStop: { finishComplete() })
            }
        }
        delegate.onHTTPError = { status, data in
            let err = self.mapHTTPError(status: status, data: data)
            fail(err)
        }
        delegate.onTransportError = { err in
            if (err as NSError).code == NSURLErrorCancelled {
                fail(AnthropicError.cancelled)
            } else if (err as NSError).code == NSURLErrorNotConnectedToInternet || (err as NSError).code == NSURLErrorNetworkConnectionLost {
                fail(AnthropicError.networkOffline)
            } else {
                fail(err)
            }
        }
        delegate.onFinish = {
            let events = parser.finish()
            for ev in events {
                self.handleEvent(ev, onThinkingDelta: onThinkingDelta, onTextDelta: onTextDelta, onStopReason: { sr in currentStopReason = sr }, onError: { err in fail(err) }, onMessageStop: { finishComplete() })
            }
            if !didFinish {
                finishComplete()
            }
        }

        let task = session.dataTask(with: req)
        let handle = StreamHandle(task: task, session: session)
        delegate.task = task
        task.resume()
        return handle
    }

    private func handleEvent(
        _ ev: SSEEvent,
        onThinkingDelta: @escaping (String) -> Void,
        onTextDelta: @escaping (String) -> Void,
        onStopReason: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void,
        onMessageStop: @escaping () -> Void
    ) {
        guard !ev.data.isEmpty else { return }
        guard let json = try? JSONSerialization.jsonObject(with: Data(ev.data.utf8)) as? [String: Any] else { return }

        let type = (ev.event as String?) ?? (json["type"] as? String)

        if type == "ping" { return }

        switch type {
        case "content_block_start":
            break
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any], let dtype = delta["type"] as? String {
                if dtype == "text_delta", let text = delta["text"] as? String {
                    DispatchQueue.main.async { onTextDelta(text) }
                } else if dtype == "thinking_delta", let thinking = delta["thinking"] as? String {
                    DispatchQueue.main.async { onThinkingDelta(thinking) }
                } else if dtype == "signature_delta" {
                    // ignore signature
                }
            }
        case "message_delta":
            if let delta = json["delta"] as? [String: Any], let sr = delta["stop_reason"] as? String {
                onStopReason(sr)
            }
        case "message_stop":
            onMessageStop()
        case "error":
            let errObj = json["error"] as? [String: Any]
            let msg = errObj?["message"] as? String ?? ""
            let errType = errObj?["type"] as? String ?? ""
            let mapped: Error
            if errType == "overloaded_error" {
                mapped = AnthropicError.overloaded
            } else if errType == "rate_limit_error" {
                mapped = AnthropicError.rateLimit
            } else if errType == "authentication_error" || errType == "invalid_request_error" && msg.lowercased().contains("api key") {
                mapped = AnthropicError.invalidKey
            } else {
                mapped = AnthropicError.serverError(msg.isEmpty ? "エラーが発生しました。" : msg)
            }
            onError(mapped)
        default:
            break
        }
    }

    private func buildBody(model: String, messages: [Message], system: String?, maxTokens: Int, thinkingEnabled: Bool, thinkingBudget: Int) -> Data {
        var dict: [String: Any] = [:]
        dict["model"] = model
        dict["stream"] = true
        if let system = system, !system.isEmpty { dict["system"] = system }

        // Filter messages
        var filtered: [Message] = []
        for m in messages {
            if m.isError { continue }
            if m.role == .assistant {
                if m.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            } else {
                let hasContent = !m.attachments.isEmpty || !m.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !hasContent { continue }
            }
            filtered.append(m)
        }
        // drop leading assistants
        while let first = filtered.first, first.role == .assistant {
            filtered.removeFirst()
        }

        // Build entries
        struct Entry {
            var role: String
            var userBlocks: [[String: Any]]?
            var assistantText: String
        }
        var entries: [Entry] = []
        for m in filtered {
            if m.role == .user {
                var blocks: [[String: Any]] = []
                for att in m.attachments {
                    if att.kind == .image, let b64 = att.base64Data {
                        blocks.append(["type": "image", "source": ["type": "base64", "media_type": att.mediaType, "data": b64]])
                    } else if att.kind == .textFile, let text = att.textContent {
                        blocks.append(["type": "text", "text": "[File: \(att.fileName)]\n\(text)"])
                    }
                }
                if !m.text.isEmpty {
                    blocks.append(["type": "text", "text": m.text])
                }
                if blocks.isEmpty { continue }
                entries.append(Entry(role: "user", userBlocks: blocks, assistantText: ""))
            } else {
                entries.append(Entry(role: "assistant", userBlocks: nil, assistantText: m.text))
            }
        }

        // Merge consecutive same-role
        var merged: [Entry] = []
        for e in entries {
            if let last = merged.last, last.role == e.role {
                if e.role == "user" {
                    var blocks = merged[merged.count - 1].userBlocks ?? []
                    blocks.append(contentsOf: e.userBlocks ?? [])
                    merged[merged.count - 1].userBlocks = blocks
                } else {
                    let prev = merged[merged.count - 1].assistantText
                    let newText = prev.isEmpty ? e.assistantText : prev + "\n\n" + e.assistantText
                    merged[merged.count - 1].assistantText = newText
                }
            } else {
                merged.append(e)
            }
        }

        var msgs: [[String: Any]] = []
        for e in merged {
            if e.role == "user" {
                msgs.append(["role": "user", "content": e.userBlocks ?? []])
            } else {
                msgs.append(["role": "assistant", "content": e.assistantText])
            }
        }
        dict["messages"] = msgs

        let supports = ModelOption.find(id: model)?.supportsThinking ?? false
        var mt = maxTokens
        if thinkingEnabled && supports {
            var budget = thinkingBudget
            if budget < 1024 { budget = 1024 }
            if mt <= budget { mt = budget + 1024 }
            dict["thinking"] = ["type": "enabled", "budget_tokens": budget]
        }
        dict["max_tokens"] = mt

        // Effort (API-key mode): unverified; documented as output_config.effort.
        // Only low/medium/high are sent; other values are ignored here.
        let effort = SettingsStore.shared.effort
        if !effort.isEmpty && (effort == "low" || effort == "medium" || effort == "high") {
            dict["output_config"] = ["effort": effort]
        }

        return (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()
    }

    private func mapHTTPError(status: Int, data: Data) -> Error {
        var message = ""
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["error"] as? [String: Any],
           let m = err["message"] as? String {
            message = m
        }
        switch status {
        case 401: return AnthropicError.invalidKey
        case 429: return AnthropicError.rateLimit
        case 529: return AnthropicError.overloaded
        default:
            if message.isEmpty { message = "HTTP \(status)" }
            return AnthropicError.serverError(message)
        }
    }

    // MARK: - Title generation

    func generateTitle(for firstUserText: String, assistantText: String, conversationId: String? = nil, completion: @escaping (String?) -> Void) {
        let settings = SettingsStore.shared
        if settings.authMode == "claudeAccount" {
            if ClaudeAccountAuth.shared.isLoggedIn, let sk = ClaudeAccountAuth.shared.sessionKey, !sk.isEmpty {
                ClaudeAccountClient.shared.generateTitle(for: firstUserText, assistantText: assistantText, conversationId: conversationId, completion: completion)
                return
            }
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let base = settings.apiBaseURL
        let apiKey = settings.apiKey
        let url = URL(string: "\(base)/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let prompt = "以下の会話に短いタイトルを日本語で付けてください。20文字以内、引用符なし。\nユーザー: \(firstUserText)\nアシスタント: \(assistantText)"
        let body: [String: Any] = [
            "model": "claude-haiku-5-5",
            "max_tokens": 30,
            "stream": false,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            var title: String? = nil
            defer { DispatchQueue.main.async { completion(title) } }
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            guard let content = json["content"] as? [[String: Any]], let first = content.first else { return }
            guard let text = first["text"] as? String else { return }
            var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            t = t.trimmingCharacters(in: CharacterSet(charactersIn: "\"'「」"))
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { title = t }
        }
        task.resume()
    }

    // MARK: - Validate key

    func validateKey(completion: @escaping (Result<Void, Error>) -> Void) {
        let settings = SettingsStore.shared
        if settings.authMode == "claudeAccount" {
            DispatchQueue.main.async { completion(.failure(AnthropicError.accountNotLoggedIn)) }
            return
        }
        let base = settings.apiBaseURL
        let apiKey = settings.apiKey

        let url = URL(string: "\(base)/v1/models")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorNotConnectedToInternet || (error as NSError).code == NSURLErrorNetworkConnectionLost {
                    DispatchQueue.main.async { completion(.failure(AnthropicError.networkOffline)) }
                } else {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                DispatchQueue.main.async { completion(.success(())) }
                return
            }
            if status == 401 {
                DispatchQueue.main.async { completion(.failure(AnthropicError.invalidKey)) }
                return
            }
            var message = ""
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? [String: Any],
               let m = err["message"] as? String {
                message = m
            }
            let err: Error
            if status == 429 { err = AnthropicError.rateLimit }
            else if status == 529 { err = AnthropicError.overloaded }
            else { err = AnthropicError.serverError(message.isEmpty ? "HTTP \(status)" : message) }
            DispatchQueue.main.async { completion(.failure(err)) }
        }
        task.resume()
    }

    // MARK: - System prompt helper

    static func buildSystemPrompt(style: String, userName: String, project: Project?) -> String {
        var parts: [String] = []
        switch style {
        case "concise": parts.append("Be concise and to the point.")
        case "explanatory": parts.append("Explain your reasoning step by step.")
        case "formal": parts.append("Use a formal, professional tone.")
        default: break
        }
        if let p = project {
            if !p.instructions.isEmpty {
                parts.append("Project instructions:\n\(p.instructions)")
            }
            for k in p.knowledge {
                let text = k.textContent ?? ""
                parts.append("<document filename=\"\(k.fileName)\">\n\(text)\n</document>")
            }
        }
        if !userName.isEmpty {
            parts.append("The user's name is \(userName).")
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - StreamDelegate

private final class StreamDelegate: NSObject, URLSessionDataDelegate {
    var onData: ((Data) -> Void)?
    var onHTTPError: ((Int, Data) -> Void)?
    var onTransportError: ((Error) -> Void)?
    var onFinish: (() -> Void)?
    var task: URLSessionDataTask?

    private var statusCode: Int = 0
    private var receivedData = Data()

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            statusCode = http.statusCode
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if statusCode >= 400 {
            receivedData.append(data)
        } else {
            onData?(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onTransportError?(error)
        } else if statusCode >= 400 {
            onHTTPError?(statusCode, receivedData)
        } else {
            onFinish?()
        }
        session.finishTasksAndInvalidate()
    }
}