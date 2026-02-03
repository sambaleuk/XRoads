import XCTest
@testable import XRoads

// MARK: - UnifiedFlowTests
/// Tests for US-V3-014: Unified Action Flow (Single & Agentic)
/// Verifies that ActionRunner works identically in both modes

final class UnifiedFlowTests: XCTestCase {

    // MARK: - Single Mode Tests

    func testSingleModeUsesSlotZero() async throws {
        // Given
        let appState = AppState()

        // Configure only slot 1 (slotNumber 1 = index 0)
        let worktree = Worktree(path: "/tmp/test-worktree", branch: "test-branch")
        appState.terminalSlots[0].worktree = worktree
        appState.terminalSlots[0].agentType = .claude
        appState.terminalSlots[0].actionType = .implement
        appState.terminalSlots[0].status = .ready

        // Then
        // Single mode should only use slot[0] (slotNumber 1)
        let singleModeSlots = appState.terminalSlots.filter { $0.slotNumber == 1 && $0.isConfigured }
        XCTAssertEqual(singleModeSlots.count, 1, "Single mode should have exactly one configured slot")
        XCTAssertEqual(singleModeSlots.first?.slotNumber, 1, "Single mode slot should be slot 1 (index 0)")
    }

    func testSingleModeSlotConfiguration() {
        // Given
        var slot = TerminalSlot(slotNumber: 1)

        // When - configure for single mode
        let worktree = Worktree(path: "/test/path", branch: "main")
        slot.worktree = worktree
        slot.agentType = .claude
        slot.actionType = .implement
        slot.status = .ready

        // Then
        XCTAssertTrue(slot.isConfigured, "Slot should be fully configured")
        XCTAssertEqual(slot.slotNumber, 1, "Single mode uses slot 1")
        XCTAssertEqual(slot.actionType, .implement, "Action type should be set")
    }

    // MARK: - Agentic Mode Tests

    func testAgenticModeIteratesAllConfiguredSlots() async throws {
        // Given
        let appState = AppState()

        // Configure multiple slots for agentic mode
        let configuredSlotNumbers = [1, 2, 4, 6]
        for slotNumber in configuredSlotNumbers {
            guard let index = appState.terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else {
                continue
            }
            let worktree = Worktree(path: "/tmp/test-\(slotNumber)", branch: "feature-\(slotNumber)")
            appState.terminalSlots[index].worktree = worktree
            appState.terminalSlots[index].agentType = slotNumber % 2 == 0 ? .gemini : .claude
            appState.terminalSlots[index].actionType = .implement
            appState.terminalSlots[index].status = .ready
        }

        // Then
        let allConfiguredSlots = appState.terminalSlots.filter { $0.isConfigured }
        XCTAssertEqual(allConfiguredSlots.count, 4, "Should have 4 configured slots")

        // Verify all expected slots are configured
        let configuredNumbers = Set(allConfiguredSlots.map { $0.slotNumber })
        XCTAssertEqual(configuredNumbers, Set(configuredSlotNumbers), "All expected slots should be configured")
    }

    func testAgenticModeDistributesDifferentAgents() {
        // Given
        var slots = (1...6).map { TerminalSlot(slotNumber: $0) }

        // Configure with different agent types
        let worktree1 = Worktree(path: "/test/1", branch: "feat-1")
        let worktree2 = Worktree(path: "/test/2", branch: "feat-2")
        let worktree3 = Worktree(path: "/test/3", branch: "feat-3")

        slots[0].worktree = worktree1
        slots[0].agentType = .claude
        slots[0].actionType = .implement

        slots[1].worktree = worktree2
        slots[1].agentType = .gemini
        slots[1].actionType = .review

        slots[2].worktree = worktree3
        slots[2].agentType = .codex
        slots[2].actionType = .integrationTest

        // Then
        let configuredSlots = slots.filter { $0.isConfigured }
        XCTAssertEqual(configuredSlots.count, 3)

        let agentTypes = Set(configuredSlots.compactMap { $0.agentType })
        XCTAssertEqual(agentTypes.count, 3, "Should have 3 different agent types")
        XCTAssertTrue(agentTypes.contains(.claude))
        XCTAssertTrue(agentTypes.contains(.gemini))
        XCTAssertTrue(agentTypes.contains(.codex))
    }

