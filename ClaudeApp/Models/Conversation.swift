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

    init(id: String = UUID().uuidString, title: String = "New Chat", createdAt: Date = Date(), updatedAt: Date = Date(), isStarred: Bool = false, projectId: String? = nil, model: String = ModelOption.default.id, messages: [Message] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isStarred = isStarred
        self.projectId = projectId
        self.model = model
        self.messages = messages
    }
}
