//
//  OrchestrationWorkflowTests.swift
//  XRoadsTests
//
//  Tests for the unified orchestration workflow
//  Validates: single launch system, worktree paths, slot state synchronization
//

import XCTest
@testable import XRoadsLib

final class OrchestrationWorkflowTests: XCTestCase {

    // MARK: - Test Fixtures

    var tempRepoPath: URL!
    var prd: PRDDocument!

    override func setUp() async throws {
        // Create a temporary directory for test repo
        tempRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("xroads-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRepoPath, withIntermediateDirectories: true)

        // Initialize a git repo
        let initResult = try runGitCommand(["init"], in: tempRepoPath)
        XCTAssertTrue(initResult, "Git init should succeed")

        // Create initial commit
        let gitkeep = tempRepoPath.appendingPathComponent(".gitkeep")
        try "".write(to: gitkeep, atomically: true, encoding: .utf8)

        _ = try runGitCommand(["add", "."], in: tempRepoPath)
        _ = try runGitCommand(["commit", "-m", "Initial commit"], in: tempRepoPath)

        // Create test PRD
        prd = PRDDocument(
            featureName: "TestFeature",
            description: "Test feature for unit tests",
            author: "test",
            templateType: .feature,
            userStories: [
                PRDUserStory(
                    id: "US-001",
                    title: "First Story",
                    description: "Test story 1",
                    priority: .high,
                    status: .pending,
                    acceptanceCriteria: ["Criterion 1"],
                    dependsOn: [],
                    estimatedComplexity: 3
                ),
                PRDUserStory(
                    id: "US-002",
                    title: "Second Story",
                    description: "Test story 2",
                    priority: .medium,
                    status: .blocked,
                    acceptanceCriteria: ["Criterion 2"],
                    dependsOn: ["US-001"],
                    estimatedComplexity: 2
                )
            ]
        )
    }

    override func tearDown() async throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempRepoPath)
    }

    // MARK: - Helper

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

    // MARK: - Test: Worktree Path Consistency

    /// Verifies that worktree paths are computed consistently across all components
    func testWorktreePathConsistency() throws {
        let slotNumber = 1
        let agentType = AgentType.claude
        let storyIds = ["US-001", "US-002"]

        // Compute path using WorktreePathResolver (centralized component)
        let resolvedPath = WorktreePathResolver.resolve(
            repoPath: tempRepoPath,
            slotNumber: slotNumber,
            agentType: agentType,
            storyIds: storyIds
        )

        // Compute branch name
        let branchName = WorktreePathResolver.branchName(
            slotNumber: slotNumber,
            agentType: agentType,
            storyIds: storyIds
        )

        // Verify path follows expected pattern
        XCTAssertTrue(resolvedPath.path.contains("/worktrees/"),
                      "Worktree path must contain /worktrees/ directory")
        XCTAssertTrue(resolvedPath.path.contains("slot-\(slotNumber)"),
                      "Worktree path must contain slot number")
        XCTAssertTrue(resolvedPath.path.contains(agentType.rawValue),
                      "Worktree path must contain agent type")

        // Verify branch name follows expected pattern
        XCTAssertTrue(branchName.hasPrefix("xroads/"),
                      "Branch name must start with xroads/")
        XCTAssertTrue(branchName.contains("slot-\(slotNumber)"),
                      "Branch name must contain slot number")
    }

    // MARK: - Test: WorktreePathResolver Consistency

    /// Verifies that WorktreePathResolver produces consistent results
    func testWorktreePathResolverConsistency() {
        let repoPath = URL(fileURLWithPath: "/test/repo")

        // Call resolve multiple times with same input
        let path1 = WorktreePathResolver.resolve(
            repoPath: repoPath,
            slotNumber: 1,
            agentType: .claude,
            storyIds: ["US-001", "US-002"]
        )

        let path2 = WorktreePathResolver.resolve(
            repoPath: repoPath,
            slotNumber: 1,
            agentType: .claude,
            storyIds: ["US-001", "US-002"]
        )

        XCTAssertEqual(path1, path2, "Same inputs should produce same path")

        // Different slot should produce different path
        let path3 = WorktreePathResolver.resolve(
            repoPath: repoPath,
            slotNumber: 2,
            agentType: .claude,
            storyIds: ["US-001", "US-002"]
        )

        XCTAssertNotEqual(path1, path3, "Different slot should produce different path")
    }

    // MARK: - Test: No Dual Launch (AppState isDispatching)

    /// Verifies that isDispatching correctly reflects dispatch phase
    @MainActor
    func testIsDispatchingReflectsPhase() {
        let appState = AppState()

        // Idle phase - not dispatching
        appState.dispatchPhase = .idle
        XCTAssertFalse(appState.isDispatching, "Should not be dispatching when idle")

        // Preparing phase - dispatching
        appState.dispatchPhase = .preparingWorktrees
        XCTAssertTrue(appState.isDispatching, "Should be dispatching when preparing")

        // Monitoring phase - dispatching
        appState.dispatchPhase = .monitoring
        XCTAssertTrue(appState.isDispatching, "Should be dispatching when monitoring")

        // Completed phase - not dispatching
        appState.dispatchPhase = .completed
        XCTAssertFalse(appState.isDispatching, "Should not be dispatching when completed")

        // Failed phase - not dispatching
        appState.dispatchPhase = .failed
        XCTAssertFalse(appState.isDispatching, "Should not be dispatching when failed")
    }

    // MARK: - Test: Worktree Directory Creation

    /// Verifies that worktree directories can be created
    func testWorktreeDirectoryCreation() throws {
        // Ensure worktrees parent directory
        try WorktreePathResolver.ensureWorktreesDirectory(repoPath: tempRepoPath)

        let worktreesDir = tempRepoPath.appendingPathComponent("worktrees")
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreesDir.path),
                      "Worktrees directory should exist")
    }

    // MARK: - Test: Dependency Layer Calculation

    /// Verifies that dependency layers are calculated correctly
    func testDependencyLayerCalculation() async throws {
        let loopLauncher = LoopLauncher()

        let layers = await loopLauncher.calculateDependencyLayers(stories: prd.userStories)

        XCTAssertEqual(layers.count, 2, "Should have 2 layers")

        // Layer 0: US-001 (no dependencies)
        XCTAssertTrue(layers[0].storyIds.contains("US-001"),
                      "Layer 0 should contain US-001")

        // Layer 1: US-002 (depends on US-001)
        XCTAssertTrue(layers[1].storyIds.contains("US-002"),
                      "Layer 1 should contain US-002")
    }

    // MARK: - Test: Status File Initialization

    /// Verifies that status file is created correctly
    func testStatusFileInitialization() async throws {
        let loopLauncher = LoopLauncher()
        let sessionId = UUID()

        let statusFilePath = try await loopLauncher.initializeSession(
            repoPath: tempRepoPath,
            sessionId: sessionId,
            prd: prd
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: statusFilePath.path),
                      "Status file should be created")

        // Verify content
        let data = try Data(contentsOf: statusFilePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let status = try decoder.decode(OrchestrationStatusFile.self, from: data)

        XCTAssertEqual(status.prdName, prd.featureName)
        XCTAssertEqual(status.stories.count, prd.userStories.count)
        XCTAssertEqual(status.stories["US-001"]?.status, .ready)
        XCTAssertEqual(status.stories["US-002"]?.status, .blocked)
    }

    // MARK: - Test: Git Worktree Creation

    /// Verifies that git worktrees can be created
    func testGitWorktreeCreation() async throws {
        let gitService = GitService()

        // Create worktrees directory
        try WorktreePathResolver.ensureWorktreesDirectory(repoPath: tempRepoPath)

        let branchName = "xroads/test-slot-1"
        let worktreePath = tempRepoPath
            .appendingPathComponent("worktrees")
            .appendingPathComponent("test-slot-1")

        // Create worktree
        try await gitService.createWorktree(
            repoPath: tempRepoPath.path,
            branch: branchName,
            worktreePath: worktreePath.path
        )

        // Verify worktree exists and is valid
        let gitFile = worktreePath.appendingPathComponent(".git")
        XCTAssertTrue(FileManager.default.fileExists(atPath: gitFile.path),
                      "Worktree should have .git file")

        // Cleanup - use force removal via shell command to avoid path matching issues
        // The worktree was created successfully, which is what we're testing
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "remove", worktreePath.path, "--force"]
        process.currentDirectoryURL = tempRepoPath
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Test: LoopConfiguration Uses WorktreePathResolver

    /// Verifies that LoopConfiguration produces paths consistent with WorktreePathResolver
    func testLoopConfigurationPathConsistency() {
        let slotNumber = 2
        let agentType = AgentType.gemini
        // Use story IDs from the test PRD
        let storyIds = ["US-001", "US-002"]

        // Get path from WorktreePathResolver
        let resolverPath = WorktreePathResolver.resolve(
            repoPath: tempRepoPath,
            slotNumber: slotNumber,
            agentType: agentType,
            storyIds: storyIds
        )

        // Get path from LoopConfiguration
        let branchName = WorktreePathResolver.branchName(
            slotNumber: slotNumber,
            agentType: agentType,
            storyIds: storyIds
        )

        // Filter stories that match the storyIds
        let stories = prd.userStories.filter { storyIds.contains($0.id) }
        XCTAssertFalse(stories.isEmpty, "Should have stories to test with")

        let config = LoopConfiguration(
            slotNumber: slotNumber,
            agentType: agentType,
            repoPath: tempRepoPath,
            branchName: branchName,
            stories: stories,
            fullPRD: prd
        )

        // Paths should match
        XCTAssertEqual(resolverPath.path, config.worktreePath.path,
                       "LoopConfiguration should use WorktreePathResolver internally")
    }
}

