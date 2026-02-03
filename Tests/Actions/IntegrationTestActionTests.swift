import XCTest
@testable import XRoads

/// Tests for IntegrationTestAction
/// NOTE: These are unit tests for the action itself - the action generates integration test PLANS
final class IntegrationTestActionTests: XCTestCase {

    // MARK: - IntegrationPointType Tests

    func testIntegrationPointTypeDisplayNames() {
        XCTAssertEqual(IntegrationPointType.serviceToService.displayName, "Service-to-Service")
        XCTAssertEqual(IntegrationPointType.serviceToExternal.displayName, "External Integration")
        XCTAssertEqual(IntegrationPointType.viewModelToService.displayName, "ViewModel-Service")
        XCTAssertEqual(IntegrationPointType.processExecution.displayName, "Process Execution")
        XCTAssertEqual(IntegrationPointType.fileSystem.displayName, "File System")
        XCTAssertEqual(IntegrationPointType.network.displayName, "Network")
        XCTAssertEqual(IntegrationPointType.database.displayName, "Database")
        XCTAssertEqual(IntegrationPointType.mcp.displayName, "MCP Protocol")
    }

    func testIntegrationPointTypeIconNames() {
        for type in IntegrationPointType.allCases {
            XCTAssertFalse(type.iconName.isEmpty, "Icon name should not be empty for \(type)")
        }
    }

    func testIntegrationPointTypeTestPriority() {
        // External/network should have highest priority
        XCTAssertGreaterThanOrEqual(IntegrationPointType.serviceToExternal.testPriority, IntegrationPointType.fileSystem.testPriority)
        XCTAssertGreaterThanOrEqual(IntegrationPointType.network.testPriority, IntegrationPointType.fileSystem.testPriority)

        // MCP and process execution should be high priority
        XCTAssertGreaterThanOrEqual(IntegrationPointType.mcp.testPriority, IntegrationPointType.serviceToService.testPriority)
        XCTAssertGreaterThanOrEqual(IntegrationPointType.processExecution.testPriority, IntegrationPointType.serviceToService.testPriority)
    }

    // MARK: - IntegrationComplexity Tests

    func testIntegrationComplexityDisplayNames() {
        XCTAssertEqual(IntegrationComplexity.low.displayName, "Low")
        XCTAssertEqual(IntegrationComplexity.medium.displayName, "Medium")
        XCTAssertEqual(IntegrationComplexity.high.displayName, "High")
        XCTAssertEqual(IntegrationComplexity.critical.displayName, "Critical")
    }

    func testIntegrationComplexityWeight() {
        XCTAssertLessThan(IntegrationComplexity.low.weight, IntegrationComplexity.medium.weight)
        XCTAssertLessThan(IntegrationComplexity.medium.weight, IntegrationComplexity.high.weight)
        XCTAssertLessThan(IntegrationComplexity.high.weight, IntegrationComplexity.critical.weight)
    }

    // MARK: - IntegrationPoint Tests

    func testIntegrationPointInitialization() {
        let point = IntegrationPoint(
            type: .serviceToService,
            sourceFile: "XRoads/Services/MyService.swift",
            sourceName: "MyService",
            targetName: "OtherService",
            lineNumber: 42,
            description: "MyService depends on OtherService",
            complexity: .medium,
            suggestedTestApproach: "Mock OtherService"
        )

        XCTAssertEqual(point.type, .serviceToService)
        XCTAssertEqual(point.sourceFile, "XRoads/Services/MyService.swift")
        XCTAssertEqual(point.sourceName, "MyService")
        XCTAssertEqual(point.targetName, "OtherService")
        XCTAssertEqual(point.lineNumber, 42)
        XCTAssertEqual(point.complexity, .medium)
        XCTAssertFalse(point.description.isEmpty)
        XCTAssertFalse(point.suggestedTestApproach.isEmpty)
    }

