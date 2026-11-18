import Foundation

// MARK: - Convenience

func isRemote(_ c: Conversation) -> Bool {
    return c.origin == "claudeAi"
}

// MARK: - Service

final class ClaudeHistoryService {
    static let shared = ClaudeHistoryService()
    static let didSync = Notification.Name("ClaudeHistoryService.didSync")

    private init() {}

    private(set) var isSyncing: Bool = false

    var isAvailable: Bool {
        return SettingsStore.shared.authMode == "claudeAccount" && ClaudeAccountAuth.shared.isLoggedIn
    }

    func isRemote(_ c: Conversation) -> Bool {
        return c.origin == "claudeAi"
    }

    // MARK: - Sync recents

    func syncRecents(maxPages: Int = 3, completion: ((Error?) -> Void)? = nil) {
        guard isAvailable else {
            DispatchQueue.main.async { completion?(ClaudeAccountError.notLoggedIn) }
            return
        }
        isSyncing = true
        ClaudeAccountClient.shared.resolveOrganizationId { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                self.finishSync(error: err, items: [], completion: completion)
                return
            case .success(let org):
                var allItems: [Conversation] = []
                var cursor: String? = nil
                var visited = Set<String>()
                var page = 0

                func fetchNext() {
                    if page >= maxPages {
                        self.finishSync(error: nil, items: allItems, completion: completion)
                        return
                    }
                    self.fetchRecentsPage(org: org, cursor: cursor) { pageResult in
                        switch pageResult {
                        case .failure(let err):
                            self.finishSync(error: err, items: allItems, completion: completion)
                        case .success(let (items, next)):
                            allItems.append(contentsOf: items)
                            page += 1
                            if let nextCursor = next, !nextCursor.isEmpty, page < maxPages {
                                if visited.contains(nextCursor) || nextCursor == cursor {
                                    self.finishSync(error: nil, items: allItems, completion: completion)
                                    return
                                }
                                visited.insert(nextCursor)
                                cursor = nextCursor
                                fetchNext()
                            } else {
                                self.finishSync(error: nil, items: allItems, completion: completion)
                            }
                        }
                    }
                }
                visited.insert(cursor ?? "")
                fetchNext()
            }
        }
    }

    private func finishSync(error: Error?, items: [Conversation], completion: ((Error?) -> Void)?) {
        isSyncing = false
        if let err = error {
            DispatchQueue.main.async { completion?(err) }
            return
        }
        ConversationStore.shared.mergeRemote(items)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: ClaudeHistoryService.didSync, object: self)
            completion?(nil)
        }
    }

    private func fetchRecentsPage(org: String, cursor: String?, completion: @escaping (Result<([Conversation], String?), Error>) -> Void) {
        guard var comps = URLComponents(string: "https://claude.ai/api/organizations/\(org)/recents") else {
            completion(.failure(ClaudeAccountError.invalidResponse))
            return
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "section", value: "recents"),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "surfaces", value: "chat"),
            URLQueryItem(name: "include", value: "chat")
        ]
        if let c = cursor, !c.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: c))
        }
        comps.queryItems = queryItems
        guard let url = comps.url else {
            completion(.failure(ClaudeAccountError.invalidResponse))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")

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
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw ClaudeAccountError.decoding("recents")
                }
                let sections = json["sections"] as? [[String: Any]] ?? []
                var rows: [[String: Any]] = []
                var nextCursor: String? = nil
                for sec in sections {
                    if let d = sec["data"] as? [[String: Any]] {
                        rows.append(contentsOf: d)
                    }
                    if nextCursor == nil {
                        nextCursor = sec["next_cursor"] as? String
                    }
                }
                var items: [Conversation] = []
                for row in rows {
                    if let c = self.conversationFromChatRow(row) {
                        items.append(c)
                    }
                }
                completion(.success((items, nextCursor)))
            } catch {
                completion(.failure(ClaudeAccountError.decoding(error.localizedDescription)))
            }
        }
        task.resume()
    }

    private func conversationFromChatRow(_ row: [String: Any]) -> Conversation? {
        var obj = row
        if let chat = row["chat"] as? [String: Any] { obj = chat }
        else if let conv = row["conversation"] as? [String: Any] { obj = conv }

        let type = (row["type"] as? String) ?? (obj["type"] as? String)
        guard type == nil || type == "chat" else { return nil }

        guard let uuid = (obj["uuid"] as? String) ?? (obj["id"] as? String), !uuid.isEmpty else { return nil }

        let name = obj["name"] as? String
        let title = (name != nil && !name!.isEmpty) ? name! : "New Chat"

        let createdAt = parseISO8601(obj["created_at"] as? String) ?? Date()
        let updatedAt = parseISO8601(obj["updated_at"] as? String) ?? createdAt

        let starred = obj["is_starred"] as? Bool ?? false
        let model = obj["model"] as? String
        let projectId = obj["project_uuid"] as? String

        return Conversation(
            id: uuid.lowercased(),
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isStarred: starred,
            projectId: projectId,
            model: model ?? ModelOption.default.id,
            messages: [],
            origin: "claudeAi",
            remoteLoaded: false
        )
    }

    // MARK: - Load conversation

    func loadConversation(id: String, completion: @escaping (Result<Conversation, Error>) -> Void) {
        guard isAvailable else {
            DispatchQueue.main.async { completion(.failure(ClaudeAccountError.notLoggedIn)) }
            return
        }
        ClaudeAccountClient.shared.resolveOrganizationId { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                DispatchQueue.main.async { completion(.failure(err)) }
            case .success(let org):
                let lowerId = id.lowercased()
                guard let url = URL(string: "https://claude.ai/api/organizations/\(org)/chat_conversations/\(lowerId)?tree=True&rendering_mode=messages&render_all_tools=true") else {
                    DispatchQueue.main.async { completion(.failure(ClaudeAccountError.invalidResponse)) }
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")

                let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                    guard let self = self else { return }
                    if let error = error {
                        DispatchQueue.main.async { completion(.failure(ClaudeAccountError.network(error.localizedDescription))) }
                        return
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status == 401 || status == 403 {
                        ClaudeAccountAuth.shared.clearSession()
                        DispatchQueue.main.async { completion(.failure(ClaudeAccountError.missingSession)) }
                        return
                    }
                    if status >= 400 {
                        DispatchQueue.main.async { completion(.failure(ClaudeAccountError.serverError("HTTP \(status)"))) }
                        return
                    }
                    guard let data = data else {
                        DispatchQueue.main.async { completion(.failure(ClaudeAccountError.invalidResponse)) }
                        return
                    }
                    do {
                        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            throw ClaudeAccountError.decoding("conversation")
                        }
                        let conv = try self.parseConversationDetail(json: json, id: lowerId)
                        ConversationStore.shared.save(conv, touch: false)
                        DispatchQueue.main.async { completion(.success(conv)) }
                    } catch {
                        let err = (error as? ClaudeAccountError) ?? ClaudeAccountError.decoding(error.localizedDescription)
                        DispatchQueue.main.async { completion(.failure(err)) }
                    }
                }
                task.resume()
            }
        }
    }

    private func parseConversationDetail(json: [String: Any], id: String) throws -> Conversation {
        let uuid = (json["uuid"] as? String) ?? id
        let lowerUuid = uuid.lowercased()

        let existing = ConversationStore.shared.conversation(id: lowerUuid)

        let name = json["name"] as? String
        let title: String
        if let n = name, !n.isEmpty {
            title = n
        } else {
            title = existing?.title ?? "New Chat"
        }

        let model = json["model"] as? String
        let starred = json["is_starred"] as? Bool ?? (existing?.isStarred ?? false)

        let createdAt = parseISO8601(json["created_at"] as? String) ?? existing?.createdAt ?? Date()
        let updatedAt = parseISO8601(json["updated_at"] as? String) ?? existing?.updatedAt ?? Date()

        let leaf = json["current_leaf_message_uuid"] as? String
        let rawMessages = json["chat_messages"] as? [[String: Any]] ?? []

        var byUuid: [String: [String: Any]] = [:]
        for m in rawMessages {
            if let u = m["uuid"] as? String { byUuid[u] = m }
        }

        var branch: [[String: Any]] = []
        if let leafUuid = leaf, !leafUuid.isEmpty, byUuid[leafUuid] != nil {
            var current: String? = leafUuid
            var visited = Set<String>()
            while let cur = current, !cur.isEmpty, !visited.contains(cur), let msg = byUuid[cur] {
                visited.insert(cur)
                branch.append(msg)
                current = msg["parent_message_uuid"] as? String
            }
            branch.reverse()
        } else {
            branch = rawMessages.sorted { (a, b) in
                let ia = a["index"] as? Int ?? 0
                let ib = b["index"] as? Int ?? 0
                return ia < ib
            }
        }

        let messages = branch.compactMap { self.convertMessage($0) }

        return Conversation(
            id: lowerUuid,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isStarred: starred,
            projectId: existing?.projectId,
            model: model ?? (existing?.model ?? ModelOption.default.id),
            messages: messages,
            origin: "claudeAi",
            remoteLoaded: true
        )
    }

    private func convertMessage(_ raw: [String: Any]) -> Message? {
        let uuid = raw["uuid"] as? String
        let sender = raw["sender"] as? String
        let role: Message.Role
        if sender == "human" {
            role = .user
        } else if sender == "assistant" {
            role = .assistant
        } else {
            return nil
        }

        let createdAt = parseISO8601(raw["created_at"] as? String) ?? Date()

        var textBlocks: [String] = []
        var thinkingBlocks: [String] = []
        var toolNames: [String] = []
        if let content = raw["content"] as? [[String: Any]] {
            for block in content {
                let type = block["type"] as? String
                switch type {
                case "text":
                    if let t = block["text"] as? String { textBlocks.append(t) }
                case "thinking":
                    if let t = block["thinking"] as? String, !t.isEmpty { thinkingBlocks.append(t) }
                case "tool_use":
                    if let name = block["name"] as? String { toolNames.append(name) }
                default:
                    break
                }
            }
        }

        var baseText = ""
        if !textBlocks.isEmpty {
            baseText = textBlocks.joined(separator: "\n")
        } else if let t = raw["text"] as? String {
            baseText = t
        }
        for name in toolNames {
            if baseText.isEmpty {
                baseText = "> 🔧 ツール: \(name)"
            } else {
                baseText += "\n\n> 🔧 ツール: \(name)"
            }
        }

        let thinking = thinkingBlocks.isEmpty ? nil : thinkingBlocks.joined(separator: "\n")

        let msgId = uuid?.lowercased() ?? UUID().uuidString
        return Message(
            id: msgId,
            role: role,
            text: baseText,
            thinking: thinking,
            attachments: [],
            createdAt: createdAt,
            isError: false,
            serverUuid: uuid?.lowercased()
        )
    }

    // MARK: - Rename / Star / Delete

    func rename(id: String, title: String, completion: ((Error?) -> Void)? = nil) {
        mutateConversation(id: id, body: ["name": title]) { _ in
            ConversationStore.shared.rename(id: id.lowercased(), title: title)
        } completion: { err in
            completion?(err)
        }
    }

    func setStarred(id: String, starred: Bool, completion: ((Error?) -> Void)? = nil) {
        mutateConversation(id: id, body: ["is_starred": starred]) { _ in
            if var c = ConversationStore.shared.conversation(id: id.lowercased()) {
                c.isStarred = starred
                ConversationStore.shared.save(c, touch: false)
            }
        } completion: { err in
            completion?(err)
        }
    }

    func delete(id: String, completion: ((Error?) -> Void)? = nil) {
        guard isAvailable else {
            DispatchQueue.main.async { completion?(ClaudeAccountError.notLoggedIn) }
            return
        }
        ClaudeAccountClient.shared.resolveOrganizationId { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                DispatchQueue.main.async { completion?(err) }
            case .success(let org):
                let lowerId = id.lowercased()
                guard let url = URL(string: "https://claude.ai/api/organizations/\(org)/chat_conversations/\(lowerId)") else {
                    DispatchQueue.main.async { completion?(ClaudeAccountError.invalidResponse) }
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "DELETE"
                req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")

                let task = URLSession.shared.dataTask(with: req) { _, response, error in
                    if let error = error {
                        DispatchQueue.main.async { completion?(ClaudeAccountError.network(error.localizedDescription)) }
                        return
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status == 401 || status == 403 {
                        ClaudeAccountAuth.shared.clearSession()
                        DispatchQueue.main.async { completion?(ClaudeAccountError.missingSession) }
                        return
                    }
                    if status >= 400 && status != 204 {
                        DispatchQueue.main.async { completion?(ClaudeAccountError.serverError("HTTP \(status)")) }
                        return
                    }
                    ConversationStore.shared.delete(id: lowerId)
                    DispatchQueue.main.async { completion?(nil) }
                }
                task.resume()
            }
        }
    }

    private func mutateConversation(id: String, body: [String: Any], onSuccess: @escaping ([String: Any]) -> Void, completion: @escaping (Error?) -> Void) {
        guard isAvailable else {
            DispatchQueue.main.async { completion(ClaudeAccountError.notLoggedIn) }
            return
        }
        ClaudeAccountClient.shared.resolveOrganizationId { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                DispatchQueue.main.async { completion(err) }
            case .success(let org):
                let lowerId = id.lowercased()
                guard let url = URL(string: "https://claude.ai/api/organizations/\(org)/chat_conversations/\(lowerId)") else {
                    DispatchQueue.main.async { completion(ClaudeAccountError.invalidResponse) }
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "PUT"
                req.setValue(self.cookieHeader(org: org), forHTTPHeaderField: "Cookie")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

                let task = URLSession.shared.dataTask(with: req) { _, response, error in
                    if let error = error {
                        DispatchQueue.main.async { completion(ClaudeAccountError.network(error.localizedDescription)) }
                        return
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status == 401 || status == 403 {
                        ClaudeAccountAuth.shared.clearSession()
                        DispatchQueue.main.async { completion(ClaudeAccountError.missingSession) }
                        return
                    }
                    if status >= 400 {
                        DispatchQueue.main.async { completion(ClaudeAccountError.serverError("HTTP \(status)")) }
                        return
                    }
                    onSuccess([:])
                    DispatchQueue.main.async { completion(nil) }
                }
                task.resume()
            }
        }
    }

    // MARK: - Cookie helper

    private func cookieHeader(org: String?) -> String {
        let sk = ClaudeAccountAuth.shared.sessionKey ?? ""
        var parts = ["sessionKey=\(sk)"]
        let orgValue = org ?? ClaudeAccountAuth.shared.lastActiveOrg
        if let o = orgValue, !o.isEmpty {
            parts.append("lastActiveOrg=\(o)")
        }
        return parts.joined(separator: "; ")
    }
}

// MARK: - Date parsing

private func parseISO8601(_ s: String?) -> Date? {
    guard let s = s, !s.isEmpty else { return nil }
    let f1 = ISO8601DateFormatter()
    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f1.date(from: s) { return d }
    let f2 = ISO8601DateFormatter()
    f2.formatOptions = [.withInternetDateTime]
    if let d = f2.date(from: s) { return d }
    // Fallback: some strings may include space instead of T
    let f3 = DateFormatter()
    f3.locale = Locale(identifier: "en_US_POSIX")
    f3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
    if let d = f3.date(from: s) { return d }
    let f4 = DateFormatter()
    f4.locale = Locale(identifier: "en_US_POSIX")
    f4.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
    return f4.date(from: s)
}
