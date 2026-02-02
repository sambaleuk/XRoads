import Foundation

/// Status of an AI agent in a worktree
enum AgentStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case idle
    case running
    case planning
    case complete
    case error

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .planning: return "Planning"
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }

    var isActive: Bool {
        switch self {
        case .running, .planning: return true
        default: return false
        }
    }
}
