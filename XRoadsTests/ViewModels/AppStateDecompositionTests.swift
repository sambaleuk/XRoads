//
//  AppStateDecompositionTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-06.
//  CR-301: Verify AppState God Object is decomposed into focused sub-states
//

import XCTest
@testable import XRoadsLib

@MainActor
final class AppStateDecompositionTests: XCTestCase {

    // MARK: - Sub-State Existence Tests

    /// Verifies DashboardState exists as a separate @Observable class
    func test_dashboardState_existsAsSeparateClass() {
        let dashboard = DashboardState()
        XCTAssertNotNil(dashboard, "DashboardState should be instantiable as a separate class")
    }

    /// Verifies DispatchState exists as a separate @Observable class
    func test_dispatchState_existsAsSeparateClass() {
        let dispatch = DispatchState()
        XCTAssertNotNil(dispatch, "DispatchState should be instantiable as a separate class")
    }

    /// Verifies OrchestrationSubState exists as a separate @Observable class
    func test_orchestrationSubState_existsAsSeparateClass() {
        let orchestration = OrchestrationSubState()
        XCTAssertNotNil(orchestration, "OrchestrationSubState should be instantiable as a separate class")
    }

    // MARK: - Composition Tests

    /// Verifies AppState composes sub-states via stored properties
    func test_appState_composesDashboardState() {
        let appState = AppState()
        XCTAssertNotNil(appState.dashboard, "AppState should expose DashboardState via .dashboard")
    }

    func test_appState_composesDispatchState() {
        let appState = AppState()
        XCTAssertNotNil(appState.dispatch, "AppState should expose DispatchState via .dispatch")
    }

    func test_appState_composesOrchestrationState() {
        let appState = AppState()
        XCTAssertNotNil(appState.orchestration, "AppState should expose OrchestrationSubState via .orchestration")
    }

    // MARK: - DashboardState Property Tests

    /// Verifies DashboardState owns terminal slots
    func test_dashboardState_ownsTerminalSlots() {
        let dashboard = DashboardState()
        XCTAssertEqual(dashboard.terminalSlots.count, 6, "DashboardState should have 6 terminal slots")
    }

    /// Verifies DashboardState owns orchestrator visual state
    func test_dashboardState_ownsOrchestratorVisualState() {
        let dashboard = DashboardState()
        XCTAssertEqual(dashboard.orchestratorVisualState, .sleeping, "Default orchestrator visual state should be .sleeping")
    }

    /// Verifies DashboardState owns dashboard mode
    func test_dashboardState_ownsDashboardMode() {
        let dashboard = DashboardState()
        XCTAssertEqual(dashboard.dashboardMode, .agentic, "Default dashboard mode should be .agentic")
    }

    /// Verifies DashboardState owns git info
    func test_dashboardState_ownsGitInfo() {
        let dashboard = DashboardState()
        XCTAssertFalse(dashboard.isGitRepository, "Default isGitRepository should be false")
        XCTAssertFalse(dashboard.isInitializingGit, "Default isInitializingGit should be false")
        XCTAssertTrue(dashboard.recentCommits.isEmpty, "Default recentCommits should be empty")
    }

    /// Verifies DashboardState computed properties work
    func test_dashboardState_computedProperties() {
        let dashboard = DashboardState()
        XCTAssertTrue(dashboard.activeSlots.isEmpty, "No slots should be active by default")
        XCTAssertTrue(dashboard.configuredSlots.isEmpty, "No slots should be configured by default")
        XCTAssertEqual(dashboard.terminalSlotsProgress, 0, "Default progress should be 0")
    }

    // MARK: - DispatchState Property Tests

    /// Verifies DispatchState owns dispatch phase and progress
    func test_dispatchState_ownsDispatchPhase() {
        let dispatch = DispatchState()
        XCTAssertEqual(dispatch.dispatchPhase, .idle, "Default dispatch phase should be .idle")
        XCTAssertNil(dispatch.dispatchProgress, "Default dispatch progress should be nil")
        XCTAssertTrue(dispatch.dispatchMessage.isEmpty, "Default dispatch message should be empty")
    }

