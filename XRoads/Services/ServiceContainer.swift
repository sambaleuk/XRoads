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

    /// GitMaster intelligent resolver
    var gitMaster: GitMaster { get }

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

/// Production implementation of ServiceContainer with real services.
///
/// Safety: @unchecked Sendable is justified because all stored properties are `let` bindings
/// of actor types (inherently Sendable) or Sendable value types. The class is `final`,
/// preventing subclassing, and no mutable state exists after initialization.
final class DefaultServiceContainer: ServiceContainer, @unchecked Sendable {

    let gitService: GitService
    let processRunner: ProcessRunner
    let ptyRunner: PTYProcessRunner
    let mcpClient: MCPClient
    let agentEventBus: AgentEventBus
    let mergeCoordinator: MergeCoordinator
    let gitMaster: GitMaster
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
        self.gitMaster = GitMaster(gitService: gitService)
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

/// Mock implementation of ServiceContainer for testing and previews.
///
/// All services are initialized with `testMode: true` where supported, ensuring
/// no real processes are launched, no git commands execute, and no MCP servers start.
/// Services without testMode (AgentEventBus, NotesSyncService, etc.) are pure in-memory
/// or lightweight enough to be safe in test contexts.
///
/// Safety: @unchecked Sendable is justified because all stored properties are `let` bindings
/// of actor types (inherently Sendable) or Sendable value types. The class is `final`,
/// preventing subclassing, and no mutable state exists after initialization.
final class MockServiceContainer: ServiceContainer, @unchecked Sendable {

    let gitService: GitService
    let processRunner: ProcessRunner
    let ptyRunner: PTYProcessRunner
    let mcpClient: MCPClient
    let agentEventBus: AgentEventBus
    let mergeCoordinator: MergeCoordinator
    let gitMaster: GitMaster
    let notesSyncService: NotesSyncService
    let historyService: OrchestrationHistoryService
    let agentLauncher: AgentLauncher
    let loopLauncher: LoopLauncher
    let layeredDispatcher: LayeredDispatcher
    let actionRunner: ActionRunner
    let unifiedDispatcher: UnifiedDispatcher
    let orchestrator: ClaudeOrchestrator

    init() {
        // Critical services initialized with testMode to prevent real I/O
        self.gitService = GitService(testMode: true)
        self.processRunner = ProcessRunner(testMode: true)
        self.ptyRunner = PTYProcessRunner(testMode: true)
        self.mcpClient = MCPClient(testMode: true)

        // Pure in-memory services — safe without testMode
        self.agentEventBus = AgentEventBus()
        self.notesSyncService = NotesSyncService()

        // Services composed from test-mode dependencies — inherit safety
        self.mergeCoordinator = MergeCoordinator(gitService: gitService)
        self.gitMaster = GitMaster(gitService: gitService)
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
