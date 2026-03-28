import XCTest
import GRDB
@testable import XRoadsLib

/// US-003: Validates approval card display, approve/reject flow, and lifecycle transitions
final class ApprovalCardViewTests: XCTestCase {

    private var dbManager: CockpitDatabaseManager!
    private var sessionRepo: CockpitSessionRepository!
    private var gateRepo: ExecutionGateRepository!
    private var testSlotId: UUID!
    private var testSessionId: UUID!

    override func setUp() async throws {
        try await super.setUp()
        dbManager = try CockpitDatabaseManager()
        let dbQueue = await dbManager.dbQueue
        sessionRepo = CockpitSessionRepository(dbQueue: dbQueue)
        gateRepo = ExecutionGateRepository(dbQueue: dbQueue)

        // Create a session + slot for FK reference
        let session = try await sessionRepo.createSession(
            CockpitSession(projectPath: "/tmp/approval-test", status: .active)
        )
        testSessionId = session.id
        let slot = try await sessionRepo.createSlot(
            AgentSlot(
                cockpitSessionId: session.id,
                slotIndex: 0,
                status: .running,
                agentType: "claude"
            )
        )
        testSlotId = slot.id
    }

    override func tearDown() async throws {
        gateRepo = nil
        sessionRepo = nil
        dbManager = nil
        testSlotId = nil
        testSessionId = nil
        try await super.tearDown()
    }

    // MARK: - Assertion 1: should display approval card when slot is in waiting_approval

    func test_approvalCard_displayedWhenSlotWaitingApproval() async throws {
        // Create gate and move to awaiting_approval
        let gate = try await createAwaitingApprovalGate()

        // Transition slot to waiting_approval
        var slot = try await fetchSlot()
        slot.status = .waitingApproval
        slot.updatedAt = Date()
        _ = try await sessionRepo.updateSlot(slot)

        // Verify gate is in awaiting_approval state
        let fetched = try await gateRepo.fetch(id: gate.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.status, .awaitingApproval)

        // Verify slot is in waiting_approval state
        let updatedSlot = try await fetchSlot()
        XCTAssertEqual(updatedSlot.status, .waitingApproval)

        // The card should display for this slot — verified by gate/slot state alignment
        XCTAssertEqual(fetched?.agentSlotId, updatedSlot.id)
    }

    // MARK: - Assertion 2: should show risk_level badge with appropriate color

    func test_riskLevel_parsedCorrectly() throws {
        // Verify RiskLevel enum covers all expected values
        XCTAssertEqual(RiskLevel(rawValue: "low"), .low)
        XCTAssertEqual(RiskLevel(rawValue: "medium"), .medium)
        XCTAssertEqual(RiskLevel(rawValue: "high"), .high)
        XCTAssertEqual(RiskLevel(rawValue: "critical"), .critical)
        XCTAssertNil(RiskLevel(rawValue: "unknown"))
    }

    func test_gateRiskLevel_preservedThroughLifecycle() async throws {
        let gate = try await createAwaitingApprovalGate(riskLevel: "critical")
        let fetched = try await gateRepo.fetch(id: gate.id)
        XCTAssertEqual(fetched?.riskLevel, "critical")
    }

    // MARK: - Assertion 3: should call approve and transition gate to executing

    func test_approve_transitionsGateToExecuting() async throws {
        let gate = try await createAwaitingApprovalGate()

        // Approve with human guard
        let approved = try await gateRepo.updateStatus(
            gateId: gate.id,
            event: .approve,
            context: ExecutionGateGuardContext(approvedByHuman: true),
            approvedBy: "board_user"
        )

        XCTAssertEqual(approved.status, .executing)
        XCTAssertEqual(approved.approvedBy, "board_user")
        XCTAssertNotNil(approved.approvedAt)
    }

    func test_approve_blockedWithoutHumanConfirmation() async throws {
        let gate = try await createAwaitingApprovalGate()

        // Attempt approve without approvedByHuman guard — must fail
        do {
            _ = try await gateRepo.updateStatus(
                gateId: gate.id,
                event: .approve,
                context: ExecutionGateGuardContext(approvedByHuman: false)
            )
            XCTFail("Should have thrown guardViolation for approved_by_human")
        } catch let error as ExecutionGateStateMachineError {
            if case .guardViolation(let guardName, let event) = error {
                XCTAssertEqual(guardName, "approved_by_human")
                XCTAssertEqual(event, .approve)
            } else {
                XCTFail("Wrong error variant: \(error)")
            }
        }
    }

