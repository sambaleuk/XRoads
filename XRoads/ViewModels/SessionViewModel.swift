import Foundation
import SwiftUI

// MARK: - SessionViewModel

/// ViewModel for managing session and worktree operations following MVVM pattern
/// Uses @MainActor for thread-safe UI updates
@MainActor
final class SessionViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All worktrees in the current view
    @Published var worktrees: [Worktree] = []

    /// Currently selected worktree
    @Published var selectedWorktree: Worktree?

    /// Log entries for display
    @Published var logs: [LogEntry] = []

    /// Loading state indicator
    @Published var isLoading: Bool = false

    /// Current error for display
    @Published var error: SessionError?

    /// Agents indexed by their worktree path
    @Published private(set) var agents: [String: Agent] = [:]

    /// MCP connection status
    @Published private(set) var mcpConnectionStatus: MCPConnectionStatus = .disconnected

    /// Indicates if log streaming is active
    @Published private(set) var isStreamingLogs: Bool = false

    /// Running process IDs indexed by worktree ID
    private var processIds: [UUID: UUID] = [:]

    /// Task for log streaming
    private var logStreamTask: Task<Void, Never>?

    // MARK: - Services

    private let gitService: GitService
    private let processRunner: ProcessRunner
    private let mcpClient: MCPClient

    // MARK: - Initialization

    init(
        gitService: GitService,
        processRunner: ProcessRunner,
        mcpClient: MCPClient
    ) {
        self.gitService = gitService
        self.processRunner = processRunner
        self.mcpClient = mcpClient
    }

    /// Convenience initializer with ServiceContainer
    convenience init(services: ServiceContainer) {
        self.init(
            gitService: services.gitService,
            processRunner: services.processRunner,
            mcpClient: services.mcpClient
        )
    }

    // MARK: - Worktree Management

    /// Creates a new worktree with the specified parameters
    /// - Parameters:
    ///   - name: Name for the worktree (used in branch name)
    ///   - repoPath: Path to the main git repository
    ///   - agentType: Type of agent to assign to this worktree
    func createWorktree(name: String, repoPath: String, agentType: AgentType) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Generate branch name from worktree name
            let branchName = "worktree/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"

            // Generate worktree path in the same parent directory
            let repoURL = URL(fileURLWithPath: repoPath)
            let parentDir = repoURL.deletingLastPathComponent()
            let worktreePath = parentDir.appendingPathComponent("\(repoURL.lastPathComponent)-\(name)").path

            // Create the git worktree
            try await gitService.createWorktree(
                repoPath: repoPath,
                branch: branchName,
                worktreePath: worktreePath
            )

            // Create agent for this worktree
            let agent = Agent(
                type: agentType,
                status: .idle,
                worktreePath: worktreePath
            )

            // Create worktree model with agent reference
            let worktree = Worktree(
                path: worktreePath,
                branch: branchName,
                agentId: agent.id
            )

            // Update state
            worktrees.append(worktree)
            agents[worktreePath] = agent

            // Log success
            addLog(level: .info, source: "SessionViewModel", worktree: worktreePath,
                   message: "Created worktree '\(name)' with \(agentType.displayName)")

        } catch let gitError as GitError {
            error = .gitError(gitError.localizedDescription)
            addLog(level: .error, source: "SessionViewModel", worktree: nil,
                   message: "Failed to create worktree: \(gitError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
            addLog(level: .error, source: "SessionViewModel", worktree: nil,
                   message: "Unexpected error: \(error.localizedDescription)")
        }
    }

    /// Starts the agent for a specific worktree
    /// - Parameter worktreeId: UUID of the worktree
    func startAgent(worktreeId: UUID) async {
        guard let worktree = worktrees.first(where: { $0.id == worktreeId }) else {
            error = .worktreeNotFound(worktreeId)
            return
        }

        guard var agent = agents[worktree.path] else {
            error = .agentNotFound(worktree.path)
            return
        }

        // Check if already running
        if let existingProcessId = processIds[worktreeId],
           await processRunner.isRunning(id: existingProcessId) {
            error = .agentAlreadyRunning(worktree.path)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Determine executable path based on agent type
            let executable = executablePath(for: agent.type)

            // Update agent status to running
            agent.status = .running
            agents[worktree.path] = agent

            // Launch the process with output streaming
            let processId = try await processRunner.launch(
                executable: executable,
                arguments: agentArguments(for: agent.type, worktreePath: worktree.path),
                workingDirectory: worktree.path,
                environment: nil
            ) { [weak self] output in
                Task { @MainActor [weak self] in
                    self?.handleAgentOutput(output, worktreePath: worktree.path, agentType: agent.type)
                }
            }

            // Track process ID
            processIds[worktreeId] = processId

            addLog(level: .info, source: agent.type.rawValue, worktree: worktree.path,
                   message: "Agent started")

        } catch let processError as ProcessError {
            // Revert agent status on failure
            agent.status = .error
            agents[worktree.path] = agent

            error = .processError(processError.localizedDescription)
            addLog(level: .error, source: agent.type.rawValue, worktree: worktree.path,
                   message: "Failed to start agent: \(processError.localizedDescription)")
        } catch {
            // Revert agent status on failure
            agent.status = .error
            agents[worktree.path] = agent

            self.error = .unknown(error.localizedDescription)
            addLog(level: .error, source: agent.type.rawValue, worktree: worktree.path,
                   message: "Unexpected error: \(error.localizedDescription)")
        }
    }

    /// Stops the agent for a specific worktree
    /// - Parameter worktreeId: UUID of the worktree
    func stopAgent(worktreeId: UUID) async {
        guard let worktree = worktrees.first(where: { $0.id == worktreeId }) else {
            error = .worktreeNotFound(worktreeId)
            return
        }

        guard var agent = agents[worktree.path] else {
            error = .agentNotFound(worktree.path)
            return
        }

        guard let processId = processIds[worktreeId] else {
            // No process to stop, just update status
            agent.status = .idle
            agents[worktree.path] = agent
            return
        }

        do {
            try await processRunner.terminate(id: processId)

            // Update agent status
            agent.status = .idle
            agents[worktree.path] = agent

            // Remove process tracking
            processIds.removeValue(forKey: worktreeId)

            addLog(level: .info, source: agent.type.rawValue, worktree: worktree.path,
                   message: "Agent stopped")

        } catch let processError as ProcessError {
            error = .processError(processError.localizedDescription)
            addLog(level: .warn, source: agent.type.rawValue, worktree: worktree.path,
                   message: "Error stopping agent: \(processError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }

    /// Deletes a worktree and its associated agent
    /// - Parameter worktreeId: UUID of the worktree to delete
    func deleteWorktree(worktreeId: UUID) async {
        guard let worktree = worktrees.first(where: { $0.id == worktreeId }) else {
            error = .worktreeNotFound(worktreeId)
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Stop agent if running
        if let processId = processIds[worktreeId],
           await processRunner.isRunning(id: processId) {
            await stopAgent(worktreeId: worktreeId)
        }

        // Find the main repo path (parent of worktree)
        let worktreeURL = URL(fileURLWithPath: worktree.path)
        let parentDir = worktreeURL.deletingLastPathComponent()

        // We need to find the main repo - for now assume it's the parent worktree
        // In production, this would be stored in the Session or Worktree model
        let mainRepoPath = parentDir.path

        // Try to remove the git worktree
        // Note: This might fail if the repo path is not the main repo
        // In that case, just clean up our local state
        do {
            try await gitService.removeWorktree(repoPath: mainRepoPath, worktreePath: worktree.path)
        } catch {
            // Log but continue - the physical worktree removal might fail
            addLog(level: .warn, source: "SessionViewModel", worktree: worktree.path,
                   message: "Could not remove git worktree: \(error.localizedDescription)")
        }

        // Clean up state
        worktrees.removeAll { $0.id == worktreeId }
        agents.removeValue(forKey: worktree.path)
        processIds.removeValue(forKey: worktreeId)

        // Clear selection if this was selected
        if selectedWorktree?.id == worktreeId {
            selectedWorktree = nil
        }

        addLog(level: .info, source: "SessionViewModel", worktree: nil,
               message: "Deleted worktree '\(worktree.name)'")
    }

    // MARK: - Agent Helpers

    /// Gets the agent for a specific worktree
    func agent(for worktree: Worktree) -> Agent? {
        return agents[worktree.path]
    }

    /// Selects a worktree
    func selectWorktree(_ worktree: Worktree?) {
        selectedWorktree = worktree
    }

    // MARK: - Error Handling

    /// Clears the current error
    func clearError() {
        error = nil
    }

    // MARK: - MCP Log Streaming

    /// Starts the MCP server and begins streaming logs
    /// Logs are automatically added to the logs array as they arrive
    func startLogStreaming() async {
        guard !isStreamingLogs else { return }

        isStreamingLogs = true
        addLog(level: .info, source: "system", worktree: nil, message: "Starting MCP connection...")

        // Start MCP server if not running
        do {
            let isRunning = await mcpClient.serverIsRunning
            if !isRunning {
                try await mcpClient.start()
            }

            // Update connection status
            mcpConnectionStatus = await mcpClient.status
            addLog(level: .info, source: "mcp", worktree: nil, message: "MCP server connected")

        } catch {
            mcpConnectionStatus = .error(error.localizedDescription)
            isStreamingLogs = false
            addLog(level: .error, source: "mcp", worktree: nil, message: "Failed to start MCP: \(error.localizedDescription)")
            return
        }

        // Start consuming the log stream
        logStreamTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await self.mcpClient.logStream()

            for await logEntry in stream {
                // Check for cancellation
                guard !Task.isCancelled else { break }

                // Add log on main actor
                await MainActor.run {
                    self.logs.append(logEntry)

                    // Limit logs for performance
                    if self.logs.count > 500 {
                        self.logs.removeFirst(self.logs.count - 500)
                    }
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

        addLog(level: .info, source: "system", worktree: nil, message: "Stopping MCP connection...")

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

        addLog(level: .info, source: "mcp", worktree: nil, message: "MCP server disconnected")
    }

    /// Refreshes the MCP connection status
    func refreshMCPStatus() async {
        mcpConnectionStatus = await mcpClient.status
    }

    // MARK: - Private Helpers

    /// Returns the executable path for an agent type
    private func executablePath(for agentType: AgentType) -> String {
        switch agentType {
        case .claude:
            return "/usr/local/bin/claude"
        case .gemini:
            return "/usr/local/bin/gemini"
        case .codex:
            return "/usr/local/bin/codex"
        }
    }

    /// Returns launch arguments for an agent type
    private func agentArguments(for agentType: AgentType, worktreePath: String) -> [String] {
        switch agentType {
        case .claude:
            return ["--dangerously-skip-permissions"]
        case .gemini:
            return []
        case .codex:
            return []
        }
    }

    /// Handles output from a running agent
    private func handleAgentOutput(_ output: String, worktreePath: String, agentType: AgentType) {
        // Parse output and add as log entry
        let logLevel: LogLevel = output.lowercased().contains("error") ? .error :
                                 output.lowercased().contains("warn") ? .warn : .info

        addLog(level: logLevel, source: agentType.rawValue, worktree: worktreePath, message: output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Adds a log entry
    private func addLog(level: LogLevel, source: String, worktree: String?, message: String) {
        let log = LogEntry(
            level: level,
            source: source,
            worktree: worktree ?? "",
            message: message
        )
        logs.append(log)

        // Limit logs for performance
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }
}

// MARK: - SessionError

/// Errors specific to session/worktree operations
enum SessionError: Error, LocalizedError, Identifiable {
    case worktreeNotFound(UUID)
    case agentNotFound(String)
    case agentAlreadyRunning(String)
    case gitError(String)
    case processError(String)
    case unknown(String)

    var id: String {
        localizedDescription
    }

    var errorDescription: String? {
        switch self {
        case .worktreeNotFound(let id):
            return "Worktree not found: \(id)"
        case .agentNotFound(let path):
            return "No agent found for worktree: \(path)"
        case .agentAlreadyRunning(let path):
            return "Agent already running for worktree: \(path)"
        case .gitError(let message):
            return "Git error: \(message)"
        case .processError(let message):
            return "Process error: \(message)"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
}