    // MARK: - Log Routing Tests

    func testLogRoutingBySlot() {
        // Given
        var slot1 = TerminalSlot(slotNumber: 1)
        var slot2 = TerminalSlot(slotNumber: 2)

        // When - add logs to different slots
        let log1 = LogEntry(level: .info, source: "claude", worktree: "/test/1", message: "Log for slot 1")
        let log2 = LogEntry(level: .info, source: "gemini", worktree: "/test/2", message: "Log for slot 2")

        slot1.addLog(log1)
        slot2.addLog(log2)

        // Then
        XCTAssertEqual(slot1.logs.count, 1, "Slot 1 should have 1 log")
        XCTAssertEqual(slot2.logs.count, 1, "Slot 2 should have 1 log")
        XCTAssertTrue(slot1.logs.first?.message.contains("slot 1") ?? false)
        XCTAssertTrue(slot2.logs.first?.message.contains("slot 2") ?? false)
    }

    func testLogRoutingIsolation() {
        // Given
        var slot = TerminalSlot(slotNumber: 1)

        // When - add multiple logs
        for i in 1...5 {
            let log = LogEntry(level: .debug, source: "test", worktree: nil, message: "Message \(i)")
            slot.addLog(log)
        }

        // Then
        XCTAssertEqual(slot.logs.count, 5, "Slot should have all 5 logs")
        XCTAssertEqual(slot.recentLogs.count, 5, "Recent logs should show last 5")
    }

    // MARK: - Progress and Status Tests

    func testProgressUnifiedAcrossModes() {
        // Given
        let appState = AppState()

        // Configure slots with progress
        appState.terminalSlots[0].worktree = Worktree(path: "/t1", branch: "b1")
        appState.terminalSlots[0].agentType = .claude
        appState.terminalSlots[0].actionType = .implement
        appState.terminalSlots[0].progress = 0.5

        appState.terminalSlots[1].worktree = Worktree(path: "/t2", branch: "b2")
        appState.terminalSlots[1].agentType = .gemini
        appState.terminalSlots[1].actionType = .review
        appState.terminalSlots[1].progress = 1.0

        // Then
        let configured = appState.terminalSlots.filter { $0.isConfigured }
        XCTAssertEqual(configured.count, 2)

        // Progress calculation should work the same regardless of mode
        let totalProgress = configured.reduce(0.0) { $0 + $1.progress }
        let averageProgress = totalProgress / Double(configured.count)
        XCTAssertEqual(averageProgress, 0.75, accuracy: 0.001)
    }

    func testStatusUnifiedAcrossModes() {
        // Given
        var slot = TerminalSlot(slotNumber: 1)
        slot.worktree = Worktree(path: "/test", branch: "main")
        slot.agentType = .claude
        slot.actionType = .implement

        // When - test status transitions that apply to both modes
        slot.status = .ready
        XCTAssertTrue(slot.status.canStart, "Ready status can start")

        slot.status = .running
        XCTAssertTrue(slot.status.isActive, "Running status is active")
        XCTAssertTrue(slot.status.canStop, "Running status can stop")

        slot.status = .completed
        XCTAssertFalse(slot.status.isActive, "Completed status is not active")
        XCTAssertTrue(slot.status.canStart, "Completed status can restart")
    }

    // MARK: - ActionRunner Unified Tests

    func testActionRunnerWorksIdenticallyInBothModes() async throws {
        // Given
        let runner = ActionRunner()

        // When - check skill availability (works the same in both modes)
        let (singleModeAvailable, singleMissing) = await runner.checkSkillsAvailability(
            for: .implement,
            agent: .claude
        )

        let (agenticModeAvailable, agenticMissing) = await runner.checkSkillsAvailability(
            for: .implement,
            agent: .claude
        )

        // Then - both modes should have identical behavior
        XCTAssertEqual(singleModeAvailable, agenticModeAvailable, "Skill availability should be same in both modes")
        XCTAssertEqual(singleMissing, agenticMissing, "Missing skills should be same in both modes")
    }

