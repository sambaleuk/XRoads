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

    // MARK: - Private Properties

    /// Task for log streaming
    private var logStreamTask: Task<Void, Never>?

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

    // MARK: - Initialization

    init(services: ServiceContainer = DefaultServiceContainer()) {
        self.services = services
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
        if var session = selectedSession {
            session.worktrees.append(worktree.id)
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
                selectedSession = session
            }
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

        // Remove from session
        if var session = selectedSession {
            session.worktrees.removeAll { $0 == worktree.id }
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
                selectedSession = session
            }
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
