import Foundation

// MARK: - OrchestrationSubState

/// Manages orchestration session state: agent assignments, status snapshots,
/// health monitoring, merge coordination, history, and conflict resolution.
/// Extracted from AppState (CR-301) to reduce God Object complexity.
@MainActor
@Observable
final class OrchestrationSubState {

    // MARK: - Session

    /// Current orchestration session ID
    private(set) var orchestrationSessionID: UUID?

    /// Current orchestration state
    var orchestrationState: OrchestratorState = .idle

    /// Active worktree assignments for current orchestration
    var activeWorktreeAssignments: [WorktreeAssignment] = []

    /// Active agent sessions
    var activeAgentSessions: [AgentSession] = []

    // MARK: - Agent Dashboard

    /// Active task assignments tracked for Full Agentic Mode
    var agentAssignments: [String: TaskAssignment] = [:]

    /// Latest agent status snapshots keyed by assignment/agent id
    var agentStatusSnapshots: [String: AgentStatusSnapshot] = [:]

    /// Timeline of recent agent events for the dashboard (CR-001: bounded at 1000 with FIFO eviction)
    var agentTimelineEvents = BoundedBuffer<AgentTimelineEvent>(capacity: 1000)

    /// Health metrics per agent
    var agentHealthMetrics: [String: AgentHealthMetrics] = [:]

    /// Active health issues detected for agents
    var agentHealthIssues: [AgentHealthIssue] = []
    var presentedHealthIssue: AgentHealthIssue?

    // MARK: - Internal Health Trackers

    var lastStatusTimestamps: [String: Date] = [:]
    var repeatedMessageTracker: [String: (message: String, count: Int)] = [:]
    var storyStartTimestamps: [String: [String: Date]] = [:]

    // MARK: - Merge Coordination

    /// Latest merge plan/result for Full Agentic Mode
    var mergePlan: MergePlan?
    var mergeResult: MergeResult?
    var orchestrationRepoPath: URL?
    var conflictFiles: [String] = []
    var unresolvedConflicts: [MergeConflict] = []
    var selectedConflictFile: String?
    var isConflictSheetPresented: Bool = false

    // MARK: - Recovery

    /// Detected interrupted orchestration from a previous session (set on app launch)
    var recoveredOrchestration: RecoveredOrchestration?

    /// When set, the next dispatch should operate in resume mode using this recovery data.
    var pendingRecovery: RecoveredOrchestration?

    /// Triggers the slot assignment sheet in recovery mode.
    var showRecoverySlotAssignment: Bool = false

    // MARK: - History & PRD

    var historyRecords: [OrchestrationRecord] = []
    var showHistorySheet: Bool = false
    var pendingPRDURL: URL?
    private(set) var activePRDURL: URL?
    private(set) var activePRDName: String?

    // MARK: - Internal Tracking

    var assignmentStartTimes: [String: Date] = [:]
    var assignmentFinishTimes: [String: Date] = [:]
    var agentCompletedStories: [String: Set<String>] = [:]
    var agentErrorMessages: [String: [String]] = [:]

    // MARK: - Health Alert Queue

    var healthAlertQueue: [AgentHealthIssue] = []

    // MARK: - Computed Properties

    /// Whether orchestration is in progress
    var isOrchestrating: Bool {
        switch orchestrationState {
        case .idle, .complete, .error:
            return false
        default:
            return true
        }
    }

    /// Dashboard entries mirroring latest agent statuses
    var dashboardEntries: [AgentDashboardEntry] {
        agentStatusSnapshots.values.map { snapshot in
            let assignment = agentAssignments[snapshot.agentId]
            let metrics = agentHealthMetrics[snapshot.agentId]
            let healthIssue = agentHealthIssues.first { issue in
                issue.agentId == snapshot.agentId && issue.state == .active
            }
            return AgentDashboardEntry(
                id: snapshot.agentId,
                agentType: snapshot.agentType ?? assignment?.agentType,
                stories: assignment?.storyIds ?? [],
                currentStoryId: snapshot.currentStoryId,
                progress: min(max(snapshot.progress, 0), 1),
                state: snapshot.state,
                message: snapshot.message,
                lastUpdate: snapshot.timestamp,
                averageStoryTime: metrics?.averageStoryTime,
                successRate: metrics?.successRate,
                activeHealthIssue: healthIssue
            )
        }
        .sorted { $0.lastUpdate > $1.lastUpdate }
    }