    /// Verifies DispatchState computed isDispatching
    func test_dispatchState_isDispatching_idle() {
        let dispatch = DispatchState()
        XCTAssertFalse(dispatch.isDispatching, "isDispatching should be false when idle")
    }

    /// Verifies DispatchState owns global logs
    func test_dispatchState_ownsGlobalLogs() {
        let dispatch = DispatchState()
        XCTAssertTrue(dispatch.globalLogs.isEmpty, "Default global logs should be empty")
    }

    /// Verifies DispatchState owns layer tracking
    func test_dispatchState_ownsLayerTracking() {
        let dispatch = DispatchState()
        XCTAssertNil(dispatch.currentPRD, "Default currentPRD should be nil")
        XCTAssertEqual(dispatch.currentDispatchLayer, 0, "Default current layer should be 0")
        XCTAssertEqual(dispatch.totalDispatchLayers, 0, "Default total layers should be 0")
    }

    // MARK: - OrchestrationSubState Property Tests

    /// Verifies OrchestrationSubState owns orchestration session
    func test_orchestrationState_ownsSession() {
        let orch = OrchestrationSubState()
        XCTAssertNil(orch.orchestrationSessionID, "Default session ID should be nil")
        XCTAssertEqual(orch.orchestrationState, .idle, "Default orchestration state should be .idle")
        XCTAssertFalse(orch.isOrchestrating, "isOrchestrating should be false when idle")
    }

    /// Verifies OrchestrationSubState owns agent assignments
    func test_orchestrationState_ownsAgentAssignments() {
        let orch = OrchestrationSubState()
        XCTAssertTrue(orch.agentAssignments.isEmpty, "Default agent assignments should be empty")
        XCTAssertTrue(orch.agentStatusSnapshots.isEmpty, "Default agent status snapshots should be empty")
        XCTAssertTrue(orch.agentTimelineEvents.isEmpty, "Default agent timeline events should be empty")
    }

    /// Verifies OrchestrationSubState owns health monitoring
    func test_orchestrationState_ownsHealthMonitoring() {
        let orch = OrchestrationSubState()
        XCTAssertTrue(orch.agentHealthMetrics.isEmpty, "Default health metrics should be empty")
        XCTAssertTrue(orch.agentHealthIssues.isEmpty, "Default health issues should be empty")
        XCTAssertNil(orch.presentedHealthIssue, "Default presented health issue should be nil")
    }

    /// Verifies OrchestrationSubState owns merge state
    func test_orchestrationState_ownsMergeState() {
        let orch = OrchestrationSubState()
        XCTAssertNil(orch.mergePlan, "Default merge plan should be nil")
        XCTAssertNil(orch.mergeResult, "Default merge result should be nil")
        XCTAssertNil(orch.orchestrationRepoPath, "Default repo path should be nil")
        XCTAssertTrue(orch.conflictFiles.isEmpty, "Default conflict files should be empty")
        XCTAssertFalse(orch.isConflictSheetPresented, "Default conflict sheet should not be presented")
    }

    /// Verifies OrchestrationSubState owns history and PRD
    func test_orchestrationState_ownsHistoryAndPRD() {
        let orch = OrchestrationSubState()
        XCTAssertTrue(orch.historyRecords.isEmpty, "Default history records should be empty")
        XCTAssertFalse(orch.showHistorySheet, "Default show history sheet should be false")
        XCTAssertNil(orch.pendingPRDURL, "Default pending PRD URL should be nil")
        XCTAssertNil(orch.activePRDURL, "Default active PRD URL should be nil")
        XCTAssertNil(orch.activePRDName, "Default active PRD name should be nil")
    }

    // MARK: - Delegation Tests

    /// Verifies AppState delegates dashboard properties correctly
    func test_appState_delegatesDashboardMode() {
        let appState = AppState()
        appState.dashboardMode = .single
        XCTAssertEqual(appState.dashboard.dashboardMode, .single, "Setting dashboardMode on AppState should update DashboardState")
        XCTAssertEqual(appState.dashboardMode, .single, "Reading dashboardMode from AppState should reflect DashboardState")
    }

