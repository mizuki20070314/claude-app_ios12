import Foundation

enum AnthropicError: Error, LocalizedError {
    case invalidKey
    case rateLimit
    case overloaded
    case networkOffline
    case serverError(String)
    case decoding(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "APIキーが無効です。設定を確認してください。"
        case .rateLimit: return "レート制限に達しました。しばらく待ってください。"
        case .overloaded: return "サーバーが過負荷です。しばらく待ってください。"
        case .networkOffline: return "ネットワークに接続できません。"
        case .serverError(let m): return m.isEmpty ? "エラーが発生しました。" : m
        case .decoding(let m): return "応答の解析に失敗しました: \(m)"
        case .cancelled: return "キャンセルしました。"
        }
    }
}

final class StreamHandle {
    private let task: URLSessionDataTask
    private let session: URLSession
    init(task: URLSessionDataTask, session: URLSession) {
        self.task = task
        self.session = session
    }
    func cancel() {
        task.cancel()
        session.invalidateAndCancel()
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
        onThinkingDelta: @escaping (String) -> Void,
        onTextDelta: @escaping (String) -> Void,
        onComplete: @escaping (String?) -> Void,
        onError: @escaping (Error) -> Void
    ) -> StreamHandle {
        let settings = SettingsStore.shared
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

        let delegate = StreamDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

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
            // flush parser
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
        if ev.event == "ping" { return }
        guard let json = try? JSONSerialization.jsonObject(with: Data(ev.data.utf8)) as? [String: Any] else { return }

        switch ev.event {
        case "content_block_start":
            break
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any], let type = delta["type"] as? String {
                if type == "text_delta", let text = delta["text"] as? String {
                    DispatchQueue.main.async { onTextDelta(text) }
                } else if type == "thinking_delta", let thinking = delta["thinking"] as? String {
                    DispatchQueue.main.async { onThinkingDelta(thinking) }
                }
            }
        case "message_delta":
            if let delta = json["delta"] as? [String: Any], let sr = delta["stop_reason"] as? String {
                onStopReason(sr)
            }
        case "message_stop":
            onMessageStop()
        case "error":
            let msg = (json["error"] as? [String: Any])?["message"] as? String ?? ""
            onError(AnthropicError.serverError(msg.isEmpty ? "エラーが発生しました。" : msg))
        default:
            break
        }
    }

    private func buildBody(model: String, messages: [Message], system: String?, maxTokens: Int, thinkingEnabled: Bool, thinkingBudget: Int) -> Data {
        var dict: [String: Any] = [:]
        dict["model"] = model
        var mt = maxTokens
        dict["stream"] = true
        if let system = system, !system.isEmpty { dict["system"] = system }

        var msgs: [[String: Any]] = []
        for m in messages {
            let role = (m.role == .user) ? "user" : "assistant"
            if m.role == .assistant {
                msgs.append(["role": role, "content": m.text])
            } else {
                var content: [[String: Any]] = []
                for att in m.attachments {
                    if att.kind == .image, let b64 = att.base64Data {
                        content.append(["type": "image", "source": ["type": "base64", "media_type": att.mediaType, "data": b64]])
                    } else if att.kind == .textFile, let text = att.textContent {
                        content.append(["type": "text", "text": "[File: \(att.fileName)]\n\(text)"])
                    }
                }
                if !m.text.isEmpty {
                    content.append(["type": "text", "text": m.text])
                }
                if content.isEmpty {
                    content.append(["type": "text", "text": ""])
                }
                msgs.append(["role": role, "content": content])
            }
        }
        dict["messages"] = msgs

        let supports = ModelOption.find(id: model)?.supportsThinking ?? false
        if thinkingEnabled && supports {
            var budget = thinkingBudget
            if budget < 1024 { budget = 1024 }
            if mt <= budget { mt = budget + 1024 }
            dict["thinking"] = ["type": "enabled", "budget_tokens": budget]
        }
        dict["max_tokens"] = mt

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

    func generateTitle(for firstUserText: String, assistantText: String, completion: @escaping (String?) -> Void) {
        let settings = SettingsStore.shared
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
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // remove quotes
                title = title?.trimmingCharacters(in: CharacterSet(charactersIn: "\"'「」"))
            }
            DispatchQueue.main.async { completion(title) }
        }
        task.resume()
    }

    // MARK: - Validate key

    func validateKey(completion: @escaping (Result<Void, Error>) -> Void) {
        let settings = SettingsStore.shared
        let base = settings.apiBaseURL
        let apiKey = settings.apiKey

        // Try models endpoint
        let url = URL(string: "\(base)/v1/models")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                    DispatchQueue.main.async { completion(.failure(AnthropicError.networkOffline)) }
                } else {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(status) {
                DispatchQueue.main.async { completion(.success(())) }
                return
            }
            if status == 404 || status == 405 {
                // fallback: tiny messages call
                self?.validateKeyFallback(completion: completion)
                return
            }
            var message = ""
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let err = json["error"] as? [String: Any], let m = err["message"] as? String {
                message = m
            }
            let err: Error
            if status == 401 { err = AnthropicError.invalidKey }
            else if status == 429 { err = AnthropicError.rateLimit }
            else if status == 529 { err = AnthropicError.overloaded }
            else { err = AnthropicError.serverError(message.isEmpty ? "HTTP \(status)" : message) }
            DispatchQueue.main.async { completion(.failure(err)) }
        }
        task.resume()
    }

    private func validateKeyFallback(completion: @escaping (Result<Void, Error>) -> Void) {
        let settings = SettingsStore.shared
        let base = settings.apiBaseURL
        let apiKey = settings.apiKey
        let url = URL(string: "\(base)/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": "claude-haiku-5-5",
            "max_tokens": 1,
            "stream": false,
            "messages": [["role": "user", "content": "hi"]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(status) {
                DispatchQueue.main.async { completion(.success(())) }
            } else {
                var message = ""
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let err = json["error"] as? [String: Any], let m = err["message"] as? String { message = m }
                let err: Error = (status == 401) ? AnthropicError.invalidKey : AnthropicError.serverError(message.isEmpty ? "HTTP \(status)" : message)
                DispatchQueue.main.async { completion(.failure(err)) }
            }
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
            return
        }
        if statusCode >= 400 {
            onHTTPError?(statusCode, receivedData)
            return
        }
        onFinish?()
    }
}
