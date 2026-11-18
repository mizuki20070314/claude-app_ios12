import Foundation

// MARK: - Service

final class ClaudeCodeService {
    static let shared = ClaudeCodeService()
    private init() {}

    // cursor storage per session
    private var sessionCursors: [String: (next: String?, resume: String?)] = [:]

    func cursor(for sessionId: String) -> (next: String?, resume: String?)? {
        return sessionCursors[sessionId]
    }

    func storeCursor(sessionId: String, next: String?, resume: String?) {
        sessionCursors[sessionId] = (next: next, resume: resume)
    }

    // MARK: - Org

    func resolveOrg(completion: @escaping (Result<String, Error>) -> Void) {
        ClaudeAccountClient.shared.resolveOrganizationId { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Headers / URLs

    func applyHeaders(_ req: inout URLRequest, org: String, accept: String) {
        let cookie = ClaudeAccountClient.shared.cookieHeader(org: org)
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        req.setValue("2023-06-01", forHTTPHeaderField: "Anthropic-Version")
        req.setValue("ccr-byoc-2025-07-29", forHTTPHeaderField: "Anthropic-Beta")
        req.setValue(org, forHTTPHeaderField: "X-Organization-Uuid")
        req.setValue(accept, forHTTPHeaderField: "Accept")
    }

    func listURL(cursor: String?) -> URL? {
        var components = URLComponents(string: "https://claude.ai/v1/code/sessions")
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "50")]
        if let c = cursor, !c.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: c))
        }
        components?.queryItems = items
        return components?.url
    }

    func eventsURL(sessionId: String, cursor: String?, limit: Int) -> URL? {
        var components = URLComponents(string: "https://claude.ai/v1/code/sessions/\(sessionId)/events")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort_order", value: "asc")
        ]
        if let c = cursor, !c.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: c))
        }
        components?.queryItems = items
        return components?.url
    }

    func streamURL(sessionId: String, fromSequence: Int) -> URL? {
        var components = URLComponents(string: "https://claude.ai/v1/code/sessions/\(sessionId)/events/stream")
        components?.queryItems = [URLQueryItem(name: "from_sequence_num", value: String(fromSequence))]
        return components?.url
    }

    // MARK: - listSessions

    func listSessions(cursor: String? = nil, completion: @escaping (Result<(sessions: [CodeSession], nextCursor: String?), Error>) -> Void) {
        resolveOrg { [weak self] orgResult in
            guard let self = self else { return }
            switch orgResult {
            case .failure(let e):
                DispatchQueue.main.async { completion(.failure(e)) }
            case .success(let org):
                self.fetchListSessions(org: org, cursor: cursor, completion: completion)
            }
        }
    }

    private func fetchListSessions(org: String, cursor: String?, completion: @escaping (Result<(sessions: [CodeSession], nextCursor: String?), Error>) -> Void) {
        guard let url = listURL(cursor: cursor) else {
            DispatchQueue.main.async { completion(.failure(ClaudeAccountError.invalidResponse)) }
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        applyHeaders(&req, org: org, accept: "application/json")
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
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw ClaudeAccountError.decoding("root")
                    }
                    let arr = json["data"] as? [[String: Any]] ?? []
                    var sessions: [CodeSession] = []
                    for item in arr {
                        if let s = self.parseSession(item) { sessions.append(s) }
                    }
                    let next = json["next_cursor"] as? String
                    let nextCursor = (next?.isEmpty == false) ? next : nil
                    DispatchQueue.main.async { completion(.success((sessions: sessions, nextCursor: nextCursor))) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(ClaudeAccountError.decoding(error.localizedDescription))) }
                }
            }
        }
        task.resume()
    }

    private func parseSession(_ dict: [String: Any]) -> CodeSession? {
        guard let id = dict["id"] as? String, !id.isEmpty else { return nil }
        let title = dict["title"] as? String ?? ""
        let status = dict["status"] as? String ?? ""
        let statusBucket = dict["status_bucket"] as? String
        let workerStatus = dict["worker_status"] as? String
        let connectionStatus = dict["connection_status"] as? String
        let environmentKind = dict["environment_kind"] as? String
        var origin = dict["origin"] as? String
        if origin == nil, let cfg = dict["config"] as? [String: Any] {
            origin = cfg["origin"] as? String
        }
        var model = dict["model"] as? String
        if model == nil, let cfg = dict["config"] as? [String: Any] {
            model = cfg["model"] as? String
        }
        let statusLine = dict["status_line"] as? String
        let updatedAt = parseDate(dict["updated_at"])
        let lastEventAt = parseDate(dict["last_event_at"])
        let unread = dict["unread"] as? Bool ?? false
        return CodeSession(id: id, title: title, status: status, statusBucket: statusBucket,
                           workerStatus: workerStatus, connectionStatus: connectionStatus,
                           environmentKind: environmentKind, origin: origin, model: model,
                           statusLine: statusLine, updatedAt: updatedAt, lastEventAt: lastEventAt,
                           unread: unread)
    }

    // MARK: - loadTranscript

    func loadTranscript(sessionId: String, completion: @escaping (Result<(items: [CodeTranscriptItem], lastSequence: Int), Error>) -> Void) {
        resolveOrg { [weak self] orgResult in
            guard let self = self else { return }
            switch orgResult {
            case .failure(let e):
                DispatchQueue.main.async { completion(.failure(e)) }
            case .success(let org):
                self.fetchTranscript(org: org, sessionId: sessionId, completion: completion)
            }
        }
    }

    private func fetchTranscript(org: String, sessionId: String, completion: @escaping (Result<(items: [CodeTranscriptItem], lastSequence: Int), Error>) -> Void) {
        var allItems: [CodeTranscriptItem] = []
        var lastSeq = 0
        var eventCount = 0
        var nextCursor: String? = nil
        var resumeCursor: String? = nil

        func finish() {
            DispatchQueue.main.async {
                self.storeCursor(sessionId: sessionId, next: nextCursor, resume: resumeCursor)
                completion(.success((items: allItems, lastSequence: lastSeq)))
            }
        }
        func fail(_ e: Error) {
            DispatchQueue.main.async { completion(.failure(e)) }
        }

        func fetchPage(cursor: String?) {
            guard eventCount < 3000 else { finish(); return }
            guard let url = eventsURL(sessionId: sessionId, cursor: cursor, limit: 100) else {
                fail(ClaudeAccountError.invalidResponse); return
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            applyHeaders(&req, org: org, accept: "application/json")
            let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                guard let self = self else { return }
                if let error = error {
                    fail(ClaudeAccountError.network(error.localizedDescription)); return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 401 || status == 403 {
                    ClaudeAccountAuth.shared.clearSession()
                    fail(ClaudeAccountError.missingSession); return
                }
                if status >= 400 {
                    fail(ClaudeAccountError.serverError("HTTP \(status)")); return
                }
                guard let data = data else {
                    fail(ClaudeAccountError.invalidResponse); return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        DispatchQueue.main.async { fail(ClaudeAccountError.decoding("events")) }
                        return
                    }
                    let arr = json["data"] as? [[String: Any]] ?? []
                    let pageNext = json["next_cursor"] as? String
                    let pageResume = json["resume_cursor"] as? String
                    nextCursor = (pageNext?.isEmpty == false) ? pageNext : nil
                    if let pr = pageResume, !pr.isEmpty { resumeCursor = pr }

                    if arr.isEmpty {
                        DispatchQueue.main.async { finish() }
                        return
                    }

                    for evDict in arr {
                        if eventCount >= 3000 { break }
                        eventCount += 1
                        let seq = self.sequenceNumber(evDict)
                        if seq > lastSeq { lastSeq = seq }
                        let converted = self.convertEvent(evDict)
                        allItems.append(contentsOf: converted)
                    }

                    let shouldContinue = (pageNext?.isEmpty == false) && eventCount < 3000
                    if shouldContinue {
                        fetchPage(cursor: pageNext)
                    } else {
                        DispatchQueue.main.async { finish() }
                    }
                }
            }
            task.resume()
        }

        fetchPage(cursor: nil)
    }

    // MARK: - fetchEventsPage (for polling)

    func fetchEventsPage(org: String, sessionId: String, cursor: String?, limit: Int, completion: @escaping (Result<(events: [[String: Any]], nextCursor: String?, resumeCursor: String?), Error>) -> Void) {
        guard let url = eventsURL(sessionId: sessionId, cursor: cursor, limit: limit) else {
            DispatchQueue.main.async { completion(.failure(ClaudeAccountError.invalidResponse)) }
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        applyHeaders(&req, org: org, accept: "application/json")
        let task = URLSession.shared.dataTask(with: req) { data, response, error in
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
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion(.failure(ClaudeAccountError.decoding("events"))) }
                return
            }
            let arr = json["data"] as? [[String: Any]] ?? []
            let next = json["next_cursor"] as? String
            let resume = json["resume_cursor"] as? String
            let nextCursor = (next?.isEmpty == false) ? next : nil
            let resumeCursor = (resume?.isEmpty == false) ? resume : nil
            DispatchQueue.main.async { completion(.success((events: arr, nextCursor: nextCursor, resumeCursor: resumeCursor))) }
        }
        task.resume()
    }

    // MARK: - subscribe

    func subscribe(sessionId: String, fromSequence: Int, onItems: @escaping ([CodeTranscriptItem]) -> Void, onSessionUpdate: ((CodeSession) -> Void)?) -> CodeSessionSubscription {
        let controller = SubscriptionController(service: self, sessionId: sessionId, fromSequence: fromSequence, onItems: onItems, onSessionUpdate: onSessionUpdate)
        let sub = CodeSessionSubscription(controller: controller)
        DispatchQueue.main.async { [weak controller] in
            controller?.start()
        }
        return sub
    }

    // MARK: - Conversion helpers (exposed)

    func sequenceNumber(_ ev: [String: Any]) -> Int {
        if let s = ev["sequence_num"] as? String { return Int(s) ?? 0 }
        if let n = ev["sequence_num"] as? Int { return n }
        if let n = ev["sequence_num"] as? Double { return Int(n) }
        return 0
    }

    func eventDicts(from json: Any) -> [[String: Any]] {
        if let arr = json as? [[String: Any]] { return arr }
        if let dict = json as? [String: Any] {
            if let ev = dict["event"] as? [String: Any] { return [ev] }
            if let data = dict["data"] as? [String: Any] { return [data] }
            if let data = dict["data"] as? [[String: Any]] { return data }
            if dict["event_type"] != nil || dict["sequence_num"] != nil { return [dict] }
            return []
        }
        return []
    }

    func convertEvent(_ ev: [String: Any]) -> [CodeTranscriptItem] {
        let type = ev["event_type"] as? String ?? ""
        let createdAt = parseDate(ev["created_at"])
        let payload = ev["payload"] as? [String: Any] ?? [:]
        var items: [CodeTranscriptItem] = []

        if type == "user" {
            let isSynthetic = payload["isSynthetic"] as? Bool ?? false
            let message = payload["message"] as? [String: Any] ?? [:]
            let content = message["content"]
            if let str = content as? String {
                items.append(.user(text: str, isSynthetic: isSynthetic, date: createdAt))
            } else if let arr = content as? [[String: Any]] {
                var textParts: [String] = []
                for block in arr {
                    let btype = block["type"] as? String ?? ""
                    if btype == "text" {
                        if let t = block["text"] as? String { textParts.append(t) }
                    } else if btype == "tool_result" {
                        if !textParts.isEmpty {
                            items.append(.user(text: textParts.joined(separator: "\n"), isSynthetic: isSynthetic, date: createdAt))
                            textParts = []
                        }
                        let toolUseId = block["tool_use_id"] as? String ?? ""
                        let isError = block["is_error"] as? Bool ?? false
                        let text = extractToolResultText(block["content"])
                        items.append(.toolResult(toolUseId: toolUseId, text: truncate(text, 2000), isError: isError))
                    }
                    // image ignored
                }
                if !textParts.isEmpty {
                    items.append(.user(text: textParts.joined(separator: "\n"), isSynthetic: isSynthetic, date: createdAt))
                }
            }
        } else if type == "assistant" {
            let message = payload["message"] as? [String: Any] ?? [:]
            let content = message["content"]
            if let arr = content as? [[String: Any]] {
                for block in arr {
                    let btype = block["type"] as? String ?? ""
                    if btype == "text" {
                        if let t = block["text"] as? String, !t.isEmpty {
                            items.append(.assistant(text: t, date: createdAt))
                        }
                    } else if btype == "thinking" {
                        if let t = block["thinking"] as? String, !t.isEmpty {
                            items.append(.thinking(text: t))
                        }
                    } else if btype == "tool_use" {
                        let id = block["id"] as? String ?? ""
                        let name = block["name"] as? String ?? ""
                        let input = block["input"] as? [String: Any] ?? [:]
                        let summary = toolUseSummary(input)
                        items.append(.toolUse(id: id, name: name, summary: summary))
                    }
                }
            } else if let str = content as? String, !str.isEmpty {
                items.append(.assistant(text: str, date: createdAt))
            }
        } else if type == "result" {
            if payload["result"] != nil || payload["subtype"] != nil {
                let text = resultStatusText(payload)
                items.append(.status(text: text))
            }
        }
        return items
    }

    func convertEventPublic(_ ev: [String: Any]) -> [CodeTranscriptItem] { return convertEvent(ev) }

    // MARK: - Helpers

    static func parseDate(_ value: Any?) -> Date? {
        guard let s = value as? String, !s.isEmpty else { return nil }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: s) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss"] {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    private func parseDate(_ value: Any?) -> Date? { return ClaudeCodeService.parseDate(value) }

    private func extractToolResultText(_ content: Any?) -> String {
        if let s = content as? String { return s }
        if let arr = content as? [[String: Any]] {
            var parts: [String] = []
            for block in arr {
                if block["type"] as? String == "text", let t = block["text"] as? String {
                    parts.append(t)
                }
            }
            return parts.joined(separator: "\n")
        }
        return ""
    }

    private func toolUseSummary(_ input: [String: Any]) -> String {
        let keys = ["command", "file_path", "path", "pattern", "url", "description", "query"]
        for k in keys {
            if let v = input[k] {
                var s = ""
                if let str = v as? String { s = str }
                else { s = String(describing: v) }
                s = s.replacingOccurrences(of: "\r\n", with: " ")
                s = s.replacingOccurrences(of: "\n", with: " ")
                s = s.replacingOccurrences(of: "\r", with: " ")
                if s.count > 120 { s = String(s.prefix(120)) }
                return s
            }
        }
        return ""
    }

    private func resultStatusText(_ payload: [String: Any]) -> String {
        if let r = payload["result"] {
            if let s = r as? String { return s }
            return String(describing: r)
        }
        if let s = payload["subtype"] as? String { return s }
        return ""
    }

    private func truncate(_ s: String, _ n: Int) -> String {
        if s.count <= n { return s }
        return String(s.prefix(n))
    }
}

