import Foundation

// MARK: - ProcessError

/// Errors that can occur during process operations
enum ProcessError: Error, LocalizedError, Sendable {
    case executableNotFound(path: String)
    case workingDirectoryNotFound(path: String)
    case processNotFound(id: UUID)
    case processAlreadyTerminated(id: UUID)
    case launchFailed(executable: String, reason: String)
    case inputWriteFailed(id: UUID, reason: String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executable not found at: \(path)"
        case .workingDirectoryNotFound(let path):
            return "Working directory not found: \(path)"
        case .processNotFound(let id):
            return "Process not found: \(id)"
        case .processAlreadyTerminated(let id):
            return "Process already terminated: \(id)"
        case .launchFailed(let executable, let reason):
            return "Failed to launch '\(executable)': \(reason)"
        case .inputWriteFailed(let id, let reason):
            return "Failed to write to process \(id): \(reason)"
        }
    }
}

// MARK: - ManagedProcessInfo

/// Information about a running process
struct ManagedProcessInfo: Sendable {
    let id: UUID
    let executable: String
    let arguments: [String]
    let workingDirectory: String
    let startedAt: Date
    let pid: Int32
}

// MARK: - ProcessRunner Actor

/// Thread-safe service for managing external processes with output streaming
actor ProcessRunner {

    // MARK: - Types

    /// Callback type for process output - called on MainActor for UI updates
    typealias OutputHandler = @MainActor @Sendable (String) -> Void

    /// Internal state for a managed process
    private struct ManagedProcess {
        let process: Process
        let info: ManagedProcessInfo
        let stdinPipe: Pipe
        let stdoutPipe: Pipe
        let stderrPipe: Pipe
        var isTerminated: Bool = false
    }

    // MARK: - Properties

    /// When true, all launch/terminate calls are no-ops returning mock values.
    /// Used by MockServiceContainer to prevent real I/O in tests and previews.
    let testMode: Bool

    private var processes: [UUID: ManagedProcess] = [:]

    init(testMode: Bool = false) {
        self.testMode = testMode
    }

    // MARK: - Public Methods

    /// Launches a new process with output streaming
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Command-line arguments
    ///   - workingDirectory: Working directory for the process
    ///   - environment: Environment variables for the process
    ///   - closeStdinImmediately: If true, closes stdin right after launch (for tools expecting EOF)
    ///   - onOutput: Callback invoked on MainActor when output is received (stdout or stderr)
    /// - Returns: UUID identifying the launched process
    /// - Throws: ProcessError if launch fails
    func launch(
        executable: String,
        arguments: [String] = [],
        workingDirectory: String,
        environment: [String: String]? = nil,
        closeStdinImmediately: Bool = false,
        onOutput: @escaping OutputHandler
    ) async throws -> UUID {
        // In test mode, return a mock UUID without launching any process
        if testMode { return UUID() }

        // Verify executable exists
        guard FileManager.default.fileExists(atPath: executable) else {
            throw ProcessError.executableNotFound(path: executable)
        }

        // Verify working directory exists
        guard FileManager.default.fileExists(atPath: workingDirectory) else {
            throw ProcessError.workingDirectoryNotFound(path: workingDirectory)
        }

        let processId = UUID()
        let process = Process()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        // Setup environment if provided
        if let environment = environment {
            process.environment = environment
        }

        // Setup pipes for stdin, stdout, stderr
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Create process info
        let info = ManagedProcessInfo(
            id: processId,
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            startedAt: Date(),
            pid: 0 // Will be updated after launch
        )

        // Store managed process
        var managedProcess = ManagedProcess(
            process: process,
            info: info,
            stdinPipe: stdinPipe,
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe
        )

        // Setup output streaming handlers
        setupOutputHandler(pipe: stdoutPipe, onOutput: onOutput)
        setupOutputHandler(pipe: stderrPipe, onOutput: onOutput)

        // Setup termination handler
        let terminationProcessId = processId
        process.terminationHandler = { [weak self] terminatedProcess in
            let msg = "[\(Date())] Termination handler called for \(terminationProcessId), exitCode: \(terminatedProcess.terminationStatus)\n"
            if let data = msg.data(using: .utf8), let handle = FileHandle(forWritingAtPath: "/tmp/xroads_orchestrator.log") {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
            Task { [weak self] in
                await self?.markTerminated(id: terminationProcessId)
            }
        }

        // Launch the process
        do {
            try process.run()
        } catch {
            throw ProcessError.launchFailed(
                executable: executable,
                reason: error.localizedDescription
            )
        }

        // Update with actual PID
        let updatedInfo = ManagedProcessInfo(
            id: processId,
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            startedAt: Date(),
            pid: process.processIdentifier
        )
        managedProcess = ManagedProcess(
            process: process,
            info: updatedInfo,
            stdinPipe: stdinPipe,
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe
        )

        processes[processId] = managedProcess

        // Close stdin immediately if requested (for tools expecting EOF to start processing)
        if closeStdinImmediately {
            // Log to file for debugging
            let logMsg = "[\(Date())] Closing stdin for process \(processId)\n"
            if let data = logMsg.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: "/tmp/xroads_orchestrator.log") {
                    if let handle = FileHandle(forWritingAtPath: "/tmp/xroads_orchestrator.log") {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                }
            }
            stdinPipe.fileHandleForWriting.closeFile()
        }

        return processId
    }

    /// Terminates a running process
    /// - Parameter id: UUID of the process to terminate
    /// - Throws: ProcessError if process not found
    func terminate(id: UUID) throws {
        guard let managedProcess = processes[id] else {
            throw ProcessError.processNotFound(id: id)
        }

        guard !managedProcess.isTerminated else {
            throw ProcessError.processAlreadyTerminated(id: id)
        }

        // Close stdin to signal EOF
        managedProcess.stdinPipe.fileHandleForWriting.closeFile()

        // Terminate the process
        managedProcess.process.terminate()
    }

    /// Checks if a process is currently running
    /// - Parameter id: UUID of the process
    /// - Returns: true if the process is running, false otherwise
    func isRunning(id: UUID) -> Bool {
        guard let managedProcess = processes[id] else {
            return false
        }
        let processIsRunning = managedProcess.process.isRunning
        let isTerminated = managedProcess.isTerminated
        return processIsRunning && !isTerminated
    }

    /// Sends input to a process's stdin
    /// - Parameters:
    ///   - id: UUID of the process
    ///   - text: Text to write to stdin (newline added if not present)
    /// - Throws: ProcessError if process not found or write fails
    func sendInput(id: UUID, text: String) throws {
        guard let managedProcess = processes[id] else {
            throw ProcessError.processNotFound(id: id)
        }

        guard !managedProcess.isTerminated else {
            throw ProcessError.processAlreadyTerminated(id: id)
        }

        // Ensure text ends with newline
        let textWithNewline = text.hasSuffix("\n") ? text : text + "\n"

        guard let data = textWithNewline.data(using: .utf8) else {
            throw ProcessError.inputWriteFailed(id: id, reason: "Failed to encode text as UTF-8")
        }

        do {
            try managedProcess.stdinPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            throw ProcessError.inputWriteFailed(id: id, reason: error.localizedDescription)
        }
    }

    /// Gets information about a process
    /// - Parameter id: UUID of the process
    /// - Returns: ManagedProcessInfo if found, nil otherwise
    func getProcessInfo(id: UUID) -> ManagedProcessInfo? {
        return processes[id]?.info
    }

    /// Gets the termination status of a completed process
    /// - Parameter id: UUID of the process
    /// - Returns: Exit code if process has terminated, nil if still running or not found
    func getTerminationStatus(id: UUID) -> Int32? {
        guard let managedProcess = processes[id] else {
            return nil
        }

        guard managedProcess.isTerminated || !managedProcess.process.isRunning else {
            return nil
        }

        return managedProcess.process.terminationStatus
    }

    /// Removes a terminated process from tracking
    /// - Parameter id: UUID of the process to remove
    func removeProcess(id: UUID) {
        processes.removeValue(forKey: id)
    }

    /// Gets all currently tracked process IDs
    var allProcessIds: [UUID] {
        return Array(processes.keys)
    }

    /// Gets all currently running process IDs
    var runningProcessIds: [UUID] {
        return processes.compactMap { id, managed in
            managed.process.isRunning && !managed.isTerminated ? id : nil
        }
    }

    // MARK: - Private Methods

    /// Sets up an output handler for a pipe
    private func setupOutputHandler(pipe: Pipe, onOutput: @escaping OutputHandler) {
        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData

            guard !data.isEmpty else {
                // EOF reached, remove handler
                fileHandle.readabilityHandler = nil
                return
            }

            if let text = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    onOutput(text)
                }
            }
        }
    }

    /// Marks a process as terminated
    private func markTerminated(id: UUID) {
        guard var managedProcess = processes[id] else {
            return
        }

        managedProcess.isTerminated = true
        processes[id] = managedProcess

        // Clean up handlers
        managedProcess.stdoutPipe.fileHandleForReading.readabilityHandler = nil
        managedProcess.stderrPipe.fileHandleForReading.readabilityHandler = nil
    }
}
