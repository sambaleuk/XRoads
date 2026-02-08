import Foundation
import SwiftUI

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

    /// Neon color for glowing connections
    var neonColor: Color {
        switch self {
        case .claude: return Color(red: 0.45, green: 0.84, blue: 1.0)   // Cyan
        case .gemini: return Color(red: 1.0, green: 0.75, blue: 0.3)    // Gold glow
        case .codex: return Color(red: 0.4, green: 1.0, blue: 0.5)      // Green glow
        }
    }

    /// CLI display name for slot headers (e.g., "CLAUDE CODE")
    var cliDisplayName: String {
        switch self {
        case .claude: return "CLAUDE CODE"
        case .gemini: return "GEMINI CLI"
        case .codex: return "CODEX"
        }
    }

    /// Short name for compact display
    var shortName: String {
        switch self {
        case .claude: return "CC"
        case .gemini: return "GM"
        case .codex: return "CX"
        }
    }

    /// Loop script name for this agent type
    var loopScriptName: String {
        switch self {
        case .claude: return "nexus-loop"
        case .gemini: return "gemini-loop"
        case .codex: return "codex-loop"
        }
    }

    /// Ordered failover alternatives when this agent is rate-limited
    var failoverAlternatives: [AgentType] {
        switch self {
        case .claude: return [.gemini, .codex]
        case .gemini: return [.claude, .codex]
        case .codex: return [.claude, .gemini]
        }
    }
}
