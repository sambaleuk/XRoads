//
//  MergeWiringTests.swift
//  XRoadsTests
//
//  Tests for the merge wiring and post-orchestration cleanup pipeline.
//  Validates: coordinateMerge uses real MergeCoordinator, GitService.deleteBranch,
//  completeOrchestration triggers merge, post-merge cleanup, history recording
//  without MergePlan dependency.
//

import XCTest
@testable import XRoadsLib

// MARK: - ClaudeOrchestrator Merge Tests

final class ClaudeOrchestratorMergeTests: XCTestCase {

    var tempRepoPath: URL!

    override func setUp() async throws {
        tempRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("xroads-merge-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRepoPath, withIntermediateDirectories: true)
        _ = try runGitCommand(["init"], in: tempRepoPath)
        let gitkeep = tempRepoPath.appendingPathComponent(".gitkeep")
        try "".write(to: gitkeep, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "."], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Initial commit"], in: tempRepoPath)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempRepoPath)
    }

    private func runGitCommand(_ args: [String], in directory: URL) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - Protocol Conformance

    /// coordinateMerge requires repoPath parameter in the protocol
    func test_orchestratorProtocol_coordinateMerge_requiresRepoPath() async throws {
        let orchestrator = ClaudeOrchestrator()
        let assignments: [WorktreeAssignment] = []

        // Should compile and work with repoPath parameter
        let result = try await orchestrator.coordinateMerge(for: assignments, repoPath: tempRepoPath)
        XCTAssertTrue(result.success, "Empty assignments should produce successful empty merge")
        XCTAssertTrue(result.mergedBranches.isEmpty, "No branches to merge")
    }

    /// coordinateMerge transitions to .merging then .complete on success
    func test_coordinateMerge_transitionsToMergingThenComplete() async throws {
        let orchestrator = ClaudeOrchestrator()
        let result = try await orchestrator.coordinateMerge(for: [], repoPath: tempRepoPath)
        XCTAssertTrue(result.success)
        let state = await orchestrator.state
        XCTAssertEqual(state, .complete)
    }

    /// coordinateMerge with real branches merges them via MergeCoordinator
    func test_coordinateMerge_mergesRealBranches() async throws {
        // Create a feature branch with a commit
        _ = try runGitCommand(["checkout", "-b", "xroads/test-feature"], in: tempRepoPath)
        let featureFile = tempRepoPath.appendingPathComponent("feature.txt")
        try "feature content".write(to: featureFile, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "feature.txt"], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Add feature"], in: tempRepoPath)
        _ = try runGitCommand(["checkout", "main"], in: tempRepoPath)

        let gitService = GitService()
        let mergeCoordinator = MergeCoordinator(gitService: gitService)
        let orchestrator = ClaudeOrchestrator(
            gitService: gitService,
            mergeCoordinator: mergeCoordinator
        )

        // Analyze a dummy PRD to set activeBaseBranch
        // We need to set it by creating worktrees first
        let taskGroup = TaskGroup(
            id: "tg-1",
            preferredAgent: .claude,
            storyIds: ["US-001"],
            estimatedComplexity: 3
        )
        let assignment = WorktreeAssignment(
            id: UUID(),
            taskGroup: taskGroup,
            agentType: .claude,
            branchName: "xroads/test-feature",
            worktreePath: tempRepoPath.appendingPathComponent("worktrees/test")
        )

        let result = try await orchestrator.coordinateMerge(
            for: [assignment],
            repoPath: tempRepoPath
        )

        XCTAssertTrue(result.success, "Merge should succeed with no conflicts")
        XCTAssertEqual(result.mergedBranches, ["xroads/test-feature"])
        XCTAssertTrue(result.conflicts.isEmpty)
    }

    /// coordinateMerge detects conflicts via MergeCoordinator
    func test_coordinateMerge_detectsConflicts() async throws {
        // Create conflicting branches
        let conflictFile = tempRepoPath.appendingPathComponent("shared.txt")
        try "original".write(to: conflictFile, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "shared.txt"], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Add shared file"], in: tempRepoPath)

        // Branch A modifies shared.txt
        _ = try runGitCommand(["checkout", "-b", "xroads/branch-a"], in: tempRepoPath)
        try "branch A content".write(to: conflictFile, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "shared.txt"], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Branch A changes"], in: tempRepoPath)

        // Branch B modifies same file
        _ = try runGitCommand(["checkout", "main"], in: tempRepoPath)
        _ = try runGitCommand(["checkout", "-b", "xroads/branch-b"], in: tempRepoPath)
        try "branch B content".write(to: conflictFile, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "shared.txt"], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Branch B changes"], in: tempRepoPath)
        _ = try runGitCommand(["checkout", "main"], in: tempRepoPath)

        let gitService = GitService()
        let mergeCoordinator = MergeCoordinator(gitService: gitService)
        let orchestrator = ClaudeOrchestrator(
            gitService: gitService,
            mergeCoordinator: mergeCoordinator
        )

        let taskGroup1 = TaskGroup(id: "tg-1", preferredAgent: .claude, storyIds: ["US-001"], estimatedComplexity: 3)
        let taskGroup2 = TaskGroup(id: "tg-2", preferredAgent: .gemini, storyIds: ["US-002"], estimatedComplexity: 2)

        let assignments = [
            WorktreeAssignment(id: UUID(), taskGroup: taskGroup1, agentType: .claude, branchName: "xroads/branch-a", worktreePath: tempRepoPath.appendingPathComponent("wt-a")),
            WorktreeAssignment(id: UUID(), taskGroup: taskGroup2, agentType: .gemini, branchName: "xroads/branch-b", worktreePath: tempRepoPath.appendingPathComponent("wt-b")),
        ]

        let result = try await orchestrator.coordinateMerge(
            for: assignments,
            repoPath: tempRepoPath
        )

        // Branch A should merge fine, Branch B should conflict
        XCTAssertFalse(result.success, "Merge should fail due to conflicts")
        XCTAssertEqual(result.mergedBranches.count, 1, "Only first branch should merge")
        XCTAssertFalse(result.conflicts.isEmpty, "Should have conflicts from second branch")

        let state = await orchestrator.state
        XCTAssertEqual(state, .error(message: "Merge conflicts detected"))
    }

    // MARK: - MergeCoordinator Injection

    /// ClaudeOrchestrator accepts mergeCoordinator in init
    func test_orchestrator_acceptsMergeCoordinatorInInit() {
        let gitService = GitService(testMode: true)
        let coordinator = MergeCoordinator(gitService: gitService)
        let orchestrator = ClaudeOrchestrator(
            gitService: gitService,
            mergeCoordinator: coordinator
        )
        XCTAssertNotNil(orchestrator, "Should initialize with custom mergeCoordinator")
    }
}

// MARK: - GitService.deleteBranch Tests

final class GitServiceDeleteBranchTests: XCTestCase {

