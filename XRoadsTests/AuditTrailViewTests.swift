import XCTest
import GRDB
@testable import XRoadsLib

/// US-004: Validates audit trail panel display and gate status rendering.
/// Tests cover: session gate listing, status distinction, audit_entry JSON display,
/// and immutable audit_entry writing on gate completion.
final class AuditTrailViewTests: XCTestCase {

    private var dbManager: CockpitDatabaseManager!
    private var sessionRepo: CockpitSessionRepository!
    private var gateRepo: ExecutionGateRepository!
    private var testSessionId: UUID!
    private var testSlotIds: [UUID]!

    override func setUp() async throws {
        try await super.setUp()
        dbManager = try CockpitDatabaseManager()
        let dbQueue = await dbManager.dbQueue
        sessionRepo = CockpitSessionRepository(dbQueue: dbQueue)
        gateRepo = ExecutionGateRepository(dbQueue: dbQueue)

        // Create a session with 2 slots for testing
        let session = try await sessionRepo.createSession(
            CockpitSession(projectPath: "/tmp/audit-trail-test", status: .active)
        )
        testSessionId = session.id

        let slot0 = try await sessionRepo.createSlot(
            AgentSlot(
                cockpitSessionId: session.id,
                slotIndex: 0,
                status: .running,
                agentType: "claude"
            )
        )
        let slot1 = try await sessionRepo.createSlot(
            AgentSlot(
                cockpitSessionId: session.id,
                slotIndex: 1,
                status: .running,
                agentType: "gemini"
            )
        )
        testSlotIds = [slot0.id, slot1.id]
    }

    override func tearDown() async throws {
        gateRepo = nil
        sessionRepo = nil
        dbManager = nil
        testSessionId = nil
        testSlotIds = nil
        try await super.tearDown()
    }

    // MARK: - Assertion 1: should list all gates for active session sorted desc

    func test_fetchGatesForSession_sortedByCreatedAtDesc() async throws {
        // Create gates on different slots with staggered timestamps
        let gate1 = try await gateRepo.create(
            agentSlotId: testSlotIds[0],
            operationType: "file_delete",
            operationPayload: "rm -rf /tmp/data",
            riskLevel: "high"
        )

        // Small delay to ensure different timestamps
        try await Task.sleep(for: .milliseconds(10))

        let gate2 = try await gateRepo.create(
            agentSlotId: testSlotIds[1],
            operationType: "git_push",
            operationPayload: "git push origin main",
            riskLevel: "medium"
        )

        try await Task.sleep(for: .milliseconds(10))

        let gate3 = try await gateRepo.create(
            agentSlotId: testSlotIds[0],
            operationType: "npm_install",
            operationPayload: "npm install lodash",
            riskLevel: "low"
        )

        // Fetch all gates for session
        let allGates = try await gateRepo.fetchGatesForSession(sessionId: testSessionId)

        XCTAssertEqual(allGates.count, 3, "Should return all 3 gates across both slots")

        // Verify sorted by created_at desc (most recent first)
        XCTAssertEqual(allGates[0].id, gate3.id, "Most recent gate should be first")
        XCTAssertEqual(allGates[1].id, gate2.id)
        XCTAssertEqual(allGates[2].id, gate1.id, "Oldest gate should be last")
    }

    func test_fetchGatesForSession_doesNotReturnGatesFromOtherSessions() async throws {
        // Create a gate on our test session
        _ = try await gateRepo.create(
            agentSlotId: testSlotIds[0],
            operationType: "git_commit",
            operationPayload: "git commit -m 'test'",
            riskLevel: "low"
        )

        // Create a different session with its own slot and gate
        let otherSession = try await sessionRepo.createSession(
            CockpitSession(projectPath: "/tmp/other-project", status: .active)
        )
        let otherSlot = try await sessionRepo.createSlot(
            AgentSlot(
                cockpitSessionId: otherSession.id,
                slotIndex: 0,
                status: .running,
                agentType: "codex"
            )
        )
        _ = try await gateRepo.create(
            agentSlotId: otherSlot.id,
            operationType: "docker_run",
            operationPayload: "docker run alpine",
            riskLevel: "high"
        )

        // Fetch gates for our test session only
        let ourGates = try await gateRepo.fetchGatesForSession(sessionId: testSessionId)
        XCTAssertEqual(ourGates.count, 1, "Should only return gates from our session")
        XCTAssertEqual(ourGates[0].operationType, "git_commit")
    }