    func testIntegrationPointLocationString() {
        let pointWithLine = IntegrationPoint(
            type: .serviceToService,
            sourceFile: "Services/MyService.swift",
            sourceName: "MyService",
            targetName: "OtherService",
            lineNumber: 42,
            description: "Test",
            suggestedTestApproach: "Mock"
        )
        XCTAssertEqual(pointWithLine.locationString, "Services/MyService.swift:42")

        let pointWithoutLine = IntegrationPoint(
            type: .serviceToService,
            sourceFile: "Services/MyService.swift",
            sourceName: "MyService",
            targetName: "OtherService",
            description: "Test",
            suggestedTestApproach: "Mock"
        )
        XCTAssertEqual(pointWithoutLine.locationString, "Services/MyService.swift")
    }

    func testIntegrationPointHashable() {
        let point1 = IntegrationPoint(
            id: UUID(),
            type: .serviceToService,
            sourceFile: "file.swift",
            sourceName: "Source",
            targetName: "Target",
            description: "Test",
            suggestedTestApproach: "Mock"
        )
        let point2 = IntegrationPoint(
            id: point1.id,
            type: .serviceToService,
            sourceFile: "file.swift",
            sourceName: "Source",
            targetName: "Target",
            description: "Test",
            suggestedTestApproach: "Mock"
        )

        XCTAssertEqual(point1, point2)

        var set = Set<IntegrationPoint>()
        set.insert(point1)
        XCTAssertTrue(set.contains(point2))
    }

    // MARK: - E2EFlow Tests

    func testE2EFlowInitialization() {
        let steps = [
            E2EStep(order: 1, action: "Open view", expectedResult: "View displays", component: "MyView"),
            E2EStep(order: 2, action: "Click button", expectedResult: "Action triggers", component: "MyView")
        ]

        let flow = E2EFlow(
            name: "Test Flow",
            description: "A test flow",
            steps: steps,
            entryPoint: "Views/MyView.swift",
            criticalPath: true,
            estimatedDuration: "1-5s"
        )

        XCTAssertEqual(flow.name, "Test Flow")
        XCTAssertEqual(flow.stepCount, 2)
        XCTAssertTrue(flow.criticalPath)
        XCTAssertEqual(flow.estimatedDuration, "1-5s")
    }

    func testE2EStepInitialization() {
        let step = E2EStep(
            order: 1,
            action: "Click submit",
            expectedResult: "Form submits",
            component: "FormView",
            assertions: ["Loading shown", "Success message"]
        )

        XCTAssertEqual(step.order, 1)
        XCTAssertEqual(step.action, "Click submit")
        XCTAssertEqual(step.expectedResult, "Form submits")
        XCTAssertEqual(step.component, "FormView")
        XCTAssertEqual(step.assertions.count, 2)
    }

    // MARK: - PerformanceTestScenario Tests

    func testPerformanceTestScenarioInitialization() {
        let scenario = PerformanceTestScenario(
            name: "Process Launch Test",
            description: "Measure process launch time",
            targetComponent: "ProcessRunner",
            operation: "Launch process",
            expectedLatency: "< 500ms",
            loadProfile: .single,
            metrics: [.latency, .memoryUsage]
        )

        XCTAssertEqual(scenario.name, "Process Launch Test")
        XCTAssertEqual(scenario.targetComponent, "ProcessRunner")
        XCTAssertEqual(scenario.loadProfile, .single)
        XCTAssertEqual(scenario.metrics.count, 2)
        XCTAssertTrue(scenario.metrics.contains(.latency))
        XCTAssertTrue(scenario.metrics.contains(.memoryUsage))
    }

    func testLoadProfileDisplayNames() {
        XCTAssertEqual(LoadProfile.single.displayName, "Single Operation")
        XCTAssertEqual(LoadProfile.burst.displayName, "Burst Load")
        XCTAssertEqual(LoadProfile.sustained.displayName, "Sustained Load")
        XCTAssertEqual(LoadProfile.stress.displayName, "Stress Test")
    }

