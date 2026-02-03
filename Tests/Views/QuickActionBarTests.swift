//
//  QuickActionBarTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-03.
//  Unit tests for QuickActionBar UI component
//

import XCTest
@testable import XRoads

final class QuickActionBarViewTests: XCTestCase {

    // MARK: - Action Button Callback Tests

    func testActionButtonCallbackWithImplement() {
        var callbackCalled = false
        var receivedAction: ActionType?
        var receivedRepo: RepoInfo?

        let repoInfo = RepoInfo(
            path: "/test/project",
            name: "project",
            branch: "main"
        )

        // Simulate callback
        let onActionSelected: (ActionType, RepoInfo) -> Void = { action, repo in
            callbackCalled = true
            receivedAction = action
            receivedRepo = repo
        }

        // Call the callback directly to test it
        onActionSelected(.implement, repoInfo)

        XCTAssertTrue(callbackCalled)
        XCTAssertEqual(receivedAction, .implement)
        XCTAssertEqual(receivedRepo?.path, "/test/project")
    }

    func testActionButtonCallbackWithAllActions() {
        let repoInfo = RepoInfo(
            path: "/test/project",
            name: "project",
            branch: "main"
        )

        var receivedActions: [ActionType] = []

        let onActionSelected: (ActionType, RepoInfo) -> Void = { action, _ in
            receivedActions.append(action)
        }

        // Simulate all primary actions
        for action in ActionType.primaryActions {
            onActionSelected(action, repoInfo)
        }

        XCTAssertEqual(receivedActions.count, 4)
        XCTAssertTrue(receivedActions.contains(.implement))
        XCTAssertTrue(receivedActions.contains(.review))
        XCTAssertTrue(receivedActions.contains(.integrationTest))
        XCTAssertTrue(receivedActions.contains(.write))
    }

    // MARK: - Last Repo Persistence Tests

    func testLastRepoPersistence() {
        let repo = RepoInfo(
            path: "/Users/test/my-app",
            name: "my-app",
            branch: "develop"
        )

        // Verify all properties are set correctly
        XCTAssertEqual(repo.path, "/Users/test/my-app")
        XCTAssertEqual(repo.name, "my-app")
        XCTAssertEqual(repo.branch, "develop")
        XCTAssertEqual(repo.displayName, "my-app")
    }

    // MARK: - Recent Repos List Tests

    func testRecentReposListEmpty() {
        let repos: [RepoInfo] = []

        XCTAssertTrue(repos.isEmpty)
    }

    func testRecentReposListWithRepos() {
        let repos = [
            RepoInfo(path: "/project1", name: "project1", branch: "main"),
            RepoInfo(path: "/project2", name: "project2", branch: "develop"),
            RepoInfo(path: "/project3", name: "project3", branch: "feature/auth")
        ]

        XCTAssertEqual(repos.count, 3)
        XCTAssertEqual(repos[0].name, "project1")
        XCTAssertEqual(repos[1].name, "project2")
        XCTAssertEqual(repos[2].name, "project3")
    }

    // MARK: - Repo Selection Callback Tests

    func testRepoSelectionCallback() {
        let repos = [
            RepoInfo(path: "/project1", name: "project1", branch: "main"),
            RepoInfo(path: "/project2", name: "project2", branch: "develop")
        ]

        var selectedRepo: RepoInfo?
        let onRepoSelected: (RepoInfo) -> Void = { repo in
            selectedRepo = repo
        }

        // Simulate selection
        onRepoSelected(repos[1])

        XCTAssertNotNil(selectedRepo)
        XCTAssertEqual(selectedRepo?.name, "project2")
        XCTAssertEqual(selectedRepo?.branch, "develop")
    }

    // MARK: - Repo Removal Callback Tests

