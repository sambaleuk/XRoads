import Foundation

/// Session status
enum SessionStatus: String, Codable, Hashable, Sendable {
    case active
    case paused
    case completed
    case archived
}

/// Represents a work session containing multiple worktrees
struct Session: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var worktrees: [UUID]
    var status: SessionStatus
    let createdAt: Date

    /// Absolute path to the git repo this session operates on
    var repoPath: String?

    /// Map of agent name → conversation ID (for `--resume` on Claude Code)
    var conversationIds: [String: String]

    /// Last generated handoff markdown (for context continuation)
    var handoffPayload: String?

    /// Links to the previous session in a handoff chain
    var parentSessionId: UUID?

    /// Last time this session was updated
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        worktrees: [UUID] = [],
        status: SessionStatus = .active,
        createdAt: Date = Date(),
        repoPath: String? = nil,
        conversationIds: [String: String] = [:],
        handoffPayload: String? = nil,
        parentSessionId: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.worktrees = worktrees
        self.status = status
        self.createdAt = createdAt
        self.repoPath = repoPath
        self.conversationIds = conversationIds
        self.handoffPayload = handoffPayload
        self.parentSessionId = parentSessionId
        self.updatedAt = updatedAt
    }

    /// Formatted creation date
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
