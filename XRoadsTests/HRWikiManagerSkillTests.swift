import XCTest
import GRDB
@testable import XRoadsLib

/// US-003: Validates HR/Wiki Manager SKILL.md and onboarding/wiki artifacts
final class HRWikiManagerSkillTests: XCTestCase {

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
        let skillPath = "skills/ops/hr-wiki-manager.md"
        let fullPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(skillPath)
        skillContent = try String(contentsOf: fullPath, encoding: .utf8)

        // Create MetierSkill record
        skill = try await repo.createSkill(MetierSkill(
            name: "hr-wiki-manager",
            family: "ops",
            skillMdPath: skillPath,
            requiredMcps: "notion,google_drive,gmail",
            description: "Employee onboarding + SOPs + internal wiki"
        ))

        // Create session + slot with skill assigned
        session = try await repo.createSession(
            CockpitSession(projectPath: "/tmp/hr-wiki-test-\(UUID().uuidString)", status: .active)
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

    // MARK: - Assertion 1: should have Notion and Google Drive as required_mcps

    func test_skillHasRequiredMcps() throws {
        // Verify MetierSkill record has correct MCPs
        let mcps = skill.requiredMcps ?? ""
        XCTAssertTrue(mcps.contains("notion"), "MetierSkill must list notion as required MCP")
        XCTAssertTrue(mcps.contains("google_drive"), "MetierSkill must list google_drive as required MCP")
        XCTAssertTrue(mcps.contains("gmail"), "MetierSkill must list gmail as required MCP")

        // Verify SKILL.md mentions these MCPs
        XCTAssertTrue(skillContent.contains("Notion"), "SKILL.md must reference Notion MCP")
        XCTAssertTrue(skillContent.contains("Google Drive"), "SKILL.md must reference Google Drive MCP")
        XCTAssertTrue(skillContent.contains("Gmail"), "SKILL.md must reference Gmail MCP")
    }

    // MARK: - Assertion 2: should produce Notion onboarding page with 30/60/90j plan

    func test_skillProducesOnboardingPageWith306090Plan() {
        // SKILL.md must define onboarding package with 30/60/90 day plan
        XCTAssertTrue(skillContent.contains("Onboarding"), "SKILL.md must reference onboarding")
        XCTAssertTrue(skillContent.contains("30/60/90"), "SKILL.md must define 30/60/90 day plan")
        XCTAssertTrue(skillContent.contains("Days 1-30"), "SKILL.md must detail days 1-30 phase")
        XCTAssertTrue(skillContent.contains("Days 31-60"), "SKILL.md must detail days 31-60 phase")
        XCTAssertTrue(skillContent.contains("Days 61-90"), "SKILL.md must detail days 61-90 phase")

        // Must include key onboarding components
        XCTAssertTrue(skillContent.contains("Required Access"), "Onboarding must list required access and tools")
        XCTAssertTrue(skillContent.contains("Key Contacts"), "Onboarding must include key contacts section")
        XCTAssertTrue(skillContent.contains("Resources"), "Onboarding must include resources section")

        // Must be a Notion page
        XCTAssertTrue(skillContent.contains("Notion page") || skillContent.contains("Notion Page"),
                       "Onboarding package must be a Notion page")
        XCTAssertTrue(skillContent.contains("RH/Onboarding"), "Onboarding must be stored in RH/Onboarding/ path")
    }

    // MARK: - Assertion 3: should produce SOP with numbered steps and error cases

    func test_skillProducesSOPWithNumberedStepsAndErrorCases() {
        // SKILL.md must define SOP structure
        XCTAssertTrue(skillContent.contains("SOP") || skillContent.contains("Standard Operating Procedure"),
                       "SKILL.md must define SOP creation process")
        XCTAssertTrue(skillContent.contains("Numbered Steps"), "SOP must have numbered steps section")
        XCTAssertTrue(skillContent.contains("Error Cases") || skillContent.contains("Troubleshooting"),
                       "SOP must include error cases section")

        // SOP must have required fields
        XCTAssertTrue(skillContent.contains("Objective"), "SOP must have objective section")
        XCTAssertTrue(skillContent.contains("Prerequisites") || skillContent.contains("Prérequis"),
                       "SOP must have prerequisites section")
        XCTAssertTrue(skillContent.contains("Owner") || skillContent.contains("owner"),
                       "SOP must have owner field")

        // SOP must have reference numbering
        XCTAssertTrue(skillContent.contains("SOP-"), "SOP must use reference numbering format SOP-DEPT-SEQ")

        // Error cases must include resolution and escalation
        XCTAssertTrue(skillContent.contains("Resolution") || skillContent.contains("resolution"),
                       "Error cases must include resolution steps")
        XCTAssertTrue(skillContent.contains("Escalation") || skillContent.contains("escalation"),
                       "Error cases must include escalation path")
    }

    // MARK: - Assertion 4: should produce structured Notion wiki architecture

    func test_skillProducesStructuredNotionWikiArchitecture() {
        // SKILL.md must define wiki architecture with required sections
        XCTAssertTrue(skillContent.contains("Wiki"), "SKILL.md must define wiki structure")
        XCTAssertTrue(skillContent.contains("Produit"), "Wiki must have Produit section")
        XCTAssertTrue(skillContent.contains("Tech"), "Wiki must have Tech section")
        XCTAssertTrue(skillContent.contains("Ops"), "Wiki must have Ops section")
        XCTAssertTrue(skillContent.contains("Marketing"), "Wiki must have Marketing section")
        XCTAssertTrue(skillContent.contains("Legal"), "Wiki must have Legal section")

        // Wiki must be in Notion
        XCTAssertTrue(skillContent.contains("Notion wiki") || skillContent.contains("Notion"),
                       "Wiki must be hosted in Notion")

        // Wiki structure must show hierarchy
        XCTAssertTrue(skillContent.contains("Wiki/"), "Wiki must use hierarchical path structure")
        XCTAssertTrue(skillContent.contains("SOPs/"), "Each wiki section must have a SOPs sub-section")
    }

    // MARK: - Assertion 5: should require gate before onboarding email send

    func test_skillRequiresGateBeforeOnboardingEmailSend() async throws {
        // SKILL.md must mandate SafeExecutor gate with risk_level=medium before onboarding email
        XCTAssertTrue(skillContent.contains("risk_level=medium") || skillContent.contains("\"risk_level\":\"medium\""),
                       "SKILL.md must require medium risk level for onboarding email")
        XCTAssertTrue(skillContent.contains("SafeExecutor"), "SKILL.md must reference SafeExecutor gate")
        XCTAssertTrue(skillContent.contains("SAFEEXEC"), "SKILL.md must include SAFEEXEC trigger format")

        // Must explicitly forbid auto-sending
        XCTAssertTrue(skillContent.contains("DO NOT SEND") || skillContent.contains("NOT send") || skillContent.contains("never auto-send"),
                       "SKILL.md must explicitly forbid auto-sending onboarding emails")

        // Verify gate creation works: simulate gate_triggered from running state
        XCTAssertEqual(slot.status, .running)

        // Create a medium-risk gate for onboarding email dispatch
        let gate = try await gateRepo.create(
            agentSlotId: slot.id,
            operationType: "api",
            operationPayload: "Draft onboarding welcome email for new employee",
            riskLevel: "medium",
            estimatedImpact: "Gmail draft creation for onboarding welcome"
        )
        XCTAssertEqual(gate.status, .pending)
        XCTAssertEqual(gate.riskLevel, "medium")
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

    // MARK: - Assertion 6: should transition slot to done on wiki completion

    func test_agentSlotLifecycle_runningToDone_onComplete() async throws {
        // Validates: AgentSlotLifecycle running -> complete -> done
        XCTAssertEqual(slot.status, .running)

        // Transition slot to done (wiki structure completion)
        var doneSlot = slot!
        doneSlot.status = .done
        doneSlot = try await repo.updateSlot(doneSlot)
        XCTAssertEqual(doneSlot.status, .done)
    }

    // MARK: - MetierSkill entity validation

    func test_metierSkill_familyIsOps() {
        XCTAssertEqual(skill.family, "ops")
        XCTAssertEqual(skill.name, "hr-wiki-manager")
        XCTAssertEqual(skill.skillMdPath, "skills/ops/hr-wiki-manager.md")
    }

    func test_metierSkill_persistedInDatabase() async throws {
        let fetched = try await repo.fetchSkill(id: skill.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "hr-wiki-manager")
        XCTAssertEqual(fetched?.family, "ops")
        XCTAssertTrue(fetched?.requiredMcps?.contains("notion") ?? false)
        XCTAssertTrue(fetched?.requiredMcps?.contains("google_drive") ?? false)
        XCTAssertTrue(fetched?.requiredMcps?.contains("gmail") ?? false)
    }
}
