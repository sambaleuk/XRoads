import XCTest
import GRDB
@testable import XRoadsLib

/// US-002: Validates context reading and CockpitLifecycle activation
final class ProjectContextReaderTests: XCTestCase {

    private var dbManager: CockpitDatabaseManager!
    private var repo: CockpitSessionRepository!
    private var gitService: GitService!
    private var contextReader: ProjectContextReader!
    private var lifecycleManager: CockpitLifecycleManager!
    private var tempDir: String!

    override func setUp() async throws {
        try await super.setUp()

        // In-memory database
        dbManager = try CockpitDatabaseManager()
        repo = await CockpitSessionRepository(databaseManager: dbManager)

        // Real GitService (not test mode — we need actual git operations)
        gitService = GitService()

        contextReader = ProjectContextReader(gitService: gitService, repository: repo)
        lifecycleManager = CockpitLifecycleManager(contextReader: contextReader, repository: repo)

        // Create a temporary git repository for testing
        tempDir = NSTemporaryDirectory() + "xroads-test-\(UUID().uuidString)"
        try await gitService.initializeRepository(path: tempDir)

        // Add a few commits to have meaningful git log
        let testFile = (tempDir as NSString).appendingPathComponent("test.txt")
        try "Hello".write(toFile: testFile, atomically: true, encoding: .utf8)
        try await runGitAt(tempDir, args: ["add", "test.txt"])
        try await runGitAt(tempDir, args: ["commit", "-m", "Add test file"])

        try "World".write(toFile: testFile, atomically: true, encoding: .utf8)
        try await runGitAt(tempDir, args: ["add", "test.txt"])
        try await runGitAt(tempDir, args: ["commit", "-m", "Update test file"])

        // Write a prd.json in the temp repo
        let prdContent: [String: Any] = [
            "feature_name": "Test Feature",
            "status": "in_progress",
            "branch": "feat/test",
            "user_stories": [
                ["id": "US-001", "title": "Story 1", "status": "complete"],
                ["id": "US-002", "title": "Story 2", "status": "pending"]
            ]
        ]
        let prdData = try JSONSerialization.data(withJSONObject: prdContent, options: .prettyPrinted)
        let prdPath = (tempDir as NSString).appendingPathComponent("prd.json")
        try prdData.write(to: URL(fileURLWithPath: prdPath))
    }

    override func tearDown() async throws {
        // Clean up temp directory
        if let dir = tempDir {
            try? FileManager.default.removeItem(atPath: dir)
        }
        tempDir = nil
        lifecycleManager = nil
        contextReader = nil
        gitService = nil
        repo = nil
        dbManager = nil
        try await super.tearDown()
    }

    // MARK: - ChairmanInput: should read git log and package as ChairmanInput

    func test_readContext_readsGitLogAndPackagesAsChairmanInput() async throws {
        let input = try await contextReader.readContext(projectPath: tempDir)

        // Git log should have at least 3 commits (initial + 2 test commits)
        XCTAssertGreaterThanOrEqual(input.gitLog.count, 3)

        // Verify commit data is populated
        let latestCommit = input.gitLog.first!
        XCTAssertFalse(latestCommit.sha.isEmpty)
        XCTAssertFalse(latestCommit.shortSha.isEmpty)
        XCTAssertFalse(latestCommit.message.isEmpty)
        XCTAssertFalse(latestCommit.author.isEmpty)

        // PRD summary should be parsed
        XCTAssertNotNil(input.prdSummary)
        XCTAssertEqual(input.prdSummary?.featureName, "Test Feature")
        XCTAssertEqual(input.prdSummary?.status, "in_progress")
        XCTAssertEqual(input.prdSummary?.totalStories, 2)
        XCTAssertEqual(input.prdSummary?.completedStories, 1)
        XCTAssertEqual(input.prdSummary?.pendingStories, 1)

        // Open branches should include at least main/master
        XCTAssertGreaterThanOrEqual(input.openBranches.count, 1)

        // Project path and timestamp
        XCTAssertEqual(input.projectPath, tempDir)
        XCTAssertNotNil(input.collectedAt)
    }

    // MARK: - State Transition: should transition to initializing on valid project

    func test_activate_transitionsToInitializingOnValidProject() async throws {
        // Create a session in idle state
        let session = CockpitSession(
            projectPath: tempDir,
            status: .idle
        )
        let created = try await repo.createSession(session)
        XCTAssertEqual(created.status, .idle)

        // Activate — should transition to initializing
        let (updated, chairmanInput) = try await lifecycleManager.activate(session: created)

        XCTAssertEqual(updated.status, .initializing)
        XCTAssertEqual(updated.id, created.id)
        XCTAssertNotNil(chairmanInput)
        XCTAssertGreaterThanOrEqual(chairmanInput.gitLog.count, 1)

        // Verify persisted state
        let persisted = try await repo.fetchSession(id: created.id)
        XCTAssertEqual(persisted?.status, .initializing)
    }

    // MARK: - Guard Violation: should reject activation on invalid project path

    func test_activate_rejectsOnInvalidProjectPath() async throws {
        let session = CockpitSession(
            projectPath: "/tmp/nonexistent-project-\(UUID().uuidString)",
            status: .idle
        )
        let created = try await repo.createSession(session)

        do {
            _ = try await lifecycleManager.activate(session: created)
            XCTFail("Should have thrown guardViolation for has_valid_project")
        } catch let error as CockpitLifecycleError {
            if case .guardViolation(let guardName, let event) = error {
                XCTAssertEqual(guardName, "has_valid_project")
                XCTAssertEqual(event, "activate")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func test_activate_rejectsOnNonGitDirectory() async throws {
        // Create a directory that exists but is NOT a git repo
        let nonGitDir = NSTemporaryDirectory() + "xroads-nongit-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: nonGitDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: nonGitDir) }

        let session = CockpitSession(
            projectPath: nonGitDir,
            status: .idle
        )
        let created = try await repo.createSession(session)

        do {
            _ = try await lifecycleManager.activate(session: created)
            XCTFail("Should have thrown guardViolation for non-git directory")
        } catch let error as CockpitLifecycleError {
            if case .guardViolation(let guardName, _) = error {
                XCTAssertEqual(guardName, "has_valid_project")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func test_activate_rejectsWhenNotInIdleState() async throws {
        let session = CockpitSession(
            projectPath: tempDir,
            status: .active
        )
        let created = try await repo.createSession(session)

        do {
            _ = try await lifecycleManager.activate(session: created)
            XCTFail("Should have thrown invalidTransition")
        } catch let error as CockpitLifecycleError {
            if case .invalidTransition(let from, let event) = error {
                XCTAssertEqual(from, .active)
                XCTAssertEqual(event, "activate")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Guard Validation

    func test_hasValidProject_returnsTrueForGitRepo() async {
        let result = await contextReader.hasValidProject(at: tempDir)
        XCTAssertTrue(result)
    }

    func test_hasValidProject_returnsFalseForInvalidPath() async {
        let result = await contextReader.hasValidProject(at: "/tmp/nonexistent-\(UUID().uuidString)")
        XCTAssertFalse(result)
    }

    // MARK: - Helpers

    /// Run a git command in the temp directory
    private func runGitAt(_ path: String, args: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "GitTest", code: Int(process.terminationStatus))
        }
    }
}
