import Foundation
import GRDB
import os

// MARK: - CostEventRepository

/// Actor-based repository for CostEvent CRUD and aggregation.
/// All database access is serialized through GRDB's DatabaseQueue.
actor CostEventRepository {

    private let logger = Logger(subsystem: "com.xroads", category: "CostRepo")
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    convenience init(databaseManager: CockpitDatabaseManager) async {
        self.init(dbQueue: await databaseManager.dbQueue)
    }

    // MARK: - Record Cost Event

    /// Records a single cost event for an agent slot.
    @discardableResult
    func record(_ event: CostEvent) throws -> CostEvent {
        try dbQueue.write { db in
            var record = event
            try record.insert(db)
            return record
        }
    }

    /// Records usage and auto-calculates cost.
    @discardableResult
    func recordUsage(
        slotId: UUID,
        provider: String,
        model: String,
        inputTokens: Int,
        outputTokens: Int
    ) throws -> CostEvent {
        let costCents = CostEvent.estimateCostCents(
            provider: provider,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
        let event = CostEvent(
            agentSlotId: slotId,
            provider: provider,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            costCents: costCents
        )
        return try record(event)
    }

    // MARK: - Fetch Events

    /// Fetches all cost events for a slot, ordered by creation time.
    func fetchEvents(slotId: UUID) throws -> [CostEvent] {
        try dbQueue.read { db in
            try CostEvent
                .filter(CostEvent.Columns.agentSlotId == slotId)
                .order(CostEvent.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    /// Fetches all cost events for a session (via slot join).
    func fetchEventsForSession(sessionId: UUID) throws -> [CostEvent] {
        try dbQueue.read { db in
            let slotIds = try AgentSlot
                .filter(AgentSlot.Columns.cockpitSessionId == sessionId)
                .select(AgentSlot.Columns.id)
                .fetchAll(db)
                .map(\.id)

            return try CostEvent
                .filter(slotIds.contains(CostEvent.Columns.agentSlotId))
                .order(CostEvent.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    // MARK: - Aggregation

    /// Returns a UsageSummary for a single slot.
    func summaryForSlot(slotId: UUID) throws -> UsageSummary {
        try dbQueue.read { db in
            let events = try CostEvent
                .filter(CostEvent.Columns.agentSlotId == slotId)
                .fetchAll(db)

            guard !events.isEmpty else { return .zero }

            return UsageSummary(
                totalInputTokens: events.reduce(0) { $0 + $1.inputTokens },
                totalOutputTokens: events.reduce(0) { $0 + $1.outputTokens },
                totalCostCents: events.reduce(0) { $0 + $1.costCents },
                eventCount: events.count
            )
        }
    }

    /// Returns a UsageSummary for an entire session (all slots combined).
    func summaryForSession(sessionId: UUID) throws -> UsageSummary {
        try dbQueue.read { db in
            let slotIds = try AgentSlot
                .filter(AgentSlot.Columns.cockpitSessionId == sessionId)
                .fetchAll(db)
                .map(\.id)

            guard !slotIds.isEmpty else { return .zero }

            let events = try CostEvent
                .filter(slotIds.contains(CostEvent.Columns.agentSlotId))
                .fetchAll(db)

            guard !events.isEmpty else { return .zero }

            return UsageSummary(
                totalInputTokens: events.reduce(0) { $0 + $1.inputTokens },
                totalOutputTokens: events.reduce(0) { $0 + $1.outputTokens },
                totalCostCents: events.reduce(0) { $0 + $1.costCents },
                eventCount: events.count
            )
        }
    }

    /// Returns per-slot usage breakdown for a session.
    func breakdownForSession(sessionId: UUID) throws -> [UUID: UsageSummary] {
        try dbQueue.read { db in
            let slotIds = try AgentSlot
                .filter(AgentSlot.Columns.cockpitSessionId == sessionId)
                .fetchAll(db)
                .map(\.id)

            guard !slotIds.isEmpty else { return [:] }

            let events = try CostEvent
                .filter(slotIds.contains(CostEvent.Columns.agentSlotId))
                .fetchAll(db)

            var result: [UUID: UsageSummary] = [:]
            let grouped = Dictionary(grouping: events) { $0.agentSlotId }
            for (slotId, slotEvents) in grouped {
                result[slotId] = UsageSummary(
                    totalInputTokens: slotEvents.reduce(0) { $0 + $1.inputTokens },
                    totalOutputTokens: slotEvents.reduce(0) { $0 + $1.outputTokens },
                    totalCostCents: slotEvents.reduce(0) { $0 + $1.costCents },
                    eventCount: slotEvents.count
                )
            }
            return result
        }
    }
}
