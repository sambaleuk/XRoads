import Foundation

/// Supported AI CLI agent types
enum AgentType: String, Codable, Hashable, Sendable, CaseIterable {
    case claude
    case gemini
    case codex

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .gemini: return "Gemini CLI"
        case .codex: return "Codex"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .gemini: return "sparkles"
        case .codex: return "terminal"
        }
    }
}
