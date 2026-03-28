import Foundation
import GRDB

// MARK: - CockpitSessionStatus

/// Maps to CockpitLifecycle states from states.json
enum CockpitSessionStatus: String, Codable, Hashable, Sendable, DatabaseValueConvertible {
    case idle
    case initializing
    case active
    case paused
    case closed
}

// MARK: - CockpitSession

/// Persisted cockpit session. Aggregate root for orchestration mode.
/// Maps to CockpitSession entity from model.json.
struct CockpitSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var projectPath: String
    var status: CockpitSessionStatus
    var chairmanBrief: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectPath: String,
        status: CockpitSessionStatus = .idle,
        chairmanBrief: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectPath = projectPath
        self.status = status
        self.chairmanBrief = chairmanBrief
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB Conformance

extension CockpitSession: FetchableRecord, PersistableRecord {
    static let databaseTableName = "cockpit_session"

    static let slots = hasMany(AgentSlot.self)

    var slots: QueryInterfaceRequest<AgentSlot> {
        request(for: CockpitSession.slots)
    }

    enum Columns: String, ColumnExpression {
        case id, projectPath, status, chairmanBrief, createdAt, updatedAt
    }
}
