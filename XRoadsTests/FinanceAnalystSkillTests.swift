import XCTest
import GRDB
@testable import XRoadsLib

/// US-001: Validates Finance Analyst SKILL.md and financial report artifacts
final class FinanceAnalystSkillTests: XCTestCase {

    private var dbManager: CockpitDatabaseManager!
    private var repo: CockpitSessionRepository!
    private var gateRepo: ExecutionGateRepository!

    // Shared fixtures
    private var session: CockpitSession!
    private var slot: AgentSlot!
    private var skill: MetierSkill!

    // SKILL.md content loaded from disk
    private var skillContent: String!

    override func setUp() async throws {
        try await super.setUp()
        dbManager = try CockpitDatabaseManager()
        let dbQueue = await dbManager.dbQueue
        repo = CockpitSessionRepository(dbQueue: dbQueue)
        gateRepo = ExecutionGateRepository(dbQueue: dbQueue)

        // Load the SKILL.md file
        let skillPath = "skills/ops/finance-analyst.md"
        let fullPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(skillPath)
        skillContent = try String(contentsOf: fullPath, encoding: .utf8)

        // Create MetierSkill record
        skill = try await repo.createSkill(MetierSkill(
            name: "finance-analyst",
            family: "ops",
            skillMdPath: skillPath,
            requiredMcps: "google_drive,gmail,web_search",
            description: "Stripe reports, anomaly alerts, financial model"
        ))

        // Create session + slot with skill assigned
        session = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/finance-test-\(UUID().uuidString)", status: .active)
        )
        slot = try await repo.createSlot(AgentSlot(
            cockpitSessionId: session.id,
            slotIndex: 0,
            status: .provisioning,
            agentType: "claude",
            skillId: skill.id
        ))
    }

    override func tearDown() async throws {
        skillContent = nil
        skill = nil
        slot = nil
        session = nil
        gateRepo = nil
        repo = nil
        dbManager = nil
        try await super.tearDown()
    }

    // MARK: - Assertion 1: should have Google Drive and Gmail as required_mcps

    func test_skillHasRequiredMcps() throws {
        // Verify MetierSkill record has correct MCPs
        let mcps = skill.requiredMcps ?? ""
        XCTAssertTrue(mcps.contains("google_drive"), "MetierSkill must list google_drive as required MCP")
        XCTAssertTrue(mcps.contains("gmail"), "MetierSkill must list gmail as required MCP")
        XCTAssertTrue(mcps.contains("web_search"), "MetierSkill must list web_search as required MCP")

        // Verify SKILL.md mentions these MCPs
        XCTAssertTrue(skillContent.contains("Google Drive"), "SKILL.md must reference Google Drive MCP")
        XCTAssertTrue(skillContent.contains("Gmail"), "SKILL.md must reference Gmail MCP")
        XCTAssertTrue(skillContent.contains("web_search"), "SKILL.md must reference web_search MCP")
    }

    // MARK: - Assertion 2: should produce Google Sheets MRR/ARR report

    func test_skillProducesRevenueReport() {
        // SKILL.md must define MRR/ARR/Churn report production
        XCTAssertTrue(skillContent.contains("MRR"), "SKILL.md must define MRR metric")
        XCTAssertTrue(skillContent.contains("ARR"), "SKILL.md must define ARR metric")
        XCTAssertTrue(skillContent.contains("Churn"), "SKILL.md must define Churn metric")
        XCTAssertTrue(skillContent.contains("Google Sheets"), "Report must target Google Sheets")
        XCTAssertTrue(skillContent.contains("Revenue Report"), "SKILL.md must produce a revenue report artifact")
    }

    // MARK: - Assertion 3: should produce anomaly alert email draft

    func test_skillProducesAnomalyAlertDraft() {
        // SKILL.md must define anomaly detection and email draft
        XCTAssertTrue(skillContent.contains("Anomaly"), "SKILL.md must define anomaly detection")
        XCTAssertTrue(skillContent.contains("20%"), "Anomaly threshold must be > 20% variation")
        XCTAssertTrue(skillContent.contains("Gmail"), "Anomaly alerts must use Gmail MCP")
        XCTAssertTrue(skillContent.contains("draft") || skillContent.contains("Draft"),
                       "Anomaly alerts must be drafts, not auto-sent")
        XCTAssertTrue(skillContent.contains("[Finance Alert]"), "Email subject must contain [Finance Alert] prefix")
    }

    // MARK: - Assertion 4: should produce 3-year financial model

    func test_skillProducesFinancialModel() {
        // SKILL.md must define 3-year financial projection model
        XCTAssertTrue(skillContent.contains("3-Year Financial Model") || skillContent.contains("3-year financial"),
                       "SKILL.md must define a 3-year financial model")
        XCTAssertTrue(skillContent.contains("36 months"), "Model must project over 36 months")
        XCTAssertTrue(skillContent.contains("Projection"), "Model must include projections")
        XCTAssertTrue(skillContent.contains("optimistic") || skillContent.contains("pessimistic"),
                       "Model must include scenario analysis")
        XCTAssertTrue(skillContent.contains("Google Sheets"), "Model must target Google Sheets")
    }

    // MARK: - Assertion 5: should require critical gate before financial data access

    func test_skillRequiresCriticalGateBeforeFinancialDataAccess() async throws {
        // SKILL.md must mandate SafeExecutor gate with risk_level=critical
        XCTAssertTrue(skillContent.contains("risk_level=critical") || skillContent.contains("\"risk_level\":\"critical\""),
                       "SKILL.md must require critical risk level for financial data access")
        XCTAssertTrue(skillContent.contains("SafeExecutor"), "SKILL.md must reference SafeExecutor gate")
        XCTAssertTrue(skillContent.contains("SAFEEXEC"), "SKILL.md must include SAFEEXEC trigger format")

        // Verify gate creation works: simulate gate_triggered from running state
        // Transition slot to running first (provisioning -> ready -> running)
        var runningSlot = slot!
        runningSlot.status = .running
        runningSlot = try await repo.updateSlot(runningSlot)
        XCTAssertEqual(runningSlot.status, .running)

        // Create a critical gate for financial data access
        let gate = try await gateRepo.create(
            agentSlotId: slot.id,
            operationType: "api",
            operationPayload: "Fetch Stripe webhook events for financial analysis",
            riskLevel: "critical",
            estimatedImpact: "Read-only access to financial transaction data"
        )
        XCTAssertEqual(gate.status, .pending)
        XCTAssertEqual(gate.riskLevel, "critical")
        XCTAssertEqual(gate.operationType, "api")

        // Verify slot transitions to waiting_approval
        var waitingSlot = runningSlot
        waitingSlot.status = .waitingApproval
        waitingSlot = try await repo.updateSlot(waitingSlot)
        XCTAssertEqual(waitingSlot.status, .waitingApproval)

        // Verify the approved_by_human guard blocks unapproved access
        XCTAssertThrowsError(
            try ExecutionGateStateMachine.transition(
                from: .awaitingApproval,
                event: .approve,
                context: ExecutionGateGuardContext(approvedByHuman: false)
            )
        ) { error in
            guard let gateError = error as? ExecutionGateStateMachineError else {
                XCTFail("Expected ExecutionGateStateMachineError")
                return
            }
            if case .guardViolation(let guardName, _) = gateError {
                XCTAssertEqual(guardName, "approved_by_human")
            } else {
                XCTFail("Expected guard violation, got \(gateError)")
            }
        }
    }

    // MARK: - Assertion 6: should never trigger payment operations

    func test_skillNeverTriggersPaymentOperations() {
        // SKILL.md must explicitly forbid payment operations
        // Must contain read-only constraint
        XCTAssertTrue(skillContent.contains("READ-ONLY") || skillContent.contains("read-only") || skillContent.contains("lecture seule"),
                       "SKILL.md must mandate read-only access to financial data")

        // Must NOT contain payment-triggering instructions (except as constraints/prohibitions)
        XCTAssertTrue(skillContent.contains("NEVER trigger payments") || skillContent.contains("never trigger payment"),
                       "SKILL.md must explicitly forbid triggering payments")

        // Must use webhook events, not direct API
        XCTAssertTrue(skillContent.contains("webhook"), "SKILL.md must use webhook events for Stripe data")
    }

    // MARK: - State machine tests from preflight

    func test_agentSlotLifecycle_provisioningToRunning_onReady() async throws {
        // Validates: AgentSlotLifecycle provisioning -> ready -> running
        XCTAssertEqual(slot.status, .provisioning)
        XCTAssertNotNil(slot.skillId, "Slot must have skill assigned for provisioning")

        // Transition to running
        var runningSlot = slot!
        runningSlot.status = .running
        runningSlot = try await repo.updateSlot(runningSlot)
        XCTAssertEqual(runningSlot.status, .running)
    }

    func test_agentSlotLifecycle_runningToWaitingApproval_onGateTriggered() async throws {
        // Validates: AgentSlotLifecycle running -> gate_triggered -> waiting_approval
        var runningSlot = slot!
        runningSlot.status = .running
        runningSlot = try await repo.updateSlot(runningSlot)

        // Create critical gate (financial data access)
        let gate = try await gateRepo.create(
            agentSlotId: slot.id,
            operationType: "api",
            operationPayload: "Fetch Stripe webhook events",
            riskLevel: "critical",
            estimatedImpact: "Read-only financial data access"
        )
        XCTAssertEqual(gate.status, .pending)

        // Transition slot to waiting_approval
        var waitingSlot = runningSlot
        waitingSlot.status = .waitingApproval
        waitingSlot = try await repo.updateSlot(waitingSlot)
        XCTAssertEqual(waitingSlot.status, .waitingApproval)
    }

    func test_executionGateGuard_blocksUnapprovedFinancialAccess() throws {
        // Validates: ExecutionGateLifecycle approve event blocked by approved_by_human guard
        XCTAssertThrowsError(
            try ExecutionGateStateMachine.transition(
                from: .awaitingApproval,
                event: .approve,
                context: ExecutionGateGuardContext(approvedByHuman: false)
            )
        ) { error in
            guard let gateError = error as? ExecutionGateStateMachineError,
                  case .guardViolation(let guardName, _) = gateError else {
                XCTFail("Expected guard violation error")
                return
            }
            XCTAssertEqual(guardName, "approved_by_human")
        }

        // Verify approval succeeds with human approval
        let newStatus = try ExecutionGateStateMachine.transition(
            from: .awaitingApproval,
            event: .approve,
            context: ExecutionGateGuardContext(approvedByHuman: true)
        )
        XCTAssertEqual(newStatus, .executing)
    }

    // MARK: - MetierSkill entity validation

    func test_metierSkill_familyIsOps() {
        XCTAssertEqual(skill.family, "ops")
        XCTAssertEqual(skill.name, "finance-analyst")
        XCTAssertEqual(skill.skillMdPath, "skills/ops/finance-analyst.md")
    }

    func test_metierSkill_persistedInDatabase() async throws {
        let fetched = try await repo.fetchSkill(id: skill.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "finance-analyst")
        XCTAssertEqual(fetched?.family, "ops")
        XCTAssertTrue(fetched?.requiredMcps?.contains("google_drive") ?? false)
    }
}
