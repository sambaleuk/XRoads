import Foundation
import GRDB

// MARK: - AgentMessageType

/// Typed message categories on the inter-slot bus.
/// Maps to model.json AgentMessage.message_type constraint.
enum AgentMessageType: String, Codable, Hashable, Sendable, DatabaseValueConvertible {
    case status
    case question
    case blocker
    case completion
    case chairmanBrief = "chairman_brief"
}

// MARK: - AgentMessage

/// Persisted message on the inter-slot bus. Allows agent communication via SQLite.
/// Maps to AgentMessage entity from model.json.
struct AgentMessage: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var content: String
    var messageType: AgentMessageType
    var fromSlotId: UUID
    var toSlotId: UUID?
    var isBroadcast: Bool
    var readAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        content: String,
        messageType: AgentMessageType,
        fromSlotId: UUID,
        toSlotId: UUID? = nil,
        isBroadcast: Bool = false,
        readAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.messageType = messageType
        self.fromSlotId = fromSlotId
        self.toSlotId = toSlotId
        self.isBroadcast = isBroadcast
        self.readAt = readAt
        self.createdAt = createdAt
    }
}

// MARK: - GRDB Conformance

extension AgentMessage: FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_message"

    /// FK relation: AgentMessage belongs to AgentSlot (emitted_by)
    static let fromSlot = belongsTo(AgentSlot.self, using: ForeignKey(["fromSlotId"]))

    var fromSlot: QueryInterfaceRequest<AgentSlot> {
        request(for: AgentMessage.fromSlot)
    }

    enum Columns: String, ColumnExpression {
        case id, content, messageType, fromSlotId, toSlotId
        case isBroadcast, readAt, createdAt
    }
}