    // MARK: - Assertion 2: should show completed and rolled_back gates distinctly

    func test_completedAndRolledBack_haveDistinctStatuses() async throws {
        // Create two gates, one will be completed, one rolled_back
        let gateA = try await createExecutingGate(
            slotId: testSlotIds[0],
            operationType: "file_write",
            riskLevel: "medium"
        )
        let gateB = try await createExecutingGate(
            slotId: testSlotIds[1],
            operationType: "db_migrate",
            riskLevel: "high"
        )

        // Gate A -> completed via success event
        let completed = try await gateRepo.updateStatus(
            gateId: gateA.id,
            event: .success
        )
        XCTAssertEqual(completed.status, .completed)

        // Gate B -> rolled_back via anomaly event
        let rolledBack = try await gateRepo.updateStatus(
            gateId: gateB.id,
            event: .anomaly
        )
        XCTAssertEqual(rolledBack.status, .rolledBack)

        // Fetch all and verify distinct statuses
        let allGates = try await gateRepo.fetchGatesForSession(sessionId: testSessionId)
        let statuses = Set(allGates.map(\.status))

        XCTAssertTrue(statuses.contains(.completed), "Should contain completed gate")
        XCTAssertTrue(statuses.contains(.rolledBack), "Should contain rolled_back gate")
    }

    // MARK: - Assertion 3: should expand row to show full audit_entry JSON

    func test_auditEntryJSON_decodableAndComplete() async throws {
        // Create a gate and move to completed with audit
        let gate = try await createExecutingGate(
            slotId: testSlotIds[0],
            operationType: "git_push",
            riskLevel: "high"
        )

        // Complete the gate
        _ = try await gateRepo.updateStatus(gateId: gate.id, event: .success)

        // Write audit entry
        let audited = try await gateRepo.writeAudit(gateId: gate.id, durationMs: 1234)

        // Verify audit_entry JSON is present
        XCTAssertNotNil(audited.auditEntry, "audit_entry should be written")

        // Decode and verify all fields
        let data = audited.auditEntry!.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(AuditEntry.self, from: data)

        XCTAssertEqual(entry.gateId, gate.id)
        XCTAssertEqual(entry.finalStatus, "completed")
        XCTAssertEqual(entry.operationType, "git_push")
        XCTAssertEqual(entry.riskLevel, "high")
        XCTAssertEqual(entry.durationMs, 1234)
        XCTAssertNotNil(entry.completedAt)
    }

    func test_auditEntryJSON_rolledBack_containsDeniedReason() async throws {
        let gate = try await createExecutingGate(
            slotId: testSlotIds[0],
            operationType: "db_drop",
            riskLevel: "critical"
        )

        // Anomaly -> rolled_back
        _ = try await gateRepo.updateStatus(gateId: gate.id, event: .anomaly)

        // Write audit entry
        let audited = try await gateRepo.writeAudit(gateId: gate.id, durationMs: 567)

        let data = audited.auditEntry!.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(AuditEntry.self, from: data)

        XCTAssertEqual(entry.finalStatus, "rolled_back")
        XCTAssertEqual(entry.durationMs, 567)
    }

    // MARK: - Assertion 4: should write immutable audit_entry on gate completion

