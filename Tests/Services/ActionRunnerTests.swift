import XCTest
@testable import XRoads

// MARK: - ActionRunnerTests

final class ActionRunnerTests: XCTestCase {

    // MARK: - Skill Loading Tests

    func testSkillLoadingForImplementAction() async throws {
        // Given
        let runner = ActionRunner()
        let actionType = ActionType.implement

        // When
        let (available, missing) = await runner.checkSkillsAvailability(
            for: actionType,
            agent: .claude
        )

        // Then
        // Note: Skill availability depends on SkillRegistry having the bundled skills loaded
        // The bundled skills include: prd, code-writer, commit (required for implement)
        XCTAssertTrue(available, "Implement action should have all required skills available. Missing: \(missing)")
    }

    func testSkillLoadingForReviewAction() async throws {
        // Given
        let runner = ActionRunner()
        let actionType = ActionType.review

        // When
        let (available, missing) = await runner.checkSkillsAvailability(
            for: actionType,
            agent: .gemini
        )

        // Then
        // Required skills: code-reviewer, lint
        XCTAssertTrue(available, "Review action should have all required skills available. Missing: \(missing)")
    }

    func testSkillLoadingForIntegrationTestAction() async throws {
        // Given
        let runner = ActionRunner()
        let actionType = ActionType.integrationTest

        // When
        let (available, missing) = await runner.checkSkillsAvailability(
            for: actionType,
            agent: .codex
        )

        // Then
        // Required skills: integration-test, e2e-test, perf-test
        XCTAssertTrue(available, "Integration test action should have all required skills available. Missing: \(missing)")
    }

    func testSkillLoadingForWriteAction() async throws {
        // Given
        let runner = ActionRunner()
        let actionType = ActionType.write

        // When
        let (available, missing) = await runner.checkSkillsAvailability(
            for: actionType,
            agent: .claude
        )

        // Then
        // Required skills: doc-generator
        XCTAssertTrue(available, "Write action should have all required skills available. Missing: \(missing)")
    }

    func testCustomActionAllowsEmptySkills() async throws {
        // Given
        let runner = ActionRunner()
        let actionType = ActionType.custom

        // When
        let (available, missing) = await runner.checkSkillsAvailability(
            for: actionType,
            agent: .claude
        )

        // Then
        // Custom actions have no required skills
        XCTAssertTrue(available, "Custom action should allow empty skills")
        XCTAssertTrue(missing.isEmpty, "Custom action should have no missing skills")
    }

    // MARK: - AGENT.md Generation Tests

    func testAgentMDGenerationIncludesSkills() async throws {
        // Given
        let skillLoader = SkillLoader.shared
        let skills = [
            Skill(
                id: "test-skill",
                name: "Test Skill",
                description: "A test skill",
                promptTemplate: "Test prompt with {{context}}",
                requiredTools: ["test-tool"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .code,
                author: "Test"
            )
        ]

        let context = SkillContext(
            agentType: .claude,
            worktreePath: "/tmp/test-worktree",
            branch: "test-branch",
            assignedStories: ["US-001", "US-002"]
        )

        // When
        let agentMD = await skillLoader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: "/tmp/test-worktree"
        )

        // Then
        XCTAssertTrue(agentMD.contains("Test Skill"), "AGENT.md should contain skill name")
        XCTAssertTrue(agentMD.contains("Claude Code"), "AGENT.md should contain agent type")
        XCTAssertTrue(agentMD.contains("test-branch"), "AGENT.md should contain branch name")
    }

    func testAgentMDGenerationWithMultipleSkills() async throws {
        // Given
        let skillLoader = SkillLoader.shared
        let skills = [
            Skill(
                id: "skill-1",
                name: "Skill One",
                description: "First skill",
                promptTemplate: "First prompt",
                requiredTools: [],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .code,
                author: "Test"
            ),
            Skill(
                id: "skill-2",
                name: "Skill Two",
                description: "Second skill",
                promptTemplate: "Second prompt",
                requiredTools: [],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .review,
                author: "Test"
            )
        ]

        let context = SkillContext(
            agentType: .gemini,
            worktreePath: "/tmp/test",
            branch: "main"
        )

        // When
        let agentMD = await skillLoader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: "/tmp/test"
        )

