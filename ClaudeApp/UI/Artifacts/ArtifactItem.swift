import Foundation

struct ArtifactItem {
    let id: String
    let title: String
    let language: String?
    let code: String
    let conversationId: String
    let conversationTitle: String
    let createdAt: Date
}

enum ArtifactExtractor {
    static func extractArtifacts(from conversations: [Conversation]) -> [ArtifactItem] {
        var result: [ArtifactItem] = []
        let documentLanguages: Set<String> = ["html", "svg", "markdown", "md"]

        for conversation in conversations {
            for message in conversation.messages {
                guard message.role == .assistant else { continue }
                let blocks = MarkdownParser.parse(message.text)
                var lastHeading: String? = nil
                var codeIndex = 0
                for block in blocks {
                    switch block {
                    case .heading(_, let text):
                        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty { lastHeading = t }
                    case .codeBlock(let language, let code):
                        let lang = language?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let normalized = (lang ?? "").lowercased()
                        let lineCount = code.components(separatedBy: "\n").count
                        let isDocument = documentLanguages.contains(normalized)
                        let isCandidate = isDocument || lineCount >= 15
                        if isCandidate {
                            codeIndex += 1
                            let title: String
                            if let h = lastHeading, !h.isEmpty {
                                title = h
                            } else if let l = lang, !l.isEmpty {
                                title = "\(l) コード"
                            } else {
                                title = "コード"
                            }
                            let item = ArtifactItem(
                                id: "\(conversation.id)-\(message.id)-\(codeIndex)",
                                title: title,
                                language: lang,
                                code: code,
                                conversationId: conversation.id,
                                conversationTitle: conversation.title,
                                createdAt: message.createdAt
                            )
                            result.append(item)
                        }
                    default:
                        break
                    }
                }
            }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }
}