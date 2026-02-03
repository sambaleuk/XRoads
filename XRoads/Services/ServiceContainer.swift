import Foundation

// MARK: - ServiceContainer Protocol

/// Protocol defining the dependency injection container for services
protocol ServiceContainer: Sendable {
    /// Git service for worktree operations
    var gitService: GitService { get }

    /// Process runner for managing external processes
    var processRunner: ProcessRunner { get }

    /// MCP client for communication with crossroads-mcp server
    var mcpClient: MCPClient { get }

    /// Agent event bus for inter-agent communication
    var agentEventBus: AgentEventBus { get }

    /// Merge coordinator for orchestrated merges
    var mergeCoordinator: MergeCoordinator { get }

    /// Notes sync service
    var notesSyncService: NotesSyncService { get }
    var historyService: OrchestrationHistoryService { get }
}

// MARK: - DefaultServiceContainer

/// Production implementation of ServiceContainer with real services
final class DefaultServiceContainer: ServiceContainer, @unchecked Sendable {

    let gitService: GitService
    let processRunner: ProcessRunner
    let mcpClient: MCPClient
    let agentEventBus: AgentEventBus
    let mergeCoordinator: MergeCoordinator
    let notesSyncService: NotesSyncService
    let historyService: OrchestrationHistoryService

    init(
        gitService: GitService = GitService(),
        processRunner: ProcessRunner = ProcessRunner(),
        mcpClient: MCPClient = MCPClient(),
        agentEventBus: AgentEventBus = AgentEventBus(),
        mergeCoordinator: MergeCoordinator = MergeCoordinator(),
        notesSyncService: NotesSyncService = NotesSyncService(),
        historyService: OrchestrationHistoryService = OrchestrationHistoryService()
    ) {
        self.gitService = gitService
        self.processRunner = processRunner
        self.mcpClient = mcpClient
        self.agentEventBus = agentEventBus
        self.mergeCoordinator = mergeCoordinator
        self.notesSyncService = notesSyncService
        self.historyService = historyService
    }
}

// MARK: - MockServiceContainer

/// Mock implementation of ServiceContainer for testing and previews
final class MockServiceContainer: ServiceContainer, @unchecked Sendable {

    let gitService: GitService
    let processRunner: ProcessRunner
    let mcpClient: MCPClient
    let agentEventBus: AgentEventBus
    let mergeCoordinator: MergeCoordinator
    let notesSyncService: NotesSyncService
    let historyService: OrchestrationHistoryService

    init() {
        // Use default instances - in a full implementation, these would be mock versions
        self.gitService = GitService()
        self.processRunner = ProcessRunner()
        self.mcpClient = MCPClient()
        self.agentEventBus = AgentEventBus()
        self.mergeCoordinator = MergeCoordinator()
        self.notesSyncService = NotesSyncService()
        self.historyService = OrchestrationHistoryService()
    }
}
