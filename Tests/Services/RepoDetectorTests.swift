//
//  RepoDetectorTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-03.
//  Unit tests for RepoDetector service
//

import XCTest
@testable import XRoads

final class RepoDetectorTests: XCTestCase {

    // MARK: - RepoInfo Tests

    func testRepoInfoInit() {
        let repoInfo = RepoInfo(
            path: "/Users/test/project",
            name: "project",
            branch: "main"
        )

        XCTAssertEqual(repoInfo.path, "/Users/test/project")
        XCTAssertEqual(repoInfo.name, "project")
        XCTAssertEqual(repoInfo.branch, "main")
        XCTAssertEqual(repoInfo.displayName, "project")
    }

    func testRepoInfoDisplayNameFromPath() {
        let repoInfo = RepoInfo(
            path: "/Users/test/my-awesome-app",
            name: "",
            branch: "develop"
        )

        XCTAssertEqual(repoInfo.displayName, "my-awesome-app")
    }

    func testRepoInfoCodable() throws {
        let original = RepoInfo(
            path: "/Users/test/project",
            name: "project",
            branch: "feature/auth"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RepoInfo.self, from: encoded)

        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.branch, original.branch)
    }

    func testRepoInfoHashable() {
        let repo1 = RepoInfo(path: "/path/a", name: "a", branch: "main")
        let repo2 = RepoInfo(path: "/path/a", name: "a", branch: "main")
        let repo3 = RepoInfo(path: "/path/b", name: "b", branch: "main")

        // Different instances with same data should not be equal due to different UUIDs
        XCTAssertNotEqual(repo1.id, repo2.id)
        XCTAssertNotEqual(repo1.id, repo3.id)
    }

    func testRepoInfoIdentifiable() {
        let repo = RepoInfo(path: "/test", name: "test", branch: "main")
        XCTAssertNotNil(repo.id)
    }

    // MARK: - RepoDetectorError Tests

    func testRepoDetectorErrorDescriptions() {
        let notARepo = RepoDetectorError.notAGitRepository(path: "/some/path")
        XCTAssertTrue(notARepo.localizedDescription.contains("/some/path"))

        let notFound = RepoDetectorError.pathNotFound(path: "/missing/path")
        XCTAssertTrue(notFound.localizedDescription.contains("/missing/path"))

        let gitFailed = RepoDetectorError.gitCommandFailed("checkout failed")
        XCTAssertTrue(gitFailed.localizedDescription.contains("checkout failed"))

        let persistFailed = RepoDetectorError.persistenceFailed("write error")
        XCTAssertTrue(persistFailed.localizedDescription.contains("write error"))
    }

    // MARK: - RepoDetectionResult Tests

    func testRepoDetectionResultNotARepo() {
        let result = RepoDetectionResult.notARepo

        XCTAssertFalse(result.isGitRepo)
        XCTAssertNil(result.repoInfo)
        XCTAssertTrue(result.recentRepos.isEmpty)
    }

    func testRepoDetectionResultWithRepo() {
        let repoInfo = RepoInfo(path: "/test", name: "test", branch: "main")
        let recentRepos = [
            RepoInfo(path: "/recent1", name: "recent1", branch: "main"),
            RepoInfo(path: "/recent2", name: "recent2", branch: "develop")
        ]

        let result = RepoDetectionResult(
            isGitRepo: true,
            repoInfo: repoInfo,
            recentRepos: recentRepos
        )

        XCTAssertTrue(result.isGitRepo)
        XCTAssertNotNil(result.repoInfo)
        XCTAssertEqual(result.repoInfo?.name, "test")
        XCTAssertEqual(result.recentRepos.count, 2)
    }

    // MARK: - Branch Name Generation Tests

    func testGenerateBranchNameForImplement() async {
        let detector = RepoDetector()
        let branchName = await detector.generateBranchName(for: .implement, baseName: "User Authentication")

        XCTAssertTrue(branchName.hasPrefix("feat/"))
        XCTAssertTrue(branchName.contains("user-authentication"))
    }

    func testGenerateBranchNameForReview() async {
        let detector = RepoDetector()
        let branchName = await detector.generateBranchName(for: .review, baseName: "Code Review")

        XCTAssertTrue(branchName.hasPrefix("review/"))
        XCTAssertTrue(branchName.contains("code-review"))
    }

    func testGenerateBranchNameForIntegrationTest() async {
        let detector = RepoDetector()
        let branchName = await detector.generateBranchName(for: .integrationTest, baseName: "E2E Tests")

        XCTAssertTrue(branchName.hasPrefix("test/"))
        XCTAssertTrue(branchName.contains("e2e-tests"))
    }

    func testGenerateBranchNameForWrite() async {
        let detector = RepoDetector()
        let branchName = await detector.generateBranchName(for: .write, baseName: "API Docs")

        XCTAssertTrue(branchName.hasPrefix("docs/"))
        XCTAssertTrue(branchName.contains("api-docs"))
    }

    func testGenerateBranchNameForCustom() async {
        let detector = RepoDetector()
        let branchName = await detector.generateBranchName(for: .custom, baseName: "My Task")

        XCTAssertTrue(branchName.hasPrefix("task/"))
        XCTAssertTrue(branchName.contains("my-task"))
    }

    func testGenerateBranchNameSanitization() async {
        let detector = RepoDetector()
        let branchName = await detector.generateBranchName(for: .implement, baseName: "Feature With_Special!@#$Characters")

        // Should only contain alphanumeric and hyphens
        let sanitizedPart = branchName.replacingOccurrences(of: "feat/", with: "")
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let isValid = sanitizedPart.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }

        XCTAssertTrue(isValid, "Branch name contains invalid characters: \(branchName)")
    }

    // MARK: - Worktree Path Generation Tests

    func testGenerateWorktreePath() async {
        let detector = RepoDetector()
        let path = await detector.generateWorktreePath(
            repoPath: "/Users/dev/my-project",
            branchName: "feat/new-feature"
        )

        XCTAssertTrue(path.contains(".xroads"))
        XCTAssertTrue(path.contains("worktrees"))
        XCTAssertTrue(path.contains("my-project"))
        XCTAssertTrue(path.contains("feat-new-feature"))
    }

    func testGenerateWorktreePathHandlesSlashes() async {
        let detector = RepoDetector()
        let path = await detector.generateWorktreePath(
            repoPath: "/Users/dev/project",
            branchName: "feature/auth/oauth"
        )

        XCTAssertFalse(path.hasSuffix("/"), "Path should not end with slash")
        // Slashes in branch name should be converted to hyphens
        let lastComponent = URL(fileURLWithPath: path).lastPathComponent
        XCTAssertFalse(lastComponent.contains("/"), "Branch folder should not contain slashes")
    }

    // MARK: - Non-Git Directory Tests

    func testDetectNonExistentDirectory() async {
        let detector = RepoDetector()
        let result = await detector.detectRepository(at: "/non/existent/path/12345")

        XCTAssertFalse(result.isGitRepo)
        XCTAssertNil(result.repoInfo)
    }

    func testIsGitRepositoryReturnsFalseForNonRepo() async {
        let detector = RepoDetector()
        // Using a system directory that definitely exists but isn't a git repo
        let isGitRepo = await detector.isGitRepository(at: "/tmp")

        XCTAssertFalse(isGitRepo)
    }

    // MARK: - Last Repo Persistence Tests

    func testGetLastUsedRepoReturnsNilWhenEmpty() async {
        let mockDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let detector = RepoDetector(userDefaults: mockDefaults)

        let lastRepo = await detector.getLastUsedRepo()
        XCTAssertNil(lastRepo)
    }

    func testClearRecentRepos() async {
        let mockDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let detector = RepoDetector(userDefaults: mockDefaults)

        // Add a repo
        let repo = RepoInfo(path: "/test/path", name: "test", branch: "main")
        await detector.addToRecentRepos(repo)

        // Clear
        await detector.clearRecentRepos()

        let recentRepos = await detector.loadRecentRepos()
        XCTAssertTrue(recentRepos.isEmpty)
    }

    func testRemoveFromRecentRepos() async {
        let mockDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let detector = RepoDetector(userDefaults: mockDefaults)

        // Add repos
        let repo1 = RepoInfo(path: "/test/path1", name: "test1", branch: "main")
        let repo2 = RepoInfo(path: "/test/path2", name: "test2", branch: "main")
        await detector.addToRecentRepos(repo1)
        await detector.addToRecentRepos(repo2)

        // Remove one
        await detector.removeFromRecentRepos(path: "/test/path1")

        let recentRepos = await detector.loadRecentRepos()
        XCTAssertEqual(recentRepos.count, 1)
        XCTAssertEqual(recentRepos.first?.path, "/test/path2")
    }

    func testMaxRecentReposLimit() async {
        let mockDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let detector = RepoDetector(userDefaults: mockDefaults, maxRecentRepos: 3)

        // Add more repos than the limit
        for i in 1...5 {
            let repo = RepoInfo(path: "/test/path\(i)", name: "test\(i)", branch: "main")
            await detector.addToRecentRepos(repo)
        }

        let recentRepos = await detector.loadRecentRepos()
        XCTAssertEqual(recentRepos.count, 3)
        // Most recent should be first
        XCTAssertEqual(recentRepos.first?.path, "/test/path5")
    }

    func testAddDuplicateRepoUpdatesPosition() async {
        let mockDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let detector = RepoDetector(userDefaults: mockDefaults)

        // Add repos
        let repo1 = RepoInfo(path: "/test/path1", name: "test1", branch: "main")
        let repo2 = RepoInfo(path: "/test/path2", name: "test2", branch: "main")
        await detector.addToRecentRepos(repo1)
        await detector.addToRecentRepos(repo2)

        // Add repo1 again
        let repo1Updated = RepoInfo(path: "/test/path1", name: "test1-updated", branch: "develop")
        await detector.addToRecentRepos(repo1Updated)

        let recentRepos = await detector.loadRecentRepos()
        XCTAssertEqual(recentRepos.count, 2)
        // repo1Updated should now be first
        XCTAssertEqual(recentRepos.first?.path, "/test/path1")
        XCTAssertEqual(recentRepos.first?.branch, "develop")
    }
}