// MARK: - Subscription

final class CodeSessionSubscription {
    private var controller: SubscriptionController?
    fileprivate init(controller: SubscriptionController) {
        self.controller = controller
    }
    func cancel() {
        controller?.cancel()
        controller = nil
    }
    deinit {
        controller?.cancel()
    }
}

// MARK: - Subscription controller

private final class SubscriptionController {
    private let service: ClaudeCodeService
    private let sessionId: String
    private let onItems: ([CodeTranscriptItem]) -> Void
    private let onSessionUpdate: ((CodeSession) -> Void)?
    private var lastSequence: Int
    private var storedNext: String?
    private var storedResume: String?
    private var orgId: String?
    private var cancelled = false

    private var sseSession: URLSession?
    private var sseDelegate: CodeSSEDelegate?
    private var sseParser = SSEParser()
    private var pollTimer: Timer?
    private var refreshTimer: Timer?
    private var polling = false

    init(service: ClaudeCodeService, sessionId: String, fromSequence: Int, onItems: @escaping ([CodeTranscriptItem]) -> Void, onSessionUpdate: ((CodeSession) -> Void)?) {
        self.service = service
        self.sessionId = sessionId
        self.onItems = onItems
        self.onSessionUpdate = onSessionUpdate
        self.lastSequence = fromSequence
        if let c = service.cursor(for: sessionId) {
            self.storedNext = c.next
            self.storedResume = c.resume
        }
    }

