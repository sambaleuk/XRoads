import Foundation

/// Represents an AI agent instance assigned to a worktree
struct Agent: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let type: AgentType
    var status: AgentStatus
    let worktreePath: String

    init(
        id: UUID = UUID(),
        type: AgentType,
        status: AgentStatus = .idle,
        worktreePath: String
    ) {
        self.id = id
        self.type = type
        self.status = status
        self.worktreePath = worktreePath
    }
}
