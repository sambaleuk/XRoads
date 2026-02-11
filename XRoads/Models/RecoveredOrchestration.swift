import Foundation

/// Data recovered from an interrupted orchestration session found on disk.
/// Built from `.crossroads/status.json` and worktree directory scanning.
struct RecoveredOrchestration: Sendable {
    let prdName: String
    let sessionId: UUID
    let startedAt: Date
    let repoPath: URL
    let statusFilePath: URL
    let totalStories: Int
    let completedStories: Int
    let remainingStories: [RemainingStory]
    let slots: [RecoveredSlot]
    let layers: [[String]]

    /// A story that has not yet reached "complete" status.
    struct RemainingStory: Sendable, Identifiable {
        let id: String
        let status: String  // "ready", "blocked", "pending", "inProgress", "failed"
        let dependsOn: [String]
    }

    /// A slot parsed from an existing worktree directory name.
    struct RecoveredSlot: Sendable, Identifiable {
        var id: Int { slotNumber }
        let slotNumber: Int
        let agentType: AgentType
        let storyIds: [String]
        let branchName: String
        let worktreePath: URL
        let allStoriesComplete: Bool
    }

    /// Whether there is meaningful work to resume (at least one incomplete story).
    var hasWorkToResume: Bool {
        !remainingStories.isEmpty
    }

    /// Human-readable progress string (e.g. "6/8 stories complete").
    var progressDescription: String {
        "\(completedStories)/\(totalStories) stories complete"
    }
}