    func start() {
        guard !cancelled else { return }
        service.resolveOrg { [weak self] result in
            guard let self = self, !self.cancelled else { return }
            if case .success(let org) = result { self.orgId = org }
            self.startSSE()
            self.startRefreshTimer()
        }
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        sseSession?.invalidateAndCancel()
        sseSession = nil
        sseDelegate = nil
        pollTimer?.invalidate()
        pollTimer = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startSSE() {
        guard !cancelled, !polling else { return }
        guard let org = orgId else {
            startPolling()
            return
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        let delegate = CodeSSEDelegate()
        self.sseDelegate = delegate
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        self.sseSession = session

        delegate.onData = { [weak self] data in
            guard let self = self, !self.cancelled else { return }
            let events = self.sseParser.feed(data)
            for ev in events { self.handleSSEEvent(ev) }
        }
        delegate.onHTTPError = { [weak self] status, data in
            guard let self = self, !self.cancelled else { return }
            self.fallbackToPolling()
        }
        delegate.onTransportError = { [weak self] err in
            guard let self = self, !self.cancelled else { return }
            if (err as NSError).code == NSURLErrorCancelled { return }
            self.fallbackToPolling()
        }
        delegate.onFinish = { [weak self] in
            guard let self = self, !self.cancelled else { return }
            let events = self.sseParser.finish()
            for ev in events { self.handleSSEEvent(ev) }
            self.fallbackToPolling()
        }

        guard let url = service.streamURL(sessionId: sessionId, fromSequence: lastSequence) else {
            fallbackToPolling(); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        service.applyHeaders(&req, org: org, accept: "text/event-stream")
        let task = session.dataTask(with: req)
        task.resume()
    }

    private func handleSSEEvent(_ ev: SSEEvent) {
        guard !ev.data.isEmpty else { return }
        guard let json = try? JSONSerialization.jsonObject(with: Data(ev.data.utf8)) else { return }
        let dicts = service.eventDicts(from: json)
        var newItems: [CodeTranscriptItem] = []
        for dict in dicts {
            let seq = service.sequenceNumber(dict)
            if seq > 0 && seq <= lastSequence { continue }
            let converted = service.convertEvent(dict)
            newItems.append(contentsOf: converted)
            if seq > lastSequence { lastSequence = seq }
        }
        if !newItems.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.cancelled else { return }
                self.onItems(newItems)
            }
        }
    }

    private func fallbackToPolling() {
        guard !cancelled, !polling else { return }
        polling = true
        sseSession?.invalidateAndCancel()
        sseSession = nil
        sseDelegate = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.cancelled else { return }
            self.pollOnce()
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.pollOnce()
            }
        }
    }

    private func pollOnce() {
        guard !cancelled, let org = orgId else { return }
        let cursor = (storedResume?.isEmpty == false ? storedResume : storedNext)
        service.fetchEventsPage(org: org, sessionId: sessionId, cursor: cursor, limit: 100) { [weak self] result in
            guard let self = self, !self.cancelled else { return }
            switch result {
            case .failure:
                return
            case .success(let page):
                if let nc = page.nextCursor, !nc.isEmpty { self.storedNext = nc }
                if let rc = page.resumeCursor, !rc.isEmpty { self.storedResume = rc }
                self.service.storeCursor(sessionId: self.sessionId, next: self.storedNext, resume: self.storedResume)
                var newItems: [CodeTranscriptItem] = []
                for ev in page.events {
                    let seq = self.service.sequenceNumber(ev)
                    if seq <= self.lastSequence { continue }
                    newItems.append(contentsOf: self.service.convertEvent(ev))
                    if seq > self.lastSequence { self.lastSequence = seq }
                }
                if !newItems.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, !self.cancelled else { return }
                        self.onItems(newItems)
                    }
                }
            }
        }
    }

    private func startRefreshTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.cancelled else { return }
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                self?.refreshSession()
            }
        }
    }

    private func refreshSession() {
        guard !cancelled else { return }
        service.listSessions(cursor: nil) { [weak self] result in
            guard let self = self, !self.cancelled else { return }
            if case .success(let (sessions, _)) = result {
                if let s = sessions.first(where: { $0.id == self.sessionId }) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, !self.cancelled else { return }
                        self.onSessionUpdate?(s)
                    }
                }
            }
        }
    }
}

// MARK: - SSE delegate

private final class CodeSSEDelegate: NSObject, URLSessionDataDelegate {
    var statusCode: Int = 0
    var errorData = Data()
    var onData: ((Data) -> Void)?
    var onHTTPError: ((Int, Data) -> Void)?
    var onTransportError: ((Error) -> Void)?
    var onFinish: (() -> Void)?

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse { statusCode = http.statusCode }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if statusCode >= 400 { errorData.append(data) } else { onData?(data) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error { onTransportError?(error) }
        else if statusCode >= 400 { onHTTPError?(statusCode, errorData) }
        else { onFinish?() }
        session.finishTasksAndInvalidate()
    }
}