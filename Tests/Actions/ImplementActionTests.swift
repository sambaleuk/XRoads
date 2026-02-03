import Foundation
import XCTest
@testable import XRoads

// MARK: - ImplementAction Tests

final class ImplementActionTests: XCTestCase {

    // MARK: - PRD Loading Tests

    func testLoadPRDFromValidPath() async throws {
        // Given a valid PRD path (using the actual prd.json in the project)
        let implementAction = ImplementAction()

        // When loading from a path that exists
        // Note: In real tests, we'd use a test fixture
        // For now, we verify the loading logic works
        let testPRDContent = """
        {
            "version": "1.0",
            "feature_name": "Test Feature",
            "description": "A test feature for unit testing",
            "user_stories": [
                {
                    "id": "US-001",
                    "title": "First Story",
                    "description": "First story description",
                    "priority": "high",
                    "status": "pending",
                    "depends_on": [],
                    "acceptance_criteria": ["Criteria 1"],
                    "unit_tests": ["Test 1"],
                    "files_to_create": ["File1.swift"],
                    "files_to_modify": [],
                    "estimated_complexity": 3
                }
            ]
        }
        """

        // Create temporary PRD file
        let tempDir = FileManager.default.temporaryDirectory
        let prdPath = tempDir.appendingPathComponent("test_prd.json")
        try testPRDContent.write(to: prdPath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: prdPath)
        }