        // Then
        XCTAssertTrue(agentMD.contains("Skill One"), "AGENT.md should contain first skill")
        XCTAssertTrue(agentMD.contains("Skill Two"), "AGENT.md should contain second skill")
    }

    // MARK: - Error Handling Tests

    func testErrorHandlingForMissingSkills() async throws {
        // Given
        let runner = ActionRunner()

        // When
        let (available, missing) = await runner.checkSkillsAvailability(
            for: .implement,
            agent: .claude
        )

        // Then
        // With bundled skills, all should be available
        // This test verifies the error detection mechanism works
        if !available {
            XCTAssertFalse(missing.isEmpty, "Missing skills should be reported")
        }
    }

    func testErrorHandlingForInvalidWorktreePath() async throws {
        // Given
        let runner = ActionRunner()
        let request = ActionRunRequest(
            actionType: .implement,
            agentType: .claude,
            worktreePath: "/nonexistent/path/that/does/not/exist"
        )

        // When/Then
        do {
            _ = try await runner.run(request: request) { _ in }
            XCTFail("Should throw error for invalid worktree path")
        } catch let error as ActionRunnerError {
            switch error {
            case .worktreePathInvalid:
                // Expected
                break
            default:
                XCTFail("Should throw worktreePathInvalid error, got: \(error)")
            }
        }
    }

    // MARK: - CLI Launch Delegation Tests

    func testCLILaunchDelegationToAgentLauncher() async throws {
        // Given
        let runner = ActionRunner()

        // When checking skill loading for different action types
        // This verifies the runner can correctly load skills that would be passed to AgentLauncher

        let implementSkills = try await runner.loadSkillsForAction(.implement, agent: .claude)
        let reviewSkills = try await runner.loadSkillsForAction(.review, agent: .gemini)
        let testSkills = try await runner.loadSkillsForAction(.integrationTest, agent: .codex)

        // Then
        // Verify skills are loaded (actual launching requires valid CLI paths)
        XCTAssertFalse(implementSkills.isEmpty, "Implement action should load skills")
        XCTAssertFalse(reviewSkills.isEmpty, "Review action should load skills")
        XCTAssertFalse(testSkills.isEmpty, "Integration test action should load skills")
    }

    // MARK: - ActionRunRequest Tests

    func testActionRunRequestInitialization() {
        // Given/When
        let request = ActionRunRequest(
            actionType: .implement,
            agentType: .claude,
            worktreePath: "/test/path",
            additionalSkillIDs: ["extra-skill"],
            prdPath: "/path/to/prd.json",
            branchName: "feature/test",
            assignedStories: ["US-001", "US-002"],
            taskDescription: "Test task",
            coordinationNotes: "Coordinate with other agents"
        )

        // Then
        XCTAssertEqual(request.actionType, .implement)
        XCTAssertEqual(request.agentType, .claude)
        XCTAssertEqual(request.worktreePath, "/test/path")
        XCTAssertEqual(request.additionalSkillIDs, ["extra-skill"])
        XCTAssertEqual(request.prdPath, "/path/to/prd.json")
        XCTAssertEqual(request.branchName, "feature/test")
        XCTAssertEqual(request.assignedStories, ["US-001", "US-002"])
        XCTAssertEqual(request.taskDescription, "Test task")
        XCTAssertEqual(request.coordinationNotes, "Coordinate with other agents")
    }

    func testActionRunRequestDefaults() {
        // Given/When
        let request = ActionRunRequest(
            actionType: .review,
            agentType: .gemini,
            worktreePath: "/test"
        )

        // Then
        XCTAssertTrue(request.additionalSkillIDs.isEmpty)
        XCTAssertNil(request.prdPath)
        XCTAssertEqual(request.branchName, "main")
        XCTAssertTrue(request.assignedStories.isEmpty)
        XCTAssertNil(request.taskDescription)
        XCTAssertNil(request.coordinationNotes)
    }

    // MARK: - ActionRunResult Tests

    func testActionRunResultProperties() {
        // Given
        let processID = UUID()
        let sessionID = UUID()
        let skills = [
            Skill(
                id: "test",
                name: "Test",
                description: "Test",
                promptTemplate: "",
                requiredTools: [],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .code,
                author: "Test"
            )
        ]

        // When
        let result = ActionRunResult(
            processID: processID,
            loadedSkills: skills,
            agentMDPath: "/test/AGENT.md",
            sessionID: sessionID,
            startedAt: Date()
        )

        // Then
        XCTAssertEqual(result.processID, processID)
        XCTAssertEqual(result.loadedSkills.count, 1)
        XCTAssertEqual(result.agentMDPath, "/test/AGENT.md")
        XCTAssertEqual(result.sessionID, sessionID)
    }

    // MARK: - Active Runs Tracking Tests

    func testActiveRunsTracking() async throws {
        // Given
        let runner = ActionRunner()

        // When - before any runs
        let initialSessions = await runner.activeSessionIDs()

        // Then
        XCTAssertTrue(initialSessions.isEmpty, "Should have no active sessions initially")
    }

    func testGetRunResultForUnknownSession() async {
        // Given
        let runner = ActionRunner()
        let unknownID = UUID()

        // When
        let result = await runner.getRunResult(sessionID: unknownID)

        // Then
        XCTAssertNil(result, "Should return nil for unknown session")
    }

    func testRemoveRunCleansUpTracking() async {
        // Given
        let runner = ActionRunner()
        let sessionID = UUID()

        // When
        await runner.removeRun(sessionID: sessionID)
        let result = await runner.getRunResult(sessionID: sessionID)

        // Then
        XCTAssertNil(result, "Should return nil after removal")
    }
}

// MARK: - ActionRunnerErrorTests

final class ActionRunnerErrorTests: XCTestCase {

    func testSkillNotFoundErrorDescription() {
        // Given
        let error = ActionRunnerError.skillNotFound(id: "missing-skill")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("missing-skill") ?? false)
        XCTAssertTrue(description?.contains("not found") ?? false)
    }

    func testSkillsLoadFailedErrorDescription() {
        // Given
        let error = ActionRunnerError.skillsLoadFailed(ids: ["skill-1", "skill-2"])

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("skill-1") ?? false)
        XCTAssertTrue(description?.contains("skill-2") ?? false)
    }

    func testAgentMDGenerationFailedErrorDescription() {
        // Given
        let error = ActionRunnerError.agentMDGenerationFailed(path: "/test/path")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("/test/path") ?? false)
        XCTAssertTrue(description?.contains("AGENT.md") ?? false)
    }

    func testWorktreePathInvalidErrorDescription() {
        // Given
        let error = ActionRunnerError.worktreePathInvalid(path: "/invalid/path")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("/invalid/path") ?? false)
        XCTAssertTrue(description?.contains("Invalid") ?? false)
    }

    func testNoSkillsLoadedErrorDescription() {
        // Given
        let error = ActionRunnerError.noSkillsLoaded

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("No skills") ?? false)
    }

    func testMissingRequiredToolErrorDescription() {
        // Given
        let error = ActionRunnerError.missingRequiredTool(tool: "git", skill: "commit")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("git") ?? false)
        XCTAssertTrue(description?.contains("commit") ?? false)
    }
}