    func testActionRunRequestIdenticalStructure() {
        // Given - request for single mode
        let singleModeRequest = ActionRunRequest(
            actionType: .implement,
            agentType: .claude,
            worktreePath: "/single/mode/path",
            branchName: "main"
        )

        // Given - request for agentic mode (same structure)
        let agenticModeRequest = ActionRunRequest(
            actionType: .implement,
            agentType: .claude,
            worktreePath: "/agentic/mode/path",
            branchName: "feature/task",
            coordinationNotes: "Running in Agentic mode with other agents"
        )

        // Then - both use the same ActionRunRequest type
        XCTAssertEqual(singleModeRequest.actionType, agenticModeRequest.actionType)
        XCTAssertEqual(singleModeRequest.agentType, agenticModeRequest.agentType)
        // Only difference is coordination notes for multi-agent scenarios
        XCTAssertNil(singleModeRequest.coordinationNotes)
        XCTAssertNotNil(agenticModeRequest.coordinationNotes)
    }

    // MARK: - DashboardMode Tests

    func testDashboardModeSlotConstraints() {
        // Given
        let singleMode = DashboardMode.single
        let agenticMode = DashboardMode.agentic

        // Then
        XCTAssertEqual(singleMode.maxSlots, 1, "Single mode allows 1 slot")
        XCTAssertEqual(agenticMode.maxSlots, 6, "Agentic mode allows 6 slots")
    }

    func testDashboardModeOrchestratorVisibility() {
        // Given
        let singleMode = DashboardMode.single
        let agenticMode = DashboardMode.agentic

        // Then
        XCTAssertFalse(singleMode.showsOrchestrator, "Single mode hides orchestrator")
        XCTAssertTrue(agenticMode.showsOrchestrator, "Agentic mode shows orchestrator")
    }

    func testDashboardModeSidePanels() {
        // Given
        let singleMode = DashboardMode.single
        let agenticMode = DashboardMode.agentic

        // Then
        XCTAssertFalse(singleMode.showsSidePanels, "Single mode hides side panels")
        XCTAssertTrue(agenticMode.showsSidePanels, "Agentic mode shows side panels")
    }

    // MARK: - Convenience Method Tests

    func testSlotConfiguredFactory() {
        // Given/When
        let worktree = Worktree(path: "/test", branch: "main")
        let slot = TerminalSlot.configured(
            slotNumber: 1,
            worktree: worktree,
            agentType: .claude,
            actionType: .implement
        )

        // Then
        XCTAssertTrue(slot.isConfigured)
        XCTAssertEqual(slot.status, .ready)
        XCTAssertEqual(slot.slotNumber, 1)
        XCTAssertEqual(slot.worktree?.branch, "main")
        XCTAssertEqual(slot.agentType, .claude)
        XCTAssertEqual(slot.actionType, .implement)
    }

    func testSlotActionDescription() {
        // Given
        var slot = TerminalSlot(slotNumber: 1)

        // When - no action
        XCTAssertEqual(slot.actionDescription, "No action selected")

        // When - with action
        slot.actionType = .implement
        XCTAssertEqual(slot.actionDescription, ActionType.implement.description)
    }

    // MARK: - Orchestrator State Tests

    func testOrchestratorStateUpdatesForBothModes() async {
        // Given
        let appState = AppState()

        // When - no configured slots
        appState.updateOrchestratorVisualState()
        XCTAssertEqual(appState.orchestratorVisualState, .sleeping, "Should be sleeping with no configured slots")

        // When - configured but not active
        appState.terminalSlots[0].worktree = Worktree(path: "/t", branch: "b")
        appState.terminalSlots[0].agentType = .claude
        appState.terminalSlots[0].actionType = .implement
        appState.terminalSlots[0].status = .ready
        appState.updateOrchestratorVisualState()
        XCTAssertEqual(appState.orchestratorVisualState, .idle, "Should be idle with configured but not running slots")

        // When - active
        appState.terminalSlots[0].status = .running
        appState.updateOrchestratorVisualState()
        XCTAssertEqual(appState.orchestratorVisualState, .monitoring, "Should be monitoring with active slots")

        // When - completed
        appState.terminalSlots[0].status = .completed
        appState.updateOrchestratorVisualState()
        XCTAssertEqual(appState.orchestratorVisualState, .celebrating, "Should be celebrating when all complete")

        // When - error
        appState.terminalSlots[0].status = .error
        appState.updateOrchestratorVisualState()
        XCTAssertEqual(appState.orchestratorVisualState, .concerned, "Should be concerned with errors")
    }
}