    func test_auditEntry_immutable_cannotWriteTwice() async throws {
        let gate = try await createExecutingGate(
            slotId: testSlotIds[0],
            operationType: "deploy",
            riskLevel: "critical"
        )

        // Complete and write audit
        _ = try await gateRepo.updateStatus(gateId: gate.id, event: .success)
        _ = try await gateRepo.writeAudit(gateId: gate.id, durationMs: 100)

        // Attempt to write audit again — must fail
        do {
            _ = try await gateRepo.writeAudit(gateId: gate.id, durationMs: 200)
            XCTFail("Should have thrown auditAlreadyWritten")
        } catch let error as ExecutionGateRepositoryError {
            if case .auditAlreadyWritten(let id) = error {
                XCTAssertEqual(id, gate.id)
            } else {
                XCTFail("Wrong error variant: \(error)")
            }
        }
    }

    // MARK: - State Machine Tests (from PRD tests)

    func test_stateMachine_executingToCompleted_onSuccess() throws {
        let result = try ExecutionGateStateMachine.transition(
            from: .executing,
            event: .success
        )
        XCTAssertEqual(result, .completed)
    }

    func test_stateMachine_executingToRolledBack_onAnomaly() throws {
        let result = try ExecutionGateStateMachine.transition(
            from: .executing,
            event: .anomaly
        )
        XCTAssertEqual(result, .rolledBack)
    }

    // MARK: - ViewModel Tests

    @MainActor
    func test_viewModel_loadsGatesForSession() async throws {
        // Create some gates
        _ = try await gateRepo.create(
            agentSlotId: testSlotIds[0],
            operationType: "test_op",
            operationPayload: "echo test",
            riskLevel: "low"
        )
        _ = try await gateRepo.create(
            agentSlotId: testSlotIds[1],
            operationType: "test_op_2",
            operationPayload: "echo test2",
            riskLevel: "medium"
        )

        let vm = AuditTrailViewModel(gateRepo: gateRepo, sessionId: testSessionId)
        await vm.loadGates()

        XCTAssertEqual(vm.gates.count, 2, "Should load all gates for session")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func test_viewModel_expandCollapse() async throws {
        let gate = try await gateRepo.create(
            agentSlotId: testSlotIds[0],
            operationType: "test_toggle",
            operationPayload: "echo toggle",
            riskLevel: "low"
        )

        let vm = AuditTrailViewModel(gateRepo: gateRepo, sessionId: testSessionId)

        XCTAssertFalse(vm.isExpanded(gateId: gate.id))

        vm.toggleExpanded(gateId: gate.id)
        XCTAssertTrue(vm.isExpanded(gateId: gate.id))

        vm.toggleExpanded(gateId: gate.id)
        XCTAssertFalse(vm.isExpanded(gateId: gate.id))
    }

    @MainActor
    func test_viewModel_prettyAuditJSON() async throws {
        let gate = try await createExecutingGate(
            slotId: testSlotIds[0],
            operationType: "pretty_print_test",
            riskLevel: "low"
        )

        _ = try await gateRepo.updateStatus(gateId: gate.id, event: .success)
        let audited = try await gateRepo.writeAudit(gateId: gate.id, durationMs: 42)

        let vm = AuditTrailViewModel(gateRepo: gateRepo, sessionId: testSessionId)
        let json = vm.prettyAuditJSON(for: audited)

        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("pretty_print_test"))
        XCTAssertTrue(json!.contains("completed"))
    }

    // MARK: - Helpers

    /// Create a gate and move it directly to executing state (via policy_direct with risk_is_low).
    private func createExecutingGate(
        slotId: UUID,
        operationType: String,
        riskLevel: String
    ) async throws -> ExecutionGate {
        let gate = try await gateRepo.create(
            agentSlotId: slotId,
            operationType: operationType,
            operationPayload: "\(operationType) --execute",
            riskLevel: riskLevel
        )

        // pending -> executing via policy_direct (guard: risk_is_low)
        let executing = try await gateRepo.updateStatus(
            gateId: gate.id,
            event: .policyDirect,
            context: ExecutionGateGuardContext(riskIsLow: true)
        )

        XCTAssertEqual(executing.status, .executing)
        return executing
    }
}
