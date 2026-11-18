import Foundation

struct Conversation: Codable, Identifiable {
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isStarred: Bool
    var projectId: String?
    var model: String
    var messages: [Message]
    var origin: String?          // nil/"local" = ローカル, "claudeAi" = サーバー
    var remoteLoaded: Bool?      // メッセージ本文を取得済みか
    var lastActivityAt: Date?    // optional, backward-compatible; drives list ordering

    var isRemote: Bool { origin == "claudeAi" }

    var sortDate: Date { lastActivityAt ?? updatedAt }

    init(id: String = UUID().uuidString, title: String = "New Chat", createdAt: Date = Date(), updatedAt: Date = Date(), isStarred: Bool = false, projectId: String? = nil, model: String = ModelOption.default.id, messages: [Message] = [], origin: String? = nil, remoteLoaded: Bool? = nil, lastActivityAt: Date? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isStarred = isStarred
        self.projectId = projectId
        self.model = model
        self.messages = messages
        self.origin = origin
        self.remoteLoaded = remoteLoaded
        self.lastActivityAt = lastActivityAt
    }
}
