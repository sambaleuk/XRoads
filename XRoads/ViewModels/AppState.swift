import Foundation
import SwiftUI

// MARK: - AppState

/// Global application state using @Observable for better SwiftUI performance
/// This class manages all shared state and provides access to services
@MainActor
@Observable
final class AppState {

    // MARK: - Weak Reference Wrapper

    private final class WeakAppStateRef: @unchecked Sendable {
        weak var value: AppState?

        init(_ value: AppState) {
            self.value = value
        }
    }

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

    /// Current project/repository path for Git Dashboard
    var projectPath: String?

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

    // MARK: - Dashboard v3 State

    /// Current dashboard display mode (Single/Agentic)
    var dashboardMode: DashboardMode = .agentic

    /// Terminal slots for the hexagonal dashboard (6 slots)
    var terminalSlots: [TerminalSlot] = (1...6).map { TerminalSlot(slotNumber: $0) }

    /// Visual state of the central orchestrator creature
    var orchestratorVisualState: OrchestratorVisualState = .sleeping

    /// Available MCP tools for checking skill dependencies (US-V4-018)
    var availableMCPTools: Set<String> = Set(["git", "file-read", "file-edit", "bash", "web-search"])

    /// Recent git commits for the right side panel
    var recentCommits: [GitCommit] = []

    /// Whether the current project path is a git repository
    var isGitRepository: Bool = false

    /// Whether git initialization is in progress
    var isInitializingGit: Bool = false

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

    // MARK: - Dispatch Progress State (LayeredDispatcher)

    /// Current dispatch phase
    var dispatchPhase: DispatchPhase = .idle

    /// Dispatch progress info
    var dispatchProgress: DispatchProgress?

    /// Current dispatch message
    var dispatchMessage: String = ""

    /// Global logs from all dispatch sources (Phase 2)
    var globalLogs: [LogEntry] = []

    /// Whether a layered dispatch is active
    var isDispatching: Bool {
        switch dispatchPhase {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }

    /// PRD being dispatched
    var currentPRD: PRDDocument?

    /// Current layer being executed
    var currentDispatchLayer: Int = 0

    /// Total layers in dispatch
    var totalDispatchLayers: Int = 0

    // MARK: - GitMaster State

    /// State of the GitMaster intelligent resolver
    var gitMasterState: GitMasterState = GitMasterState()

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

    /// Whether the dashboard should display the animated agentic pulse
    var isAgenticPulseActive: Bool {
        dashboardMode == .agentic && isOrchestrating
    }

    // MARK: - Dashboard v3 Computed Properties

    /// Active terminal slots (slots that are currently running)
    var activeSlots: [TerminalSlot] {
        terminalSlots.filter { $0.status.isActive }
    }

    /// Configured terminal slots (slots with worktree and agent assigned)
    var configuredSlots: [TerminalSlot] {
        terminalSlots.filter { $0.isConfigured }
    }

    /// Angles of active slots for orchestrator visualization
    var activeSlotAngles: [Double] {
        activeSlots.map { $0.positionAngle }
    }

    /// Global progress across all configured terminal slots
    var terminalSlotsProgress: Double {
        let configured = configuredSlots
        guard !configured.isEmpty else { return 0 }
        let totalProgress = configured.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(configured.count)
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

    // MARK: - Dashboard v3 Slot Management

    /// Configures a terminal slot with a worktree and agent type
    func configureSlot(_ slotNumber: Int, worktree: Worktree, agentType: AgentType) {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }
        terminalSlots[index].worktree = worktree
        terminalSlots[index].agentType = agentType
        terminalSlots[index].status = .ready
        updateOrchestratorVisualState()
    }

    /// Starts the agent in a terminal slot
    func startSlot(_ slotNumber: Int) async {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }
        guard terminalSlots[index].isConfigured else { return }

        terminalSlots[index].status = .starting
        updateOrchestratorVisualState()

        guard let worktree = terminalSlots[index].worktree,
              let agentType = terminalSlots[index].agentType else { return }

        let adapter = agentType.adapter()
        guard adapter.isAvailable() else {
            terminalSlots[index].status = .error
            terminalSlots[index].addLog(LogEntry(
                level: .error,
                source: agentType.rawValue,
                worktree: worktree.path,
                message: "CLI not found at \(adapter.executablePath)"
            ))
            updateOrchestratorVisualState()
            return
        }

        do {
            let slotIndex = index
            // Use PTYProcessRunner for proper terminal emulation
            // This is required for interactive CLIs like Claude Code, Gemini CLI, Codex
            let processId = try await services.ptyRunner.launch(
                executable: adapter.executablePath,
                arguments: adapter.launchArguments(worktreePath: worktree.path),
                workingDirectory: worktree.path,
                environment: nil as [String: String]?,
                onOutput: { [weak self] (output: String) in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        let entry = LogEntry(
                            level: .debug,
                            source: agentType.rawValue,
                            worktree: worktree.path,
                            message: output
                        )
                        self.terminalSlots[slotIndex].addLog(entry)
                        self.addLog(entry)
                    }
                },
                onTermination: { [weak self] (exitCode: Int32) in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.terminalSlots[slotIndex].status = exitCode == 0 ? .completed : .error
                        self.terminalSlots[slotIndex].addLog(LogEntry(
                            level: exitCode == 0 ? .info : .error,
                            source: agentType.rawValue,
                            worktree: worktree.path,
                            message: "Agent exited with code \(exitCode)"
                        ))
                        self.updateOrchestratorVisualState()
                    }
                }
            )

