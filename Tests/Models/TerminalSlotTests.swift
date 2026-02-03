//
//  TerminalSlotTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-03.
//  Unit tests for TerminalSlot model
//

import XCTest
@testable import XRoads

final class TerminalSlotTests: XCTestCase {

    // MARK: - Test Data Helpers

    private func makeTestWorktree() -> Worktree {
        Worktree(
            id: UUID(),
            path: "/test/worktree",
            branch: "test-branch",
            agentId: nil,
            createdAt: Date()
        )
    }

    private func makeTestSkill(id: String = "test-skill") -> Skill {
        Skill(
            id: id,
            name: "Test Skill",
            description: "A test skill",
            promptTemplate: "Test template with {{context}}",
            requiredTools: ["git", "file-edit"],
            version: "1.0.0",
            compatibleCLIs: Set(AgentType.allCases),
            category: .code,
            author: "Test"
        )
    }

    // MARK: - Basic Initialization Tests

    func testDefaultInitialization() {
        let slot = TerminalSlot(slotNumber: 1)

        XCTAssertEqual(slot.slotNumber, 1)
        XCTAssertNil(slot.worktree)
        XCTAssertNil(slot.agentType)
        XCTAssertNil(slot.actionType)
        XCTAssertTrue(slot.loadedSkills.isEmpty)
        XCTAssertNil(slot.processId)
        XCTAssertTrue(slot.logs.isEmpty)
        XCTAssertEqual(slot.status, .empty)
        XCTAssertNil(slot.currentTask)
        XCTAssertEqual(slot.progress, 0.0)
        XCTAssertTrue(slot.inputHistory.isEmpty)
    }

    func testFullInitialization() {
        let worktree = makeTestWorktree()
        let skill = makeTestSkill()

        let slot = TerminalSlot(
            slotNumber: 3,
            worktree: worktree,
            agentType: .claude,
            actionType: .implement,
            loadedSkills: [skill],
            processId: UUID(),
            status: .running,
            currentTask: "Building feature",
            progress: 0.5,
            inputHistory: ["yes", "no"]
        )

        XCTAssertEqual(slot.slotNumber, 3)
        XCTAssertEqual(slot.worktree?.id, worktree.id)
        XCTAssertEqual(slot.agentType, .claude)
        XCTAssertEqual(slot.actionType, .implement)
        XCTAssertEqual(slot.loadedSkills.count, 1)
        XCTAssertNotNil(slot.processId)
        XCTAssertEqual(slot.status, .running)
        XCTAssertEqual(slot.currentTask, "Building feature")
        XCTAssertEqual(slot.progress, 0.5)
        XCTAssertEqual(slot.inputHistory, ["yes", "no"])
    }

    // MARK: - isConfigured Tests

    func testIsConfiguredRequiresAllThreeComponents() {
        let worktree = makeTestWorktree()

        // Empty slot - not configured
        var slot = TerminalSlot(slotNumber: 1)
        XCTAssertFalse(slot.isConfigured)

        // Only worktree - not configured
        slot.worktree = worktree
        XCTAssertFalse(slot.isConfigured)

        // Worktree + agent - not configured (missing action)
        slot.agentType = .claude
        XCTAssertFalse(slot.isConfigured)

        // Worktree + agent + action - configured
        slot.actionType = .implement
        XCTAssertTrue(slot.isConfigured)
    }

    func testHasMinimalConfigurationRequiresWorktreeAndAgent() {
        let worktree = makeTestWorktree()

        var slot = TerminalSlot(slotNumber: 1)
        XCTAssertFalse(slot.hasMinimalConfiguration)

        slot.worktree = worktree
        XCTAssertFalse(slot.hasMinimalConfiguration)

        slot.agentType = .gemini
        XCTAssertTrue(slot.hasMinimalConfiguration)

        // Action is optional for minimal config
        XCTAssertNil(slot.actionType)
        XCTAssertTrue(slot.hasMinimalConfiguration)
    }

    // MARK: - needsInput Tests

    func testNeedsInputReflectsStatus() {
        var slot = TerminalSlot(slotNumber: 1)

        XCTAssertFalse(slot.needsInput)

        slot.status = .needsInput
        XCTAssertTrue(slot.needsInput)

        slot.status = .waitingForInput
        XCTAssertTrue(slot.needsInput)

        slot.status = .running
        XCTAssertFalse(slot.needsInput)

        slot.status = .completed
        XCTAssertFalse(slot.needsInput)
    }

    func testSetNeedsInputUpdatesStatus() {
        var slot = TerminalSlot(slotNumber: 1, status: .running)

        slot.setNeedsInput(true)
        XCTAssertEqual(slot.status, .needsInput)
        XCTAssertTrue(slot.needsInput)

        slot.setNeedsInput(false)
        XCTAssertEqual(slot.status, .running)
        XCTAssertFalse(slot.needsInput)
    }

    func testSetNeedsInputOnlyWorksForActiveSlots() {
        var slot = TerminalSlot(slotNumber: 1, status: .completed)

        // Should not change status when slot is not active
        slot.setNeedsInput(true)
        XCTAssertEqual(slot.status, .completed)
    }