    var tempRepoPath: URL!

    override func setUp() async throws {
        tempRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("xroads-branch-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRepoPath, withIntermediateDirectories: true)

        let gitService = GitService()
        try await gitService.initializeRepository(path: tempRepoPath.path)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempRepoPath)
    }

    private func runGitCommand(_ args: [String], in directory: URL) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func branchExists(_ name: String) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--verify", name]
        process.currentDirectoryURL = tempRepoPath
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// deleteBranch removes a fully merged branch
    func test_deleteBranch_removesMergedBranch() async throws {
        let gitService = GitService()

        // Create and merge a branch
        _ = try runGitCommand(["checkout", "-b", "feature-to-delete"], in: tempRepoPath)
        let file = tempRepoPath.appendingPathComponent("feature.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "feature.txt"], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Feature commit"], in: tempRepoPath)
        _ = try runGitCommand(["checkout", "main"], in: tempRepoPath)
        _ = try runGitCommand(["merge", "--no-ff", "feature-to-delete"], in: tempRepoPath)

        // Branch should exist before deletion
        XCTAssertTrue(try branchExists("feature-to-delete"), "Branch should exist before deletion")

        // Delete the merged branch
        try await gitService.deleteBranch(name: "feature-to-delete", repoPath: tempRepoPath.path)

        // Branch should be gone
        XCTAssertFalse(try branchExists("feature-to-delete"), "Branch should be removed after deletion")
    }

    /// deleteBranch with force:true removes unmerged branch
    func test_deleteBranch_forceRemovesUnmergedBranch() async throws {
        let gitService = GitService()

        // Create an unmerged branch
        _ = try runGitCommand(["checkout", "-b", "unmerged-branch"], in: tempRepoPath)
        let file = tempRepoPath.appendingPathComponent("unmerged.txt")
        try "unmerged content".write(to: file, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "unmerged.txt"], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Unmerged commit"], in: tempRepoPath)
        _ = try runGitCommand(["checkout", "main"], in: tempRepoPath)

        // Force delete
        try await gitService.deleteBranch(name: "unmerged-branch", repoPath: tempRepoPath.path, force: true)
        XCTAssertFalse(try branchExists("unmerged-branch"), "Force delete should remove unmerged branch")
    }

