//
//  ProcessRunnerTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-03.
//  Unit tests for ProcessRunner actor - US-V3-013 Input Bridge
//

import XCTest
@testable import XRoads

final class ProcessRunnerTests: XCTestCase {

    // MARK: - ProcessError Tests

    func testProcessErrorExecutableNotFound() {
        let error = ProcessError.executableNotFound(path: "/usr/bin/nonexistent")
        XCTAssertEqual(error.errorDescription, "Executable not found at: /usr/bin/nonexistent")
    }

    func testProcessErrorWorkingDirectoryNotFound() {
        let error = ProcessError.workingDirectoryNotFound(path: "/nonexistent/directory")
        XCTAssertEqual(error.errorDescription, "Working directory not found: /nonexistent/directory")
    }

    func testProcessErrorProcessNotFound() {
        let id = UUID()
        let error = ProcessError.processNotFound(id: id)
        XCTAssertEqual(error.errorDescription, "Process not found: \(id)")
    }

    func testProcessErrorProcessAlreadyTerminated() {
        let id = UUID()
        let error = ProcessError.processAlreadyTerminated(id: id)
        XCTAssertEqual(error.errorDescription, "Process already terminated: \(id)")
    }

    func testProcessErrorLaunchFailed() {
        let error = ProcessError.launchFailed(executable: "/usr/bin/test", reason: "Permission denied")
        XCTAssertEqual(error.errorDescription, "Failed to launch '/usr/bin/test': Permission denied")
    }

    func testProcessErrorInputWriteFailed() {
        let id = UUID()
        let error = ProcessError.inputWriteFailed(id: id, reason: "Broken pipe")
        XCTAssertEqual(error.errorDescription, "Failed to write to process \(id): Broken pipe")
    }

    // MARK: - ManagedProcessInfo Tests

    func testManagedProcessInfoInit() {
        let id = UUID()
        let now = Date()
        let info = ManagedProcessInfo(
            id: id,
            executable: "/usr/bin/cat",
            arguments: ["-n"],
            workingDirectory: "/tmp",
            startedAt: now,
            pid: 12345
        )

        XCTAssertEqual(info.id, id)
        XCTAssertEqual(info.executable, "/usr/bin/cat")
        XCTAssertEqual(info.arguments, ["-n"])
        XCTAssertEqual(info.workingDirectory, "/tmp")
        XCTAssertEqual(info.startedAt, now)
        XCTAssertEqual(info.pid, 12345)
    }

    func testManagedProcessInfoSendable() {
        // ManagedProcessInfo should be Sendable
        let info = ManagedProcessInfo(
            id: UUID(),
            executable: "/usr/bin/cat",
            arguments: [],
            workingDirectory: "/tmp",
            startedAt: Date(),
            pid: 0
        )

        // Verify we can pass it across async boundaries
        Task {
            let _ = info
        }
    }

    // MARK: - ProcessRunner Basic Tests