    func testPerformanceMetricDisplayNames() {
        XCTAssertEqual(PerformanceMetric.latency.displayName, "Latency")
        XCTAssertEqual(PerformanceMetric.throughput.displayName, "Throughput")
        XCTAssertEqual(PerformanceMetric.memoryUsage.displayName, "Memory Usage")
        XCTAssertEqual(PerformanceMetric.cpuUsage.displayName, "CPU Usage")
        XCTAssertEqual(PerformanceMetric.errorRate.displayName, "Error Rate")
    }

    // MARK: - IntegrationTestPlan Tests

    func testIntegrationTestPlanInitialization() {
        let plan = IntegrationTestPlan(workingDirectory: "/path/to/project")

        XCTAssertEqual(plan.workingDirectory, "/path/to/project")
        XCTAssertTrue(plan.integrationPoints.isEmpty)
        XCTAssertTrue(plan.e2eFlows.isEmpty)
        XCTAssertTrue(plan.performanceScenarios.isEmpty)
        XCTAssertTrue(plan.suggestedTestFiles.isEmpty)
    }

    func testIntegrationTestPlanTotalTestCount() {
        var plan = IntegrationTestPlan(workingDirectory: "/path")

        plan.integrationPoints = [
            IntegrationPoint(type: .serviceToService, sourceFile: "a.swift", sourceName: "A", targetName: "B", description: "test", suggestedTestApproach: "mock"),
            IntegrationPoint(type: .network, sourceFile: "b.swift", sourceName: "B", targetName: "API", description: "test", suggestedTestApproach: "mock")
        ]

        plan.e2eFlows = [
            E2EFlow(name: "Flow1", description: "test", steps: [], entryPoint: "view.swift")
        ]

        plan.performanceScenarios = [
            PerformanceTestScenario(name: "Perf1", description: "test", targetComponent: "C", operation: "op", expectedLatency: "< 1s")
        ]

        XCTAssertEqual(plan.totalTestCount, 4)
    }

    func testIntegrationTestPlanHasContent() {
        var plan = IntegrationTestPlan(workingDirectory: "/path")
        XCTAssertFalse(plan.hasContent)

        plan.integrationPoints = [
            IntegrationPoint(type: .serviceToService, sourceFile: "a.swift", sourceName: "A", targetName: "B", description: "test", suggestedTestApproach: "mock")
        ]
        XCTAssertTrue(plan.hasContent)
    }

    // MARK: - SuggestedTestFile Tests

    func testSuggestedTestFileInitialization() {
        let file = SuggestedTestFile(
            path: "Tests/Integration/MyServiceIntegrationTests.swift",
            testType: .integration,
            targetComponents: ["MyService", "OtherService"],
            suggestedTestCases: ["testMyServiceOtherServiceIntegration"]
        )

        XCTAssertEqual(file.path, "Tests/Integration/MyServiceIntegrationTests.swift")
        XCTAssertEqual(file.testType, .integration)
        XCTAssertEqual(file.targetComponents.count, 2)
        XCTAssertEqual(file.suggestedTestCases.count, 1)
    }

    func testTestFileTypeDisplayNames() {
        XCTAssertEqual(TestFileType.integration.displayName, "Integration Tests")
        XCTAssertEqual(TestFileType.e2e.displayName, "End-to-End Tests")
        XCTAssertEqual(TestFileType.performance.displayName, "Performance Tests")
    }

    func testTestFileTypeSuffix() {
        XCTAssertEqual(TestFileType.integration.fileSuffix, "IntegrationTests")
        XCTAssertEqual(TestFileType.e2e.fileSuffix, "E2ETests")
        XCTAssertEqual(TestFileType.performance.fileSuffix, "PerformanceTests")
    }

    // MARK: - IntegrationTestActionError Tests

