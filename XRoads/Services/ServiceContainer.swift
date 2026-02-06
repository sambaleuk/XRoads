import Foundation

// MARK: - ServiceContainer Protocol

/// Protocol defining the dependency injection container for services
protocol ServiceContainer: Sendable {
    /// Git service for worktree operations
    var gitService: GitService { get }

    /// Process runner for managing external processes (non-interactive)
    var processRunner: ProcessRunner { get }

    /// PTY process runner for interactive CLI agents (Claude, Gemini, Codex)
    var ptyRunner: PTYProcessRunner { get }

    /// MCP client for communication with crossroads-mcp server
    var mcpClient: MCPClient { get }

    /// Agent event bus for inter-agent communication
    var agentEventBus: AgentEventBus { get }

    /// Merge coordinator for orchestrated merges
    var mergeCoordinator: MergeCoordinator { get }

    /// Notes sync service
    var notesSyncService: NotesSyncService { get }
    var historyService: OrchestrationHistoryService { get }

    /// Agent launcher for starting CLI agents in worktrees
    var agentLauncher: AgentLauncher { get }

    /// Loop launcher for running loop scripts (nexus-loop, gemini-loop, codex-loop)
    var loopLauncher: LoopLauncher { get }

    /// Layered dispatcher for dependency-aware loop launching
    var layeredDispatcher: LayeredDispatcher { get }

    /// Action runner for skill-based action execution
    var actionRunner: ActionRunner { get }

    /// Unified dispatcher - single entry point for all dispatch operations
    var unifiedDispatcher: UnifiedDispatcher { get }

    /// Claude orchestrator for Full Agentic Mode
    var orchestrator: ClaudeOrchestrator { get }
}

// MARK: - DefaultServiceContainer

/// Production implementation of ServiceContainer with real services
final class DefaultServiceContainer: ServiceContainer, @unchecked Sendable {

    let gitService: GitService
    let processRunner: ProcessRunner
    let ptyRunner: PTYProcessRunner
    let mcpClient: MCPClient
    let agentEventBus: AgentEventBus
    let mergeCoordinator: MergeCoordinator
    let notesSyncService: NotesSyncService
    let historyService: OrchestrationHistoryService
    let agentLauncher: AgentLauncher
    let loopLauncher: LoopLauncher
    let layeredDispatcher: LayeredDispatcher
    let actionRunner: ActionRunner
    let unifiedDispatcher: UnifiedDispatcher
    let orchestrator: ClaudeOrchestrator

    init(
        gitService: GitService = GitService(),
        processRunner: ProcessRunner = ProcessRunner(),
        ptyRunner: PTYProcessRunner = PTYProcessRunner(),
        mcpClient: MCPClient = MCPClient(),
        agentEventBus: AgentEventBus = AgentEventBus(),
        mergeCoordinator: MergeCoordinator = MergeCoordinator(),
        notesSyncService: NotesSyncService = NotesSyncService(),
        historyService: OrchestrationHistoryService = OrchestrationHistoryService()
    ) {
        self.gitService = gitService
        self.processRunner = processRunner
        self.ptyRunner = ptyRunner
        self.mcpClient = mcpClient
        self.agentEventBus = agentEventBus
        self.mergeCoordinator = mergeCoordinator
        self.notesSyncService = notesSyncService
        self.historyService = historyService
        self.agentLauncher = AgentLauncher(ptyRunner: ptyRunner)
        self.loopLauncher = LoopLauncher(ptyRunner: ptyRunner, gitService: gitService)
        self.layeredDispatcher = LayeredDispatcher(loopLauncher: loopLauncher, gitService: gitService)
        self.actionRunner = ActionRunner(ptyRunner: ptyRunner)
        self.unifiedDispatcher = UnifiedDispatcher(
            layeredDispatcher: layeredDispatcher,
            actionRunner: actionRunner,
            gitService: gitService
        )
        self.orchestrator = ClaudeOrchestrator(
            gitService: gitService,
            processRunner: processRunner,
            mcpClient: mcpClient,
            agentEventBus: agentEventBus
        )
    }
}

// MARK: - MockServiceContainer

/// Mock implementation of ServiceContainer for testing and previews
final class MockServiceContainer: ServiceContainer, @unchecked Sendable {

    let gitService: GitService
    let processRunner: ProcessRunner
    let ptyRunner: PTYProcessRunner
    let mcpClient: MCPClient
    let agentEventBus: AgentEventBus
    let mergeCoordinator: MergeCoordinator
    let notesSyncService: NotesSyncService
    let historyService: OrchestrationHistoryService
    let agentLauncher: AgentLauncher
    let loopLauncher: LoopLauncher
    let layeredDispatcher: LayeredDispatcher
    let actionRunner: ActionRunner
    let unifiedDispatcher: UnifiedDispatcher
    let orchestrator: ClaudeOrchestrator

    init() {
        // Use default instances - in a full implementation, these would be mock versions
        self.gitService = GitService()
        self.processRunner = ProcessRunner()
        self.ptyRunner = PTYProcessRunner()
        self.mcpClient = MCPClient()
        self.agentEventBus = AgentEventBus()
        self.mergeCoordinator = MergeCoordinator()
        self.notesSyncService = NotesSyncService()
        self.historyService = OrchestrationHistoryService()
        self.agentLauncher = AgentLauncher(ptyRunner: ptyRunner)
        self.loopLauncher = LoopLauncher(ptyRunner: ptyRunner, gitService: gitService)
        self.layeredDispatcher = LayeredDispatcher(loopLauncher: loopLauncher, gitService: gitService)
        self.actionRunner = ActionRunner(ptyRunner: ptyRunner)
        self.unifiedDispatcher = UnifiedDispatcher(
            layeredDispatcher: layeredDispatcher,
            actionRunner: actionRunner,
            gitService: gitService
        )
        self.orchestrator = ClaudeOrchestrator(
            gitService: gitService,
            processRunner: processRunner,
            mcpClient: mcpClient,
            agentEventBus: agentEventBus
        )
    }
}
