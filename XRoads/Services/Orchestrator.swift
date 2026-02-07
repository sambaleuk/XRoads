import Foundation

// MARK: - Core Configuration

/// Strategy used when orchestrator detects potential merge conflicts.
enum ConflictStrategy: String, Codable, Sendable {
    case manualReview
    case preferPrimary
    case failFast
}

/// Configuration values that shape orchestrator behaviour.
struct OrchestratorConfig: Codable, Sendable, Equatable {
    var maxParallelAgents: Int
    var autoMerge: Bool
    var conflictStrategy: ConflictStrategy

    static let `default` = OrchestratorConfig(
        maxParallelAgents: 2,
        autoMerge: true,
        conflictStrategy: .manualReview
    )
}

// MARK: - State & Events

/// High-level orchestrator lifecycle states.
enum OrchestratorState: Equatable, Sendable {
    case idle
    case analyzing
    case distributing
    case monitoring
    case merging
    case complete
    case error(message: String?)

    var isTerminal: Bool {
        switch self {
        case .complete, .error:
            return true
        default:
            return false
        }
    }
}

/// Normalised priority level used when ordering agent handoffs.
enum TaskPriority: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case critical

    var weight: Int {
        switch self {
        case .low: return 1
        case .medium: return 5
        case .high: return 10
        case .critical: return 20
        }
    }
}

/// Assignment describing which agent tackles which stories in which worktree.
struct TaskAssignment: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let storyIds: [String]
    let agentType: AgentType
    let worktreePath: URL
    let priority: TaskPriority

    init(
        id: UUID = UUID(),
        storyIds: [String],
        agentType: AgentType,
        worktreePath: URL,
        priority: TaskPriority
    ) {
        self.id = id
        self.storyIds = storyIds
        self.agentType = agentType
        self.worktreePath = worktreePath
        self.priority = priority
    }
}

/// Runtime state emitted from agent status files.
enum AgentRunState: String, Codable, Sendable {
    case idle
    case working
    case needsInput = "needs_input"
    case blocked
    case finished
    case error
}

/// Snapshot emitted while monitoring agent progress.
struct AgentStatusSnapshot: Sendable {
    let agentId: String
    let agentType: AgentType?
    let worktreePath: URL?
    let state: AgentRunState
    let currentStoryId: String?
    let progress: Double
    let message: String
    let timestamp: Date
}

/// Events surfaced by the orchestrator to interested observers.
enum OrchestratorEvent: Sendable {
    case stateChanged(OrchestratorState)
    case agentStatus(AgentStatusSnapshot)
    case log(String)
    case agentEvent(AgentEvent)
}

// MARK: - PRD Domain
// PRDDocument and PRDUserStory are defined in Models/PRDTemplate.swift

/// Result of analysing a PRD prior to orchestration.
struct PRDAnalysis: Sendable {
    let document: PRDDocument
    let taskGroups: [TaskGroup]
}

/// Grouping of stories intended for a single agent/worktree.
struct TaskGroup: Identifiable, Sendable {
    let id: String
    let preferredAgent: AgentType
    let storyIds: [String]
    let estimatedComplexity: Int
}

/// Worktree allocation produced during orchestration.
struct WorktreeAssignment: Identifiable, Sendable {
    let id: UUID
    let taskGroup: TaskGroup
    let agentType: AgentType
    let branchName: String
    let worktreePath: URL

    var taskGroupId: String { taskGroup.id }
}

/// Merge plan step status
enum MergeStepStatus: String, Codable, Sendable {
    case pending
    case ready
    case blocked
}

/// Individual step in a merge plan.
struct MergePlanStep: Identifiable, Sendable {
    let id: UUID
    let assignment: WorktreeAssignment
    var status: MergeStepStatus
    var predictedConflicts: [String]
}

/// Merge planning artefact.
struct MergePlan: Sendable {
    let baseBranch: String
    let steps: [MergePlanStep]
    let createdAt: Date
}

struct MergeConflict: Identifiable, Sendable, Codable {
    let id: UUID
    let branch: String
    var files: [String]
    let message: String

    init(id: UUID = UUID(), branch: String, files: [String], message: String) {
        self.id = id
        self.branch = branch
        self.files = files
        self.message = message
    }
}

/// Outcome of coordinating merges across generated worktrees.
struct MergeResult: Sendable, Codable {
    let baseBranch: String
    let mergedBranches: [String]
    let conflicts: [MergeConflict]
    let success: Bool
    let rolledBack: Bool

    static let empty = MergeResult(baseBranch: "", mergedBranches: [], conflicts: [], success: true, rolledBack: false)
}

// MARK: - Orchestrator Protocol

/// Contract implemented by the Claude-driven orchestrator actor.
@preconcurrency
protocol Orchestrator: AnyObject, Sendable {
    var state: OrchestratorState { get async }
    var config: OrchestratorConfig { get async }

    func updateConfig(_ config: OrchestratorConfig) async

    func analyzePRD(_ document: PRDDocument) async throws -> PRDAnalysis
    func createWorktrees(for analysis: PRDAnalysis, repoPath: URL) async throws -> [WorktreeAssignment]
    func assignTasks(for worktrees: [WorktreeAssignment]) async throws -> [TaskAssignment]
    func monitorProgress(for assignments: [TaskAssignment], sessionID: UUID) async -> AsyncStream<OrchestratorEvent>
    func coordinateMerge(for assignments: [WorktreeAssignment], repoPath: URL) async throws -> MergeResult
}
