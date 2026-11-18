import Foundation
import UIKit

struct Message: Codable, Identifiable {
    let id: String
    var role: Role
    var text: String
    var thinking: String?
    var attachments: [Attachment]
    var createdAt: Date
    var isError: Bool
    var feedback: Int?
    var model: String?
    var serverUuid: String?

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: String = UUID().uuidString, role: Role, text: String = "", thinking: String? = nil, attachments: [Attachment] = [], createdAt: Date = Date(), isError: Bool = false, feedback: Int? = nil, model: String? = nil, serverUuid: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.thinking = thinking
        self.attachments = attachments
        self.createdAt = createdAt
        self.isError = isError
        self.feedback = feedback
        self.model = model
        self.serverUuid = serverUuid
    }
}

struct Attachment: Codable, Identifiable {
    enum Kind: String, Codable {
        case image
        case textFile = "text-file"
    }

    let id: String
    var kind: Kind
    var fileName: String
    var mediaType: String
    var base64Data: String?
    var textContent: String?

    var thumbnail: UIImage? {
        guard kind == .image, let b64 = base64Data, let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    init(id: String = UUID().uuidString, kind: Kind, fileName: String, mediaType: String, base64Data: String? = nil, textContent: String? = nil) {
        self.id = id
        self.kind = kind
        self.fileName = fileName
        self.mediaType = mediaType
        self.base64Data = base64Data
        self.textContent = textContent
    }
}
