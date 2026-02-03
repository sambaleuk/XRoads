import Foundation

enum AgentEventKind: String, Codable, Sendable {
    case storyStarted
    case storyCompleted
    case blocked
    case needsHelp
    case fileModified
}

struct AgentEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let agentId: String
    let agentType: AgentType?
    let kind: AgentEventKind
    let storyId: String?
    let filePath: String?
    let message: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        agentId: String,
        agentType: AgentType?,
        kind: AgentEventKind,
        storyId: String?,
        filePath: String?,
        message: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.agentType = agentType
        self.kind = kind
        self.storyId = storyId
        self.filePath = filePath
        self.message = message
        self.timestamp = timestamp
    }
}

/// Callback type for orchestrator notifications
typealias OrchestratorNotificationHandler = @Sendable (AgentEvent) async -> Void

actor AgentEventBus {
    private var continuations: [UUID: AsyncStream<AgentEvent>.Continuation] = [:]
    private var history: [AgentEvent] = []
    private let historyLimit = 100

    /// Optional handler called when an agent becomes blocked or needs help
    private var orchestratorHandler: OrchestratorNotificationHandler?

    /// Registers a handler to be notified when agents need orchestrator attention
    func setOrchestratorHandler(_ handler: @escaping OrchestratorNotificationHandler) {
        orchestratorHandler = handler
    }

    func publish(event: AgentEvent) {
        history.append(event)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }

        continuations.values.forEach { $0.yield(event) }

        // Notify orchestrator for blocked/needsHelp events
        if event.kind == .blocked || event.kind == .needsHelp {
            if let handler = orchestratorHandler {
                Task {
                    await handler(event)
                }
            }
        }
    }

    func subscribe(agentId: String) -> AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            let token = UUID()
            continuations[token] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(token) }
            }

            history.forEach { continuation.yield($0) }
        }
    }

    func recentEvents(limit: Int = 20) -> [AgentEvent] {
        Array(history.suffix(limit))
    }

    /// Returns events where agents are currently blocked
    func blockedAgentEvents() -> [AgentEvent] {
        // Get the latest event per agent and filter for blocked ones
        var latestByAgent: [String: AgentEvent] = [:]
        for event in history {
            if let existing = latestByAgent[event.agentId] {
                if event.timestamp > existing.timestamp {
                    latestByAgent[event.agentId] = event
                }
            } else {
                latestByAgent[event.agentId] = event
            }
        }
        return latestByAgent.values.filter { $0.kind == .blocked || $0.kind == .needsHelp }
    }

    /// Clears all history and subscriptions
    func reset() {
        history.removeAll()
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
    }

    private func removeContinuation(_ token: UUID) {
        continuations.removeValue(forKey: token)
    }
}
