# Services & Models Public API

## Models

### ModelOption
```swift
struct ModelOption { let id: String; let displayName: String; let description: String; let supportsThinking: Bool }
static let all: [ModelOption]
static let `default`: ModelOption   // claude-sonnet-5-5
static func find(id: String) -> ModelOption?
```

### Message
```swift
struct Message: Codable, Identifiable {
    let id: String
    var role: Role // .user / .assistant
    var text: String
    var thinking: String?
    var attachments: [Attachment]
    var createdAt: Date
    var isError: Bool
    var feedback: Int? // +1 / -1
    var model: String?
    init(id:role:text:thinking:attachments:createdAt:isError:feedback:model:)
}
```

### Attachment
```swift
struct Attachment: Codable, Identifiable {
    enum Kind { case image; case textFile } // raw "image"/"text-file"
    let id: String
    var kind: Kind
    var fileName: String
    var mediaType: String
    var base64Data: String?   // image
    var textContent: String?  // text file
    var thumbnail: UIImage?   // computed
}
```

### Conversation
```swift
struct Conversation: Codable, Identifiable {
    var id: String; var title: String; var createdAt: Date; var updatedAt: Date
    var isStarred: Bool; var projectId: String?; var model: String; var messages: [Message]
}
```

### Project
```swift
struct Project: Codable, Identifiable {
    var id: String; var name: String; var description: String; var instructions: String
    var knowledge: [Attachment]; var isStarred: Bool; var createdAt: Date; var updatedAt: Date
}
```

## Services

### KeychainStore
```swift
final class KeychainStore { static let shared
    func get(_ key: String) -> String?
    func set(_ value: String, for key: String) -> Bool
    func delete(_ key: String) -> Bool
}
```
Service id: "com.mizuki.claudeios12".

### SettingsStore
```swift
final class SettingsStore { static let shared
    var selectedModelId: String
    var extendedThinking: Bool
    var thinkingBudget: Int       // default 8000
    var maxTokens: Int            // default 8192
    var themeMode: String         // "system"/"light"/"dark"
    var userName: String
    var style: String             // "normal"/"concise"/"explanatory"/"formal"
    var sendWithReturn: Bool
    var haptics: Bool
    var apiBaseURL: String        // default https://api.anthropic.com
    var apiKey: String            // Keychain-backed
}
```
Posts `Notification.Name("SettingsStore.didChange")` on any change.

### ConversationStore
```swift
final class ConversationStore { static let shared
    var allConversations: [Conversation]          // sorted updatedAt desc
    func conversation(id: String) -> Conversation?
    func save(_ conversation: Conversation)
    func delete(id: String)
    func rename(id: String, title: String)
    func toggleStar(id: String)
    func search(query: String) -> [Conversation]
    var projects: [Project]
    func project(id: String) -> Project?
    func saveProject(_ project: Project)
    func addProject(_ project: Project)
    func deleteProject(id: String)
    func toggleStarProject(id: String)
    func conversations(inProject: String?) -> [Conversation]
    func loadDemoData(_ conversations: [Conversation], _ projects: [Project])
}
```
Posts `Notification.Name("ConversationStore.didChange")` on main thread.

### SSEParser
```swift
struct SSEEvent { let event: String?; let data: String }
final class SSEParser {
    func feed(_ data: Data) -> [SSEEvent]
    func finish() -> [SSEEvent]
    func reset()
}
```

### AnthropicClient
```swift
final class StreamHandle { func cancel() }
final class AnthropicClient { static let shared
    func streamMessage(model:messages:system:maxTokens:thinkingEnabled:thinkingBudget:onThinkingDelta:onTextDelta:onComplete:onError:) -> StreamHandle
    func generateTitle(for:assistantText:completion: (String?) -> Void)
    func validateKey(completion: (Result<Void, Error>) -> Void)
    static func buildSystemPrompt(style:userName:project:) -> String
}
```
Errors: `AnthropicError` (invalidKey, rateLimit, overloaded, networkOffline, serverError, decoding, cancelled) with Japanese localizedDescription.

### ImageUtil
```swift
enum ImageUtil {
    static func resizeAndJPEG(_ image: UIImage, maxSide: CGFloat = 1568, quality: CGFloat = 0.8) -> (Data, String)?
}
```
Returns JPEG data and "image/jpeg".
