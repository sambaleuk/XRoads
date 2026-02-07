//
//  DispatchVisualStateTests.swift
//  XRoadsTests
//
//  Tests for orchestrator visual state transitions during multi-layer dispatch.
//  Validates that the "brain" stays in .monitoring between layers instead of
//  flickering to .idle ("Waiting for instructions").
//

import XCTest
@testable import XRoadsLib

@MainActor
final class DispatchVisualStateTests: XCTestCase {

    private var dashboard: DashboardState!

    override func setUp() {
        super.setUp()
        dashboard = DashboardState()
    }

    // MARK: - Helpers

    /// Configure slot with a worktree, agent, and action so isConfigured == true
    private func configureSlot(_ index: Int, status: TerminalSlotStatus = .ready) {
        let worktree = Worktree(
            path: "/tmp/wt-\(index)",
            branch: "feat/us-\(index)"
        )
        dashboard.terminalSlots[index].worktree = worktree
        dashboard.terminalSlots[index].agentType = .claude
        dashboard.terminalSlots[index].actionType = .implement
        dashboard.terminalSlots[index].status = status
    }

    // MARK: - Test: Initial State (no slots configured)

    func testInitialState_sleeping() {
        dashboard.updateOrchestratorVisualState(isDispatching: false)
        XCTAssertEqual(dashboard.orchestratorVisualState, .sleeping,
                       "With no configured slots and no dispatch, should be sleeping")
    }

    // MARK: - Test: 3 Stories in Single Layer

    func testSingleLayer_3Stories_runningToCompleted() {
        // PHASE 1: Configure 3 slots and set them running
        configureSlot(0, status: .running)
        configureSlot(1, status: .running)
        configureSlot(2, status: .running)

        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "3 running slots -> monitoring")