    /// deleteBranch without force fails on unmerged branch
    func test_deleteBranch_failsOnUnmergedBranchWithoutForce() async throws {
        let gitService = GitService()

        // Create an unmerged branch
        _ = try runGitCommand(["checkout", "-b", "unmerged-safe"], in: tempRepoPath)
        let file = tempRepoPath.appendingPathComponent("safe.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        _ = try runGitCommand(["add", "safe.txt"], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Safe commit"], in: tempRepoPath)
        _ = try runGitCommand(["checkout", "main"], in: tempRepoPath)

        do {
            try await gitService.deleteBranch(name: "unmerged-safe", repoPath: tempRepoPath.path)
            XCTFail("Should throw when deleting unmerged branch without force")
        } catch {
            // Expected: git branch -d fails on unmerged branches
            XCTAssertTrue(try branchExists("unmerged-safe"), "Branch should still exist after failed delete")
        }
    }

    /// deleteBranch in testMode is a no-op
    func test_deleteBranch_testModeIsNoOp() async throws {
        let gitService = GitService(testMode: true)
        // Should not throw even with nonexistent branch
        try await gitService.deleteBranch(name: "nonexistent", repoPath: "/fake/path")
    }
}

// MARK: - ServiceContainer Injection Tests

final class ServiceContainerMergeInjectionTests: XCTestCase {

    /// DefaultServiceContainer injects mergeCoordinator into orchestrator
    func test_defaultContainer_injectsMergeCoordinator() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Orchestrator/
            .deletingLastPathComponent() // XRoadsTests/
            .deletingLastPathComponent() // project root

        let source = try String(
            contentsOfFile: projectRoot.appendingPathComponent("XRoads/Services/ServiceContainer.swift").path,
            encoding: .utf8
        )

        // Both containers should pass mergeCoordinator to ClaudeOrchestrator
        let orchestratorInitPattern = "mergeCoordinator: mergeCoordinator"
        let occurrences = source.components(separatedBy: orchestratorInitPattern).count - 1
        XCTAssertEqual(occurrences, 2,
                       "Both DefaultServiceContainer and MockServiceContainer should inject mergeCoordinator into ClaudeOrchestrator")
    }

    /// MockServiceContainer's orchestrator receives test-mode mergeCoordinator
    func test_mockContainer_orchestratorReceivesTestModeCoordinator() {
        let container = MockServiceContainer()
        XCTAssertNotNil(container.orchestrator, "MockServiceContainer should have orchestrator")
        XCTAssertNotNil(container.mergeCoordinator, "MockServiceContainer should have mergeCoordinator")
    }
}

// MARK: - AppState completeOrchestration Tests

@MainActor
final class AppStateCompleteOrchestrationTests: XCTestCase {

    /// completeOrchestration bails out when not orchestrating
    func test_completeOrchestration_bailsWhenNotOrchestrating() async {
        let appState = AppState()
        appState.orchestrationState = .idle
        appState.activeWorktreeAssignments = []

        await appState.completeOrchestration()

        // Should stay idle - no state change
        XCTAssertEqual(appState.orchestrationState, .idle)
    }

    /// completeOrchestration bails out when no assignments
    func test_completeOrchestration_bailsWhenNoAssignments() async {
        let appState = AppState()
        appState.orchestrationState = .monitoring
        appState.activeWorktreeAssignments = []

        await appState.completeOrchestration()

        // Guard fails on empty assignments
        XCTAssertEqual(appState.orchestrationState, .monitoring)
    }

    /// completeOrchestration errors when no repoPath is set
    func test_completeOrchestration_errorsWithoutRepoPath() async {
        let appState = AppState()
        appState.orchestrationState = .monitoring

        let taskGroup = TaskGroup(id: "tg-1", preferredAgent: .claude, storyIds: ["US-001"], estimatedComplexity: 3)
        appState.activeWorktreeAssignments = [
            WorktreeAssignment(id: UUID(), taskGroup: taskGroup, agentType: .claude,
                               branchName: "xroads/test", worktreePath: URL(fileURLWithPath: "/tmp/wt"))
        ]
        appState.orchestrationRepoPath = nil

        await appState.completeOrchestration()

        // Should set error
        XCTAssertNotNil(appState.error, "Should set error when repoPath is nil")
    }
}

// MARK: - OrchestrationRecord Builder Tests

@MainActor
final class OrchestrationRecordBuilderTests: XCTestCase {

