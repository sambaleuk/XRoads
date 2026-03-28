import Foundation
import GRDB

// MARK: - AgentSlotStatus

/// Maps to AgentSlotLifecycle states from states.json
enum AgentSlotStatus: String, Codable, Hashable, Sendable, DatabaseValueConvertible {
    case empty
    case provisioning
    case running
    case waitingApproval = "waiting_approval"
    case paused
    case done
    case error
}

// MARK: - AgentSlot

/// Persisted agent slot within a cockpit session.
/// Maps to AgentSlot entity from model.json.
struct AgentSlot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var cockpitSessionId: UUID
    var slotIndex: Int
    var status: AgentSlotStatus
    var agentType: String
    var worktreePath: String?
    var branchName: String?
    var skillId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        cockpitSessionId: UUID,
        slotIndex: Int,
        status: AgentSlotStatus = .empty,
        agentType: String,
        worktreePath: String? = nil,
        branchName: String? = nil,
        skillId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.cockpitSessionId = cockpitSessionId
        self.slotIndex = slotIndex
        self.status = status
        self.agentType = agentType
        self.worktreePath = worktreePath
        self.branchName = branchName
        self.skillId = skillId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB Conformance

extension AgentSlot: FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_slot"

    static let cockpitSession = belongsTo(CockpitSession.self)

    var cockpitSession: QueryInterfaceRequest<CockpitSession> {
        request(for: AgentSlot.cockpitSession)
    }

    enum Columns: String, ColumnExpression {
        case id, cockpitSessionId, slotIndex, status, agentType
        case worktreePath, branchName, skillId, createdAt, updatedAt
    }
}

// MARK: - Guard: has_skill_assigned

extension AgentSlot {
    /// Guard from AgentSlotLifecycle: provision requires a skill assigned
    var hasSkillAssigned: Bool {
        skillId != nil
    }
}