        // Then PRD should load successfully
        let prd = try await implementAction.loadPRD(from: prdPath.path)
        XCTAssertEqual(prd.featureName, "Test Feature")
        XCTAssertEqual(prd.userStories.count, 1)
        XCTAssertEqual(prd.userStories[0].id, "US-001")
    }

    func testLoadPRDFromInvalidPathThrows() async {
        let implementAction = ImplementAction()

        do {
            _ = try await implementAction.loadPRD(from: "/nonexistent/path/prd.json")
            XCTFail("Expected error to be thrown")
        } catch let error as ImplementActionError {
            if case .prdNotFound = error {
                // Expected
            } else {
                XCTFail("Expected prdNotFound error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testLoadPRDWithInvalidJSONThrows() async throws {
        let implementAction = ImplementAction()
        let invalidJSON = "{ invalid json }"

        let tempDir = FileManager.default.temporaryDirectory
        let prdPath = tempDir.appendingPathComponent("invalid_prd.json")
        try invalidJSON.write(to: prdPath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: prdPath)
        }

        do {
            _ = try await implementAction.loadPRD(from: prdPath.path)
            XCTFail("Expected error to be thrown")
        } catch let error as ImplementActionError {
            if case .prdParsingFailed = error {
                // Expected
            } else {
                XCTFail("Expected prdParsingFailed error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Dependency Ordering Tests

    func testParsePendingStoriesOrdersByDependencies() throws {
        let implementAction = ImplementAction()

        // Given stories with dependencies: US-003 depends on US-002, US-002 depends on US-001
        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test desc",
            userStories: [
                makeStory(id: "US-003", dependsOn: ["US-002"]),
                makeStory(id: "US-001", dependsOn: []),
                makeStory(id: "US-002", dependsOn: ["US-001"])
            ]
        )

        // When parsing pending stories
        let ordered = try implementAction.parsePendingStories(from: prd)

        // Then they should be in dependency order
        XCTAssertEqual(ordered.count, 3)
        let ids = ordered.map { $0.id }
        let us001Index = ids.firstIndex(of: "US-001")!
        let us002Index = ids.firstIndex(of: "US-002")!
        let us003Index = ids.firstIndex(of: "US-003")!

        XCTAssertLessThan(us001Index, us002Index, "US-001 should come before US-002")
        XCTAssertLessThan(us002Index, us003Index, "US-002 should come before US-003")
    }

    func testParsePendingStoriesDetectsCircularDependency() {
        let implementAction = ImplementAction()

        // Given stories with circular dependency
        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test desc",
            userStories: [
                makeStory(id: "US-001", dependsOn: ["US-002"]),
                makeStory(id: "US-002", dependsOn: ["US-001"])
            ]
        )

        // Then parsing should throw circular dependency error
        XCTAssertThrowsError(try implementAction.parsePendingStories(from: prd)) { error in
            if case ImplementActionError.circularDependency = error {
                // Expected
            } else {
                XCTFail("Expected circularDependency error, got \(error)")
            }
        }
    }

    func testParsePendingStoriesSkipsCompleted() throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test desc",
            userStories: [
                makeStory(id: "US-001", status: "complete"),
                makeStory(id: "US-002", status: "pending")
            ]
        )

        let pending = try implementAction.parsePendingStories(from: prd)

        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].id, "US-002")
    }

    func testParsePendingStoriesThrowsWhenAllComplete() {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test desc",
            userStories: [
                makeStory(id: "US-001", status: "complete")
            ]
        )

        XCTAssertThrowsError(try implementAction.parsePendingStories(from: prd)) { error in
            if case ImplementActionError.noPendingStories = error {
                // Expected
            } else {
                XCTFail("Expected noPendingStories error, got \(error)")
            }
        }
    }

    // MARK: - Plan Generation Tests

    func testGeneratePlanCreatesCorrectStructure() throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test Feature",
            description: "Test description",
            userStories: [
                makeStory(id: "US-001", priority: "critical"),
                makeStory(id: "US-002", priority: "high", dependsOn: ["US-001"])
            ]
        )

        let plan = try implementAction.generatePlan(prdPath: "/test/prd.json", prd: prd)

        XCTAssertEqual(plan.featureName, "Test Feature")
        XCTAssertEqual(plan.description, "Test description")
        XCTAssertEqual(plan.prdPath, "/test/prd.json")
        XCTAssertEqual(plan.stories.count, 2)
        XCTAssertEqual(plan.totalStories, 2)
        XCTAssertEqual(plan.completedStories, 0)
        XCTAssertEqual(plan.progress, 0.0)
        XCTAssertFalse(plan.isComplete)
    }

    func testGeneratePlanSetsReadyStatusWhenDependenciesComplete() throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test",
            userStories: [
                makeStory(id: "US-001", status: "complete"),
                makeStory(id: "US-002", status: "pending", dependsOn: ["US-001"])
            ]
        )

        let plan = try implementAction.generatePlan(prdPath: "/test.json", prd: prd)

        // US-001 is complete, so only US-002 should be in the plan
        XCTAssertEqual(plan.stories.count, 1)

        // US-002's dependencies are complete, so it should be ready
        XCTAssertEqual(plan.stories[0].status, .ready)
        XCTAssertTrue(plan.stories[0].dependenciesComplete)
    }

    func testGeneratePlanSetsPendingWhenDependenciesIncomplete() throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test",
            userStories: [
                makeStory(id: "US-001", status: "pending"),
                makeStory(id: "US-002", status: "pending", dependsOn: ["US-001"])
            ]
        )

        let plan = try implementAction.generatePlan(prdPath: "/test.json", prd: prd)

        // US-001 has no dependencies, should be ready
        let us001 = plan.stories.first { $0.storyId == "US-001" }!
        XCTAssertEqual(us001.status, .ready)

        // US-002 depends on US-001 which is pending, so it should be pending
        let us002 = plan.stories.first { $0.storyId == "US-002" }!
        XCTAssertEqual(us002.status, .pending)
        XCTAssertFalse(us002.dependenciesComplete)
    }

    // MARK: - Story Completion Tracking Tests

    func testMarkStoryStartedUpdatesStatus() async throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test",
            userStories: [makeStory(id: "US-001")]
        )

        _ = try implementAction.generatePlan(prdPath: "/test.json", prd: prd)
        await implementAction.markStoryStarted("US-001")

        let plan = await implementAction.getCurrentPlan()
        XCTAssertEqual(plan?.stories[0].status, .inProgress)
        XCTAssertNotNil(plan?.stories[0].startedAt)
    }

    func testMarkStoryCompletedUpdatesProgress() async throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test",
            userStories: [
                makeStory(id: "US-001"),
                makeStory(id: "US-002")
            ]
        )

        _ = try implementAction.generatePlan(prdPath: "/test.json", prd: prd)
        await implementAction.markStoryCompleted("US-001", commitSHA: "abc123")

        let plan = await implementAction.getCurrentPlan()
        let us001 = plan?.stories.first { $0.storyId == "US-001" }!

        XCTAssertEqual(us001?.status, .committed)
        XCTAssertEqual(us001?.commitSHA, "abc123")
        XCTAssertNotNil(us001?.completedAt)
        XCTAssertEqual(plan?.completedStories, 1)
        XCTAssertEqual(plan?.progress, 0.5)
    }

    func testMarkStoryCompletedUpdatesDependentStories() async throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test",
            userStories: [
                makeStory(id: "US-001"),
                makeStory(id: "US-002", dependsOn: ["US-001"])
            ]
        )

        _ = try implementAction.generatePlan(prdPath: "/test.json", prd: prd)

        // US-002 should initially be pending (dependency not complete)
        var plan = await implementAction.getCurrentPlan()
        var us002 = plan?.stories.first { $0.storyId == "US-002" }!
        XCTAssertEqual(us002?.status, .pending)

        // Complete US-001
        await implementAction.markStoryCompleted("US-001", commitSHA: "abc123")

        // US-002 should now be ready
        plan = await implementAction.getCurrentPlan()
        us002 = plan?.stories.first { $0.storyId == "US-002" }!
        XCTAssertEqual(us002?.status, .ready)
        XCTAssertTrue(us002?.dependenciesComplete ?? false)
    }

    func testMarkStoryFailedTracksError() async throws {
        let implementAction = ImplementAction()

        let prd = ExtendedPRDDocument(
            version: "1.0",
            featureName: "Test",
            description: "Test",
            userStories: [makeStory(id: "US-001")]
        )

        _ = try implementAction.generatePlan(prdPath: "/test.json", prd: prd)
        await implementAction.markStoryFailed("US-001", error: "Build failed")

        let plan = await implementAction.getCurrentPlan()
        let us001 = plan?.stories[0]

        XCTAssertEqual(us001?.status, .failed)
        XCTAssertEqual(us001?.errorMessage, "Build failed")
    }

    // MARK: - Implementation Instructions Tests

    func testGenerateImplementationInstructionsFormat() async throws {
        let implementAction = ImplementAction()

        let story = StoryImplementationPlan(
            id: "plan-001",
            storyId: "US-001",
            title: "Test Story",
            description: "Test description",
            priority: .high,
            dependencies: ["US-000"],
            acceptanceCriteria: ["Criteria 1", "Criteria 2"],
            unitTests: ["Test case 1", "Test case 2"],
            filesToCreate: ["NewFile.swift"],
            filesToModify: ["ExistingFile.swift"],
            estimatedComplexity: 5
        )

        let instructions = await implementAction.generateImplementationInstructions(for: story)

        // Verify key sections are present
        XCTAssertTrue(instructions.contains("## Implementing: US-001"))
        XCTAssertTrue(instructions.contains("### Description"))
        XCTAssertTrue(instructions.contains("Test description"))
        XCTAssertTrue(instructions.contains("### Dependencies (already complete)"))
        XCTAssertTrue(instructions.contains("- US-000"))
        XCTAssertTrue(instructions.contains("### Acceptance Criteria"))
        XCTAssertTrue(instructions.contains("- [ ] Criteria 1"))
        XCTAssertTrue(instructions.contains("### Required Unit Tests"))
        XCTAssertTrue(instructions.contains("- [ ] Test case 1"))
        XCTAssertTrue(instructions.contains("### Files to Create"))
        XCTAssertTrue(instructions.contains("- NewFile.swift"))
        XCTAssertTrue(instructions.contains("### Files to Modify"))
        XCTAssertTrue(instructions.contains("- ExistingFile.swift"))
        XCTAssertTrue(instructions.contains("### Commit Format"))
    }

    func testGenerateCommitMessageFormat() async throws {
        let implementAction = ImplementAction()

        let story = StoryImplementationPlan(
            id: "plan-001",
            storyId: "US-V3-010",
            title: "Implement Loop Action",
            description: "Create the implement action",
            priority: .critical,
            dependencies: [],
            acceptanceCriteria: ["PRD loading works"],
            unitTests: ["Test PRD loading"],
            filesToCreate: ["XRoads/Actions/ImplementAction.swift"],
            filesToModify: [],
            estimatedComplexity: 8
        )

        let message = await implementAction.generateCommitMessage(for: story)

        XCTAssertTrue(message.contains("feat(actions): US-V3-010 Implement Loop Action"))
        XCTAssertTrue(message.contains("Create the implement action"))
        XCTAssertTrue(message.contains("- PRD loading works"))
        XCTAssertTrue(message.contains("- Test PRD loading"))
    }

    // MARK: - Error Description Tests

    func testImplementActionErrorDescriptions() {
        let errors: [ImplementActionError] = [
            .prdNotFound(path: "/test/path"),
            .prdParsingFailed(underlying: NSError(domain: "test", code: 1)),
            .noPendingStories,
            .storyNotFound(id: "US-001"),
            .dependencyNotComplete(story: "US-002", dependency: "US-001"),
            .circularDependency(stories: ["US-001", "US-002", "US-001"]),
            .planGenerationFailed(reason: "Test reason"),
            .storyImplementationFailed(storyId: "US-001", reason: "Test fail"),
            .buildFailed(output: "Build error"),
            .testsFailed(output: "Test error"),
            .commitFailed(storyId: "US-001", reason: "Commit error")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    // MARK: - Helpers

    private func makeStory(
        id: String,
        title: String? = nil,
        priority: String = "medium",
        status: String = "pending",
        dependsOn: [String] = []
    ) -> ExtendedPRDUserStory {
        ExtendedPRDUserStory(
            id: id,
            title: title ?? "Story \(id)",
            description: "Description for \(id)",
            priority: priority,
            status: status,
            completedAt: nil,
            dependsOn: dependsOn,
            acceptanceCriteria: ["Criteria for \(id)"],
            unitTests: ["Test for \(id)"],
            filesToCreate: [],
            filesToModify: [],
            estimatedComplexity: 3
        )
    }
}

// MARK: - StoryImplementationStatus Tests

final class StoryImplementationStatusTests: XCTestCase {

    func testIsCompleteOnlyForCommitted() {
        XCTAssertFalse(StoryImplementationStatus.pending.isComplete)
        XCTAssertFalse(StoryImplementationStatus.ready.isComplete)
        XCTAssertFalse(StoryImplementationStatus.inProgress.isComplete)
        XCTAssertFalse(StoryImplementationStatus.implemented.isComplete)
        XCTAssertFalse(StoryImplementationStatus.tested.isComplete)
        XCTAssertTrue(StoryImplementationStatus.committed.isComplete)
        XCTAssertFalse(StoryImplementationStatus.failed.isComplete)
    }

    func testCanStartOnlyForReady() {
        XCTAssertFalse(StoryImplementationStatus.pending.canStart)
        XCTAssertTrue(StoryImplementationStatus.ready.canStart)
        XCTAssertFalse(StoryImplementationStatus.inProgress.canStart)
        XCTAssertFalse(StoryImplementationStatus.implemented.canStart)
        XCTAssertFalse(StoryImplementationStatus.tested.canStart)
        XCTAssertFalse(StoryImplementationStatus.committed.canStart)
        XCTAssertFalse(StoryImplementationStatus.failed.canStart)
    }
}

// MARK: - ImplementationPlan Tests

final class ImplementationPlanTests: XCTestCase {

    func testProgressCalculation() {
        var plan = ImplementationPlan(
            id: UUID(),
            prdPath: "/test.json",
            featureName: "Test",
            description: "Test",
            stories: [
                makeStoryPlan(storyId: "US-001", status: .committed),
                makeStoryPlan(storyId: "US-002", status: .inProgress),
                makeStoryPlan(storyId: "US-003", status: .pending),
                makeStoryPlan(storyId: "US-004", status: .ready)
            ],
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertEqual(plan.totalStories, 4)
        XCTAssertEqual(plan.completedStories, 1)
        XCTAssertEqual(plan.progress, 0.25)
        XCTAssertFalse(plan.isComplete)

        // Complete all stories
        for i in 0..<plan.stories.count {
            plan.stories[i].status = .committed
        }

        XCTAssertEqual(plan.completedStories, 4)
        XCTAssertEqual(plan.progress, 1.0)
        XCTAssertTrue(plan.isComplete)
    }

    func testNextReadyStory() {
        let plan = ImplementationPlan(
            id: UUID(),
            prdPath: "/test.json",
            featureName: "Test",
            description: "Test",
            stories: [
                makeStoryPlan(storyId: "US-001", status: .committed),
                makeStoryPlan(storyId: "US-002", status: .pending),
                makeStoryPlan(storyId: "US-003", status: .ready),
                makeStoryPlan(storyId: "US-004", status: .ready)
            ],
            createdAt: Date(),
            updatedAt: Date()
        )

        let next = plan.nextReadyStory
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.storyId, "US-003")
    }

    func testOrderedStoriesRespectsDependencies() {
        let plan = ImplementationPlan(
            id: UUID(),
            prdPath: "/test.json",
            featureName: "Test",
            description: "Test",
            stories: [
                makeStoryPlan(storyId: "US-003", dependencies: ["US-002"], priority: .low),
                makeStoryPlan(storyId: "US-001", dependencies: [], priority: .high),
                makeStoryPlan(storyId: "US-002", dependencies: ["US-001"], priority: .medium)
            ],
            createdAt: Date(),
            updatedAt: Date()
        )

        let ordered = plan.orderedStories
        let ids = ordered.map { $0.storyId }

        // US-001 should come first (no dependencies, high priority)
        // US-002 should come second (depends on US-001)
        // US-003 should come last (depends on US-002)
        XCTAssertEqual(ids[0], "US-001")
        XCTAssertEqual(ids[1], "US-002")
        XCTAssertEqual(ids[2], "US-003")
    }

    private func makeStoryPlan(
        storyId: String,
        status: StoryImplementationStatus = .pending,
        dependencies: [String] = [],
        priority: TaskPriority = .medium
    ) -> StoryImplementationPlan {
        StoryImplementationPlan(
            id: UUID().uuidString,
            storyId: storyId,
            title: "Story \(storyId)",
            description: "Description",
            priority: priority,
            dependencies: dependencies,
            acceptanceCriteria: [],
            unitTests: [],
            filesToCreate: [],
            filesToModify: [],
            estimatedComplexity: 3,
            dependenciesComplete: dependencies.isEmpty,
            status: status
        )
    }
}

// MARK: - StoryCompletionTracker Tests

final class StoryCompletionTrackerTests: XCTestCase {

    func testTrackStoryStarted() {
        var tracker = StoryCompletionTracker()

        tracker.markStarted("US-001")

        XCTAssertTrue(tracker.isInProgress("US-001"))
        XCTAssertFalse(tracker.isCompleted("US-001"))
        XCTAssertEqual(tracker.currentStory, "US-001")
    }

    func testTrackStoryCompleted() {
        var tracker = StoryCompletionTracker()

        tracker.markStarted("US-001")
        tracker.markCompleted("US-001")

        XCTAssertFalse(tracker.isInProgress("US-001"))
        XCTAssertTrue(tracker.isCompleted("US-001"))
        XCTAssertNil(tracker.currentStory)
        XCTAssertEqual(tracker.completedCount, 1)
    }

    func testTrackStoryFailed() {
        var tracker = StoryCompletionTracker()

        tracker.markStarted("US-001")
        tracker.markFailed("US-001")

        XCTAssertFalse(tracker.isInProgress("US-001"))
        XCTAssertTrue(tracker.isFailed("US-001"))
        XCTAssertEqual(tracker.failedCount, 1)
    }

    func testAreDependenciesComplete() {
        var tracker = StoryCompletionTracker()

        tracker.markCompleted("US-001")
        tracker.markCompleted("US-002")

        XCTAssertTrue(tracker.areDependenciesComplete(["US-001", "US-002"]))
        XCTAssertFalse(tracker.areDependenciesComplete(["US-001", "US-003"]))
    }
}
