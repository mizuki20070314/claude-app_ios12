import Foundation

struct Project: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var instructions: String
    var knowledge: [Attachment]
    var isStarred: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, name: String = "", description: String = "", instructions: String = "", knowledge: [Attachment] = [], isStarred: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.instructions = instructions
        self.knowledge = knowledge
        self.isStarred = isStarred
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
