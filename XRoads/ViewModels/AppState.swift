import Foundation
import SwiftUI

// MARK: - AppState

/// Global application state using @Observable for better SwiftUI performance
/// This class manages all shared state and provides access to services
@MainActor
@Observable
final class AppState {

    // MARK: - State Properties

    /// All sessions in the application
    var sessions: [Session] = []

    /// Currently selected session
    var selectedSession: Session?

    /// All worktrees across sessions
    var worktrees: [Worktree] = []

    /// Currently selected worktree
    var selectedWorktree: Worktree?

    /// All agents indexed by their ID
    var agents: [UUID: Agent] = [:]

    /// Log entries for display
    var logs: [LogEntry] = []

    /// Loading state indicator
    var isLoading: Bool = false

    /// Current error message to display
    var error: AppError?

    /// MCP connection status
    var mcpConnectionStatus: MCPConnectionStatus = .disconnected

    /// Indicates if log streaming is active
    var isStreamingLogs: Bool = false

    /// Active task assignments tracked for Full Agentic Mode
    var agentAssignments: [String: TaskAssignment] = [:]

    /// Latest agent status snapshots keyed by assignment/agent id
    var agentStatusSnapshots: [String: AgentStatusSnapshot] = [:]

    /// Timeline of recent agent events for the dashboard
    var agentTimelineEvents: [AgentTimelineEvent] = []

    /// Health metrics per agent (avg durations, success rate, issue counters)
    var agentHealthMetrics: [String: AgentHealthMetrics] = [:]

    /// Active health issues detected for agents
    var agentHealthIssues: [AgentHealthIssue] = []
    var presentedHealthIssue: AgentHealthIssue?

    /// Internal trackers for responsiveness and repeated messages
    private var lastStatusTimestamps: [String: Date] = [:]
    private var repeatedMessageTracker: [String: (message: String, count: Int)] = [:]
    private var storyStartTimestamps: [String: [String: Date]] = [:]

    /// Latest merge plan/result for Full Agentic Mode
    var mergePlan: MergePlan?
    var mergeResult: MergeResult?
    var orchestrationRepoPath: URL?
    var conflictFiles: [String] = []
    var unresolvedConflicts: [MergeConflict] = []
    var selectedConflictFile: String?
    var isConflictSheetPresented: Bool = false

    var historyRecords: [OrchestrationRecord] = []
    var showHistorySheet: Bool = false
    var pendingPRDURL: URL?
    private(set) var activePRDURL: URL?
    private(set) var activePRDName: String?
    private var assignmentStartTimes: [String: Date] = [:]
    private var assignmentFinishTimes: [String: Date] = [:]
    private var agentCompletedStories: [String: Set<String>] = [:]
    private var agentErrorMessages: [String: [String]] = [:]

    // MARK: - Orchestration State

    /// Current orchestration session ID
    private(set) var orchestrationSessionID: UUID?

    /// Current orchestration state
    var orchestrationState: OrchestratorState = .idle

    /// Active worktree assignments for current orchestration
    var activeWorktreeAssignments: [WorktreeAssignment] = []

    /// Active agent sessions
    var activeAgentSessions: [AgentSession] = []

    /// Whether orchestration is in progress
    var isOrchestrating: Bool {
        switch orchestrationState {
        case .idle, .complete, .error:
            return false
        default:
            return true
        }
    }

    // MARK: - Private Properties

    /// Task for log streaming
    private var logStreamTask: Task<Void, Never>?
    private var agentStatusTask: Task<Void, Never>?
    private var agentEventTask: Task<Void, Never>?
    private let statusMonitor = AgentStatusMonitor()
    private var healthMonitorTask: Task<Void, Never>?
    private var healthAlertQueue: [AgentHealthIssue] = []
    private let healthCheckInterval: TimeInterval = 30
    private let nonResponsiveThreshold: TimeInterval = 120
    private let repeatedMessageThreshold = 5

    // MARK: - Services

    /// Service container providing access to all services
    let services: ServiceContainer

    // MARK: - Computed Properties

    /// Worktrees for the selected session
    var sessionWorktrees: [Worktree] {
        guard let session = selectedSession else { return [] }
        return worktrees.filter { session.worktrees.contains($0.id) }
    }

