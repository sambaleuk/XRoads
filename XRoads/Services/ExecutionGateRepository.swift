import Foundation
import GRDB
import os

// MARK: - ExecutionGateRepositoryError

enum ExecutionGateRepositoryError: LocalizedError {
    case gateNotFound(UUID)
    case auditAlreadyWritten(UUID)
    case lifecycleViolation(String)

    var errorDescription: String? {
        switch self {
        case .gateNotFound(let id):
            return "ExecutionGate not found: \(id)"
        case .auditAlreadyWritten(let id):
            return "Audit entry already written for gate: \(id) — immutable"
        case .lifecycleViolation(let reason):
            return "ExecutionGate lifecycle violation: \(reason)"
        }
    }
}

// MARK: - ExecutionGateRepository

/// Actor-based repository for ExecutionGate persistence and lifecycle management.
/// All status changes go through ExecutionGateStateMachine — no direct override.
actor ExecutionGateRepository {

    private let logger = Logger(subsystem: "com.xroads", category: "ExecutionGateRepo")
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    convenience init(databaseManager: CockpitDatabaseManager) async {
        self.init(dbQueue: await databaseManager.dbQueue)
    }

    // MARK: - Create

    /// Create a new ExecutionGate linked to an AgentSlot.
    /// Gate is always created in `pending` status (initial state from states.json).
    func create(
        agentSlotId: UUID,
        operationType: String,
        operationPayload: String,
        riskLevel: String,
        estimatedImpact: String? = nil,
        rollbackPayload: String? = nil
    ) throws -> ExecutionGate {
        let gate = ExecutionGate(
            agentSlotId: agentSlotId,
            status: .pending,
            operationType: operationType,
            operationPayload: operationPayload,
            riskLevel: riskLevel,
            estimatedImpact: estimatedImpact,
            rollbackPayload: rollbackPayload
        )

        return try dbQueue.write { db in
            var record = gate
            try record.insert(db)
            self.logger.info("ExecutionGate created: \(record.id) for slot \(agentSlotId)")
            return record
        }
    }

    // MARK: - Update Status (via StateMachine)

    /// Transition gate status by applying an event through the state machine.
    /// This is the ONLY way to change status — no direct status override allowed.
    func updateStatus(
        gateId: UUID,
        event: ExecutionGateEvent,
        context: ExecutionGateGuardContext = ExecutionGateGuardContext(),
        approvedBy: String? = nil,
        deniedReason: String? = nil
    ) throws -> ExecutionGate {
        try dbQueue.write { db in
            guard var gate = try ExecutionGate.fetchOne(db, key: gateId) else {
                throw ExecutionGateRepositoryError.gateNotFound(gateId)
            }

            // Enforce lifecycle via state machine — throws on invalid transition
            let newStatus = try ExecutionGateStateMachine.transition(
                from: gate.status,
                event: event,
                context: context
            )

            gate.status = newStatus
            gate.updatedAt = Date()

            // Set approval metadata when approving
            if event == .approve, let approver = approvedBy {
                gate.approvedBy = approver
                gate.approvedAt = Date()
            }

            // Set denial reason when rejecting
            if event == .policyDeny || event == .reject || event == .dryRunFail {
                gate.deniedReason = deniedReason
            }

            try gate.update(db)
            self.logger.info("ExecutionGate \(gateId) transitioned to \(newStatus.rawValue) via \(event.rawValue)")
            return gate
        }
    }

    // MARK: - Write Audit Entry (immutable)

    /// Write an immutable audit entry on gate completion or rollback.
    /// Throws if audit_entry is already set (immutability enforced).
    func writeAudit(gateId: UUID, durationMs: Int64? = nil) throws -> ExecutionGate {
        try dbQueue.write { db in
            guard var gate = try ExecutionGate.fetchOne(db, key: gateId) else {
                throw ExecutionGateRepositoryError.gateNotFound(gateId)
            }

            // Immutability: audit_entry can only be written once
            guard gate.auditEntry == nil else {
                throw ExecutionGateRepositoryError.auditAlreadyWritten(gateId)
            }

            // Only terminal states get audit entries
            guard gate.status == .completed || gate.status == .rolledBack else {
                throw ExecutionGateRepositoryError.lifecycleViolation(
                    "audit_entry can only be written in completed or rolled_back state, current: \(gate.status.rawValue)"
                )
            }

            let entry = AuditEntry(
                gateId: gate.id,
                finalStatus: gate.status.rawValue,
                operationType: gate.operationType,
                riskLevel: gate.riskLevel,
                approvedBy: gate.approvedBy,
                deniedReason: gate.deniedReason,
                durationMs: durationMs,
                completedAt: Date()
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(entry)
            gate.auditEntry = String(data: jsonData, encoding: .utf8)
            gate.updatedAt = Date()

            try gate.update(db)
            self.logger.info("Audit entry written for gate \(gateId)")
            return gate
        }
    }

    // MARK: - Fetch

    /// Fetch a gate by ID
    func fetch(id: UUID) throws -> ExecutionGate? {
        try dbQueue.read { db in
            try ExecutionGate.fetchOne(db, key: id)
        }
    }

    /// Fetch all gates for an AgentSlot
    func fetchGates(slotId: UUID) throws -> [ExecutionGate] {
        try dbQueue.read { db in
            try ExecutionGate
                .filter(ExecutionGate.Columns.agentSlotId == slotId)
                .order(ExecutionGate.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetch all gates for a CockpitSession (across all its slots), sorted by created_at desc.
    /// US-004: Used by AuditTrailView to display full session audit trail.
    func fetchGatesForSession(sessionId: UUID, dbQueue externalQueue: DatabaseQueue? = nil) throws -> [ExecutionGate] {
        let queue = externalQueue ?? dbQueue
        return try queue.read { db in
            // Join ExecutionGate with AgentSlot to filter by session
            let slotAlias = TableAlias(name: "slot")
            return try ExecutionGate
                .joining(required: ExecutionGate.agentSlot.aliased(slotAlias))
                .filter(slotAlias[AgentSlot.Columns.cockpitSessionId] == sessionId)
                .order(ExecutionGate.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }
}