    /// Percentage of completed stories across all tracked assignments
    var globalDashboardProgress: Double {
        let totalStories = agentAssignments.values
            .reduce(0) { $0 + $1.storyIds.count }
        guard totalStories > 0 else { return 0 }

        let completedStories = dashboardEntries.reduce(0) { partial, entry in
            let weight = entry.stories.count
            switch entry.state {
            case .finished:
                return partial + weight
            default:
                return partial + Int(Double(weight) * entry.progress)
            }
        }

        return Double(completedStories) / Double(totalStories)
    }

    /// Whether the dashboard should display the animated agentic pulse
    var isAgenticPulseActive: Bool {
        isOrchestrating
    }

    // MARK: - Session Management

    func setOrchestrationSessionID(_ id: UUID?) {
        orchestrationSessionID = id
    }

    func setActivePRD(url: URL?, name: String?) {
        activePRDURL = url
        activePRDName = name
    }

    func clearPendingPRDURL() {
        pendingPRDURL = nil
    }

    // MARK: - Conflict Helpers

    func presentConflicts(from result: MergeResult, repoPath: URL) {
        orchestrationRepoPath = repoPath
        unresolvedConflicts = result.conflicts
        conflictFiles = result.conflicts.flatMap(\.files)
        selectedConflictFile = conflictFiles.first
        isConflictSheetPresented = !conflictFiles.isEmpty
    }

    func removeConflict(file: String) {
        conflictFiles.removeAll { $0 == file }
        for index in unresolvedConflicts.indices {
            unresolvedConflicts[index].files = unresolvedConflicts[index].files.filter { $0 != file }
        }
        unresolvedConflicts.removeAll { $0.files.isEmpty }
        if conflictFiles.isEmpty {
            isConflictSheetPresented = false
        } else {
            selectedConflictFile = conflictFiles.first
        }
    }

    func clearConflicts() {
        conflictFiles.removeAll()
        unresolvedConflicts.removeAll()
        selectedConflictFile = nil
        isConflictSheetPresented = false
    }

    func dismissConflictSheet() {
        clearConflicts()
    }

    // MARK: - Assignment Management

    func registerAssignments(_ assignments: [TaskAssignment]) {
        for assignment in assignments {
            let key = assignment.id.uuidString
            agentAssignments[key] = assignment
            assignmentStartTimes[key] = Date()
            assignmentFinishTimes[key] = nil
            agentCompletedStories[key] = Set<String>()
            agentErrorMessages[key] = []
            agentHealthMetrics[key] = AgentHealthMetrics(
                agentId: key,
                agentType: assignment.agentType,
                totalStories: assignment.storyIds.count
            )
            storyStartTimestamps[key] = [:]
        }
    }

    func clearAssignments() {
        agentAssignments.removeAll()
        agentStatusSnapshots.removeAll()
        agentTimelineEvents.removeAll()
        assignmentStartTimes.removeAll()
        assignmentFinishTimes.removeAll()
        agentCompletedStories.removeAll()
        agentErrorMessages.removeAll()
        agentHealthMetrics.removeAll()
        agentHealthIssues.removeAll()
        presentedHealthIssue = nil
        healthAlertQueue.removeAll()
        lastStatusTimestamps.removeAll()
        repeatedMessageTracker.removeAll()
        storyStartTimestamps.removeAll()
    }

    // MARK: - Health Issue Management

    @discardableResult
    func recordHealthIssue(
        agentId: String,
        agentType: AgentType?,
        type: AgentHealthIssueType,
        message: String
    ) -> AgentHealthIssue? {
        let now = Date()
        if let index = agentHealthIssues.firstIndex(where: { $0.agentId == agentId && $0.type == type && $0.state != .resolved }) {
            var issue = agentHealthIssues[index]
            if issue.state == .snoozed, let snoozedUntil = issue.snoozedUntil, snoozedUntil > now {
                return nil
            }
            issue.state = .active
            issue.occurrences += 1
            issue.message = message
            issue.snoozedUntil = nil
            agentHealthIssues[index] = issue
            displayHealthIssue(issue)
            return issue
        } else {
            let issue = AgentHealthIssue(
                agentId: agentId,
                agentType: agentType,
                type: type,
                message: message
            )
            agentHealthIssues.append(issue)
            displayHealthIssue(issue)
            return issue
        }
    }

