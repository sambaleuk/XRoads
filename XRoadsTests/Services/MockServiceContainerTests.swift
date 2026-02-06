import XCTest
@testable import XRoadsLib

/// Tests for CR-305: MockServiceContainer uses testMode to prevent real I/O
final class MockServiceContainerTests: XCTestCase {

    // MARK: - MockServiceContainer Initialization

    func test_mockServiceContainer_initializesWithoutErrors() {
        // MockServiceContainer should initialize cleanly without triggering any
        // real process launches, git commands, or MCP server starts
        let container = MockServiceContainer()
        XCTAssertNotNil(container)
    }

    // MARK: - testMode Flags

    func test_gitService_hasTestModeTrue() async {
        let container = MockServiceContainer()
        let testMode = await container.gitService.testMode
        XCTAssertTrue(testMode, "GitService in MockServiceContainer should have testMode=true")
    }

    func test_processRunner_hasTestModeTrue() async {
        let container = MockServiceContainer()
        let testMode = await container.processRunner.testMode
        XCTAssertTrue(testMode, "ProcessRunner in MockServiceContainer should have testMode=true")
    }

    func test_ptyProcessRunner_hasTestModeTrue() async {
        let container = MockServiceContainer()
        let testMode = await container.ptyRunner.testMode
        XCTAssertTrue(testMode, "PTYProcessRunner in MockServiceContainer should have testMode=true")
    }

    func test_mcpClient_hasTestModeTrue() async {
        let container = MockServiceContainer()
        let testMode = await container.mcpClient.testMode
        XCTAssertTrue(testMode, "MCPClient in MockServiceContainer should have testMode=true")
    }

    // MARK: - testMode Behavior

    func test_processRunner_launchReturnsUUIDWithoutRealProcess() async throws {
        let runner = ProcessRunner(testMode: true)
        // launch() should return a UUID without actually launching any process
        let id = try await runner.launch(
            executable: "/nonexistent/binary",
            workingDirectory: "/nonexistent/path",
            onOutput: { _ in }
        )
        XCTAssertNotNil(id, "testMode ProcessRunner.launch should return a mock UUID")
        // The process should not be tracked (since it was never really launched)
        let isRunning = await runner.isRunning(id: id)
        XCTAssertFalse(isRunning, "testMode process should not appear as running")
    }

    func test_ptyProcessRunner_launchReturnsUUIDWithoutRealProcess() async throws {
        let runner = PTYProcessRunner(testMode: true)
        // launch() should return a UUID without actually launching any PTY process
        let id = try await runner.launch(
            executable: "/nonexistent/binary",
            workingDirectory: "/nonexistent/path",
            onOutput: { _ in }
        )
        XCTAssertNotNil(id, "testMode PTYProcessRunner.launch should return a mock UUID")
        let isRunning = await runner.isRunning(id: id)
        XCTAssertFalse(isRunning, "testMode PTY process should not appear as running")
    }

    func test_mcpClient_startDoesNotLaunchServer() async throws {
        let client = MCPClient(testMode: true)
        // start() should return immediately without launching an MCP server
        try await client.start()
        // If we got here without error, testMode prevented the real server launch
    }

    // MARK: - DefaultServiceContainer Defaults

    func test_defaultServiceContainer_hasTestModeFalse() async {
        let container = DefaultServiceContainer()
        let gitTestMode = await container.gitService.testMode
        let processTestMode = await container.processRunner.testMode
        let ptyTestMode = await container.ptyRunner.testMode
        let mcpTestMode = await container.mcpClient.testMode

        XCTAssertFalse(gitTestMode, "DefaultServiceContainer GitService should have testMode=false")
        XCTAssertFalse(processTestMode, "DefaultServiceContainer ProcessRunner should have testMode=false")
        XCTAssertFalse(ptyTestMode, "DefaultServiceContainer PTYProcessRunner should have testMode=false")
        XCTAssertFalse(mcpTestMode, "DefaultServiceContainer MCPClient should have testMode=false")
    }

    // MARK: - Source Code Verification

    func test_mockServiceContainer_sourceUsesTestMode() throws {
        // Verify that the MockServiceContainer source code actually passes testMode: true
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services/
            .deletingLastPathComponent() // XRoadsTests/
            .deletingLastPathComponent() // project root

        let serviceContainerPath = projectRoot
            .appendingPathComponent("XRoads/Services/ServiceContainer.swift").path

        let source = try String(contentsOfFile: serviceContainerPath, encoding: .utf8)

        XCTAssertTrue(
            source.contains("GitService(testMode: true)"),
            "MockServiceContainer should initialize GitService with testMode: true"
        )
        XCTAssertTrue(
            source.contains("ProcessRunner(testMode: true)"),
            "MockServiceContainer should initialize ProcessRunner with testMode: true"
        )
        XCTAssertTrue(
            source.contains("PTYProcessRunner(testMode: true)"),
            "MockServiceContainer should initialize PTYProcessRunner with testMode: true"
        )
        XCTAssertTrue(
            source.contains("MCPClient(testMode: true)"),
            "MockServiceContainer should initialize MCPClient with testMode: true"
        )
    }
}