    func testIntegrationTestActionErrorDescriptions() {
        let errors: [IntegrationTestActionError] = [
            .noIntegrationPointsFound,
            .analysisFailure(reason: "test reason"),
            .testGenerationFailed(reason: "test reason"),
            .outputFailed(path: "/path", reason: "test reason"),
            .invalidWorkingDirectory(path: "/path"),
            .gitNotAvailable,
            .noTestableFlowsFound,
            .configurationError(reason: "test reason")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    // MARK: - No Unit Test Overlap Tests

    func testVerifyNoUnitTestOverlapWithEmptyPlan() async {
        let action = IntegrationTestAction()

        // With no plan, should return true (no overlap possible)
        let result = await action.verifyNoUnitTestOverlap(existingTestFiles: ["Tests/MyServiceTests.swift"])
        XCTAssertTrue(result)
    }

    // MARK: - Convenience Method Tests

    func testGetPlanSummaryWithNoPlan() async {
        let action = IntegrationTestAction()
        let summary = await action.getPlanSummary()
        XCTAssertEqual(summary, "No plan loaded")
    }

    func testHasCriticalFlowsWithNoPlan() async {
        let action = IntegrationTestAction()
        let result = await action.hasCriticalFlows()
        XCTAssertFalse(result)
    }

    func testGetHighComplexityPointsWithNoPlan() async {
        let action = IntegrationTestAction()
        let points = await action.getHighComplexityPoints()
        XCTAssertTrue(points.isEmpty)
    }

    func testGetCurrentPlanInitiallyNil() async {
        let action = IntegrationTestAction()
        let plan = await action.getCurrentPlan()
        XCTAssertNil(plan)
    }

    func testGetIntegrationPointsByType() async {
        let action = IntegrationTestAction()
        let points = await action.getIntegrationPoints(type: .serviceToService)
        XCTAssertTrue(points.isEmpty)
    }

    func testGetCriticalFlows() async {
        let action = IntegrationTestAction()
        let flows = await action.getCriticalFlows()
        XCTAssertTrue(flows.isEmpty)
    }
}

// MARK: - E2EFlow Hashable Tests

final class E2EFlowHashableTests: XCTestCase {

    func testE2EFlowEquatable() {
        let id = UUID()
        let steps = [E2EStep(order: 1, action: "test", expectedResult: "result", component: "comp")]

        let flow1 = E2EFlow(id: id, name: "Flow", description: "desc", steps: steps, entryPoint: "entry")
        let flow2 = E2EFlow(id: id, name: "Flow", description: "desc", steps: steps, entryPoint: "entry")

        XCTAssertEqual(flow1, flow2)
    }

    func testE2EStepEquatable() {
        let id = UUID()
        let step1 = E2EStep(id: id, order: 1, action: "test", expectedResult: "result", component: "comp", assertions: ["a"])
        let step2 = E2EStep(id: id, order: 1, action: "test", expectedResult: "result", component: "comp", assertions: ["a"])

        XCTAssertEqual(step1, step2)
    }
}

// MARK: - PerformanceTestScenario Hashable Tests

final class PerformanceTestScenarioHashableTests: XCTestCase {

    func testPerformanceTestScenarioEquatable() {
        let id = UUID()
        let scenario1 = PerformanceTestScenario(
            id: id,
            name: "Test",
            description: "desc",
            targetComponent: "comp",
            operation: "op",
            expectedLatency: "< 1s",
            loadProfile: .single,
            metrics: [.latency]
        )
        let scenario2 = PerformanceTestScenario(
            id: id,
            name: "Test",
            description: "desc",
            targetComponent: "comp",
            operation: "op",
            expectedLatency: "< 1s",
            loadProfile: .single,
            metrics: [.latency]
        )

        XCTAssertEqual(scenario1, scenario2)
    }
}

// MARK: - SuggestedTestFile Hashable Tests

final class SuggestedTestFileHashableTests: XCTestCase {

    func testSuggestedTestFileEquatable() {
        let id = UUID()
        let file1 = SuggestedTestFile(
            id: id,
            path: "Tests/Test.swift",
            testType: .integration,
            targetComponents: ["A"],
            suggestedTestCases: ["testA"]
        )
        let file2 = SuggestedTestFile(
            id: id,
            path: "Tests/Test.swift",
            testType: .integration,
            targetComponents: ["A"],
            suggestedTestCases: ["testA"]
        )

        XCTAssertEqual(file1, file2)
    }
}