    func resolveHealthIssue(for agentId: String, type: AgentHealthIssueType) {
        guard let index = agentHealthIssues.firstIndex(where: { $0.agentId == agentId && $0.type == type && $0.state != .resolved }) else {
            return
        }
        agentHealthIssues[index].state = .resolved
        agentHealthIssues[index].snoozedUntil = nil

        if presentedHealthIssue?.id == agentHealthIssues[index].id {
            presentedHealthIssue = nil
            dequeueNextHealthIssue()
        } else {
            healthAlertQueue.removeAll { $0.id == agentHealthIssues[index].id }
        }
    }

    func displayHealthIssue(_ issue: AgentHealthIssue) {
        if presentedHealthIssue?.id == issue.id {
            presentedHealthIssue = issue
        } else if presentedHealthIssue == nil {
            presentedHealthIssue = issue
        } else if !healthAlertQueue.contains(where: { $0.id == issue.id }) {
            healthAlertQueue.append(issue)
        }
    }

    func dequeueNextHealthIssue() {
        while !healthAlertQueue.isEmpty {
            let next = healthAlertQueue.removeFirst()
            if let index = agentHealthIssues.firstIndex(where: { $0.id == next.id && $0.state == .active }) {
                presentedHealthIssue = agentHealthIssues[index]
                return
            }
        }
    }

    func incrementHealthMetric(for agentId: String, type: AgentHealthIssueType) {
        guard var metrics = agentHealthMetrics[agentId] else { return }
        switch type {
        case .nonResponsive:
            metrics.nonResponsiveHits += 1
        case .repeatedMessage:
            metrics.repeatedMessageHits += 1
        }
        agentHealthMetrics[agentId] = metrics
    }

    func updateStoredIssue(_ issue: AgentHealthIssue) {
        if let index = agentHealthIssues.firstIndex(where: { $0.id == issue.id }) {
            agentHealthIssues[index] = issue
        }
    }

    // MARK: - Story Tracking

    func recordStoryStart(agentId: String, storyId: String, timestamp: Date) {
        var stories = storyStartTimestamps[agentId] ?? [:]
        stories[storyId] = timestamp
        storyStartTimestamps[agentId] = stories
    }

    func completeStory(agentId: String, storyId: String, completedAt: Date) {
        var stories = storyStartTimestamps[agentId] ?? [:]
        let start = stories.removeValue(forKey: storyId)
        storyStartTimestamps[agentId] = stories
        let duration = start.map { max(completedAt.timeIntervalSince($0), 0) } ?? 0
        updateMetricsForStoryCompletion(agentId: agentId, duration: duration)
    }

    private func updateMetricsForStoryCompletion(agentId: String, duration: TimeInterval) {
        guard var metrics = agentHealthMetrics[agentId] else { return }
        if duration > 0 {
            metrics.storyDurations.append(duration)
        }
        metrics.completedStories = min(metrics.totalStories, metrics.completedStories + 1)
        agentHealthMetrics[agentId] = metrics
    }

    // MARK: - Metrics Building

    func makeAgentMetrics(completedAt: Date) -> [AgentRunMetric] {
        agentAssignments.map { key, assignment in
            let start = assignmentStartTimes[key] ?? mergePlan?.createdAt ?? completedAt
            let finish = assignmentFinishTimes[key] ?? completedAt
            let duration = max(finish.timeIntervalSince(start), 0)
            let snapshot = agentStatusSnapshots[key]
            let state = snapshot?.state ?? .idle
            let totalStories = assignment.storyIds.count
            let completedCount: Int
            let recordedCompletions = agentCompletedStories[key]?.count ?? 0

            if state == .finished {
                completedCount = totalStories
            } else if recordedCompletions > 0 {
                completedCount = min(totalStories, recordedCompletions)
            } else {
                let progress = snapshot?.progress ?? 0
                let approximate = Int((progress * Double(totalStories)).rounded())
                completedCount = max(0, min(totalStories, approximate))
            }

            let errors = agentErrorMessages[key] ?? []

            return AgentRunMetric(
                agentId: key,
                agentType: assignment.agentType,
                storiesTotal: totalStories,
                storiesCompleted: completedCount,
                state: state,
                durationSeconds: duration,
                lastMessage: snapshot?.message,
                errors: errors
            )
        }
        .sorted { lhs, rhs in
            let leftName = lhs.agentType?.displayName ?? lhs.agentId
            let rightName = rhs.agentType?.displayName ?? rhs.agentId
            return leftName < rightName
        }
    }
}