    // MARK: - Input History Tests

    func testAddInputAppendsToHistory() {
        var slot = TerminalSlot(slotNumber: 1)

        slot.addInput("first")
        XCTAssertEqual(slot.inputHistory, ["first"])

        slot.addInput("second")
        XCTAssertEqual(slot.inputHistory, ["first", "second"])

        slot.addInput("third")
        XCTAssertEqual(slot.inputHistory, ["first", "second", "third"])
    }

    func testAddInputRespectMaxHistoryLimit() {
        var slot = TerminalSlot(slotNumber: 1)

        // Add more than max history
        for i in 0..<60 {
            slot.addInput("input-\(i)")
        }

        XCTAssertEqual(slot.inputHistory.count, TerminalSlot.maxInputHistoryCount)
        // Should have kept the most recent entries
        XCTAssertEqual(slot.inputHistory.first, "input-10")
        XCTAssertEqual(slot.inputHistory.last, "input-59")
    }

    func testLastInputReturnsLastEntry() {
        var slot = TerminalSlot(slotNumber: 1)

        XCTAssertNil(slot.lastInput)

        slot.addInput("hello")
        XCTAssertEqual(slot.lastInput, "hello")

        slot.addInput("world")
        XCTAssertEqual(slot.lastInput, "world")
    }

    func testClearInputHistory() {
        var slot = TerminalSlot(slotNumber: 1, inputHistory: ["a", "b", "c"])

        XCTAssertEqual(slot.inputHistory.count, 3)

        slot.clearInputHistory()
        XCTAssertTrue(slot.inputHistory.isEmpty)
    }

    // MARK: - Action Configuration Tests

    func testConfigureAction() {
        var slot = TerminalSlot(slotNumber: 1)
        let skills = [makeTestSkill(id: "skill-1"), makeTestSkill(id: "skill-2")]

        slot.configureAction(.review, skills: skills)

        XCTAssertEqual(slot.actionType, .review)
        XCTAssertEqual(slot.loadedSkills.count, 2)
        XCTAssertEqual(slot.loadedSkillNames, ["Test Skill", "Test Skill"])
    }

    func testConfigureActionWithoutSkills() {
        var slot = TerminalSlot(slotNumber: 1)

        slot.configureAction(.write)

        XCTAssertEqual(slot.actionType, .write)
        XCTAssertTrue(slot.loadedSkills.isEmpty)
    }

    func testClearAction() {
        var slot = TerminalSlot(
            slotNumber: 1,
            worktree: makeTestWorktree(),
            agentType: .claude,
            actionType: .implement,
            loadedSkills: [makeTestSkill()]
        )

        slot.clearAction()

        XCTAssertNil(slot.actionType)
        XCTAssertTrue(slot.loadedSkills.isEmpty)
        // Worktree and agent should remain
        XCTAssertNotNil(slot.worktree)
        XCTAssertEqual(slot.agentType, .claude)
    }

    // MARK: - Loaded Skills Tests

    func testLoadedSkillCount() {
        var slot = TerminalSlot(slotNumber: 1)

        XCTAssertEqual(slot.loadedSkillCount, 0)

        slot.loadedSkills = [makeTestSkill(id: "a"), makeTestSkill(id: "b")]
        XCTAssertEqual(slot.loadedSkillCount, 2)
    }

    func testHasLoadedSkills() {
        var slot = TerminalSlot(slotNumber: 1)

        XCTAssertFalse(slot.hasLoadedSkills)

        slot.loadedSkills = [makeTestSkill()]
        XCTAssertTrue(slot.hasLoadedSkills)
    }

    // MARK: - Reset Tests

    func testResetClearsAllFields() {
        var slot = TerminalSlot(
            slotNumber: 2,
            worktree: makeTestWorktree(),
            agentType: .gemini,
            actionType: .integrationTest,
            loadedSkills: [makeTestSkill()],
            processId: UUID(),
            status: .running,
            currentTask: "Testing",
            progress: 0.75,
            inputHistory: ["input1", "input2"]
        )
        slot.addLog(LogEntry(level: .info, source: "test", worktree: nil, message: "test"))

        slot.reset()

        XCTAssertEqual(slot.slotNumber, 2) // slotNumber is preserved
        XCTAssertNil(slot.worktree)
        XCTAssertNil(slot.agentType)
        XCTAssertNil(slot.actionType)
        XCTAssertTrue(slot.loadedSkills.isEmpty)
        XCTAssertNil(slot.processId)
        XCTAssertTrue(slot.logs.isEmpty)
        XCTAssertEqual(slot.status, .empty)
        XCTAssertNil(slot.currentTask)
        XCTAssertEqual(slot.progress, 0.0)
        XCTAssertTrue(slot.inputHistory.isEmpty)
    }

    // MARK: - Equatable Tests

