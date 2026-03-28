import Foundation

// MARK: - ChairmanInput

/// Context package sent to cockpit-council Chairman for deliberation.
/// Assembled by ProjectContextReader from the project's git log, PRD, and open branches.
struct ChairmanInput: Codable, Hashable, Sendable {

    /// Recent git commit entries (last N commits)
    let gitLog: [GitLogEntry]

    /// Summary of the active PRD (feature name, status, pending stories)
    let prdSummary: PRDSummary?

    /// Currently open branches in the project
    let openBranches: [String]

    /// Last cockpit session info (if any)
    let lastSession: LastSessionInfo?

    /// Project path this context was read from
    let projectPath: String

    /// Timestamp of context collection
    let collectedAt: Date
}

// MARK: - GitLogEntry

/// A single git commit entry for Chairman context
struct GitLogEntry: Codable, Hashable, Sendable, Identifiable {
    let sha: String
    let shortSha: String
    let message: String
    let author: String
    let date: Date

    var id: String { sha }
}

// MARK: - PRDSummary

/// Summary of the active PRD for Chairman deliberation
struct PRDSummary: Codable, Hashable, Sendable {
    let featureName: String
    let status: String
    let branch: String?
    let totalStories: Int
    let pendingStories: Int
    let completedStories: Int
}

// MARK: - LastSessionInfo

/// Info about the most recent cockpit session for continuity
struct LastSessionInfo: Codable, Hashable, Sendable {
    let sessionId: UUID
    let status: String
    let chairmanBrief: String?
    let createdAt: Date
}
