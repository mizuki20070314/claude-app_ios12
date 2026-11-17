import Foundation

struct ModelOption {
    let id: String
    let displayName: String
    let description: String
    let supportsThinking: Bool

    static let all: [ModelOption] = [
        ModelOption(id: "claude-opus-5-5", displayName: "Claude Opus 5.5", description: "複雑な作業向けの最も高性能なモデル", supportsThinking: true),
        ModelOption(id: "claude-sonnet-5-5", displayName: "Claude Sonnet 5.5", description: "日常の作業に最適", supportsThinking: true),
        ModelOption(id: "claude-haiku-5-5", displayName: "Claude Haiku 5.5", description: "高速な応答", supportsThinking: false),
        ModelOption(id: "claude-fable-5-1", displayName: "Claude Fable 5.1", description: "創造的な作業向け", supportsThinking: true),
        ModelOption(id: "claude-opus-4-1", displayName: "Claude Opus 4.1", description: "旧世代の高性能モデル", supportsThinking: true),
        ModelOption(id: "claude-sonnet-4-5", displayName: "Claude Sonnet 4.5", description: "旧世代のバランスモデル", supportsThinking: true),
        ModelOption(id: "claude-haiku-4-5", displayName: "Claude Haiku 4.5", description: "旧世代の高速モデル", supportsThinking: false)
    ]

    static let `default`: ModelOption = ModelOption.all[1] // Sonnet 5.5

    static func find(id: String) -> ModelOption? {
        return all.first { $0.id == id }
    }
}