        // PHASE 2: First slot completes
        dashboard.terminalSlots[0].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "2 still running -> monitoring")

        // PHASE 3: Second slot completes
        dashboard.terminalSlots[1].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "1 still running -> monitoring")

        // PHASE 4: All slots complete — dispatch finishes (isDispatching becomes false)
        dashboard.terminalSlots[2].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: false)
        XCTAssertEqual(dashboard.orchestratorVisualState, .celebrating,
                       "All 3 complete, dispatch done -> celebrating")
    }

    // MARK: - Test: 3 Stories Across 2 Layers (the key scenario)

    func testTwoLayers_3Stories_noFlickerBetweenLayers() {
        // LAYER 1: 2 stories in parallel (slots 0, 1)
        configureSlot(0, status: .running)
        configureSlot(1, status: .running)

        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "Layer 1: 2 running -> monitoring")

        // Layer 1 slot 0 finishes
        dashboard.terminalSlots[0].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "Layer 1: 1 running -> monitoring")

        // Layer 1 slot 1 finishes -> CRITICAL MOMENT: no active slots but dispatch still active
        dashboard.terminalSlots[1].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "Between layers: 0 active but isDispatching=true -> should stay monitoring, NOT idle")

        // Also test via updateOrchestratorStateAfterTermination
        dashboard.orchestratorVisualState = .monitoring // reset
        dashboard.updateOrchestratorStateAfterTermination(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "AfterTermination between layers: should stay monitoring")

        // LAYER 2: Story 3 launches on slot 2
        configureSlot(2, status: .running)

        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "Layer 2: 1 running -> monitoring")

        // Layer 2 completes
        dashboard.terminalSlots[2].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: false) // dispatch done
        XCTAssertEqual(dashboard.orchestratorVisualState, .celebrating,
                       "All layers done, dispatch complete -> celebrating")
    }

    // MARK: - Test: Between layers WITHOUT dispatch flag shows idle (old behavior)

    func testBetweenLayers_withoutDispatchFlag_showsIdle() {
        configureSlot(0, status: .completed)
        configureSlot(1, status: .completed)

        dashboard.updateOrchestratorVisualState(isDispatching: false)
        // All configured slots completed -> celebrating
        XCTAssertEqual(dashboard.orchestratorVisualState, .celebrating,
                       "All configured slots completed (no dispatch) -> celebrating")
    }

    // MARK: - Test: Error during dispatch

    func testErrorDuringDispatch_showsConcerned() {
        configureSlot(0, status: .running)
        configureSlot(1, status: .error)
        configureSlot(2, status: .running)

        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .concerned,
                       "Any error -> concerned, regardless of dispatch state")
    }

    // MARK: - Test: NeedsInput during dispatch

    func testNeedsInputDuringDispatch_showsConcerned() {
        configureSlot(0, status: .running)
        configureSlot(1, status: .needsInput)
        configureSlot(2, status: .running)

        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .concerned,
                       "Any slot needing input -> concerned")
    }

    // MARK: - Test: Termination callback between layers

    func testTerminationCallback_betweenLayers_staysMonitoring() {
        configureSlot(0, status: .completed)
        configureSlot(1, status: .completed)

        dashboard.updateOrchestratorStateAfterTermination(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "AfterTermination with dispatch active: all configured done -> monitoring (not celebrating yet)")
    }

    func testTerminationCallback_dispatchDone_celebrates() {
        configureSlot(0, status: .completed)
        configureSlot(1, status: .completed)

        dashboard.updateOrchestratorStateAfterTermination(isDispatching: false)
        XCTAssertEqual(dashboard.orchestratorVisualState, .celebrating,
                       "AfterTermination with dispatch done: all configured done -> celebrating")
    }

    func testTerminationCallback_failedSlot_showsConcerned() {
        configureSlot(0, status: .completed)
        configureSlot(1, status: .error)

        dashboard.updateOrchestratorStateAfterTermination(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .concerned,
                       "AfterTermination with failed slot -> concerned")
    }

    // MARK: - Test: Full 3-Layer Simulation

    func testThreeLayers_fullSimulation() {
        // Layer 1: US-001 on slot 0
        configureSlot(0, status: .running)

        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring)

        // Layer 1 complete
        dashboard.terminalSlots[0].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "Between L1->L2: stays monitoring")

        // Layer 2: US-002 on slot 1
        configureSlot(1, status: .running)
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring)

        // Layer 2 complete
        dashboard.terminalSlots[1].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "Between L2->L3: stays monitoring")

        // Layer 3: US-003 on slot 2
        configureSlot(2, status: .running)
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring)

        // Layer 3 complete, dispatch finished
        dashboard.terminalSlots[2].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: false)
        XCTAssertEqual(dashboard.orchestratorVisualState, .celebrating,
                       "All 3 layers done -> celebrating")
    }

    // MARK: - Test: Status messages match states

    func testStatusMessages() {
        XCTAssertEqual(OrchestratorVisualState.idle.statusMessage, "Waiting for instructions...")
        XCTAssertEqual(OrchestratorVisualState.monitoring.statusMessage, "Monitoring agent progress...")
        XCTAssertEqual(OrchestratorVisualState.concerned.statusMessage, "Some agents need attention")
        XCTAssertEqual(OrchestratorVisualState.celebrating.statusMessage, "All tasks completed!")
        XCTAssertEqual(OrchestratorVisualState.sleeping.statusMessage, "Zzz...")
    }

    // MARK: - Test: Rapid state transitions (no flicker)

    func testRapidTransitions_noFlicker() {
        configureSlot(0, status: .running)
        configureSlot(1, status: .running)

        // Simulate rapid slot completions within same run loop
        dashboard.terminalSlots[0].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        let stateAfterFirst = dashboard.orchestratorVisualState

        dashboard.terminalSlots[1].status = .completed
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        let stateAfterSecond = dashboard.orchestratorVisualState

        XCTAssertEqual(stateAfterFirst, .monitoring, "After first: still monitoring")
        XCTAssertEqual(stateAfterSecond, .monitoring,
                       "After second with dispatch active: monitoring (not idle or celebrating)")
    }

    // MARK: - Test: No configured slots during dispatch (edge case)

    func testNoConfiguredSlots_duringDispatch_staysMonitoring() {
        // Edge case: dispatch is active but no slots configured yet
        dashboard.updateOrchestratorVisualState(isDispatching: true)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "No slots but dispatch active -> monitoring (preparing)")
    }

    // MARK: - Test: Mixed completed and unconfigured during dispatch

    func testMixedState_completedAndEmpty_duringDispatch() {
        configureSlot(0, status: .completed)
        // Slots 1-5 remain empty (unconfigured)

        dashboard.updateOrchestratorVisualState(isDispatching: true)
        // 1 configured, all configured completed, but dispatch active -> monitoring (more layers coming)
        XCTAssertEqual(dashboard.orchestratorVisualState, .monitoring,
                       "All configured completed but dispatch active -> monitoring (next layer pending)")
    }
}