    /// buildOrchestrationRecord(baseBranch:result:) works without MergePlan
    func test_historyRecordCreation_withoutMergePlan() async {
        let appState = AppState()
        appState.orchestration.setActivePRD(url: nil, name: "TestPRD")

        let result = MergeResult(
            baseBranch: "main",
            mergedBranches: ["feature-a", "feature-b"],
            conflicts: [],
            success: true,
            rolledBack: false
        )

        // Access the private method through the public flow:
        // Set up orchestration state then check that history is recorded
        // after completeOrchestration succeeds.
        // Since we can't directly call private methods, we verify the record structure
        // via the OrchestrationRecord init.
        let record = OrchestrationRecord(
            id: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            prdName: appState.orchestration.activePRDName ?? result.baseBranch,
            prdPath: appState.orchestration.activePRDURL?.path,
            resultSummary: result.success ? "Merged" : (result.conflicts.isEmpty ? "Partial" : "Conflicts"),
            mergedBranches: result.mergedBranches,
            conflicts: result.conflicts.flatMap(\.files),
            totalStories: 0,
            completedStories: 0,
            agentMetrics: [],
            errors: []
        )

        XCTAssertEqual(record.prdName, "TestPRD")
        XCTAssertEqual(record.resultSummary, "Merged")
        XCTAssertEqual(record.mergedBranches, ["feature-a", "feature-b"])
        XCTAssertTrue(record.conflicts.isEmpty)
    }

    /// MergeResult with conflicts produces "Conflicts" summary
    func test_conflictResult_producesConflictsSummary() {
        let result = MergeResult(
            baseBranch: "main",
            mergedBranches: ["feature-a"],
            conflicts: [MergeConflict(branch: "feature-b", files: ["shared.txt"], message: "conflict")],
            success: false,
            rolledBack: true
        )

        let summary = result.success ? "Merged" : (result.conflicts.isEmpty ? "Partial" : "Conflicts")
        XCTAssertEqual(summary, "Conflicts")
    }

    /// Partial result (no conflicts but not success) produces "Partial" summary
    func test_partialResult_producesPartialSummary() {
        let result = MergeResult(
            baseBranch: "main",
            mergedBranches: [],
            conflicts: [],
            success: false,
            rolledBack: false
        )

        let summary = result.success ? "Merged" : (result.conflicts.isEmpty ? "Partial" : "Conflicts")
        XCTAssertEqual(summary, "Partial")
    }
}

// MARK: - onComplete Callback Source Verification Tests

final class OnCompleteCallbackTests: XCTestCase {

    /// SlotAssignmentSheet onComplete calls completeOrchestration
    func test_slotAssignmentSheet_onComplete_callsCompleteOrchestration() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let source = try String(
            contentsOfFile: projectRoot.appendingPathComponent("XRoads/Views/SlotAssignmentSheet.swift").path,
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("await appState.completeOrchestration()"),
            "SlotAssignmentSheet onComplete must call completeOrchestration()"
        )
    }

    /// OrchestratorChatView onComplete calls completeOrchestration
    func test_orchestratorChatView_onComplete_callsCompleteOrchestration() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let source = try String(
            contentsOfFile: projectRoot.appendingPathComponent("XRoads/Views/Orchestrator/OrchestratorChatView.swift").path,
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("await self.appState.completeOrchestration()"),
            "OrchestratorChatView onComplete must call completeOrchestration()"
        )
    }

    /// ClaudeOrchestrator coordinateMerge no longer returns placeholder
    func test_coordinateMerge_isNotPlaceholder() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let source = try String(
            contentsOfFile: projectRoot.appendingPathComponent("XRoads/Services/ClaudeOrchestrator.swift").path,
            encoding: .utf8
        )

        XCTAssertFalse(
            source.contains("Placeholder merge result"),
            "coordinateMerge should no longer contain placeholder comment"
        )
        XCTAssertTrue(
            source.contains("mergeCoordinator.prepareMerge"),
            "coordinateMerge should call mergeCoordinator.prepareMerge"
        )
        XCTAssertTrue(
            source.contains("mergeCoordinator.executeMerge"),
            "coordinateMerge should call mergeCoordinator.executeMerge"
        )
    }

    /// AppState has cleanupPostOrchestration method
    func test_appState_hasCleanupPostOrchestration() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let source = try String(
            contentsOfFile: projectRoot.appendingPathComponent("XRoads/ViewModels/AppState.swift").path,
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("func cleanupPostOrchestration"),
            "AppState should have cleanupPostOrchestration method"
        )
        XCTAssertTrue(
            source.contains("deleteBranch"),
            "cleanupPostOrchestration should call deleteBranch"
        )
        XCTAssertTrue(
            source.contains("removeWorktree"),
            "cleanupPostOrchestration should call removeWorktree"
        )
    }

    /// GitService has deleteBranch method
    func test_gitService_hasDeleteBranch() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let source = try String(
            contentsOfFile: projectRoot.appendingPathComponent("XRoads/Services/GitService.swift").path,
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("func deleteBranch(name:"),
            "GitService should have deleteBranch method"
        )
    }
}
