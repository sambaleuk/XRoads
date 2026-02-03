import Foundation

/// Represents a single log entry from an agent or system
struct LogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let source: String
    let worktree: String?
    let message: String
    let metadata: [String: String]?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        source: String,
        worktree: String? = nil,
        message: String,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.source = source
        self.worktree = worktree
        self.message = message
        self.metadata = metadata
    }

    /// Formatted timestamp for display [HH:mm:ss]
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: timestamp))]"
    }
}
