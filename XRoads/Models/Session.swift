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

    init(
        id: UUID = UUID(),
        name: String,
        worktrees: [UUID] = [],
        status: SessionStatus = .active,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.worktrees = worktrees
        self.status = status
        self.createdAt = createdAt
    }

    /// Formatted creation date
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