    func testEquatableIncludesActionType() {
        let worktree = makeTestWorktree()

        let slot1 = TerminalSlot(
            slotNumber: 1,
            worktree: worktree,
            agentType: .claude,
            actionType: .implement
        )

        var slot2 = TerminalSlot(
            id: slot1.id,
            slotNumber: 1,
            worktree: worktree,
            agentType: .claude,
            actionType: .implement
        )

        XCTAssertEqual(slot1, slot2)

        // Change action type - should not be equal
        slot2.actionType = .review
        XCTAssertNotEqual(slot1, slot2)
    }

    func testEquatableIncludesLoadedSkills() {
        let worktree = makeTestWorktree()
        let skill = makeTestSkill()

        let slot1 = TerminalSlot(
            slotNumber: 1,
            worktree: worktree,
            agentType: .claude,
            loadedSkills: [skill]
        )

        var slot2 = TerminalSlot(
            id: slot1.id,
            slotNumber: 1,
            worktree: worktree,
            agentType: .claude,
            loadedSkills: [skill]
        )

        XCTAssertEqual(slot1, slot2)

        // Remove skills - should not be equal
        slot2.loadedSkills = []
        XCTAssertNotEqual(slot1, slot2)
    }

    func testEquatableIncludesNeedsInput() {
        let slot1 = TerminalSlot(slotNumber: 1, status: .needsInput)
        var slot2 = TerminalSlot(id: slot1.id, slotNumber: 1, status: .running)

        XCTAssertNotEqual(slot1, slot2)

        slot2.status = .needsInput
        XCTAssertEqual(slot1, slot2)
    }

    func testEquatableIncludesInputHistoryCount() {
        var slot1 = TerminalSlot(slotNumber: 1, inputHistory: ["a", "b"])
        var slot2 = TerminalSlot(id: slot1.id, slotNumber: 1, inputHistory: ["a", "b"])

        XCTAssertEqual(slot1, slot2)

        slot2.addInput("c")
        XCTAssertNotEqual(slot1, slot2)
    }

    // MARK: - Static Factory Method Tests

    func testConfiguredFactoryMethod() {
        let worktree = makeTestWorktree()
        let skills = [makeTestSkill()]

        let slot = TerminalSlot.configured(
            slotNumber: 4,
            worktree: worktree,
            agentType: .codex,
            actionType: .write,
            loadedSkills: skills
        )

        XCTAssertEqual(slot.slotNumber, 4)
        XCTAssertEqual(slot.worktree?.id, worktree.id)
        XCTAssertEqual(slot.agentType, .codex)
        XCTAssertEqual(slot.actionType, .write)
        XCTAssertEqual(slot.loadedSkills.count, 1)
        XCTAssertEqual(slot.status, .ready)
        XCTAssertTrue(slot.isConfigured)
    }

    // MARK: - Action Description Tests

    func testActionDescriptionWithoutAction() {
        let slot = TerminalSlot(slotNumber: 1)
        XCTAssertEqual(slot.actionDescription, "No action selected")
    }

    func testActionDescriptionWithAction() {
        var slot = TerminalSlot(slotNumber: 1)

        slot.actionType = .implement
        XCTAssertEqual(slot.actionDescription, ActionType.implement.description)

        slot.actionType = .review
        XCTAssertEqual(slot.actionDescription, ActionType.review.description)
    }

    func testActionIconNameWithoutAction() {
        let slot = TerminalSlot(slotNumber: 1)
        XCTAssertEqual(slot.actionIconName, "questionmark.circle")
    }

    func testActionIconNameWithAction() {
        var slot = TerminalSlot(slotNumber: 1)

        slot.actionType = .implement
        XCTAssertEqual(slot.actionIconName, "hammer.fill")

        slot.actionType = .integrationTest
        XCTAssertEqual(slot.actionIconName, "testtube.2")
    }

    // MARK: - TerminalSlotStatus Tests

    func testStatusIsWaitingForInput() {
        XCTAssertFalse(TerminalSlotStatus.empty.isWaitingForInput)
        XCTAssertFalse(TerminalSlotStatus.running.isWaitingForInput)
        XCTAssertFalse(TerminalSlotStatus.completed.isWaitingForInput)
        XCTAssertTrue(TerminalSlotStatus.needsInput.isWaitingForInput)
        XCTAssertTrue(TerminalSlotStatus.waitingForInput.isWaitingForInput)
    }

    func testStatusIsActiveIncludesInputStates() {
        XCTAssertTrue(TerminalSlotStatus.running.isActive)
        XCTAssertTrue(TerminalSlotStatus.starting.isActive)
        XCTAssertTrue(TerminalSlotStatus.needsInput.isActive)
        XCTAssertTrue(TerminalSlotStatus.waitingForInput.isActive)
        XCTAssertFalse(TerminalSlotStatus.completed.isActive)
        XCTAssertFalse(TerminalSlotStatus.paused.isActive)
    }

    func testStatusCanStopIncludesInputStates() {
        XCTAssertTrue(TerminalSlotStatus.running.canStop)
        XCTAssertTrue(TerminalSlotStatus.needsInput.canStop)
        XCTAssertTrue(TerminalSlotStatus.waitingForInput.canStop)
        XCTAssertFalse(TerminalSlotStatus.completed.canStop)
        XCTAssertFalse(TerminalSlotStatus.empty.canStop)
    }
}