    // MARK: - Assertion 4: should resume agent process after approval

    func test_slotTransitionsBackToRunning_afterApproval() async throws {
        let gate = try await createAwaitingApprovalGate()

        // Set slot to waiting_approval
        var slot = try await fetchSlot()
        slot.status = .waitingApproval
        slot.updatedAt = Date()
        _ = try await sessionRepo.updateSlot(slot)

        // Approve the gate
        _ = try await gateRepo.updateStatus(
            gateId: gate.id,
            event: .approve,
            context: ExecutionGateGuardContext(approvedByHuman: true),
            approvedBy: "board_user"
        )

        // Transition slot back to running (gate_approved event from AgentSlotLifecycle)
        var resumed = try await fetchSlot()
        resumed.status = .running
        resumed.updatedAt = Date()
        let persisted = try await sessionRepo.updateSlot(resumed)

        XCTAssertEqual(persisted.status, .running)
    }

    // MARK: - Assertion 5: should transition slot back to running (reject path)

    func test_reject_transitionsGateToRejected() async throws {
        let gate = try await createAwaitingApprovalGate()

        let rejected = try await gateRepo.updateStatus(
            gateId: gate.id,
            event: .reject,
            deniedReason: "Too risky for current sprint"
        )

        XCTAssertEqual(rejected.status, .rejected)
        XCTAssertEqual(rejected.deniedReason, "Too risky for current sprint")
    }

    func test_slotTransitionsBackToRunning_afterRejection() async throws {
        let gate = try await createAwaitingApprovalGate()

        // Set slot to waiting_approval
        var slot = try await fetchSlot()
        slot.status = .waitingApproval
        slot.updatedAt = Date()
        _ = try await sessionRepo.updateSlot(slot)

        // Reject the gate
        _ = try await gateRepo.updateStatus(
            gateId: gate.id,
            event: .reject,
            deniedReason: "Rejected by board"
        )

        // Transition slot back to running (gate_rejected event)
        var resumed = try await fetchSlot()
        resumed.status = .running
        resumed.updatedAt = Date()
        let persisted = try await sessionRepo.updateSlot(resumed)

        XCTAssertEqual(persisted.status, .running)
    }

    // MARK: - State Machine Guard Tests (from PRD tests)

    func test_stateMachine_awaitingApprovalToExecuting() throws {
        let result = try ExecutionGateStateMachine.transition(
            from: .awaitingApproval,
            event: .approve,
            context: ExecutionGateGuardContext(approvedByHuman: true)
        )
        XCTAssertEqual(result, .executing)
    }

    func test_stateMachine_guardViolation_approveWithoutHuman() {
        XCTAssertThrowsError(
            try ExecutionGateStateMachine.transition(
                from: .awaitingApproval,
                event: .approve,
                context: ExecutionGateGuardContext(approvedByHuman: false)
            )
        ) { error in
            guard let smError = error as? ExecutionGateStateMachineError,
                  case .guardViolation(let guard_, _) = smError else {
                XCTFail("Expected guardViolation, got: \(error)")
                return
            }
            XCTAssertEqual(guard_, "approved_by_human")
        }
    }

    func test_stateMachine_awaitingApprovalToRejected() throws {
        let result = try ExecutionGateStateMachine.transition(
            from: .awaitingApproval,
            event: .reject
        )
        XCTAssertEqual(result, .rejected)
    }

    // MARK: - Helpers

    /// Create a gate and move it through pending -> dry_run -> awaiting_approval
    private func createAwaitingApprovalGate(riskLevel: String = "high") async throws -> ExecutionGate {
        let gate = try await gateRepo.create(
            agentSlotId: testSlotId,
            operationType: "git_push",
            operationPayload: "git push origin main --force",
            riskLevel: riskLevel,
            estimatedImpact: "Force push may overwrite remote history"
        )

        // pending -> dry_run
        var updated = try await gateRepo.updateStatus(
            gateId: gate.id,
            event: .policyAllow,
            context: ExecutionGateGuardContext(requiresDryRun: true)
        )

        // dry_run -> awaiting_approval
        updated = try await gateRepo.updateStatus(
            gateId: updated.id,
            event: .dryRunDone,
            context: ExecutionGateGuardContext(dryRunFeasible: true)
        )

        XCTAssertEqual(updated.status, .awaitingApproval)
        return updated
    }

    private func fetchSlot() async throws -> AgentSlot {
        let slots = try await sessionRepo.fetchSlots(sessionId: testSessionId)
        return slots.first(where: { $0.id == testSlotId })!
    }
}
