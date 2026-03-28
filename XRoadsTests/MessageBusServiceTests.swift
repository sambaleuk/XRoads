import XCTest
import GRDB
@testable import XRoadsLib

/// US-001: Validates AgentMessage persistence and pub/sub mechanics
final class MessageBusServiceTests: XCTestCase {

    private var dbManager: CockpitDatabaseManager!
    private var repo: CockpitSessionRepository!
    private var bus: MessageBusService!

    // Shared test fixtures
    private var session: CockpitSession!
    private var slot: AgentSlot!

    override func setUp() async throws {
        try await super.setUp()
        dbManager = try CockpitDatabaseManager()
        repo = await CockpitSessionRepository(databaseManager: dbManager)
        bus = await MessageBusService(databaseManager: dbManager)

        // Create a session + slot for all tests
        session = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/bus-test", status: .active)
        )
        slot = try await repo.createSlot(
            AgentSlot(
                cockpitSessionId: session.id,
                slotIndex: 0,
                agentType: "claude"
            )
        )
    }

    override func tearDown() async throws {
        bus = nil
        repo = nil
        dbManager = nil
        session = nil
        slot = nil
        try await super.tearDown()
    }

    // MARK: - Persistence

    func test_publish_persistsAgentMessageToSQLite() async throws {
        let message = AgentMessage(
            content: "Working on feature X",
            messageType: .status,
            fromSlotId: slot.id,
            isBroadcast: true
        )

        let persisted = try await bus.publish(message: message, fromSlot: slot.id)

        XCTAssertEqual(persisted.id, message.id)
        XCTAssertEqual(persisted.content, "Working on feature X")
        XCTAssertEqual(persisted.messageType, .status)
        XCTAssertEqual(persisted.fromSlotId, slot.id)
        XCTAssertTrue(persisted.isBroadcast)

        // Verify it can be fetched back from DB
        let fetched = try await bus.fetchMessages(slotId: slot.id)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.content, "Working on feature X")
    }

    // MARK: - Pub/Sub via AsyncStream

    func test_subscribe_notifiesOnNewMessage() async throws {
        let stream = await bus.subscribe(toSession: session.id)
        var iterator = stream.makeAsyncIterator()

        // Publish a message
        let message = AgentMessage(
            content: "I have a question",
            messageType: .question,
            fromSlotId: slot.id
        )
        try await bus.publish(message: message, fromSlot: slot.id)

        // Subscriber should receive it
        let received = await iterator.next()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.content, "I have a question")
        XCTAssertEqual(received?.messageType, .question)
    }

    // MARK: - Cascade Delete

    func test_cascadeDelete_removesMessagesOnSlotDeletion() async throws {
        // Publish messages
        for i in 0..<3 {
            let msg = AgentMessage(
                content: "Message \(i)",
                messageType: .status,
                fromSlotId: slot.id
            )
            try await bus.publish(message: msg, fromSlot: slot.id)
        }

        // Verify messages exist
        let before = try await bus.fetchMessages(slotId: slot.id)
        XCTAssertEqual(before.count, 3)

        // Delete the slot — messages should cascade
        try await repo.deleteSlot(id: slot.id)

        // Verify messages are gone
        let after = try await bus.fetchMessages(slotId: slot.id)
        XCTAssertEqual(after.count, 0)
    }

    // MARK: - Session Filtering

    func test_fetchMessages_filtersByCockpitSession() async throws {
        // Create a second session + slot
        let session2 = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/bus-test-2", status: .active)
        )
        let slot2 = try await repo.createSlot(
            AgentSlot(
                cockpitSessionId: session2.id,
                slotIndex: 0,
                agentType: "gemini"
            )
        )

        // Publish to first session's slot
        try await bus.publish(
            message: AgentMessage(content: "From session 1", messageType: .status, fromSlotId: slot.id),
            fromSlot: slot.id
        )

        // Publish to second session's slot
        try await bus.publish(
            message: AgentMessage(content: "From session 2", messageType: .completion, fromSlotId: slot2.id),
            fromSlot: slot2.id
        )

        // Fetch for session 1 — should only see session 1 messages
        let session1Messages = try await bus.fetchMessages(sessionId: session.id)
        XCTAssertEqual(session1Messages.count, 1)
        XCTAssertEqual(session1Messages.first?.content, "From session 1")

        // Fetch for session 2 — should only see session 2 messages
        let session2Messages = try await bus.fetchMessages(sessionId: session2.id)
        XCTAssertEqual(session2Messages.count, 1)
        XCTAssertEqual(session2Messages.first?.content, "From session 2")
    }

    // MARK: - Message Types

    func test_allMessageTypes_persistCorrectly() async throws {
        let types: [AgentMessageType] = [.status, .question, .blocker, .completion, .chairmanBrief]

        for msgType in types {
            let msg = AgentMessage(
                content: "Type: \(msgType.rawValue)",
                messageType: msgType,
                fromSlotId: slot.id
            )
            try await bus.publish(message: msg, fromSlot: slot.id)
        }

        let all = try await bus.fetchMessages(slotId: slot.id)
        XCTAssertEqual(all.count, 5)

        let persistedTypes = Set(all.map(\.messageType))
        XCTAssertEqual(persistedTypes, Set(types))
    }

    // MARK: - Relation Integrity

    func test_agentMessage_linkedToAgentSlot() async throws {
        let msg = AgentMessage(
            content: "Linked to slot",
            messageType: .status,
            fromSlotId: slot.id
        )
        try await bus.publish(message: msg, fromSlot: slot.id)

        // Verify FK relation — fetch the slot's messages
        let messages = try await bus.fetchMessages(slotId: slot.id)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.fromSlotId, slot.id)
    }

    func test_agentMessage_linkedToCockpitSession_cascadeDelete() async throws {
        // Publish a message
        try await bus.publish(
            message: AgentMessage(content: "Will be cascade deleted", messageType: .blocker, fromSlotId: slot.id),
            fromSlot: slot.id
        )

        // Verify message exists
        let before = try await bus.fetchMessages(sessionId: session.id)
        XCTAssertEqual(before.count, 1)

        // Delete the session — cascades to slots, which cascades to messages
        try await repo.deleteSession(id: session.id)

        // Messages should be gone (slot was cascade-deleted, which cascade-deletes messages)
        let after = try await bus.fetchMessages(slotId: slot.id)
        XCTAssertEqual(after.count, 0)
    }
}
