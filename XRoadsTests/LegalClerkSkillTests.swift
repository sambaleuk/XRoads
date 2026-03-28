import XCTest
import GRDB
@testable import XRoadsLib

/// US-002: Validates Legal Clerk SKILL.md and contract generation artifacts
final class LegalClerkSkillTests: XCTestCase {

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
        let skillPath = "skills/ops/legal-clerk.md"
        let fullPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(skillPath)
        skillContent = try String(contentsOf: fullPath, encoding: .utf8)

        // Create MetierSkill record
        skill = try await repo.createSkill(MetierSkill(
            name: "legal-clerk",
            family: "ops",
            skillMdPath: skillPath,
            requiredMcps: "google_drive,gmail,notion",
            description: "Contracts MSA/SOW/NDA from templates"
        ))

        // Create session + slot with skill assigned
        session = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/legal-test-\(UUID().uuidString)", status: .active)
        )
        slot = try await repo.createSlot(AgentSlot(
            cockpitSessionId: session.id,
            slotIndex: 0,
            status: .running,
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
        XCTAssertTrue(mcps.contains("notion"), "MetierSkill must list notion as required MCP")

        // Verify SKILL.md mentions these MCPs
        XCTAssertTrue(skillContent.contains("Google Drive"), "SKILL.md must reference Google Drive MCP")
        XCTAssertTrue(skillContent.contains("Gmail"), "SKILL.md must reference Gmail MCP")
        XCTAssertTrue(skillContent.contains("Notion"), "SKILL.md must reference Notion MCP")
    }

    // MARK: - Assertion 2: should read template from Drive templates/ directory

    func test_skillReadsTemplateFromDriveTemplates() {
        // SKILL.md must reference templates/ directory in Google Drive
        XCTAssertTrue(skillContent.contains("templates/"), "SKILL.md must reference Drive templates/ directory")
        XCTAssertTrue(skillContent.contains("MSA"), "SKILL.md must define MSA template")
        XCTAssertTrue(skillContent.contains("SOW"), "SKILL.md must define SOW template")
        XCTAssertTrue(skillContent.contains("NDA"), "SKILL.md must define NDA template")
        XCTAssertTrue(skillContent.contains("Master Service Agreement"), "SKILL.md must describe MSA full name")
        XCTAssertTrue(skillContent.contains("Statement of Work"), "SKILL.md must describe SOW full name")
        XCTAssertTrue(skillContent.contains("Non-Disclosure Agreement"), "SKILL.md must describe NDA full name")
        // Templates must be read-only — never modify originals
        XCTAssertTrue(skillContent.contains("read-only") || skillContent.contains("NEVER modify"),
                       "SKILL.md must mandate templates are read-only")
    }

    // MARK: - Assertion 3: should fill all client-specific variables

    func test_skillFillsClientSpecificVariables() {
        // SKILL.md must define client variable placeholders
        XCTAssertTrue(skillContent.contains("{{CLIENT_LEGAL_NAME}}"), "SKILL.md must define CLIENT_LEGAL_NAME variable")
        XCTAssertTrue(skillContent.contains("{{PROJECT_SCOPE}}"), "SKILL.md must define PROJECT_SCOPE variable")
        XCTAssertTrue(skillContent.contains("{{CONTRACT_AMOUNT}}"), "SKILL.md must define CONTRACT_AMOUNT variable")
        XCTAssertTrue(skillContent.contains("{{START_DATE}}"), "SKILL.md must define START_DATE variable")
        XCTAssertTrue(skillContent.contains("{{END_DATE}}"), "SKILL.md must define END_DATE variable")
        XCTAssertTrue(skillContent.contains("{{CLIENT_EMAIL}}"), "SKILL.md must define CLIENT_EMAIL variable")
        XCTAssertTrue(skillContent.contains("{{PAYMENT_TERMS}}"), "SKILL.md must define PAYMENT_TERMS variable")

        // Must verify no placeholders remain after filling
        XCTAssertTrue(skillContent.contains("No `{{...}}` should remain") || skillContent.contains("no `{{...}}`"),
                       "SKILL.md must verify all placeholders are filled")
    }

    // MARK: - Assertion 4: should produce signature-ready Google Docs contract

    func test_skillProducesSignatureReadyGoogleDocs() {
        // SKILL.md must produce a Google Docs contract ready for signature
        XCTAssertTrue(skillContent.contains("Google Doc"), "SKILL.md must produce Google Docs output")
        XCTAssertTrue(skillContent.contains("signature"), "Contract must be signature-ready")
        XCTAssertTrue(skillContent.contains("Signature block") || skillContent.contains("signature block") || skillContent.contains("Signature blocks"),
                       "Contract must include signature blocks")
        XCTAssertTrue(skillContent.contains("Clients/"), "Contract must be stored in client folder")

        // Must include RGPD clause in MSA
        XCTAssertTrue(skillContent.contains("RGPD") || skillContent.contains("GDPR"),
                       "SKILL.md must include RGPD/GDPR compliance")
        XCTAssertTrue(skillContent.contains("Article 28") || skillContent.contains("article 28"),
                       "MSA must include RGPD Article 28 data processing clause")
    }

    // MARK: - Assertion 5: should draft cover email without sending

    func test_skillDraftsCoverEmailWithoutSending() {
        // SKILL.md must draft cover email via Gmail MCP without sending
        XCTAssertTrue(skillContent.contains("Gmail"), "Must use Gmail MCP for cover email")
        XCTAssertTrue(skillContent.contains("draft") || skillContent.contains("Draft"),
                       "Email must be a draft, not auto-sent")
        XCTAssertTrue(skillContent.contains("DO NOT SEND") || skillContent.contains("NOT send") || skillContent.contains("never auto-send"),
                       "SKILL.md must explicitly forbid auto-sending emails")
        XCTAssertTrue(skillContent.contains("Cover Email") || skillContent.contains("cover email"),
                       "SKILL.md must define cover email artifact")

        // Cover email must contain contract reference and client name
        XCTAssertTrue(skillContent.contains("CONTRACT_REF") || skillContent.contains("contract reference"),
                       "Cover email must include contract reference")
    }

    // MARK: - Assertion 6: should require SafeExecutor gate before dispatch

    func test_skillRequiresSafeExecutorGateBeforeDispatch() async throws {
        // SKILL.md must mandate SafeExecutor gate with risk_level=high before contract dispatch
        XCTAssertTrue(skillContent.contains("risk_level=high") || skillContent.contains("\"risk_level\":\"high\""),
                       "SKILL.md must require high risk level for contract dispatch")
        XCTAssertTrue(skillContent.contains("SafeExecutor"), "SKILL.md must reference SafeExecutor gate")
        XCTAssertTrue(skillContent.contains("SAFEEXEC"), "SKILL.md must include SAFEEXEC trigger format")

        // Verify gate creation works: simulate gate_triggered from running state
        XCTAssertEqual(slot.status, .running)

        // Create a high-risk gate for contract email dispatch
        let gate = try await gateRepo.create(
            agentSlotId: slot.id,
            operationType: "api",
            operationPayload: "Draft cover email for contract dispatch to client",
            riskLevel: "high",
            estimatedImpact: "Gmail draft creation for contract delivery"
        )
        XCTAssertEqual(gate.status, .pending)
        XCTAssertEqual(gate.riskLevel, "high")
        XCTAssertEqual(gate.operationType, "api")

        // Verify slot transitions to waiting_approval (gate_triggered event)
        var waitingSlot = slot!
        waitingSlot.status = .waitingApproval
        waitingSlot = try await repo.updateSlot(waitingSlot)
        XCTAssertEqual(waitingSlot.status, .waitingApproval)

        // Verify the approved_by_human guard blocks unapproved dispatch
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

        // Verify approval succeeds with human approval
        let newStatus = try ExecutionGateStateMachine.transition(
            from: .awaitingApproval,
            event: .approve,
            context: ExecutionGateGuardContext(approvedByHuman: true)
        )
        XCTAssertEqual(newStatus, .executing)
    }

    // MARK: - State machine test from preflight

    func test_agentSlotLifecycle_runningToWaitingApproval_onGateTriggered() async throws {
        // Validates: AgentSlotLifecycle running -> gate_triggered -> waiting_approval
        XCTAssertEqual(slot.status, .running)

        // Create high-risk gate (contract dispatch)
        let gate = try await gateRepo.create(
            agentSlotId: slot.id,
            operationType: "api",
            operationPayload: "Create contract Google Doc for client",
            riskLevel: "high",
            estimatedImpact: "Personalized contract document creation"
        )
        XCTAssertEqual(gate.status, .pending)

        // Transition slot to waiting_approval
        var waitingSlot = slot!
        waitingSlot.status = .waitingApproval
        waitingSlot = try await repo.updateSlot(waitingSlot)
        XCTAssertEqual(waitingSlot.status, .waitingApproval)
    }

    // MARK: - MetierSkill entity validation

    func test_metierSkill_familyIsOps() {
        XCTAssertEqual(skill.family, "ops")
        XCTAssertEqual(skill.name, "legal-clerk")
        XCTAssertEqual(skill.skillMdPath, "skills/ops/legal-clerk.md")
    }

    func test_metierSkill_persistedInDatabase() async throws {
        let fetched = try await repo.fetchSkill(id: skill.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "legal-clerk")
        XCTAssertEqual(fetched?.family, "ops")
        XCTAssertTrue(fetched?.requiredMcps?.contains("google_drive") ?? false)
        XCTAssertTrue(fetched?.requiredMcps?.contains("gmail") ?? false)
        XCTAssertTrue(fetched?.requiredMcps?.contains("notion") ?? false)
    }
}
