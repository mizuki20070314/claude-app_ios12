import Foundation

final class ConversationStore {
    static let shared = ConversationStore()

    private let queue = DispatchQueue(label: "com.mizuki.claudeios12.conversationstore")
    private var convMap: [String: Conversation] = [:]
    private var projMap: [String: Project] = [:]
    private var demoMode = false
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
            Array(convMap.values).sorted { $0.sortDate > $1.sortDate }
        }
    }

    func conversation(id: String) -> Conversation? {
        return queue.sync { convMap[id] }
    }

    func save(_ conversation: Conversation, touch: Bool = true) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var c = conversation
            if touch { c.updatedAt = Date() }
            self.convMap[c.id] = c
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
            self.convMap.removeValue(forKey: id)
            if !self.demoMode {
                let url = self.dir.appendingPathComponent("conv_\(id).json")
                try? FileManager.default.removeItem(at: url)
            }
            self.writeIndex()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.changeName, object: self)
            }
        }
    }

    func rename(id: String, title: String) {
        if var c = conversation(id: id) {
            c.title = title
            save(c, touch: false)
        }
    }

    func toggleStar(id: String) {
        if var c = conversation(id: id) {
            c.isStarred.toggle()
            save(c, touch: false)
        }
    }

    func isRemote(_ c: Conversation) -> Bool {
        return c.origin == "claudeAi"
    }

    func mergeRemote(_ items: [Conversation], fullResync: Bool = false) {
        queue.sync {
            for item in items {
                guard item.origin == "claudeAi" else { continue }
                if var existing = convMap[item.id] {
                    existing.title = item.title
                    existing.updatedAt = item.updatedAt
                    existing.isStarred = item.isStarred
                    existing.model = item.model
                    existing.origin = "claudeAi"
                    // lastActivityAt: don't overwrite a newer local value with an older
                    // server value unless this is a full re-sync ordering pass.
                    if fullResync {
                        existing.lastActivityAt = item.lastActivityAt
                    } else if existing.lastActivityAt == nil || (item.lastActivityAt != nil && item.lastActivityAt! > existing.lastActivityAt!) {
                        existing.lastActivityAt = item.lastActivityAt
                    }
                    // preserve messages, remoteLoaded, createdAt, projectId
                    convMap[item.id] = existing
                    if !demoMode { persist(existing) }
                } else {
                    var c = item
                    c.origin = c.origin ?? "claudeAi"
                    convMap[c.id] = c
                    if !demoMode { persist(c) }
                }
            }
            if !demoMode && !items.isEmpty { writeIndex() }
        }
        if !items.isEmpty {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.changeName, object: self)
            }
        }
    }

    func search(query: String) -> [Conversation] {
        let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        guard !q.isEmpty else { return allConversations }
        return queue.sync {
            convMap.values.filter { c in
                let title = c.title.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                if title.contains(q) { return true }
                for m in c.messages {
                    let text = m.text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                    if text.contains(q) { return true }
                }
                return false
            }.sorted { $0.sortDate > $1.sortDate }
        }
    }

    func conversations(inProject projectId: String?) -> [Conversation] {
        return queue.sync {
            convMap.values.filter { $0.projectId == projectId }.sorted { $0.sortDate > $1.sortDate }
        }
    }

    // MARK: - Projects

    var projects: [Project] {
        return queue.sync {
            Array(projMap.values).sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func project(id: String) -> Project? {
        return queue.sync { projMap[id] }
    }

    func saveProject(_ project: Project) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var p = project
            p.updatedAt = Date()
            self.projMap[p.id] = p
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
            self.projMap.removeValue(forKey: id)
            self.writeProjects()
            // unassign conversations
            let affected = self.convMap.filter { $0.value.projectId == id }.map { $0.key }
            for cid in affected {
                if var c = self.convMap[cid] {
                    c.projectId = nil
                    self.convMap[cid] = c
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
            self.demoMode = true
            self.convMap = [:]
            for c in conversations { self.convMap[c.id] = c }
            self.projMap = [:]
            for p in projects { self.projMap[p.id] = p }
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
                for p in arr { projMap[p.id] = p }
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
                        convMap[c.id] = c
                    }
                }
            }
        }
    }

    private func persist(_ c: Conversation) {
        if demoMode { return }
        let url = dir.appendingPathComponent("conv_\(c.id).json")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(c) {
            try? data.write(to: url)
        }
    }

    private func writeProjects() {
        if demoMode { return }
        let url = dir.appendingPathComponent("projects.json")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        let arr = Array(projMap.values)
        if let data = try? enc.encode(arr) {
            try? data.write(to: url)
        }
    }

    private func writeIndex() {
        if demoMode { return }
        let url = dir.appendingPathComponent("index.json")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        let summaries = Array(convMap.values).map { c in
            Summary(id: c.id, title: c.title, updatedAt: c.updatedAt, isStarred: c.isStarred, projectId: c.projectId, model: c.model, messageCount: c.messages.count)
        }
        if let data = try? enc.encode(summaries) {
            try? data.write(to: url)
        }
    }
}