    /// Logs filtered for the selected worktree
    var filteredLogs: [LogEntry] {
        guard let worktree = selectedWorktree else { return logs }
        return logs.filter { $0.worktree == worktree.path }
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

    // MARK: - Initialization

    init(services: ServiceContainer = DefaultServiceContainer()) {
        self.services = services
    }
    
    // MARK: - Lifecycle
    
    /// Cleanup all resources when app is closing
    func cleanup() async {
        // Stop log streaming
        logStreamTask?.cancel()
        logStreamTask = nil
        
        // Stop agent monitoring
        agentStatusTask?.cancel()
        agentStatusTask = nil
        
        agentEventTask?.cancel()
        agentEventTask = nil
        
        healthMonitorTask?.cancel()
        healthMonitorTask = nil
        
        // Stop MCP server
        await services.mcpClient.stop()
        
        // Clear state
        isStreamingLogs = false
        mcpConnectionStatus = .disconnected
    }

    // MARK: - Session Management

    /// Creates a new session
    func createSession(name: String) {
        let session = Session(name: name)
        sessions.append(session)
        selectedSession = session
    }

    /// Selects a session
    func selectSession(_ session: Session?) {
        selectedSession = session
        selectedWorktree = nil
    }

    /// Removes a session
    func removeSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        if selectedSession?.id == session.id {
            selectedSession = sessions.first
        }
    }

    // MARK: - Worktree Management

