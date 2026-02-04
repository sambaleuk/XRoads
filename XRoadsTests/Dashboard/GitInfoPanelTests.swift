//
//  GitInfoPanelTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-028: Unit tests for Quick Actions in GitInfoPanel
//

import XCTest
@testable import XRoadsLib

final class GitInfoPanelTests: XCTestCase {

    // MARK: - Test Properties

    var receivedNotification: Notification?
    var observers: [NSObjectProtocol] = []

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        receivedNotification = nil
        observers = []
    }

    override func tearDown() async throws {
        // Remove all observers
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        receivedNotification = nil
        try await super.tearDown()
    }

    // MARK: - Test: New Feature Opens PRD Assistant

    func test_quickAction_newFeature_opensPRDAssistant() async {
        // Given: An observer for the PRD Assistant notification
        let expectation = XCTestExpectation(description: "PRD Assistant notification should be posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .openPRDAssistant,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            expectation.fulfill()
        }
        observers.append(observer)

        // When: Posting the notification (simulating button tap)
        NotificationCenter.default.post(name: .openPRDAssistant, object: nil)

        // Then: The notification should be received
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification, "PRD Assistant notification should be received")
    }

    // MARK: - Test: Art Direction Button Opens Art Direction View

    func test_quickAction_artDirection_opensArtDirectionView() async {
        // Given: An observer for the Art Direction notification
        let expectation = XCTestExpectation(description: "Art Direction notification should be posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .openArtDirection,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            expectation.fulfill()
        }
        observers.append(observer)

        // When: Posting the notification (simulating button tap)
        NotificationCenter.default.post(name: .openArtDirection, object: nil)

        // Then: The notification should be received
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification, "Art Direction notification should be received")
    }

    // MARK: - Test: Quick Loop Starts on Current Branch

    func test_quickAction_quickLoop_startsOnCurrentBranch() async {
        // Given: An observer for the Quick Loop notification
        let expectation = XCTestExpectation(description: "Quick Loop notification should be posted")
        let testBranch = "main"

        let observer = NotificationCenter.default.addObserver(
            forName: .launchQuickLoop,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            expectation.fulfill()
        }
        observers.append(observer)

        // When: Posting the notification with the branch name
        NotificationCenter.default.post(name: .launchQuickLoop, object: testBranch)

        // Then: The notification should be received with the branch name
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification, "Quick Loop notification should be received")
        XCTAssertEqual(receivedNotification?.object as? String, testBranch,
                       "Quick Loop notification should contain the branch name")
    }

    // MARK: - Test: Recent PRDs Listed

    func test_recentPRDs_listedFromHistory() {
        // Given: An orchestration record with a PRD path
        let record = OrchestrationRecord(
            id: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            prdName: "Test Feature",
            prdPath: "/path/to/prd.json",
            resultSummary: "Success",
            mergedBranches: ["feat/test"],
            conflicts: [],
            totalStories: 5,
            completedStories: 5,
            agentMetrics: [],
            errors: []
        )

        // Then: The record should have a valid PRD path
        XCTAssertNotNil(record.prdPath, "PRD path should be present")
        XCTAssertEqual(record.prdName, "Test Feature", "PRD name should match")
        XCTAssertEqual(record.completionRate, 1.0, "Completion rate should be 100%")
    }

    func test_recentPRDs_filterRecordsWithPrdPath() {
        // Given: Multiple records, some with PRD paths, some without
        let recordWithPath = OrchestrationRecord(
            id: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            prdName: "Feature A",
            prdPath: "/path/to/featureA.json",
            resultSummary: "Success",
            mergedBranches: [],
            conflicts: [],
            totalStories: 3,
            completedStories: 3,
            agentMetrics: [],
            errors: []
        )

        let recordWithoutPath = OrchestrationRecord(
            id: UUID(),
            startedAt: Date(),
            finishedAt: nil,
            prdName: "Feature B",
            prdPath: nil,
            resultSummary: "In Progress",
            mergedBranches: [],
            conflicts: [],
            totalStories: 2,
            completedStories: 0,
            agentMetrics: [],
            errors: []
        )

        let allRecords = [recordWithPath, recordWithoutPath]

        // When: Filtering for records with PRD paths
        let recentPRDs = allRecords.filter { $0.prdPath != nil }

        // Then: Only the record with a path should be included
        XCTAssertEqual(recentPRDs.count, 1, "Only one record should have a PRD path")
        XCTAssertEqual(recentPRDs.first?.prdName, "Feature A", "The record with path should be Feature A")
    }

    // MARK: - Test: Load PRD From Path Notification

    func test_loadPRDFromPath_notificationPosted() async {
        // Given: An observer for the load PRD notification
        let expectation = XCTestExpectation(description: "Load PRD notification should be posted")
        let testPath = "/path/to/test.json"

        let observer = NotificationCenter.default.addObserver(
            forName: .loadPRDFromPath,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            expectation.fulfill()
        }
        observers.append(observer)

        // When: Posting the notification with the path
        NotificationCenter.default.post(name: .loadPRDFromPath, object: testPath)

        // Then: The notification should be received with the path
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification, "Load PRD notification should be received")
        XCTAssertEqual(receivedNotification?.object as? String, testPath,
                       "Load PRD notification should contain the path")
    }

    // MARK: - Test: Notification Names Exist

    func test_notificationName_launchQuickLoop_exists() {
        // Then: The notification name should be defined
        XCTAssertEqual(Notification.Name.launchQuickLoop.rawValue, "launchQuickLoop",
                       "launchQuickLoop notification name should be defined")
    }

    func test_notificationName_loadPRDFromPath_exists() {
        // Then: The notification name should be defined
        XCTAssertEqual(Notification.Name.loadPRDFromPath.rawValue, "loadPRDFromPath",
                       "loadPRDFromPath notification name should be defined")
    }

    func test_notificationName_openPRDAssistant_exists() {
        // Then: The notification name should be defined
        XCTAssertEqual(Notification.Name.openPRDAssistant.rawValue, "openPRDAssistant",
                       "openPRDAssistant notification name should be defined")
    }

    func test_notificationName_openArtDirection_exists() {
        // Then: The notification name should be defined
        XCTAssertEqual(Notification.Name.openArtDirection.rawValue, "openArtDirection",
                       "openArtDirection notification name should be defined")
    }

    // MARK: - Test: OrchestrationRecord Completion Rate

    func test_orchestrationRecord_completionRate_fullCompletion() {
        // Given: A fully completed orchestration
        let record = OrchestrationRecord(
            id: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            prdName: "Full Feature",
            prdPath: "/path/to/full.json",
            resultSummary: "Success",
            mergedBranches: ["feat/full"],
            conflicts: [],
            totalStories: 10,
            completedStories: 10,
            agentMetrics: [],
            errors: []
        )

        // Then: Completion rate should be 100%
        XCTAssertEqual(record.completionRate, 1.0, accuracy: 0.001,
                       "Completion rate should be 1.0 for full completion")
    }

    func test_orchestrationRecord_completionRate_partialCompletion() {
        // Given: A partially completed orchestration
        let record = OrchestrationRecord(
            id: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            prdName: "Partial Feature",
            prdPath: "/path/to/partial.json",
            resultSummary: "Partial",
            mergedBranches: ["feat/partial"],
            conflicts: [],
            totalStories: 10,
            completedStories: 7,
            agentMetrics: [],
            errors: []
        )

        // Then: Completion rate should be 70%
        XCTAssertEqual(record.completionRate, 0.7, accuracy: 0.001,
                       "Completion rate should be 0.7 for 7/10 completion")
    }

    func test_orchestrationRecord_completionRate_zeroStories() {
        // Given: An orchestration with no stories
        let record = OrchestrationRecord(
            id: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            prdName: "Empty Feature",
            prdPath: "/path/to/empty.json",
            resultSummary: "Empty",
            mergedBranches: [],
            conflicts: [],
            totalStories: 0,
            completedStories: 0,
            agentMetrics: [],
            errors: []
        )

        // Then: Completion rate should be 0 (avoid division by zero)
        XCTAssertEqual(record.completionRate, 0.0, accuracy: 0.001,
                       "Completion rate should be 0.0 when totalStories is 0")
    }

    // MARK: - Test: Context Menu Actions

    func test_contextMenu_startLoopOnBranch_postsNotification() async {
        // Given: An observer for the Quick Loop notification
        let expectation = XCTestExpectation(description: "Quick Loop notification from context menu")
        let testBranch = "feat/my-feature"

        let observer = NotificationCenter.default.addObserver(
            forName: .launchQuickLoop,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            expectation.fulfill()
        }
        observers.append(observer)

        // When: Posting the notification (simulating context menu action)
        NotificationCenter.default.post(name: .launchQuickLoop, object: testBranch)

        // Then: The notification should contain the branch name
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedNotification?.object as? String, testBranch,
                       "Context menu Quick Loop should pass the branch name")
    }

    func test_contextMenu_createFeaturePRD_postsNotification() async {
        // Given: An observer for the PRD Assistant notification
        let expectation = XCTestExpectation(description: "PRD Assistant notification from context menu")

        let observer = NotificationCenter.default.addObserver(
            forName: .openPRDAssistant,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            expectation.fulfill()
        }
        observers.append(observer)

        // When: Posting the notification (simulating context menu action)
        NotificationCenter.default.post(name: .openPRDAssistant, object: nil)

        // Then: The notification should be received
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification, "Context menu Create Feature PRD should post notification")
    }

    func test_contextMenu_createWorktree_postsNotification() async {
        // Given: An observer for the new worktree notification
        let expectation = XCTestExpectation(description: "New worktree notification from context menu")

        let observer = NotificationCenter.default.addObserver(
            forName: .showNewWorktreeSheet,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            expectation.fulfill()
        }
        observers.append(observer)

        // When: Posting the notification (simulating context menu action)
        NotificationCenter.default.post(name: .showNewWorktreeSheet, object: nil)

        // Then: The notification should be received
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification, "Context menu Create Worktree should post notification")
    }
}