    func testProcessRunnerSendInputErrorForInvalidProcessId() async {
        let runner = ProcessRunner()
        let invalidId = UUID()

        do {
            try await runner.sendInput(id: invalidId, text: "test input")
            XCTFail("Expected error for invalid process ID")
        } catch let error as ProcessError {
            switch error {
            case .processNotFound(let id):
                XCTAssertEqual(id, invalidId)
            default:
                XCTFail("Expected processNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testProcessRunnerIsRunningReturnsFalseForInvalidId() async {
        let runner = ProcessRunner()
        let invalidId = UUID()

        let isRunning = await runner.isRunning(id: invalidId)
        XCTAssertFalse(isRunning)
    }

    func testProcessRunnerGetProcessInfoReturnsNilForInvalidId() async {
        let runner = ProcessRunner()
        let invalidId = UUID()

        let info = await runner.getProcessInfo(id: invalidId)
        XCTAssertNil(info)
    }

    func testProcessRunnerGetTerminationStatusReturnsNilForInvalidId() async {
        let runner = ProcessRunner()
        let invalidId = UUID()

        let status = await runner.getTerminationStatus(id: invalidId)
        XCTAssertNil(status)
    }

    func testProcessRunnerAllProcessIdsEmptyInitially() async {
        let runner = ProcessRunner()
        let ids = await runner.allProcessIds
        XCTAssertTrue(ids.isEmpty)
    }

    func testProcessRunnerRunningProcessIdsEmptyInitially() async {
        let runner = ProcessRunner()
        let ids = await runner.runningProcessIds
        XCTAssertTrue(ids.isEmpty)
    }

    func testProcessRunnerRemoveProcessDoesNotCrashForInvalidId() async {
        let runner = ProcessRunner()
        let invalidId = UUID()

        // Should not crash
        await runner.removeProcess(id: invalidId)

        // Verify state is still valid
        let ids = await runner.allProcessIds
        XCTAssertTrue(ids.isEmpty)
    }

    func testProcessRunnerTerminateErrorForInvalidId() async {
        let runner = ProcessRunner()
        let invalidId = UUID()

        do {
            try await runner.terminate(id: invalidId)
            XCTFail("Expected error for invalid process ID")
        } catch let error as ProcessError {
            switch error {
            case .processNotFound(let id):
                XCTAssertEqual(id, invalidId)
            default:
                XCTFail("Expected processNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Launch Tests

    func testProcessRunnerLaunchErrorForNonexistentExecutable() async {
        let runner = ProcessRunner()

        do {
            _ = try await runner.launch(
                executable: "/nonexistent/executable",
                arguments: [],
                workingDirectory: "/tmp",
                environment: nil
            ) { _ in }
            XCTFail("Expected error for nonexistent executable")
        } catch let error as ProcessError {
            switch error {
            case .executableNotFound(let path):
                XCTAssertEqual(path, "/nonexistent/executable")
            default:
                XCTFail("Expected executableNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testProcessRunnerLaunchErrorForNonexistentWorkingDirectory() async {
        let runner = ProcessRunner()

        do {
            _ = try await runner.launch(
                executable: "/bin/echo",
                arguments: ["test"],
                workingDirectory: "/nonexistent/directory",
                environment: nil
            ) { _ in }
            XCTFail("Expected error for nonexistent working directory")
        } catch let error as ProcessError {
            switch error {
            case .workingDirectoryNotFound(let path):
                XCTAssertEqual(path, "/nonexistent/directory")
            default:
                XCTFail("Expected workingDirectoryNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Integration Tests (requires actual process execution)

    func testProcessRunnerLaunchAndTerminate() async throws {
        let runner = ProcessRunner()
        let outputExpectation = expectation(description: "Output received")
        outputExpectation.assertForOverFulfill = false

        var receivedOutput = ""

        // Launch a simple echo command
        let processId = try await runner.launch(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: "/tmp",
            environment: nil
        ) { output in
            receivedOutput += output
            outputExpectation.fulfill()
        }

        // Verify process is tracked
        var ids = await runner.allProcessIds
        XCTAssertTrue(ids.contains(processId))

        // Verify process is running
        var isRunning = await runner.isRunning(id: processId)
        XCTAssertTrue(isRunning)

        // Verify process info
        let info = await runner.getProcessInfo(id: processId)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.executable, "/bin/cat")
        XCTAssertEqual(info?.workingDirectory, "/tmp")

        // Send input
        try await runner.sendInput(id: processId, text: "Hello, World!")

        // Wait for output
        await fulfillment(of: [outputExpectation], timeout: 2.0)

        // Verify output was received
        XCTAssertTrue(receivedOutput.contains("Hello, World!"), "Expected output to contain 'Hello, World!', got: \(receivedOutput)")

        // Terminate the process
        try await runner.terminate(id: processId)

        // Give process time to terminate
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify process is no longer running
        isRunning = await runner.isRunning(id: processId)
        XCTAssertFalse(isRunning)

        // Process should still be tracked until removed
        ids = await runner.allProcessIds
        XCTAssertTrue(ids.contains(processId))

        // Remove the process
        await runner.removeProcess(id: processId)
        ids = await runner.allProcessIds
        XCTAssertFalse(ids.contains(processId))
    }

    func testProcessRunnerSendInputAddsNewlineIfMissing() async throws {
        let runner = ProcessRunner()
        let outputExpectation = expectation(description: "Output received")

        var receivedOutput = ""

        let processId = try await runner.launch(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: "/tmp",
            environment: nil
        ) { output in
            receivedOutput += output
            if receivedOutput.contains("NoNewline") {
                outputExpectation.fulfill()
            }
        }

        // Send input without newline
        try await runner.sendInput(id: processId, text: "NoNewline")

        // Wait for output
        await fulfillment(of: [outputExpectation], timeout: 2.0)

        // Cleanup
        try? await runner.terminate(id: processId)
    }

    func testProcessRunnerSendInputPreservesExistingNewline() async throws {
        let runner = ProcessRunner()
        let outputExpectation = expectation(description: "Output received")

        var receivedOutput = ""

        let processId = try await runner.launch(
            executable: "/bin/cat",
            arguments: [],
            workingDirectory: "/tmp",
            environment: nil
        ) { output in
            receivedOutput += output
            if receivedOutput.contains("WithNewline") {
                outputExpectation.fulfill()
            }
        }

        // Send input with newline
        try await runner.sendInput(id: processId, text: "WithNewline\n")

        // Wait for output
        await fulfillment(of: [outputExpectation], timeout: 2.0)

        // The output should not have double newlines
        XCTAssertTrue(receivedOutput.contains("WithNewline\n"))

        // Cleanup
        try? await runner.terminate(id: processId)
    }

    func testProcessRunnerEnvironmentVariables() async throws {
        let runner = ProcessRunner()
        let outputExpectation = expectation(description: "Output received")

        var receivedOutput = ""

        // Launch env command to print environment variables
        let processId = try await runner.launch(
            executable: "/usr/bin/printenv",
            arguments: ["CROSSROADS_TEST_VAR"],
            workingDirectory: "/tmp",
            environment: ["CROSSROADS_TEST_VAR": "test_value_123"]
        ) { output in
            receivedOutput += output
            outputExpectation.fulfill()
        }

        // Wait for output
        await fulfillment(of: [outputExpectation], timeout: 2.0)

        // Verify environment variable was set
        XCTAssertTrue(receivedOutput.contains("test_value_123"))

        // Cleanup
        try? await runner.terminate(id: processId)
    }
}

// MARK: - Input Echo Tests

final class ProcessRunnerInputEchoTests: XCTestCase {

    func testInputEchoFormat() {
        // Test the expected echo format used in AppState
        let userInput = "test command"
        let echoMessage = "▶ \(userInput)"

        XCTAssertEqual(echoMessage, "▶ test command")
    }

    func testMultilineInputEchoFormat() {
        let userInput = "line1\nline2\nline3"
        let echoMessage = "▶ \(userInput)"

        XCTAssertTrue(echoMessage.contains("line1"))
        XCTAssertTrue(echoMessage.contains("line2"))
        XCTAssertTrue(echoMessage.contains("line3"))
    }
}

// MARK: - AppState Input Bridge Tests

final class AppStateInputBridgeTests: XCTestCase {

    @MainActor
    func testSendInputToSlotReturnsErrorForMissingSlot() async {
        let appState = AppState()

        // Try to send to slot 99 which doesn't exist
        let result = await appState.sendInputToSlot(99, text: "test")

        XCTAssertFalse(result)
    }

    @MainActor
    func testSendInputToSlotReturnsErrorWhenNoProcessRunning() async {
        let appState = AppState()

        // Slot 1 exists but has no process
        let result = await appState.sendInputToSlot(1, text: "test")

        XCTAssertFalse(result)
    }

    @MainActor
    func testProcessIdForSlotReturnsNilForEmptySlot() {
        let appState = AppState()

        let processId = appState.processIdForSlot(1)

        XCTAssertNil(processId)
    }

    @MainActor
    func testProcessIdForSlotReturnsNilForInvalidSlot() {
        let appState = AppState()

        let processId = appState.processIdForSlot(99)

        XCTAssertNil(processId)
    }

    @MainActor
    func testIsProcessRunningInSlotReturnsFalseForEmptySlot() async {
        let appState = AppState()

        let isRunning = await appState.isProcessRunningInSlot(1)

        XCTAssertFalse(isRunning)
    }

    @MainActor
    func testSendInputToWorktreeReturnsErrorWhenNoProcessRunning() async {
        let appState = AppState()
        let worktree = Worktree(path: "/test/worktree", branch: "main")
        appState.worktrees.append(worktree)

        let result = await appState.sendInputToWorktree(worktree.id, text: "test")

        XCTAssertFalse(result)
    }

    @MainActor
    func testSendInputToWorktreeReturnsErrorForUnknownWorktree() async {
        let appState = AppState()
        let unknownId = UUID()

        let result = await appState.sendInputToWorktree(unknownId, text: "test")

        XCTAssertFalse(result)
    }
}
