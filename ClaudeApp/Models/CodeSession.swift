import Foundation

struct CodeSession: Identifiable {
    let id: String
    var title: String
    var status: String
    var statusBucket: String?
    var workerStatus: String?
    var connectionStatus: String?
    var environmentKind: String?
    var origin: String?
    var model: String?
    var statusLine: String?
    var updatedAt: Date?
    var lastEventAt: Date?
    var unread: Bool

    var isRemoteControl: Bool { environmentKind == "bridge" }
    var isLive: Bool { connectionStatus == "connected" || workerStatus == "running" || workerStatus == "requires_action" }

    init(id: String,
         title: String = "",
         status: String = "",
         statusBucket: String? = nil,
         workerStatus: String? = nil,
         connectionStatus: String? = nil,
         environmentKind: String? = nil,
         origin: String? = nil,
         model: String? = nil,
         statusLine: String? = nil,
         updatedAt: Date? = nil,
         lastEventAt: Date? = nil,
         unread: Bool = false) {
        self.id = id
        self.title = title
        self.status = status
        self.statusBucket = statusBucket
        self.workerStatus = workerStatus
        self.connectionStatus = connectionStatus
        self.environmentKind = environmentKind
        self.origin = origin
        self.model = model
        self.statusLine = statusLine
        self.updatedAt = updatedAt
        self.lastEventAt = lastEventAt
        self.unread = unread
    }
}

enum CodeTranscriptItem {
    case user(text: String, isSynthetic: Bool, date: Date?)
    case assistant(text: String, date: Date?)
    case thinking(text: String)
    case toolUse(id: String, name: String, summary: String)
    case toolResult(toolUseId: String, text: String, isError: Bool)
    case status(text: String)
}