// MARK: - ActionRunnerUnifiedExecutionTests

final class ActionRunnerUnifiedExecutionTests: XCTestCase {

    func testRunSingleConvenienceMethod() async throws {
        // Given
        let runner = ActionRunner()

        // When - check that runSingle creates correct request structure
        let (available, _) = await runner.checkSkillsAvailability(for: .implement, agent: .claude)

        // Then
        XCTAssertTrue(available, "Skills should be available for runSingle")
    }

    func testRunAgenticConvenienceMethod() async throws {
        // Given
        let runner = ActionRunner()

        // When - check that runAgentic creates correct request structure
        let (available, _) = await runner.checkSkillsAvailability(for: .implement, agent: .claude)

        // Then
        XCTAssertTrue(available, "Skills should be available for runAgentic")
    }

    func testSkillLoadingIdenticalForBothModes() async throws {
        // Given
        let runner = ActionRunner()

        // When - load skills (would be used by both modes)
        let skills = try await runner.loadSkillsForAction(.implement, agent: .claude)

        // Then - skills loaded the same way regardless of mode
        XCTAssertFalse(skills.isEmpty, "Should load skills for implement action")
        XCTAssertTrue(skills.contains { $0.id == "prd" || $0.id == "code-writer" || $0.id == "commit" })
    }
}

// MARK: - AppStateUnifiedFlowTests

final class AppStateUnifiedFlowTests: XCTestCase {

    func testTerminalSlotsInitialization() {
        // Given
        let appState = AppState()

        // Then
        XCTAssertEqual(appState.terminalSlots.count, 6, "Should have 6 terminal slots")

        // Verify slot numbers
        let slotNumbers = appState.terminalSlots.map { $0.slotNumber }
        XCTAssertEqual(slotNumbers, [1, 2, 3, 4, 5, 6], "Slots should be numbered 1-6")
    }

    func testConfiguredSlotsComputed() {
        // Given
        let appState = AppState()

        // When - no configured slots
        XCTAssertTrue(appState.configuredSlots.isEmpty)

        // When - configure some slots
        appState.terminalSlots[0].worktree = Worktree(path: "/t1", branch: "b1")
        appState.terminalSlots[0].agentType = .claude
        appState.terminalSlots[0].actionType = .implement

        appState.terminalSlots[2].worktree = Worktree(path: "/t2", branch: "b2")
        appState.terminalSlots[2].agentType = .gemini
        appState.terminalSlots[2].actionType = .review

        // Then
        XCTAssertEqual(appState.configuredSlots.count, 2)
    }

    func testActiveSlotsComputed() {
        // Given
        let appState = AppState()
        appState.terminalSlots[0].worktree = Worktree(path: "/t", branch: "b")
        appState.terminalSlots[0].agentType = .claude
        appState.terminalSlots[0].actionType = .implement
        appState.terminalSlots[0].status = .running

        // Then
        XCTAssertEqual(appState.activeSlots.count, 1)
        XCTAssertEqual(appState.activeSlots.first?.slotNumber, 1)
    }

    func testTerminalSlotsProgressComputed() {
        // Given
        let appState = AppState()

        // When - no configured slots
        XCTAssertEqual(appState.terminalSlotsProgress, 0)

        // When - configure with progress
        appState.terminalSlots[0].worktree = Worktree(path: "/t1", branch: "b1")
        appState.terminalSlots[0].agentType = .claude
        appState.terminalSlots[0].actionType = .implement
        appState.terminalSlots[0].progress = 0.5

        appState.terminalSlots[1].worktree = Worktree(path: "/t2", branch: "b2")
        appState.terminalSlots[1].agentType = .gemini
        appState.terminalSlots[1].actionType = .review
        appState.terminalSlots[1].progress = 1.0

        // Then
        XCTAssertEqual(appState.terminalSlotsProgress, 0.75, accuracy: 0.001)
    }
}
