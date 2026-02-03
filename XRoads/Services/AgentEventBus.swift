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

actor AgentEventBus {
    private var continuations: [UUID: AsyncStream<AgentEvent>.Continuation] = [:]
    private var history: [AgentEvent] = []
    private let historyLimit = 100

    func publish(event: AgentEvent) {
        history.append(event)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }

        continuations.values.forEach { $0.yield(event) }

        if event.kind == .blocked {
            // Optionally trigger additional logic here if needed later
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

    private func removeContinuation(_ token: UUID) {
        continuations.removeValue(forKey: token)
    }
}