    /// Verifies AppState delegates dispatch properties correctly
    func test_appState_delegatesDispatchPhase() {
        let appState = AppState()
        appState.dispatchPhase = .completed
        XCTAssertEqual(appState.dispatch.dispatchPhase, .completed, "Setting dispatchPhase on AppState should update DispatchState")
        XCTAssertEqual(appState.dispatchPhase, .completed, "Reading dispatchPhase from AppState should reflect DispatchState")
    }

    /// Verifies AppState delegates orchestration properties correctly
    func test_appState_delegatesOrchestrationState() {
        let appState = AppState()
        appState.orchestrationState = .analyzing
        XCTAssertEqual(appState.orchestration.orchestrationState, .analyzing, "Setting orchestrationState on AppState should update OrchestrationSubState")
        XCTAssertTrue(appState.isOrchestrating, "isOrchestrating should reflect OrchestrationSubState")
    }

    // MARK: - Sub-State Method Tests

    /// Verifies DashboardState updateOrchestratorVisualState works
    func test_dashboardState_updateOrchestratorVisualState() {
        let dashboard = DashboardState()
        // All slots unconfigured -> sleeping
        dashboard.updateOrchestratorVisualState()
        XCTAssertEqual(dashboard.orchestratorVisualState, .sleeping, "Should be sleeping when no slots configured")
    }

    /// Verifies OrchestrationSubState clearAssignments works
    func test_orchestrationState_clearAssignments() {
        let orch = OrchestrationSubState()
        orch.agentAssignments["test"] = TaskAssignment(
            id: UUID(),
            storyIds: ["S-1"],
            agentType: .claude,
            worktreePath: URL(fileURLWithPath: "/tmp/test"),
            priority: .medium
        )
        orch.agentStatusSnapshots["test"] = AgentStatusSnapshot(
            agentId: "test",
            agentType: nil,
            worktreePath: nil,
            state: .idle,
            currentStoryId: nil,
            progress: 0,
            message: "",
            timestamp: Date()
        )
        XCTAssertEqual(orch.agentAssignments.count, 1)
        XCTAssertEqual(orch.agentStatusSnapshots.count, 1)

        orch.clearAssignments()

        XCTAssertTrue(orch.agentAssignments.isEmpty, "clearAssignments should empty agentAssignments")
        XCTAssertTrue(orch.agentStatusSnapshots.isEmpty, "clearAssignments should empty agentStatusSnapshots")
        XCTAssertTrue(orch.agentTimelineEvents.isEmpty, "clearAssignments should empty agentTimelineEvents")
        XCTAssertTrue(orch.agentHealthMetrics.isEmpty, "clearAssignments should empty agentHealthMetrics")
        XCTAssertTrue(orch.agentHealthIssues.isEmpty, "clearAssignments should empty agentHealthIssues")
        XCTAssertNil(orch.presentedHealthIssue, "clearAssignments should nil presentedHealthIssue")
    }

    /// Verifies OrchestrationSubState setActivePRD works
    func test_orchestrationState_setActivePRD() {
        let orch = OrchestrationSubState()
        let url = URL(fileURLWithPath: "/tmp/prd.json")
        orch.setActivePRD(url: url, name: "Test PRD")
        XCTAssertEqual(orch.activePRDURL, url, "setActivePRD should update activePRDURL")
        XCTAssertEqual(orch.activePRDName, "Test PRD", "setActivePRD should update activePRDName")
    }

    // MARK: - AppState Core Properties Not Extracted

    /// Verifies core properties remain in AppState (not extracted)
    func test_appState_retainsCoreProperties() {
        let appState = AppState()
        XCTAssertTrue(appState.sessions.isEmpty, "sessions should remain in AppState")
        XCTAssertNil(appState.selectedSession, "selectedSession should remain in AppState")
        XCTAssertTrue(appState.worktrees.isEmpty, "worktrees should remain in AppState")
        XCTAssertNil(appState.selectedWorktree, "selectedWorktree should remain in AppState")
        XCTAssertTrue(appState.agents.isEmpty, "agents should remain in AppState")
        XCTAssertTrue(appState.logs.isEmpty, "logs should remain in AppState")
        XCTAssertFalse(appState.isLoading, "isLoading should remain in AppState")
        XCTAssertNil(appState.error, "error should remain in AppState")
    }
}
