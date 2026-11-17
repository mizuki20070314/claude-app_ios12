import Foundation

final class ConversationStore {
    static let shared = ConversationStore()

    private let queue = DispatchQueue(label: "com.mizuki.claudeios12.conversationstore")
    private var conversations: [String: Conversation] = [:]
    private var projects: [String: Project] = [:]
    private let dir: URL
    private let changeName = Notification.Name("ConversationStore.didChange")

    private struct Summary: Codable {
        let id: String
        let title: String
        let updatedAt: Date
        let isStarred: Bool
        let projectId: String?
        let model: String
        let messageCount: Int
    }

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        dir = base.appendingPathComponent("ClaudeData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        loadAll()
    }

    // MARK: - Conversations

    var allConversations: [Conversation] {
        return queue.sync {
            Array(conversations.values).sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func conversation(id: String) -> Conversation? {
        return queue.sync { conversations[id] }
    }

    func save(_ conversation: Conversation) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var c = conversation
            c.updatedAt = Date()
            self.conversations[c.id] = c
            self.persist(c)
            self.writeIndex()
            self.writeProjects()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.changeName, object: self)
            }
        }
    }

    func delete(id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.conversations.removeValue(forKey: id)
            let url = self.dir.appendingPathComponent("conv_\(id).json")
            try? FileManager.default.removeItem(at: url)
            self.writeIndex()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.changeName, object: self)
            }
        }
    }

    func rename(id: String, title: String) {
        if var c = conversation(id: id) {
            c.title = title
            save(c)
        }
    }

    func toggleStar(id: String) {
        if var c = conversation(id: id) {
            c.isStarred.toggle()
            save(c)
        }
    }

    func search(query: String) -> [Conversation] {
        let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        guard !q.isEmpty else { return allConversations }
        return queue.sync {
            conversations.values.filter { c in
                let title = c.title.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                if title.contains(q) { return true }
                for m in c.messages {
                    let text = m.text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                    if text.contains(q) { return true }
                }
                return false
            }.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func conversations(inProject projectId: String?) -> [Conversation] {
        return queue.sync {
            conversations.values.filter { $0.projectId == projectId }.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    // MARK: - Projects

    var projects: [Project] {
        return queue.sync {
            Array(projects.values).sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func project(id: String) -> Project? {
        return queue.sync { projects[id] }
    }

    func saveProject(_ project: Project) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var p = project
            p.updatedAt = Date()
            self.projects[p.id] = p
            self.writeProjects()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.changeName, object: self)
            }
        }
    }

    func addProject(_ project: Project) { saveProject(project) }

    func deleteProject(id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.projects.removeValue(forKey: id)
            self.writeProjects()
            // unassign conversations
            let affected = self.conversations.filter { $0.value.projectId == id }.map { $0.key }
            for cid in affected {
                if var c = self.conversations[cid] {
                    c.projectId = nil
                    self.conversations[cid] = c
                    self.persist(c)
                }
            }
            self.writeIndex()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.changeName, object: self)
            }
        }
    }

    func toggleStarProject(id: String) {
        if var p = project(id: id) {
            p.isStarred.toggle()
            saveProject(p)
        }
    }

    // MARK: - Demo data

    func loadDemoData(_ conversations: [Conversation], _ projects: [Project]) {
        queue.sync {
            self.conversations = [:]
            for c in conversations { self.conversations[c.id] = c }
            self.projects = [:]
            for p in projects { self.projects[p.id] = p }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: self.changeName, object: self)
        }
    }

    // MARK: - Persistence

    private func loadAll() {
        // projects
        let purl = dir.appendingPathComponent("projects.json")
        if let data = try? Data(contentsOf: purl) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            if let arr = try? dec.decode([Project].self, from: data) {
                for p in arr { projects[p.id] = p }
            }
        }
        // conversations
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files {
                let name = f.lastPathComponent
                guard name.hasPrefix("conv_") && name.hasSuffix(".json") else { continue }
                if let data = try? Data(contentsOf: f) {
                    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
                    if let c = try? dec.decode(Conversation.self, from: data) {
                        conversations[c.id] = c
                    }
                }
            }
        }
    }

    private func persist(_ c: Conversation) {
        let url = dir.appendingPathComponent("conv_\(c.id).json")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(c) {
            try? data.write(to: url)
        }
    }

    private func writeProjects() {
        let url = dir.appendingPathComponent("projects.json")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        let arr = Array(projects.values)
        if let data = try? enc.encode(arr) {
            try? data.write(to: url)
        }
    }

    private func writeIndex() {
        let url = dir.appendingPathComponent("index.json")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        let summaries = Array(conversations.values).map { c in
            Summary(id: c.id, title: c.title, updatedAt: c.updatedAt, isStarred: c.isStarred, projectId: c.projectId, model: c.model, messageCount: c.messages.count)
        }
        if let data = try? enc.encode(summaries) {
            try? data.write(to: url)
        }
    }
}
