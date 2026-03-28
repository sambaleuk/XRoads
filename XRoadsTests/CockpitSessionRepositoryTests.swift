import XCTest
import GRDB
@testable import XRoadsLib

/// US-001: Validates SQLite persistence of CockpitSession and AgentSlot with cascade
final class CockpitSessionRepositoryTests: XCTestCase {

    private var dbManager: CockpitDatabaseManager!
    private var repo: CockpitSessionRepository!

    override func setUp() async throws {
        try await super.setUp()
        // In-memory database for each test — isolated and fast
        dbManager = try CockpitDatabaseManager()
        repo = await CockpitSessionRepository(databaseManager: dbManager)
    }

    override func tearDown() async throws {
        repo = nil
        dbManager = nil
        try await super.tearDown()
    }

    // MARK: - CockpitSession Persistence

    func test_createCockpitSession_persistsToSQLite() async throws {
        let session = CockpitSession(
            projectPath: "/tmp/test-project",
            status: .idle
        )

        let created = try await repo.createSession(session)
        XCTAssertEqual(created.id, session.id)
        XCTAssertEqual(created.projectPath, "/tmp/test-project")
        XCTAssertEqual(created.status, .idle)

        // Verify it can be fetched back
        let fetched = try await repo.fetchSession(id: session.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.projectPath, "/tmp/test-project")
    }

    // MARK: - Unique project_path Constraint

    func test_uniqueProjectPath_blocksSecondActiveSession() async throws {
        let session1 = CockpitSession(
            projectPath: "/tmp/test-project",
            status: .idle
        )
        _ = try await repo.createSession(session1)

        // Second active session on same path should fail
        let session2 = CockpitSession(
            projectPath: "/tmp/test-project",
            status: .idle
        )

        do {
            _ = try await repo.createSession(session2)
            XCTFail("Should have thrown activeSessionExists")
        } catch let error as CockpitSessionRepositoryError {
            if case .activeSessionExists(let path) = error {
                XCTAssertEqual(path, "/tmp/test-project")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func test_uniqueProjectPath_allowsAfterClose() async throws {
        var session1 = CockpitSession(
            projectPath: "/tmp/test-project",
            status: .idle
        )
        session1 = try await repo.createSession(session1)

        // Close the first session
        session1.status = .closed
        _ = try await repo.updateSession(session1)

        // Now a new session on the same path should succeed
        let session2 = CockpitSession(
            projectPath: "/tmp/test-project",
            status: .idle
        )
        let created = try await repo.createSession(session2)
        XCTAssertEqual(created.projectPath, "/tmp/test-project")
    }

    // MARK: - Cascade Delete

    func test_cascadeDelete_removesSlots() async throws {
        let session = CockpitSession(
            projectPath: "/tmp/cascade-test",
            status: .active
        )
        let created = try await repo.createSession(session)

        // Create slots attached to the session
        let slot1 = AgentSlot(
            cockpitSessionId: created.id,
            slotIndex: 0,
            agentType: "claude"
        )
        let slot2 = AgentSlot(
            cockpitSessionId: created.id,
            slotIndex: 1,
            agentType: "gemini"
        )
        _ = try await repo.createSlot(slot1)
        _ = try await repo.createSlot(slot2)

        // Verify slots exist
        let slotsBefore = try await repo.fetchSlots(sessionId: created.id)
        XCTAssertEqual(slotsBefore.count, 2)

        // Delete the session — slots should cascade
        try await repo.deleteSession(id: created.id)

        // Verify slots are gone
        let slotsAfter = try await repo.fetchSlots(sessionId: created.id)
        XCTAssertEqual(slotsAfter.count, 0)

        // Verify session is gone
        let fetchedSession = try await repo.fetchSession(id: created.id)
        XCTAssertNil(fetchedSession)
    }

    // MARK: - AgentSlot CRUD

    func test_createAndFetchSlots() async throws {
        let session = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/slot-test", status: .active)
        )

        let slot = AgentSlot(
            cockpitSessionId: session.id,
            slotIndex: 0,
            agentType: "claude",
            worktreePath: "/tmp/worktree-0",
            branchName: "feat/slot-0"
        )
        let created = try await repo.createSlot(slot)
        XCTAssertEqual(created.slotIndex, 0)
        XCTAssertEqual(created.agentType, "claude")

        let fetched = try await repo.fetchSlot(id: slot.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.worktreePath, "/tmp/worktree-0")
    }

    func test_updateSlot_changesStatus() async throws {
        let session = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/update-test", status: .active)
        )

        var slot = AgentSlot(
            cockpitSessionId: session.id,
            slotIndex: 0,
            agentType: "claude",
            skillId: UUID()
        )
        slot = try await repo.createSlot(slot)
        XCTAssertEqual(slot.status, .empty)

        slot.status = .provisioning
        slot = try await repo.updateSlot(slot)
        XCTAssertEqual(slot.status, .provisioning)
    }

    // MARK: - Guard: has_skill_assigned

    func test_provisionGuard_blocksWithoutSkill() async throws {
        let slot = AgentSlot(
            cockpitSessionId: UUID(),
            slotIndex: 0,
            agentType: "claude",
            skillId: nil
        )

        do {
            try await repo.validateProvisionGuard(slot: slot)
            XCTFail("Should have thrown guardViolation")
        } catch let error as CockpitSessionRepositoryError {
            if case .guardViolation(let name) = error {
                XCTAssertEqual(name, "has_skill_assigned")
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    func test_provisionGuard_allowsWithSkill() async throws {
        let slot = AgentSlot(
            cockpitSessionId: UUID(),
            slotIndex: 0,
            agentType: "claude",
            skillId: UUID()
        )

        // Should not throw
        try await repo.validateProvisionGuard(slot: slot)
    }

    // MARK: - Fetch Session With Slots

    func test_fetchSessionWithSlots() async throws {
        let session = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/with-slots", status: .active)
        )

        for i in 0..<3 {
            _ = try await repo.createSlot(
                AgentSlot(
                    cockpitSessionId: session.id,
                    slotIndex: i,
                    agentType: "claude"
                )
            )
        }

        let result = try await repo.fetchSessionWithSlots(id: session.id)
        XCTAssertNotNil(result)
        let (fetchedSession, slots) = result!
        XCTAssertEqual(fetchedSession.id, session.id)
        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(slots.map(\.slotIndex), [0, 1, 2])
    }
}