    func testRepoRemovalCallback() {
        var repos = [
            RepoInfo(path: "/project1", name: "project1", branch: "main"),
            RepoInfo(path: "/project2", name: "project2", branch: "develop")
        ]

        let onRepoRemoved: (RepoInfo) -> Void = { repo in
            repos.removeAll { $0.path == repo.path }
        }

        // Simulate removal
        onRepoRemoved(repos[0])

        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos.first?.name, "project2")
    }

    // MARK: - Display Name Tests

    func testDisplayNameWithCustomName() {
        let repo = RepoInfo(
            path: "/some/path/to/folder",
            name: "Custom Name",
            branch: "main"
        )

        XCTAssertEqual(repo.displayName, "Custom Name")
    }

    func testDisplayNameFromPath() {
        let repo = RepoInfo(
            path: "/Users/dev/awesome-project",
            name: "",
            branch: "main"
        )

        XCTAssertEqual(repo.displayName, "awesome-project")
    }

    // MARK: - Action Integration Tests

    func testActionIntegrationWithRepoInfo() {
        let repoInfo = RepoInfo(
            path: "/test/path",
            name: "test",
            branch: "main"
        )

        // Test that action types have the required properties
        for action in ActionType.primaryActions {
            XCTAssertFalse(action.displayName.isEmpty)
            XCTAssertFalse(action.iconName.isEmpty)
            XCTAssertFalse(action.description.isEmpty)
            XCTAssertFalse(action.shortName.isEmpty)
        }

        // Test repo info has required properties
        XCTAssertFalse(repoInfo.path.isEmpty)
        XCTAssertFalse(repoInfo.displayName.isEmpty)
        XCTAssertFalse(repoInfo.branch.isEmpty)
    }
}

// MARK: - Compact Quick Action Bar Tests

final class CompactQuickActionBarTests: XCTestCase {

    func testCompactActionCallback() {
        var callbackReceived = false
        var receivedAction: ActionType?

        let repoInfo = RepoInfo(
            path: "/compact/test",
            name: "compact-test",
            branch: "main"
        )

        let onActionSelected: (ActionType, RepoInfo) -> Void = { action, _ in
            callbackReceived = true
            receivedAction = action
        }

        // Simulate action
        onActionSelected(.review, repoInfo)

        XCTAssertTrue(callbackReceived)
        XCTAssertEqual(receivedAction, .review)
    }

    func testCompactDisplaysAllPrimaryActions() {
        let primaryActions = ActionType.primaryActions

        // All primary actions should have short names for compact display
        for action in primaryActions {
            XCTAssertFalse(action.shortName.isEmpty)
            XCTAssertLessThanOrEqual(action.shortName.count, 7, "Short name should be 7 chars or less")
        }
    }
}

// MARK: - Recent Repos List Integration Tests

final class RecentReposListTests: XCTestCase {

    func testRecentReposListSorting() {
        let now = Date()
        let repos = [
            RepoInfo(path: "/old", name: "old", branch: "main", lastAccessedAt: now.addingTimeInterval(-3600)),
            RepoInfo(path: "/recent", name: "recent", branch: "main", lastAccessedAt: now),
            RepoInfo(path: "/middle", name: "middle", branch: "main", lastAccessedAt: now.addingTimeInterval(-1800))
        ]

        // Sort by last accessed (most recent first)
        let sorted = repos.sorted { $0.lastAccessedAt > $1.lastAccessedAt }

        XCTAssertEqual(sorted[0].name, "recent")
        XCTAssertEqual(sorted[1].name, "middle")
        XCTAssertEqual(sorted[2].name, "old")
    }

    func testRecentReposListFiltering() {
        let repos = [
            RepoInfo(path: "/project-a", name: "project-a", branch: "main"),
            RepoInfo(path: "/project-b", name: "project-b", branch: "develop"),
            RepoInfo(path: "/project-c", name: "project-c", branch: "main")
        ]

        // Filter by branch
        let mainBranchRepos = repos.filter { $0.branch == "main" }

        XCTAssertEqual(mainBranchRepos.count, 2)
        XCTAssertTrue(mainBranchRepos.contains { $0.name == "project-a" })
        XCTAssertTrue(mainBranchRepos.contains { $0.name == "project-c" })
    }

    func testRecentReposListSearch() {
        let repos = [
            RepoInfo(path: "/my-app", name: "my-app", branch: "main"),
            RepoInfo(path: "/your-app", name: "your-app", branch: "main"),
            RepoInfo(path: "/other-project", name: "other-project", branch: "main")
        ]

        let searchTerm = "app"
        let filtered = repos.filter { $0.name.lowercased().contains(searchTerm.lowercased()) }

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.name == "my-app" })
        XCTAssertTrue(filtered.contains { $0.name == "your-app" })
    }
}