// MARK: - QuickActionBar Tests

final class QuickActionBarTests: XCTestCase {

    func testActionTypePrimaryActions() {
        let primaryActions = ActionType.primaryActions

        XCTAssertEqual(primaryActions.count, 4)
        XCTAssertTrue(primaryActions.contains(.implement))
        XCTAssertTrue(primaryActions.contains(.review))
        XCTAssertTrue(primaryActions.contains(.integrationTest))
        XCTAssertTrue(primaryActions.contains(.write))
        XCTAssertFalse(primaryActions.contains(.custom))
    }

    func testActionTypeShortNames() {
        XCTAssertEqual(ActionType.implement.shortName, "Impl")
        XCTAssertEqual(ActionType.review.shortName, "Review")
        XCTAssertEqual(ActionType.integrationTest.shortName, "Test")
        XCTAssertEqual(ActionType.write.shortName, "Docs")
        XCTAssertEqual(ActionType.custom.shortName, "Custom")
    }

    func testRepoInfoForQuickActionBar() {
        let repoInfo = RepoInfo(
            path: "/Users/dev/my-project",
            name: "my-project",
            branch: "main"
        )

        XCTAssertEqual(repoInfo.displayName, "my-project")
        XCTAssertEqual(repoInfo.branch, "main")
        XCTAssertEqual(repoInfo.path, "/Users/dev/my-project")
    }
}
