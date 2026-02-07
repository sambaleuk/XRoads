import Foundation

// MARK: - Errors

enum OrchestratorError: LocalizedError {
    case invalidPRD
    case monitoringCancelled

    var errorDescription: String? {
        switch self {
        case .invalidPRD:
            return "The supplied PRD document is invalid or incomplete."
        case .monitoringCancelled:
            return "Monitoring stopped before completion."
        }
    }
}

// MARK: - ClaudeOrchestrator

/// Actor responsible for coordinating multi-agent workflows in Full Agentic Mode.
actor ClaudeOrchestrator: Orchestrator {

    private(set) var state: OrchestratorState = .idle {
        didSet { eventContinuation?.yield(.stateChanged(state)) }
    }

    private(set) var config: OrchestratorConfig

    private let gitService: GitService
    private let processRunner: ProcessRunner
    private let mcpClient: MCPClient
    private let agentEventBus: AgentEventBus
    private let mergeCoordinator: MergeCoordinator
    private lazy var worktreeFactory = WorktreeFactory(gitService: gitService)
    private let statusMonitor = AgentStatusMonitor()

    private var eventContinuation: AsyncStream<OrchestratorEvent>.Continuation?
    private var activeBaseBranch: String?

    init(
        config: OrchestratorConfig = .default,
        gitService: GitService = GitService(),
        processRunner: ProcessRunner = ProcessRunner(),
        mcpClient: MCPClient = MCPClient(),
        agentEventBus: AgentEventBus = AgentEventBus(),
        mergeCoordinator: MergeCoordinator = MergeCoordinator()
    ) {
        self.config = config
        self.gitService = gitService
        self.processRunner = processRunner
        self.mcpClient = mcpClient
        self.agentEventBus = agentEventBus
        self.mergeCoordinator = mergeCoordinator
    }

    func updateConfig(_ config: OrchestratorConfig) async {
        self.config = config
    }

    func analyzePRD(_ document: PRDDocument) async throws -> PRDAnalysis {
        transition(to: .analyzing)

        guard !document.userStories.isEmpty else {
            transition(to: .error(message: "PRD does not contain user stories."))
            throw OrchestratorError.invalidPRD
        }

        // Simple placeholder grouping: one story per group, assigned to Claude by default.
        let splitter = TaskSplitter()
        let groups = try splitter.split(
            prd: document,
            availableAgents: AgentType.allCases
        )

        transition(to: .distributing)
        return PRDAnalysis(document: document, taskGroups: groups)
    }

    func createWorktrees(for analysis: PRDAnalysis, repoPath: URL) async throws -> [WorktreeAssignment] {
        transition(to: .distributing)
        let base = try await gitService.getCurrentBranch(path: repoPath.path)
        activeBaseBranch = base
        return try await worktreeFactory.createWorktreesForTasks(
            taskGroups: analysis.taskGroups,
            repoPath: repoPath
        )
    }

    func assignTasks(for worktrees: [WorktreeAssignment]) async throws -> [TaskAssignment] {
        let assignments = worktrees.map { worktree -> TaskAssignment in
            TaskAssignment(
                id: worktree.id,
                storyIds: worktree.taskGroup.storyIds,
                agentType: worktree.agentType,
                worktreePath: worktree.worktreePath,
                priority: priority(for: worktree.taskGroup)
            )
        }
        return assignments
    }

    func monitorProgress(for assignments: [TaskAssignment], sessionID: UUID) async -> AsyncStream<OrchestratorEvent> {
        transition(to: .monitoring)

        let statusStream = await statusMonitor.monitor(
            sessionID: sessionID,
            assignments: assignments
        )

        let eventStream = await agentEventBus.subscribe(agentId: "orchestrator-\(sessionID.uuidString)")

        return AsyncStream { continuation in
            self.eventContinuation = continuation
            continuation.yield(.log("Monitoring \(assignments.count) assignments via status files."))

            Task {
                for await snapshot in statusStream {
                    continuation.yield(.agentStatus(snapshot))
                }
            }

            Task {
                for await event in eventStream {
                    continuation.yield(.agentEvent(event))
                }
            }
        }
    }

    func coordinateMerge(for assignments: [WorktreeAssignment], repoPath: URL) async throws -> MergeResult {
        transition(to: .merging)

        let plan = try await mergeCoordinator.prepareMerge(
            assignments: assignments,
            repoPath: repoPath,
            baseBranch: activeBaseBranch
        )

        let result = try await mergeCoordinator.executeMerge(plan: plan, repoPath: repoPath)
        transition(to: result.success ? .complete : .error(message: "Merge conflicts detected"))
        return result
    }

    // MARK: - Helpers

    private func transition(to newState: OrchestratorState) {
        state = newState
    }

    private func priority(for group: TaskGroup) -> TaskPriority {
        if group.estimatedComplexity >= TaskPriority.critical.weight {
            return .critical
        } else if group.estimatedComplexity >= TaskPriority.high.weight {
            return .high
        } else if group.estimatedComplexity >= TaskPriority.medium.weight {
            return .medium
        } else {
            return .low
        }
    }
}