            terminalSlots[index].processId = processId
            terminalSlots[index].status = .running
            terminalSlots[index].addLog(LogEntry(
                level: .info,
                source: agentType.rawValue,
                worktree: worktree.path,
                message: "Agent started with PTY"
            ))
            updateOrchestratorVisualState()

        } catch {
            terminalSlots[index].status = .error
            terminalSlots[index].addLog(LogEntry(
                level: .error,
                source: agentType.rawValue,
                worktree: worktree.path,
                message: "Failed to start: \(error.localizedDescription)"
            ))
            updateOrchestratorVisualState()
        }
    }

    /// Stops the agent in a terminal slot
    func stopSlot(_ slotNumber: Int) async {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }
        guard let processId = terminalSlots[index].processId else {
            terminalSlots[index].status = .ready
            return
        }

        do {
            try await services.ptyRunner.terminate(id: processId)
        } catch {
            // Process may already be terminated
        }

        terminalSlots[index].processId = nil
        terminalSlots[index].status = .ready
        terminalSlots[index].progress = 0
        terminalSlots[index].currentTask = nil
        terminalSlots[index].addLog(LogEntry(
            level: .info,
            source: terminalSlots[index].agentType?.rawValue ?? "system",
            worktree: terminalSlots[index].worktree?.path,
            message: "Agent stopped"
        ))
        updateOrchestratorVisualState()
    }

    /// Resets a terminal slot to empty state
    func resetSlot(_ slotNumber: Int) async {
        await stopSlot(slotNumber)
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }
        terminalSlots[index].reset()
        updateOrchestratorVisualState()
    }

    /// Gets logs for a specific terminal slot
    func logsForSlot(_ slot: TerminalSlot) -> [LogEntry] {
        slot.logs
    }

    /// Append output to a terminal slot's log buffer
    /// - Parameters:
    ///   - slotNumber: The slot number (1-6)
    ///   - output: The output string to append
    func appendSlotOutput(slotNumber: Int, output: String) {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else {
            return
        }

        let logEntry = LogEntry(
            level: .info,
            source: terminalSlots[index].agentType?.rawValue ?? "agent",
            worktree: terminalSlots[index].worktree?.path,
            message: output
        )

        terminalSlots[index].logs.append(logEntry)

        // Also add to global logs
        globalLogs.append(logEntry)
    }

    /// Handle slot termination - update status when a loop finishes
    /// - Parameters:
    ///   - slotNumber: The slot number (1-6)
    ///   - exitCode: The process exit code (0 = success)
    func handleSlotTermination(slotNumber: Int, exitCode: Int32) {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else {
            return
        }

        // Update slot status based on exit code
        if exitCode == 0 {
            terminalSlots[index].status = .completed
            terminalSlots[index].addLog(LogEntry(
                level: .info,
                source: "system",
                worktree: terminalSlots[index].worktree?.path,
                message: "✅ Loop completed successfully"
            ))
        } else {
            terminalSlots[index].status = .error
            terminalSlots[index].addLog(LogEntry(
                level: .error,
                source: "system",
                worktree: terminalSlots[index].worktree?.path,
                message: "❌ Loop failed with exit code \(exitCode)"
            ))
        }

        // Clear process ID
        terminalSlots[index].processId = nil

        // Add to global logs
        let status = exitCode == 0 ? "completed" : "failed (code \(exitCode))"
        addLog(LogEntry(
            level: exitCode == 0 ? .info : .error,
            source: "slot-\(slotNumber)",
            worktree: terminalSlots[index].worktree?.path,
            message: "Loop \(status)"
        ))

        // Update orchestrator visual state if no more running slots
        updateOrchestratorStateAfterTermination()
    }

    /// Update orchestrator visual state after a slot terminates
    private func updateOrchestratorStateAfterTermination() {
        let runningSlots = terminalSlots.filter { $0.status == .running }
        let completedSlots = terminalSlots.filter { $0.status == .completed }
        let failedSlots = terminalSlots.filter { $0.status == .error }
        let configuredSlots = terminalSlots.filter { $0.isConfigured }

        if runningSlots.isEmpty {
            if !failedSlots.isEmpty {
                // Some slots failed
                orchestratorVisualState = .concerned
            } else if completedSlots.count == configuredSlots.count && !configuredSlots.isEmpty {
                // All configured slots completed successfully
                orchestratorVisualState = .celebrating
                // Reset to idle after celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.orchestratorVisualState = .idle
                }
            } else {
                // No running, no failures, not all complete - idle
                orchestratorVisualState = .idle
            }
        }
        // If still running, keep current state (monitoring/distributing)
    }

    // MARK: - Input Bridge (US-V3-013)

    /// Sends input to a terminal slot's process stdin
    /// - Parameters:
    ///   - slotNumber: The slot number (1-6)
    ///   - text: The text to send to stdin
    /// - Returns: true if input was sent successfully, false otherwise
    @discardableResult
    func sendInputToSlot(_ slotNumber: Int, text: String) async -> Bool {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else {
            addLog(LogEntry(level: .error, source: "system", worktree: nil, message: "Slot \(slotNumber) not found"))
            return false
        }

        guard let processId = terminalSlots[index].processId else {
            addLog(LogEntry(level: .warn, source: "system", worktree: terminalSlots[index].worktree?.path, message: "No process running in slot \(slotNumber)"))
            return false
        }

        do {
            try await services.ptyRunner.sendInput(id: processId, text: text)

            // Echo input in terminal output
            let echoEntry = LogEntry(
                level: .info,
                source: "user",
                worktree: terminalSlots[index].worktree?.path,
                message: "▶ \(text)"
            )
            terminalSlots[index].addLog(echoEntry)
            addLog(echoEntry)

            // Add to input history
            terminalSlots[index].addInput(text)

            // If slot was waiting for input, transition back to running
            if terminalSlots[index].status == .waitingForInput || terminalSlots[index].status == .needsInput {
                terminalSlots[index].status = .running
            }

            return true
        } catch {
            let errorEntry = LogEntry(
                level: .error,
                source: "system",
                worktree: terminalSlots[index].worktree?.path,
                message: "Failed to send input: \(error.localizedDescription)"
            )
            terminalSlots[index].addLog(errorEntry)
            addLog(errorEntry)
            return false
        }
    }

    /// Sends input to a worktree's running process
    /// - Parameters:
    ///   - worktreeId: The worktree's UUID
    ///   - text: The text to send to stdin
    /// - Returns: true if input was sent successfully, false otherwise
    @discardableResult
    func sendInputToWorktree(_ worktreeId: UUID, text: String) async -> Bool {
        guard let processId = worktreeProcessIds[worktreeId] else {
            let worktreePath = worktrees.first { $0.id == worktreeId }?.path
            addLog(LogEntry(level: .warn, source: "system", worktree: worktreePath, message: "No process running for worktree"))
            return false
        }

        guard let worktree = worktrees.first(where: { $0.id == worktreeId }) else {
            addLog(LogEntry(level: .error, source: "system", worktree: nil, message: "Worktree not found"))
            return false
        }

        do {
            try await services.ptyRunner.sendInput(id: processId, text: text)

            // Echo input in terminal output
            let echoEntry = LogEntry(
                level: .info,
                source: "user",
                worktree: worktree.path,
                message: "▶ \(text)"
            )
            addLog(echoEntry)

            return true
        } catch {
            addLog(LogEntry(
                level: .error,
                source: "system",
                worktree: worktree.path,
                message: "Failed to send input: \(error.localizedDescription)"
            ))
            return false
        }
    }

    /// Gets the process ID for a terminal slot
    /// - Parameter slotNumber: The slot number (1-6)
    /// - Returns: The process UUID if a process is running, nil otherwise
    func processIdForSlot(_ slotNumber: Int) -> UUID? {
        terminalSlots.first { $0.slotNumber == slotNumber }?.processId
    }

    /// Checks if a terminal slot has a running process
    /// - Parameter slotNumber: The slot number (1-6)
    /// - Returns: true if a process is running in the slot
    func isProcessRunningInSlot(_ slotNumber: Int) async -> Bool {
        guard let processId = processIdForSlot(slotNumber) else { return false }
        return await services.ptyRunner.isRunning(id: processId)
    }

    /// Updates the orchestrator visual state based on slot states
    func updateOrchestratorVisualState() {
        let activeCount = activeSlots.count
        let configuredCount = configuredSlots.count
        let hasErrors = terminalSlots.contains { $0.status == .error }
        let hasNeedsInput = terminalSlots.contains { $0.status == .needsInput }
        let allCompleted = configuredCount > 0 && configuredSlots.allSatisfy { $0.status == .completed }

        if allCompleted {
            orchestratorVisualState = .celebrating
        } else if hasErrors || hasNeedsInput {
            orchestratorVisualState = .concerned
        } else if activeCount > 0 {
            orchestratorVisualState = .monitoring
        } else if configuredCount > 0 {
            orchestratorVisualState = .idle
        } else {
            orchestratorVisualState = .sleeping
        }
    }

    // MARK: - Unified Action Flow (US-V3-014)

    /// Shared ActionRunner instance for unified action execution
    /// Uses the shared ptyRunner from services for proper PTY-based process management
    @ObservationIgnored
    private var _actionRunner: ActionRunner?

    private var actionRunner: ActionRunner {
        if _actionRunner == nil {
            _actionRunner = ActionRunner(ptyRunner: services.ptyRunner)
        }
        return _actionRunner!
    }

    /// Executes an action in a terminal slot using ActionRunner
    /// Works identically for both Single and Agentic modes
    /// - Parameters:
    ///   - slotNumber: The slot number (1-6, or 1 for single mode)
    ///   - slot: The terminal slot configuration
    ///   - mode: The current dashboard mode
    func executeActionInSlot(_ slotNumber: Int, slot: TerminalSlot, mode: DashboardMode) async {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else {
            addLog(LogEntry(level: .error, source: "system", worktree: nil, message: "Slot \(slotNumber) not found"))
            return
        }

        guard let worktree = slot.worktree,
              let agentType = slot.agentType,
              let actionType = slot.actionType else {
            addLog(LogEntry(level: .error, source: "system", worktree: slot.worktree?.path, message: "Slot not fully configured"))
            terminalSlots[index].status = .error
            return
        }

        // Log the execution mode for traceability
        let modeDescription = mode == .single ? "Single mode (slot[0])" : "Agentic mode (slot[\(slotNumber)])"
        addLog(LogEntry(level: .info, source: "system", worktree: worktree.path, message: "Starting action via \(modeDescription)"))

        // Update slot status
        terminalSlots[index].status = .starting
        updateOrchestratorVisualState()

        // Build the action request - same structure for both modes
        let sessionID = UUID()
        let slotIndex = index

        // Create output handler that routes logs to the correct slot
        let outputHandler: ProcessRunner.OutputHandler = { [weak self] output in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let entry = LogEntry(
                    level: .debug,
                    source: agentType.rawValue,
                    worktree: worktree.path,
                    message: output
                )
                // Route log to the specific slot
                self.terminalSlots[slotIndex].addLog(entry)
                // Also add to global logs
                self.addLog(entry)
            }
        }

        do {
            // Use ActionRunner for unified execution
            // The run method works identically regardless of mode
            let request = ActionRunRequest(
                actionType: actionType,
                agentType: agentType,
                worktreePath: worktree.path,
                additionalSkillIDs: slot.loadedSkills.map { $0.id },
                sessionID: sessionID,
                prdPath: activePRDURL?.path,
                branchName: worktree.branch,
                assignedStories: [],
                taskDescription: actionType.description,
                coordinationNotes: mode == .agentic ? "Running in Agentic mode with other agents" : nil
            )

            let result = try await actionRunner.run(request: request, onOutput: outputHandler)

            // Update slot with process info
            terminalSlots[index].processId = result.processID
            terminalSlots[index].loadedSkills = result.loadedSkills
            terminalSlots[index].status = .running
            terminalSlots[index].currentTask = "Running \(actionType.displayName)..."
            terminalSlots[index].addLog(LogEntry(
                level: .info,
                source: agentType.rawValue,
                worktree: worktree.path,
                message: "Action started with \(result.loadedSkills.count) skills"
            ))

            updateOrchestratorVisualState()

        } catch {
            terminalSlots[index].status = .error
            terminalSlots[index].addLog(LogEntry(
                level: .error,
                source: agentType.rawValue,
                worktree: worktree.path,
                message: "Failed to start action: \(error.localizedDescription)"
            ))
            addLog(LogEntry(
                level: .error,
                source: "system",
                worktree: worktree.path,
                message: "Action execution failed: \(error.localizedDescription)"
            ))
            updateOrchestratorVisualState()
        }
    }

    /// Starts all configured slots in the current mode
    /// For single mode: starts slot[0] only
    /// For agentic mode: iterates all configured slots
    func startAllSlotsForMode(_ mode: DashboardMode) async {
        let slotsToStart: [TerminalSlot]

        switch mode {
        case .single:
            // Single mode only uses slot[0] (slotNumber 1)
            slotsToStart = terminalSlots.filter { $0.slotNumber == 1 && $0.isConfigured }
        case .agentic:
            // Agentic mode iterates all configured slots
            slotsToStart = terminalSlots.filter { $0.isConfigured }
        }

        for slot in slotsToStart {
            await executeActionInSlot(slot.slotNumber, slot: slot, mode: mode)
        }
    }

    /// Stops all active slots
    func stopAllSlots() async {
        for slot in activeSlots {
            await stopSlot(slot.slotNumber)
        }
    }

    // MARK: - PRD Dispatch to Slots (Manual Orchestration)

    /// Dispatches a PRD to manually configured slots using loop scripts
    /// Creates isolated git worktrees for each slot and manages dependencies
    /// - Parameters:
    ///   - prd: The full PRD document
    ///   - slotAssignments: Dictionary mapping slot numbers to story IDs
    ///   - repoPath: Path to the main git repository
    func dispatchPRDToSlots(
        prd: PRDDocument,
        slotAssignments: [Int: [String]],
        repoPath: URL? = nil
    ) async {
        guard !slotAssignments.isEmpty else {
            addLog(LogEntry(level: .warn, source: "orchestrator", worktree: nil, message: "No slot assignments provided"))
            return
        }

        // Use provided repo path or try to get from projectPath
        guard let mainRepoPath = repoPath ?? (projectPath.map { URL(fileURLWithPath: $0) }) else {
            addLog(LogEntry(level: .error, source: "orchestrator", worktree: nil, message: "No repository path configured"))
            return
        }

        orchestratorVisualState = .distributing
        addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Starting orchestration for \(prd.featureName) with \(slotAssignments.count) slots"))

        // Initialize status file for dependency tracking
        let sessionId = UUID()
        var statusFilePath: URL?
        do {
            statusFilePath = try await services.loopLauncher.initializeSession(
                repoPath: mainRepoPath,
                sessionId: sessionId,
                prd: prd
            )
            addLog(LogEntry(level: .info, source: "orchestrator", worktree: nil, message: "Status file created at \(statusFilePath?.path ?? "unknown")"))
        } catch {
            addLog(LogEntry(level: .warn, source: "orchestrator", worktree: nil, message: "Could not create status file: \(error.localizedDescription)"))
        }

        // Sort slots by dependency layer (slots with fewer dependencies first)
        let sortedSlots = slotAssignments.sorted { (a, b) in
            let aStories = prd.userStories.filter { a.value.contains($0.id) }
            let bStories = prd.userStories.filter { b.value.contains($0.id) }
            let aMaxDeps = aStories.map { $0.dependsOn.count }.max() ?? 0
            let bMaxDeps = bStories.map { $0.dependsOn.count }.max() ?? 0
            return aMaxDeps < bMaxDeps
        }

        for (slotNumber, storyIds) in sortedSlots {
            guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }),
                  let agentType = terminalSlots[index].agentType else {
                addLog(LogEntry(level: .error, source: "orchestrator", worktree: nil, message: "Slot \(slotNumber) has no agent configured"))
                continue
            }

            // Filter stories for this slot
            let assignedStories = prd.userStories.filter { storyIds.contains($0.id) }

            guard !assignedStories.isEmpty else {
                addLog(LogEntry(level: .warn, source: "orchestrator", worktree: nil, message: "No stories found for slot \(slotNumber)"))
                continue
            }

            // Generate branch name: agent/slot-N-story-ids
            let storyIdsSuffix = storyIds.prefix(2).joined(separator: "-").lowercased()
            let branchName = "xroads/slot-\(slotNumber)-\(agentType.rawValue)-\(storyIdsSuffix)"

            // Build loop configuration with worktree support
            let config = LoopConfiguration(
                slotNumber: slotNumber,
                agentType: agentType,
                repoPath: mainRepoPath,
                branchName: branchName,
                stories: assignedStories,
                fullPRD: prd,
                maxIterations: 15,
                sleepSeconds: 5,
                statusFilePath: statusFilePath
            )

            // Update slot status
            terminalSlots[index].status = .starting
            terminalSlots[index].currentTask = "Creating worktree for \(assignedStories.count) stories..."

            // Update slot's worktree info with the actual worktree path
            let worktreePath = config.worktreePath
            terminalSlots[index].worktree = Worktree(
                id: UUID(),
                path: worktreePath.path,
                branch: branchName,
                createdAt: Date()
            )

            do {
                let slotIndex = index
                let actualWorktreePath = worktreePath.path

                addLog(LogEntry(level: .info, source: "orchestrator", worktree: actualWorktreePath, message: "Creating worktree for slot \(slotNumber): \(branchName)"))

                let processId = try await services.loopLauncher.launchLoop(
                    config: config,
                    onOutput: { [weak self] (output: String) in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            let entry = LogEntry(
                                level: .debug,
                                source: agentType.rawValue,
                                worktree: actualWorktreePath,
                                message: output
                            )
                            self.terminalSlots[slotIndex].addLog(entry)
                            self.addLog(entry)
                        }
                    }
                )

                terminalSlots[index].processId = processId
                terminalSlots[index].status = .running
                terminalSlots[index].addLog(LogEntry(
                    level: .info,
                    source: agentType.rawValue,
                    worktree: actualWorktreePath,
                    message: "Loop started for stories: \(storyIds.joined(separator: ", "))"
                ))

                addLog(LogEntry(
                    level: .info,
                    source: "orchestrator",
                    worktree: actualWorktreePath,
                    message: "\(agentType.displayName) loop started on slot \(slotNumber) with \(assignedStories.count) stories in branch \(branchName)"
                ))

            } catch {
                terminalSlots[index].status = .error
                terminalSlots[index].addLog(LogEntry(
                    level: .error,
                    source: agentType.rawValue,
                    worktree: nil,
                    message: "Failed to start loop: \(error.localizedDescription)"
                ))
                addLog(LogEntry(
                    level: .error,
                    source: "orchestrator",
                    worktree: nil,
                    message: "Slot \(slotNumber) launch failed: \(error.localizedDescription)"
                ))
            }
        }

        updateOrchestratorVisualState()
    }

    /// Starts loops on all configured slots with their pre-assigned stories
    /// Requires that each slot has a worktree with a prd.json already in place
    func startLoopsOnConfiguredSlots() async {
        let slotsToStart = terminalSlots.filter { $0.isConfigured && $0.status == .ready }

        guard !slotsToStart.isEmpty else {
            addLog(LogEntry(level: .warn, source: "orchestrator", worktree: nil, message: "No configured slots ready to start"))
            return
        }

        orchestratorVisualState = .distributing

        for slot in slotsToStart {
            guard let worktree = slot.worktree,
                  let agentType = slot.agentType,
                  let index = terminalSlots.firstIndex(where: { $0.id == slot.id }) else {
                continue
            }

            // Check if prd.json exists in the worktree
            let prdPath = URL(fileURLWithPath: worktree.path).appendingPathComponent("prd.json")
            guard FileManager.default.fileExists(atPath: prdPath.path) else {
                terminalSlots[index].status = .error
                terminalSlots[index].addLog(LogEntry(
                    level: .error,
                    source: "system",
                    worktree: worktree.path,
                    message: "No prd.json found in worktree. Configure slot assignments first."
                ))
                continue
            }

            terminalSlots[index].status = .starting

            do {
                let slotIndex = index
                let loopScript = agentType.loopScriptName
                let scriptsDir = "/Users/birahimmbow/Projets/CrossRoads/scripts"
                let scriptPath = "\(scriptsDir)/\(loopScript)"

                var environment = ProcessInfo.processInfo.environment
                environment["CROSSROADS_SLOT"] = String(slot.slotNumber)
                environment["CROSSROADS_AGENT"] = agentType.rawValue

                let processId = try await services.ptyRunner.launch(
                    executable: scriptPath,
                    arguments: ["10", "3"],  // max_iterations, sleep_seconds
                    workingDirectory: worktree.path,
                    environment: environment,
                    onOutput: { [weak self] (output: String) in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            let entry = LogEntry(
                                level: .debug,
                                source: agentType.rawValue,
                                worktree: worktree.path,
                                message: output
                            )
                            self.terminalSlots[slotIndex].addLog(entry)
                            self.addLog(entry)
                        }
                    },
                    onTermination: { [weak self] (exitCode: Int32) in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.terminalSlots[slotIndex].status = exitCode == 0 ? .completed : .error
                            self.terminalSlots[slotIndex].addLog(LogEntry(
                                level: exitCode == 0 ? .info : .error,
                                source: agentType.rawValue,
                                worktree: worktree.path,
                                message: "Loop exited with code \(exitCode)"
                            ))
                            self.updateOrchestratorVisualState()
                        }
                    }
                )

                terminalSlots[index].processId = processId
                terminalSlots[index].status = .running
                terminalSlots[index].addLog(LogEntry(
                    level: .info,
                    source: agentType.rawValue,
                    worktree: worktree.path,
                    message: "\(loopScript) started"
                ))

            } catch {
                terminalSlots[index].status = .error
                terminalSlots[index].addLog(LogEntry(
                    level: .error,
                    source: agentType.rawValue,
                    worktree: worktree.path,
                    message: "Failed to start loop: \(error.localizedDescription)"
                ))
            }
        }

        updateOrchestratorVisualState()
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

    /// Running process IDs indexed by worktree ID
    private var worktreeProcessIds: [UUID: UUID] = [:]

    /// Starts an agent for a specific worktree
    func startAgentForWorktree(_ worktree: Worktree) async {
        guard var agent = agent(for: worktree) else {
            addLog(LogEntry(level: .error, source: "system", worktree: worktree.path, message: "No agent assigned to this worktree"))
            return
        }

        // Check if already running
        if let existingProcessId = worktreeProcessIds[worktree.id],
           await services.ptyRunner.isRunning(id: existingProcessId) {
            addLog(LogEntry(level: .warn, source: "system", worktree: worktree.path, message: "Agent already running"))
            return
        }

        // Emit to MCP: Agent starting
        await emitToMCP(level: .info, source: agent.type.rawValue, worktree: worktree.path, message: "Starting agent...")

        do {
            let adapter = agent.type.adapter()

            guard adapter.isAvailable() else {
                await emitToMCP(level: .error, source: agent.type.rawValue, worktree: worktree.path, message: "CLI not found at \(adapter.executablePath)")
                return
            }

            // Update agent status
            agent.status = .running
            setAgent(agent)

            // Update MCP status
            await updateMCPStatus(agent: agent.type.rawValue, worktree: worktree.path, status: .running, task: "Initializing")

            // Launch the process with PTY for proper terminal emulation
            let agentType = agent.type
            let worktreePath = worktree.path
            let processId = try await services.ptyRunner.launch(
                executable: adapter.executablePath,
                arguments: adapter.launchArguments(worktreePath: worktree.path),
                workingDirectory: worktree.path,
                environment: nil as [String: String]?,
                onOutput: { [weak self] (output: String) in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        await self.handleAgentOutput(output, agentType: agentType, worktreePath: worktreePath)
                    }
                },
                onTermination: { [weak self] (exitCode: Int32) in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        await self.handleAgentTermination(exitCode: exitCode, agentType: agentType, worktreePath: worktreePath)
                    }
                }
            )

            worktreeProcessIds[worktree.id] = processId
            await emitToMCP(level: .info, source: agent.type.rawValue, worktree: worktree.path, message: "Agent started with PTY (PID: \(processId))")

        } catch {
            agent.status = .error
            setAgent(agent)
            await emitToMCP(level: .error, source: agent.type.rawValue, worktree: worktree.path, message: "Failed to start: \(error.localizedDescription)")
            await updateMCPStatus(agent: agent.type.rawValue, worktree: worktree.path, status: .error, task: nil)
        }
    }

    /// Handles agent output: parses for status markers, emits to MCP, and updates local state
    private func handleAgentOutput(_ output: String, agentType: AgentType, worktreePath: String) async {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Determine log level from content
        let level: LogLevel = parseLogLevel(from: trimmed)

        // Emit to MCP and local logs
        await emitToMCP(level: level, source: agentType.rawValue, worktree: worktreePath, message: trimmed)

        // Detect status changes from output patterns
        await detectAndUpdateStatus(from: trimmed, agentType: agentType, worktreePath: worktreePath)
    }

    /// Handles agent process termination
    private func handleAgentTermination(exitCode: Int32, agentType: AgentType, worktreePath: String) async {
        let level: LogLevel = exitCode == 0 ? .info : .error
        let message = exitCode == 0 ? "Agent completed successfully" : "Agent exited with code \(exitCode)"

        await emitToMCP(level: level, source: agentType.rawValue, worktree: worktreePath, message: message)
        await updateMCPStatus(
            agent: agentType.rawValue,
            worktree: worktreePath,
            status: exitCode == 0 ? .complete : .error,
            task: nil
        )

        // Update local agent status
        if let worktree = worktrees.first(where: { $0.path == worktreePath }),
           var agent = agent(for: worktree) {
            agent.status = exitCode == 0 ? .idle : .error
            setAgent(agent)
        }

        // Remove from process tracking
        if let worktree = worktrees.first(where: { $0.path == worktreePath }) {
            worktreeProcessIds.removeValue(forKey: worktree.id)
        }
    }

    /// Parses log level from output content
    private func parseLogLevel(from text: String) -> LogLevel {
        let lower = text.lowercased()
        if lower.contains("error") || lower.contains("failed") || lower.contains("exception") {
            return .error
        } else if lower.contains("warn") || lower.contains("warning") {
            return .warn
        } else if lower.contains("success") || lower.contains("complete") || lower.contains("done") {
            return .info
        }
        return .debug
    }

    /// Detects status changes from agent output patterns
    private func detectAndUpdateStatus(from text: String, agentType: AgentType, worktreePath: String) async {
        let lower = text.lowercased()

        // Detect completion
        if lower.contains("task complete") || lower.contains("all done") || lower.contains("finished") {
            await updateMCPStatus(agent: agentType.rawValue, worktree: worktreePath, status: .complete, task: "Completed")
            // Update local agent status
            if let worktree = worktrees.first(where: { $0.path == worktreePath }),
               var agent = agent(for: worktree) {
                agent.status = .idle
                setAgent(agent)
            }
        }
        // Detect planning phase
        else if lower.contains("planning") || lower.contains("analyzing") || lower.contains("thinking") {
            await updateMCPStatus(agent: agentType.rawValue, worktree: worktreePath, status: .planning, task: "Planning")
        }
        // Detect errors
        else if lower.contains("error") || lower.contains("failed") {
            await updateMCPStatus(agent: agentType.rawValue, worktree: worktreePath, status: .error, task: nil)
        }
        // Detect active work
        else if lower.contains("writing") || lower.contains("editing") || lower.contains("creating") ||
                lower.contains("running") || lower.contains("executing") {
            // Extract task description (first 50 chars)
            let task = String(text.prefix(50))
            await updateMCPStatus(agent: agentType.rawValue, worktree: worktreePath, status: .running, task: task)
        }
    }

    /// Emits a log to both MCP server and local logs
    private func emitToMCP(level: LogLevel, source: String, worktree: String, message: String) async {
        // Add to local logs
        addLog(LogEntry(level: level, source: source, worktree: worktree, message: message))

        // Emit to MCP server if connected
        let mcpClient = services.mcpClient
        if await mcpClient.serverIsRunning {
            do {
                try await mcpClient.emitLog(level: level, source: source, worktree: worktree, message: message)
            } catch {
                // Silently fail MCP emission - local logs still work
                #if DEBUG
                print("MCP emitLog failed: \(error)")
                #endif
            }
        }
    }

    /// Updates agent status on MCP server
    private func updateMCPStatus(agent: String, worktree: String, status: AgentStatus, task: String?) async {
        let mcpClient = services.mcpClient
        if await mcpClient.serverIsRunning {
            do {
                try await mcpClient.updateStatus(agent: agent, worktree: worktree, status: status, task: task)
            } catch {
                #if DEBUG
                print("MCP updateStatus failed: \(error)")
                #endif
            }
        }
    }

    /// Stops the agent for a specific worktree
    func stopAgentForWorktree(_ worktree: Worktree) async {
        guard var agent = agent(for: worktree) else { return }

        guard let processId = worktreeProcessIds[worktree.id] else {
            agent.status = .idle
            setAgent(agent)
            return
        }

        do {
            try await services.ptyRunner.terminate(id: processId)
            agent.status = .idle
            setAgent(agent)
            worktreeProcessIds.removeValue(forKey: worktree.id)
            addLog(LogEntry(level: .info, source: agent.type.rawValue, worktree: worktree.path, message: "Agent stopped"))
        } catch {
            addLog(LogEntry(level: .warn, source: agent.type.rawValue, worktree: worktree.path, message: "Error stopping: \(error.localizedDescription)"))
        }
    }

    /// Checks if an agent is running for a worktree
    func isAgentRunning(for worktree: Worktree) async -> Bool {
        guard let processId = worktreeProcessIds[worktree.id] else { return false }
        return await services.ptyRunner.isRunning(id: processId)
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

    // MARK: - Git Repository Management

    /// Checks if the current project path is a git repository
    func checkGitRepositoryStatus() async {
        guard let path = projectPath else {
            await MainActor.run { self.isGitRepository = false }
            return
        }

        let gitPath = (path as NSString).appendingPathComponent(".git")
        let exists = FileManager.default.fileExists(atPath: gitPath)
        await MainActor.run { self.isGitRepository = exists }
    }

    /// Initializes a git repository at the current project path
    func initializeGitRepository() async throws {
        guard let path = projectPath else {
            throw AppError.gitError("No project path set")
        }

        await MainActor.run { self.isInitializingGit = true }

        do {
            try await services.gitService.initializeRepository(path: path)
            await MainActor.run {
                self.isGitRepository = true
                self.isInitializingGit = false
            }
            addLog(LogEntry(level: .info, source: "git", worktree: nil, message: "Git repository initialized at \(path)"))
        } catch {
            await MainActor.run { self.isInitializingGit = false }
            addLog(LogEntry(level: .error, source: "git", worktree: nil, message: "Failed to init git: \(error.localizedDescription)"))
            throw AppError.gitError(error.localizedDescription)
        }
    }

    /// Creates a new project folder and optionally initializes git
    func createProjectFolder(name: String, at parentPath: String, initGit: Bool) async throws -> String {
        let newPath = (parentPath as NSString).appendingPathComponent(name)

        // Create folder
        try FileManager.default.createDirectory(atPath: newPath, withIntermediateDirectories: true, attributes: nil)

        // Update project path
        await MainActor.run { self.projectPath = newPath }

        // Init git if requested
        if initGit {
            try await services.gitService.initializeRepository(path: newPath)
            await MainActor.run { self.isGitRepository = true }
            addLog(LogEntry(level: .info, source: "system", worktree: nil, message: "Created project folder '\(name)' with git"))
        } else {
            await MainActor.run { self.isGitRepository = false }
            addLog(LogEntry(level: .info, source: "system", worktree: nil, message: "Created project folder '\(name)'"))
        }

        return newPath
    }

    /// Sets the project path and checks git status
    func setProjectPath(_ path: String) async {
        await MainActor.run { self.projectPath = path }
        await checkGitRepositoryStatus()

        // Also load recent commits if it's a git repo
        if isGitRepository {
            await loadRecentCommits()
        }
    }

    /// Loads recent commits for the current project
    func loadRecentCommits() async {
        guard let path = projectPath, isGitRepository else {
            await MainActor.run { self.recentCommits = [] }
            return
        }

        do {
            let commitInfos = try await services.gitService.getRecentCommits(path: path, count: 10)
            let commits = commitInfos.map { info in
                GitCommit(
                    hash: info.sha,
                    message: info.message,
                    author: info.author,
                    date: info.date
                )
            }
            await MainActor.run { self.recentCommits = commits }
        } catch {
            addLog(LogEntry(level: .debug, source: "git", worktree: nil, message: "Could not load commits: \(error.localizedDescription)"))
        }
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
            let weakSelf = WeakAppStateRef(self)
            await services.agentEventBus.setOrchestratorHandler { event in
                await MainActor.run {
                    weakSelf.value?.handleBlockedAgent(event: event)
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
                try await services.ptyRunner.terminate(id: session.processId)
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

// MARK: - Environment Keys

/// Environment key for accessing AppState
private struct AppStateKey: EnvironmentKey {
    @MainActor static var defaultValue: AppState = AppState()
}

/// Environment key for accessing ServiceContainer
private struct ServicesKey: EnvironmentKey {
    static var defaultValue: any ServiceContainer = DefaultServiceContainer()
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }

    var services: any ServiceContainer {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}
