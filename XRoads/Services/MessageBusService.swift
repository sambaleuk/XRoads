import Foundation
import GRDB
import os

// MARK: - MessageBusService

/// Actor-based message bus for inter-slot communication.
/// Persists AgentMessages to SQLite and notifies subscribers via AsyncStream.
actor MessageBusService {

    private let logger = Logger(subsystem: "com.xroads", category: "MessageBus")
    private let dbQueue: DatabaseQueue

    /// Active subscriptions keyed by session ID
    private var subscriptions: [UUID: [SubscriptionEntry]] = [:]

    /// Internal subscription tracking
    private struct SubscriptionEntry {
        let id: UUID
        let continuation: AsyncStream<AgentMessage>.Continuation
    }

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    convenience init(databaseManager: CockpitDatabaseManager) async {
        self.init(dbQueue: await databaseManager.dbQueue)
    }

    // MARK: - Publish

    /// Publish a message from a slot. Persists to SQLite, then notifies subscribers.
    @discardableResult
    func publish(message: AgentMessage, fromSlot slotId: UUID) throws -> AgentMessage {
        // Persist to SQLite
        let persisted = try dbQueue.write { db in
            var record = message
            try record.insert(db)
            return record
        }

        // Resolve session ID from the slot's cockpitSessionId
        let sessionId = try dbQueue.read { db -> UUID? in
            let slot = try AgentSlot.fetchOne(db, key: slotId)
            return slot?.cockpitSessionId
        }

        if let sessionId {
            notifySubscribers(sessionId: sessionId, message: persisted)
        }

        let messageId = persisted.id.uuidString
        logger.info("Published message \(messageId) from slot \(slotId)")
        return persisted
    }

    // MARK: - Subscribe

    /// Subscribe to all messages for a CockpitSession.
    /// Returns an AsyncStream that yields new messages as they are published.
    func subscribe(toSession sessionId: UUID) -> AsyncStream<AgentMessage> {
        let subscriptionId = UUID()

        let stream = AsyncStream<AgentMessage> { continuation in
            let entry = SubscriptionEntry(id: subscriptionId, continuation: continuation)
            self.subscriptions[sessionId, default: []].append(entry)

            continuation.onTermination = { @Sendable _ in
                Task { await self.removeSubscription(id: subscriptionId, sessionId: sessionId) }
            }
        }

        let subId = subscriptionId.uuidString
        logger.info("New subscription \(subId) for session \(sessionId)")
        return stream
    }

    // MARK: - Query

    /// Fetch all messages for a session, ordered by creation time.
    func fetchMessages(sessionId: UUID) throws -> [AgentMessage] {
        try dbQueue.read { db in
            // Get slot IDs for this session
            let slots = try AgentSlot
                .filter(AgentSlot.Columns.cockpitSessionId == sessionId)
                .fetchAll(db)
            let slotIds = slots.map(\.id)

            guard !slotIds.isEmpty else { return [] }

            return try AgentMessage
                .filter(slotIds.contains(AgentMessage.Columns.fromSlotId))
                .order(AgentMessage.Columns.createdAt)
                .fetchAll(db)
        }
    }

    /// Fetch messages for a specific slot
    func fetchMessages(slotId: UUID) throws -> [AgentMessage] {
        try dbQueue.read { db in
            try AgentMessage
                .filter(AgentMessage.Columns.fromSlotId == slotId)
                .order(AgentMessage.Columns.createdAt)
                .fetchAll(db)
        }
    }

    // MARK: - Private

    private func notifySubscribers(sessionId: UUID, message: AgentMessage) {
        guard let entries = subscriptions[sessionId] else { return }
        for entry in entries {
            entry.continuation.yield(message)
        }
    }

    private func removeSubscription(id: UUID, sessionId: UUID) {
        subscriptions[sessionId]?.removeAll { $0.id == id }
        if subscriptions[sessionId]?.isEmpty == true {
            subscriptions.removeValue(forKey: sessionId)
        }
    }
}