    /// Adds a worktree to the current session
    func addWorktree(_ worktree: Worktree) {
        worktrees.append(worktree)
        
        // Update the session's worktrees array directly in the sessions array
        if let session = selectedSession,
           let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].worktrees.append(worktree.id)
            // Update selectedSession to reflect the change
            selectedSession = sessions[index]
        }
    }

    /// Selects a worktree
    func selectWorktree(_ worktree: Worktree?) {
        selectedWorktree = worktree
    }

    /// Removes a worktree
    func removeWorktree(_ worktree: Worktree) {
        worktrees.removeAll { $0.id == worktree.id }
        
        if selectedWorktree?.id == worktree.id {
            selectedWorktree = nil
        }

        // Remove associated agent
        if let agentId = worktree.agentId {
            agents.removeValue(forKey: agentId)
        }

        // Remove from session's worktrees array directly
        if let session = selectedSession,
           let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].worktrees.removeAll { $0 == worktree.id }
            // Update selectedSession to reflect the change
            selectedSession = sessions[index]
        }
    }

    // MARK: - Agent Management

    /// Gets the agent for a worktree
    func agent(for worktree: Worktree) -> Agent? {
        guard let agentId = worktree.agentId else { return nil }
        return agents[agentId]
    }

    /// Adds or updates an agent
    func setAgent(_ agent: Agent) {
        agents[agent.id] = agent
    }

    /// Removes an agent
    func removeAgent(_ agentId: UUID) {
        agents.removeValue(forKey: agentId)
    }

    // MARK: - Log Management

    /// Adds a log entry
    func addLog(_ log: LogEntry) {
        logs.append(log)
        // Limit to last 500 logs for performance
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }

    /// Adds multiple log entries
    func addLogs(_ newLogs: [LogEntry]) {
        logs.append(contentsOf: newLogs)
        // Limit to last 500 logs for performance
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }

    // MARK: - Agent Dashboard Management

    /// Registers task assignments so the dashboard can determine total scope
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

    /// Clears tracked assignments
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
        healthMonitorTask?.cancel()
        healthMonitorTask = nil
    }

    /// Handles an incoming agent status snapshot
    func handleAgentStatusSnapshot(_ snapshot: AgentStatusSnapshot) {
        lastStatusTimestamps[snapshot.agentId] = snapshot.timestamp
        if snapshot.state != .error && snapshot.state != .blocked {
            resolveHealthIssue(for: snapshot.agentId, type: .nonResponsive)
        }
        evaluateRepeatedMessage(for: snapshot)

        if assignmentStartTimes[snapshot.agentId] == nil {
            assignmentStartTimes[snapshot.agentId] = snapshot.timestamp
        }
        if snapshot.state == .finished || snapshot.state == .error {
            assignmentFinishTimes[snapshot.agentId] = snapshot.timestamp
        }
        if snapshot.state == .error || snapshot.state == .blocked {
            var errors = agentErrorMessages[snapshot.agentId] ?? []
            errors.append(snapshot.message)
            agentErrorMessages[snapshot.agentId] = errors
        }

        agentStatusSnapshots[snapshot.agentId] = snapshot
        let event = AgentTimelineEvent(
            agentId: snapshot.agentId,
            agentType: snapshot.agentType,
            state: snapshot.state,
            message: snapshot.message,
            timestamp: snapshot.timestamp
        )
        agentTimelineEvents.insert(event, at: 0)
        if agentTimelineEvents.count > 100 {
            agentTimelineEvents.removeLast(agentTimelineEvents.count - 100)
        }
    }

    func handleAgentEvent(_ event: AgentEvent) {
        if event.kind == .storyStarted, let storyId = event.storyId {
            recordStoryStart(agentId: event.agentId, storyId: storyId, timestamp: event.timestamp)
        }
        if event.kind == .storyCompleted, let storyId = event.storyId {
            var stories = agentCompletedStories[event.agentId] ?? []
            stories.insert(storyId)
            agentCompletedStories[event.agentId] = stories
            completeStory(agentId: event.agentId, storyId: storyId, completedAt: event.timestamp)
        }
        if event.kind == .blocked || event.kind == .needsHelp {
            var errors = agentErrorMessages[event.agentId] ?? []
            errors.append(event.message)
            agentErrorMessages[event.agentId] = errors
        }

        let state: AgentRunState
        switch event.kind {
        case .storyStarted, .fileModified:
            state = .working
        case .storyCompleted:
            state = .finished
        case .blocked:
            state = .blocked
        case .needsHelp:
            state = .needsInput
        }

        let timelineEvent = AgentTimelineEvent(
            agentId: event.agentId,
            agentType: event.agentType,
            state: state,
            message: event.message,
            timestamp: event.timestamp
        )

        agentTimelineEvents.insert(timelineEvent, at: 0)
        if agentTimelineEvents.count > 100 {
            agentTimelineEvents.removeLast(agentTimelineEvents.count - 100)
        }
    }

    func setOrchestrationRepoPath(_ url: URL) {
        orchestrationRepoPath = url
    }

    func setActivePRD(url: URL?, name: String?) {
        activePRDURL = url
        activePRDName = name
    }

    func clearPendingPRDURL() {
        pendingPRDURL = nil
    }

    func presentConflicts(from result: MergeResult, repoPath: URL) {
        orchestrationRepoPath = repoPath
        unresolvedConflicts = result.conflicts
        conflictFiles = result.conflicts.flatMap(\.files)
        selectedConflictFile = conflictFiles.first
        isConflictSheetPresented = !conflictFiles.isEmpty
    }

    func keepOurs(for file: String) async {
        await resolveConflict(file: file, keepOurs: true)
    }

    func keepTheirs(for file: String) async {
        await resolveConflict(file: file, keepOurs: false)
    }

    func markResolved(file: String) async {
        guard let repo = orchestrationRepoPath else { return }
        do {
            try await services.gitService.stageFile(repoPath: repo.path, file: file)
            await MainActor.run {
                self.removeConflict(file: file)
            }
        } catch {
            setError(.processError("Failed to mark resolved: \(error.localizedDescription)"))
        }
    }

    func abortMerge() async {
        guard let repo = orchestrationRepoPath else { return }
        do {
            try await services.gitService.abortMerge(repoPath: repo.path)
            try await services.gitService.resetHard(repoPath: repo.path)
            await MainActor.run {
                self.clearConflicts()
            }
        } catch {
            setError(.processError("Failed to abort merge: \(error.localizedDescription)"))
        }
    }

    func dismissConflictSheet() {
        clearConflicts()
    }

    private func resolveConflict(file: String, keepOurs: Bool) async {
        guard let repo = orchestrationRepoPath else { return }
        do {
            try await services.gitService.resolveConflict(
                repoPath: repo.path,
                file: file,
                keepOurs: keepOurs
            )
            try await services.gitService.stageFile(repoPath: repo.path, file: file)
            await MainActor.run {
                self.removeConflict(file: file)
            }
        } catch {
            setError(.processError("Failed to resolve conflict for \(file): \(error.localizedDescription)"))
        }
    }

    private func removeConflict(file: String) {
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

    private func clearConflicts() {
        conflictFiles.removeAll()
        unresolvedConflicts.removeAll()
        selectedConflictFile = nil
        isConflictSheetPresented = false
    }

    private func syncNotesBack(result: MergeResult, repoPath: URL) throws {
        guard let plan = mergePlan else { return }
        for branch in result.mergedBranches {
            guard let assignment = plan.steps.first(where: { $0.assignment.branchName == branch })?.assignment else {
                continue
            }
            try services.notesSyncService.syncNotesBack(repoPath: repoPath, assignment: assignment)
        }
    }

    /// Clears all logs
    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Error Handling

    /// Sets the current error
    func setError(_ error: AppError) {
        self.error = error
    }

    /// Clears the current error
    func clearError() {
        self.error = nil
    }

    // MARK: - MCP Log Streaming

    /// Starts the MCP server and begins streaming logs
    /// Logs are automatically added to the logs array as they arrive
    func startLogStreaming() async {
        guard !isStreamingLogs else { return }

        isStreamingLogs = true
        addLog(LogEntry(level: .info, source: "system", worktree: "", message: "Starting MCP connection..."))

        let mcpClient = services.mcpClient

        // Start MCP server if not running
        do {
            let isRunning = await mcpClient.serverIsRunning
            if !isRunning {
                try await mcpClient.start()
            }

            // Update connection status
            mcpConnectionStatus = await mcpClient.status
            addLog(LogEntry(level: .info, source: "mcp", worktree: "", message: "MCP server connected"))

        } catch {
            mcpConnectionStatus = .error(error.localizedDescription)
            isStreamingLogs = false
            addLog(LogEntry(level: .error, source: "mcp", worktree: "", message: "Failed to start MCP: \(error.localizedDescription)"))
            return
        }

        // Start consuming the log stream
        logStreamTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await mcpClient.logStream()

            for await logEntry in stream {
                // Check for cancellation
                guard !Task.isCancelled else { break }

                // Add log on main actor
                await MainActor.run {
                    self.addLog(logEntry)
                }
            }

            // Stream ended
            await MainActor.run {
                self.isStreamingLogs = false
            }
        }
    }

    /// Stops log streaming and disconnects from MCP
    func stopLogStreaming() async {
        guard isStreamingLogs else { return }

        addLog(LogEntry(level: .info, source: "system", worktree: "", message: "Stopping MCP connection..."))

        let mcpClient = services.mcpClient

        // Cancel the stream task
        logStreamTask?.cancel()
        logStreamTask = nil

        // Stop the MCP log stream
        await mcpClient.stopLogStream()

        // Stop the MCP server
        await mcpClient.stop()

        // Update state
        mcpConnectionStatus = .disconnected
        isStreamingLogs = false

        addLog(LogEntry(level: .info, source: "mcp", worktree: "", message: "MCP server disconnected"))
    }

    /// Refreshes the MCP connection status
    func refreshMCPStatus() async {
        mcpConnectionStatus = await services.mcpClient.status
    }

    // MARK: - Agent Status Monitoring

    func startAgentStatusMonitoring(sessionID: UUID, assignments: [TaskAssignment]) {
        agentStatusTask?.cancel()
        registerAssignments(assignments)

        agentStatusTask = Task { [weak self] in
            guard let self else { return }
            let stream = await statusMonitor.monitor(sessionID: sessionID, assignments: assignments)
            for await snapshot in stream {
                await MainActor.run {
                    self.handleAgentStatusSnapshot(snapshot)
                }
            }
        }

        startHealthMonitorLoop()
    }

    func stopAgentStatusMonitoring() {
        agentStatusTask?.cancel()
        agentStatusTask = nil
        healthMonitorTask?.cancel()
        healthMonitorTask = nil
    }

    func startAgentEventStream() {
        guard agentEventTask == nil else { return }
        agentEventTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.services.agentEventBus.subscribe(agentId: "dashboard-\(UUID().uuidString)")
            for await event in stream {
                await MainActor.run {
                    self.handleAgentEvent(event)
                }
            }
        }
    }

    func stopAgentEventStream() {
        agentEventTask?.cancel()
        agentEventTask = nil
    }

    // MARK: - Merge Coordination

    func prepareMergePlan(assignments: [WorktreeAssignment], repoPath: URL, baseBranch: String? = nil) async {
        orchestrationRepoPath = repoPath
        do {
            mergePlan = try await services.mergeCoordinator.prepareMerge(
                assignments: assignments,
                repoPath: repoPath,
                baseBranch: baseBranch
            )
            mergeResult = nil
            try assignments.forEach { assignment in
                try services.notesSyncService.syncNotesToWorktree(repoPath: repoPath, assignment: assignment)
            }
        } catch {
            setError(.processError("Failed to prepare merge plan: \(error.localizedDescription)"))
        }
    }

    func executeMergePlan(repoPath: URL) async {
        guard let plan = mergePlan else { return }
        do {
            mergeResult = try await services.mergeCoordinator.executeMerge(plan: plan, repoPath: repoPath)
            if let result = mergeResult, !result.conflicts.isEmpty {
                presentConflicts(from: result, repoPath: repoPath)
            } else if let result = mergeResult {
                try syncNotesBack(result: result, repoPath: repoPath)
                let record = buildOrchestrationRecord(plan: plan, result: result)
                await services.historyService.append(record: record)
                historyRecords.insert(record, at: 0)
            }
        } catch {
            setError(.processError("Failed to execute merge plan: \(error.localizedDescription)"))
        }
    }

    private func buildOrchestrationRecord(plan: MergePlan, result: MergeResult) -> OrchestrationRecord {
        let finishedAt = Date()
        let metrics = makeAgentMetrics(completedAt: finishedAt)
        let totalStories = metrics.reduce(0) { $0 + $1.storiesTotal }
        let completedStories = metrics.reduce(0) { $0 + $1.storiesCompleted }
        let errors = metrics.flatMap(\.errors)

        return OrchestrationRecord(
            id: UUID(),
            startedAt: plan.createdAt,
            finishedAt: finishedAt,
            prdName: activePRDName ?? plan.baseBranch,
            prdPath: activePRDURL?.path,
            resultSummary: result.success ? "Merged" : (result.conflicts.isEmpty ? "Partial" : "Conflicts"),
            mergedBranches: result.mergedBranches,
            conflicts: result.conflicts.flatMap(\.files),
            totalStories: totalStories,
            completedStories: completedStories,
            agentMetrics: metrics,
            errors: errors
        )
    }

    private func makeAgentMetrics(completedAt: Date) -> [AgentRunMetric] {
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

    func loadHistory() async {
        let records = await services.historyService.load()
        await MainActor.run {
            self.historyRecords = records
        }
    }

    // MARK: - Orchestration Control

    /// Starts a full orchestration from a PRD document
    /// - Parameters:
    ///   - document: The parsed PRD document
    ///   - repoPath: Path to the git repository
    func startOrchestration(document: PRDDocument, repoPath: URL) async {
        guard !isOrchestrating else {
            addLog(LogEntry(level: .warn, source: "orchestrator", worktree: nil, message: "Orchestration already in progress"))
            return
        }

        let sessionID = UUID()
        orchestrationSessionID = sessionID
        orchestrationRepoPath = repoPath
        orchestrationState = .analyzing

        addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Starting orchestration for: \(document.featureName)"))

        do {
            // Step 1: Analyze PRD and create task groups
            let analysis = try await services.orchestrator.analyzePRD(document)
            orchestrationState = .distributing

            addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Created \(analysis.taskGroups.count) task groups"))

            // Step 2: Create worktrees for each task group
            let worktreeAssignments = try await services.orchestrator.createWorktrees(for: analysis, repoPath: repoPath)
            activeWorktreeAssignments = worktreeAssignments

            addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Created \(worktreeAssignments.count) worktrees"))

            // Step 3: Get task assignments
            let taskAssignments = try await services.orchestrator.assignTasks(for: worktreeAssignments)

            // Step 4: Register assignments for monitoring
            registerAssignments(taskAssignments)

            // Step 5: Launch agents in each worktree
            orchestrationState = .monitoring
            var sessions: [AgentSession] = []

            for assignment in worktreeAssignments {
                let instructions = buildAgentInstructions(for: assignment, prd: document)

                do {
                    let session = try await services.agentLauncher.launchAgent(
                        assignment: assignment,
                        prd: document,
                        sessionID: sessionID,
                        instructions: instructions,
                        onOutput: { [weak self] output in
                            Task { @MainActor in
                                self?.addLog(LogEntry(
                                    level: .debug,
                                    source: assignment.agentType.rawValue,
                                    worktree: assignment.worktreePath.path,
                                    message: output
                                ))
                            }
                        }
                    )
                    sessions.append(session)

                    addLog(LogEntry(
                        level: .info,
                        source: "orchestrator",
                        worktree: assignment.worktreePath.path,
                        message: "Launched \(assignment.agentType.displayName) for stories: \(assignment.taskGroup.storyIds.joined(separator: ", "))"
                    ))

                    // Publish agent started event
                    await services.agentEventBus.publish(event: AgentEvent(
                        agentId: assignment.id.uuidString,
                        agentType: assignment.agentType,
                        kind: .storyStarted,
                        storyId: assignment.taskGroup.storyIds.first,
                        filePath: nil,
                        message: "Agent started in \(assignment.branchName)"
                    ))
                } catch {
                    addLog(LogEntry(
                        level: .error,
                        source: "orchestrator",
                        worktree: assignment.worktreePath.path,
                        message: "Failed to launch \(assignment.agentType.displayName): \(error.localizedDescription)"
                    ))
                }
            }

            activeAgentSessions = sessions

            // Step 6: Start monitoring
            startAgentStatusMonitoring(sessionID: sessionID, assignments: taskAssignments)
            startAgentEventStream()

            // Setup orchestrator notification for blocked agents
            await services.agentEventBus.setOrchestratorHandler { [weak self] event in
                await MainActor.run {
                    self?.handleBlockedAgent(event: event)
                }
            }

            addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Orchestration monitoring started with \(sessions.count) agents"))

        } catch {
            orchestrationState = .error(message: error.localizedDescription)
            setError(.processError("Orchestration failed: \(error.localizedDescription)"))
            addLog(LogEntry(level: .error, source: "orchestrator", worktree: nil, message: "Orchestration failed: \(error.localizedDescription)"))
        }
    }

    /// Stops the current orchestration
    func stopOrchestration() async {
        guard isOrchestrating else { return }

        addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Stopping orchestration..."))

        // Stop monitoring
        stopAgentStatusMonitoring()
        stopAgentEventStream()

        // Stop all agent processes
        for session in activeAgentSessions {
            do {
                try await services.processRunner.terminate(id: session.processId)
            } catch {
                addLog(LogEntry(level: .debug, source: "orchestrator", worktree: nil, message: "Process \(session.processId) already terminated"))
            }
        }

        // Clear state
        activeAgentSessions.removeAll()
        orchestrationState = .idle
        orchestrationSessionID = nil

        addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Orchestration stopped"))
    }

    /// Triggers merge coordination after all agents complete
    func completeOrchestration() async {
        guard isOrchestrating, !activeWorktreeAssignments.isEmpty else { return }

        orchestrationState = .merging
        addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Starting merge coordination..."))

        guard let repoPath = orchestrationRepoPath else {
            setError(.processError("No repository path set for merge"))
            return
        }

        do {
            let result = try await services.orchestrator.coordinateMerge(for: activeWorktreeAssignments)
            mergeResult = result

            if result.conflicts.isEmpty {
                orchestrationState = .complete
                addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Orchestration complete! Merged \(result.mergedBranches.count) branches"))

                // Save to history
                if let plan = mergePlan {
                    let record = buildOrchestrationRecord(plan: plan, result: result)
                    await services.historyService.append(record: record)
                    historyRecords.insert(record, at: 0)
                }
            } else {
                presentConflicts(from: result, repoPath: repoPath)
                addLog(LogEntry(level: .warn, source: "orchestrator", worktree: nil, message: "Merge conflicts detected in \(result.conflicts.count) files"))
            }
        } catch {
            orchestrationState = .error(message: error.localizedDescription)
            setError(.processError("Merge coordination failed: \(error.localizedDescription)"))
        }
    }

    /// Handles notification when an agent becomes blocked
    private func handleBlockedAgent(event: AgentEvent) {
        addLog(LogEntry(
            level: .warn,
            source: "orchestrator",
            worktree: nil,
            message: "Agent \(event.agentType?.displayName ?? event.agentId) blocked: \(event.message)"
        ))
        // The health monitoring will pick this up and show UI
    }

    /// Builds instructions for an agent based on its assignment
    private func buildAgentInstructions(for assignment: WorktreeAssignment, prd: PRDDocument) -> String {
        let storyIds = assignment.taskGroup.storyIds
        let stories = prd.userStories.filter { storyIds.contains($0.id) }

        var instructions = """
        You are working on feature: \(prd.featureName)
        Branch: \(assignment.branchName)

        Your assigned stories:
        """

        for story in stories {
            instructions += """

            ## \(story.id) - \(story.title)
            Priority: \(story.priority.rawValue)
            \(story.description)
            """
        }

        instructions += """

        Instructions:
        1. Implement each story according to its description
        2. Use MCP emit_log to report progress
        3. Write notes to notes/decisions.md for important decisions
        4. Commit your changes when each story is complete
        5. Report completion via MCP update_status when finished
        """

        return instructions
    }

    // MARK: - Health Monitoring Helpers

    private func recordStoryStart(agentId: String, storyId: String, timestamp: Date) {
        var stories = storyStartTimestamps[agentId] ?? [:]
        stories[storyId] = timestamp
        storyStartTimestamps[agentId] = stories
    }

    private func completeStory(agentId: String, storyId: String, completedAt: Date) {
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

    private func startHealthMonitorLoop() {
        healthMonitorTask?.cancel()
        healthMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
                await MainActor.run {
                    self.evaluateAgentHealthTimers()
                }
            }
        }
    }

    private func evaluateAgentHealthTimers() {
        let now = Date()
        for (agentId, lastUpdate) in lastStatusTimestamps {
            guard now.timeIntervalSince(lastUpdate) >= nonResponsiveThreshold else { continue }
            let agentType = agentAssignments[agentId]?.agentType
            if let issue = recordHealthIssue(
                agentId: agentId,
                agentType: agentType,
                type: .nonResponsive,
                message: "No status update for over 2 minutes."
            ) {
                incrementHealthMetric(for: agentId, type: .nonResponsive)
                logHealthIssue(issue)
            }
        }
    }

    private func evaluateRepeatedMessage(for snapshot: AgentStatusSnapshot) {
        let trimmed = snapshot.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            repeatedMessageTracker[snapshot.agentId] = nil
            resolveHealthIssue(for: snapshot.agentId, type: .repeatedMessage)
            return
        }

        var tracker = repeatedMessageTracker[snapshot.agentId] ?? (message: trimmed, count: 0)
        if tracker.message == trimmed {
            tracker.count += 1
        } else {
            tracker = (trimmed, 1)
            resolveHealthIssue(for: snapshot.agentId, type: .repeatedMessage)
        }
        repeatedMessageTracker[snapshot.agentId] = tracker

        if tracker.count >= repeatedMessageThreshold, tracker.count % repeatedMessageThreshold == 0 {
            let agentType = snapshot.agentType ?? agentAssignments[snapshot.agentId]?.agentType
            if let issue = recordHealthIssue(
                agentId: snapshot.agentId,
                agentType: agentType,
                type: .repeatedMessage,
                message: "Status repeated \(tracker.count)x: \(trimmed)"
            ) {
                incrementHealthMetric(for: snapshot.agentId, type: .repeatedMessage)
                logHealthIssue(issue)
            }
        }
    }

    @discardableResult
    private func recordHealthIssue(
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

    private func resolveHealthIssue(for agentId: String, type: AgentHealthIssueType) {
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

    private func displayHealthIssue(_ issue: AgentHealthIssue) {
        if presentedHealthIssue?.id == issue.id {
            presentedHealthIssue = issue
        } else if presentedHealthIssue == nil {
            presentedHealthIssue = issue
        } else if !healthAlertQueue.contains(where: { $0.id == issue.id }) {
            healthAlertQueue.append(issue)
        }
    }

    private func dequeueNextHealthIssue() {
        while !healthAlertQueue.isEmpty {
            let next = healthAlertQueue.removeFirst()
            if let index = agentHealthIssues.firstIndex(where: { $0.id == next.id && $0.state == .active }) {
                presentedHealthIssue = agentHealthIssues[index]
                return
            }
        }
    }

    private func incrementHealthMetric(for agentId: String, type: AgentHealthIssueType) {
        guard var metrics = agentHealthMetrics[agentId] else { return }
        switch type {
        case .nonResponsive:
            metrics.nonResponsiveHits += 1
        case .repeatedMessage:
            metrics.repeatedMessageHits += 1
        }
        agentHealthMetrics[agentId] = metrics
    }

    private func logHealthIssue(_ issue: AgentHealthIssue) {
        let agentName = issue.agentType?.displayName ?? String(issue.agentId.prefix(6))
        addLog(
            LogEntry(
                level: .warn,
                source: "health",
                worktree: nil,
                message: "[\(issue.type.rawValue)] \(agentName): \(issue.message)"
            )
        )
        Task {
            await services.agentEventBus.publish(
                event: AgentEvent(
                    agentId: issue.agentId,
                    agentType: issue.agentType,
                    kind: .needsHelp,
                    storyId: nil,
                    filePath: nil,
                    message: issue.message
                )
            )
        }
    }

    func handleHealthAction(_ action: AgentHealthAction) {
        guard var issue = presentedHealthIssue else { return }
        logUserHealthAction(action, issue: issue)

        switch action {
        case .wait:
            issue.state = .snoozed
            issue.snoozedUntil = Date().addingTimeInterval(nonResponsiveThreshold)
            updateStoredIssue(issue)
        case .restart, .reassign, .abort:
            issue.state = .resolved
            issue.snoozedUntil = nil
            updateStoredIssue(issue)
        }

        presentedHealthIssue = nil
        dequeueNextHealthIssue()
    }

    private func updateStoredIssue(_ issue: AgentHealthIssue) {
        if let index = agentHealthIssues.firstIndex(where: { $0.id == issue.id }) {
            agentHealthIssues[index] = issue
        }
    }

    private func logUserHealthAction(_ action: AgentHealthAction, issue: AgentHealthIssue) {
        let agentName = issue.agentType?.displayName ?? String(issue.agentId.prefix(6))
        let actionLabel = action.rawValue.capitalized
        addLog(
            LogEntry(
                level: .info,
                source: "health",
                worktree: nil,
                message: "User selected \(actionLabel) for \(agentName)."
            )
        )
        Task {
            await services.agentEventBus.publish(
                event: AgentEvent(
                    agentId: issue.agentId,
                    agentType: issue.agentType,
                    kind: .needsHelp,
                    storyId: nil,
                    filePath: nil,
                    message: "User action: \(actionLabel)"
                )
            )
        }
    }
}

// MARK: - AppError

/// Application-level errors for user display
enum AppError: Error, LocalizedError, Identifiable {
    case gitError(String)
    case processError(String)
    case mcpError(String)
    case worktreeCreationFailed(String)
    case agentLaunchFailed(String)
    case unknown(String)

    var id: String {
        localizedDescription
    }

    var errorDescription: String? {
        switch self {
        case .gitError(let message):
            return "Git Error: \(message)"
        case .processError(let message):
            return "Process Error: \(message)"
        case .mcpError(let message):
            return "MCP Error: \(message)"
        case .worktreeCreationFailed(let message):
            return "Failed to create worktree: \(message)"
        case .agentLaunchFailed(let message):
            return "Failed to launch agent: \(message)"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Environment Key

/// Environment key for accessing AppState
private struct AppStateKey: EnvironmentKey {
    @MainActor static var defaultValue: AppState = AppState()
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
