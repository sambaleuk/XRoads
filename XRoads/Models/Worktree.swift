import Foundation

/// Represents a git worktree with an assigned agent
struct Worktree: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let branch: String
    let agentId: UUID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        path: String,
        branch: String,
        agentId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.agentId = agentId
        self.createdAt = createdAt
    }

    /// Returns the worktree name from the path
    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
