import Foundation
import GRDB
import os

// MARK: - CockpitSessionRepositoryError

enum CockpitSessionRepositoryError: LocalizedError {
    case sessionNotFound(UUID)
    case slotNotFound(UUID)
    case activeSessionExists(String)
    case guardViolation(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "CockpitSession not found: \(id)"
        case .slotNotFound(let id):
            return "AgentSlot not found: \(id)"
        case .activeSessionExists(let path):
            return "An active CockpitSession already exists for: \(path)"
        case .guardViolation(let guard_name):
            return "Guard violation: \(guard_name)"
        }
    }
}

// MARK: - CockpitSessionRepository

/// Actor-based repository for CockpitSession and AgentSlot CRUD operations.
/// All database access is serialized through GRDB's DatabaseQueue.
actor CockpitSessionRepository {

    private let logger = Logger(subsystem: "com.xroads", category: "CockpitRepo")
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    convenience init(databaseManager: CockpitDatabaseManager) async {
        self.init(dbQueue: await databaseManager.dbQueue)
    }

    // MARK: - CockpitSession CRUD

    /// Create a new cockpit session. Enforces unique active session per project_path.
    func createSession(_ session: CockpitSession) throws -> CockpitSession {
        try dbQueue.write { db in
            // Check for existing non-closed session on this project_path
            let existing = try CockpitSession
                .filter(CockpitSession.Columns.projectPath == session.projectPath)
                .filter(CockpitSession.Columns.status != CockpitSessionStatus.closed.rawValue)
                .fetchOne(db)

            if existing != nil {
                throw CockpitSessionRepositoryError.activeSessionExists(session.projectPath)
            }

            var record = session
            try record.insert(db)
            return record
        }
    }

    /// Fetch a session by ID
    func fetchSession(id: UUID) throws -> CockpitSession? {
        try dbQueue.read { db in
            try CockpitSession.fetchOne(db, key: id)
        }
    }

    /// Fetch the active (non-closed) session for a project path
    func activeSession(for projectPath: String) throws -> CockpitSession? {
        try dbQueue.read { db in
            try CockpitSession
                .filter(CockpitSession.Columns.projectPath == projectPath)
                .filter(CockpitSession.Columns.status != CockpitSessionStatus.closed.rawValue)
                .fetchOne(db)
        }
    }

    /// Update a session
    func updateSession(_ session: CockpitSession) throws -> CockpitSession {
        try dbQueue.write { db in
            var record = session
            record.updatedAt = Date()
            try record.update(db)
            return record
        }
    }

    /// Delete a session (cascades to slots via FK)
    func deleteSession(id: UUID) throws {
        try dbQueue.write { db in
            guard let session = try CockpitSession.fetchOne(db, key: id) else {
                throw CockpitSessionRepositoryError.sessionNotFound(id)
            }
            try session.delete(db)
        }
    }

    /// Fetch all sessions
    func fetchAllSessions() throws -> [CockpitSession] {
        try dbQueue.read { db in
            try CockpitSession.order(CockpitSession.Columns.createdAt.desc).fetchAll(db)
        }
    }

    // MARK: - AgentSlot CRUD

    /// Create a slot for a session
    func createSlot(_ slot: AgentSlot) throws -> AgentSlot {
        try dbQueue.write { db in
            var record = slot
            try record.insert(db)
            return record
        }
    }

    /// Fetch all slots for a session
    func fetchSlots(sessionId: UUID) throws -> [AgentSlot] {
        try dbQueue.read { db in
            try AgentSlot
                .filter(AgentSlot.Columns.cockpitSessionId == sessionId)
                .order(AgentSlot.Columns.slotIndex)
                .fetchAll(db)
        }
    }

    /// Fetch a slot by ID
    func fetchSlot(id: UUID) throws -> AgentSlot? {
        try dbQueue.read { db in
            try AgentSlot.fetchOne(db, key: id)
        }
    }

    /// Update a slot
    func updateSlot(_ slot: AgentSlot) throws -> AgentSlot {
        try dbQueue.write { db in
            var record = slot
            record.updatedAt = Date()
            try record.update(db)
            return record
        }
    }

    /// Delete a slot
    func deleteSlot(id: UUID) throws {
        try dbQueue.write { db in
            guard let slot = try AgentSlot.fetchOne(db, key: id) else {
                throw CockpitSessionRepositoryError.slotNotFound(id)
            }
            try slot.delete(db)
        }
    }

    // MARK: - AgentSlotLifecycle Guards

    /// Validate the `has_skill_assigned` guard before provisioning
    func validateProvisionGuard(slot: AgentSlot) throws {
        guard slot.hasSkillAssigned else {
            throw CockpitSessionRepositoryError.guardViolation("has_skill_assigned")
        }
    }

    /// Fetch session with all its slots in a single read
    func fetchSessionWithSlots(id: UUID) throws -> (CockpitSession, [AgentSlot])? {
        try dbQueue.read { db in
            guard let session = try CockpitSession.fetchOne(db, key: id) else {
                return nil
            }
            let slots = try session.slots.order(AgentSlot.Columns.slotIndex).fetchAll(db)
            return (session, slots)
        }
    }
}
