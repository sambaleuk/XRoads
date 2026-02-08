import Foundation
import Darwin

// MARK: - PTYProcess

/// A process wrapper that provides pseudo-terminal (PTY) support using the `script` command.
/// Required for interactive CLI tools like Claude Code, Gemini CLI, Codex.
///
/// Safety: @unchecked Sendable is justified because all mutable state (`process`, `stdinPipe`,
/// `stdoutPipe`, `stderrPipe`) is protected by `NSLock` for every read and write access.
/// Immutable properties (`id`, `executable`, `arguments`, `workingDirectory`, `environment`)
/// are set once at init and never modified. Callback references (`outputHandler`,
/// `terminationHandler`) are set once in `launch()` before the process starts.
final class PTYProcess: @unchecked Sendable {

    // MARK: - Types

    enum PTYError: Error, LocalizedError {
        case scriptNotFound
        case launchFailed(reason: String)
        case processNotRunning
        case writeFailed(reason: String)

        var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "script command not found"
            case .launchFailed(let reason):
                return "Failed to launch process: \(reason)"
            case .processNotRunning:
                return "Process is not running"
            case .writeFailed(let reason):
                return "Failed to write to PTY: \(reason)"
            }
        }
    }

    typealias OutputHandler = @Sendable (String) -> Void
    typealias TerminationHandler = @Sendable (Int32) -> Void

    // MARK: - Properties

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let lock = NSLock()

    private var outputHandler: OutputHandler?
    private var terminationHandler: TerminationHandler?

    let id: UUID
    let executable: String
    let arguments: [String]
    let workingDirectory: String
    let environment: [String: String]?

    /// Temp file where the real exit code is written (script swallows it)
    private let exitCodeFile: String

    var processIdentifier: pid_t {
        lock.lock()
        defer { lock.unlock() }
        return process?.processIdentifier ?? -1
    }

    var running: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning ?? false
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        executable: String,
        arguments: [String] = [],
        workingDirectory: String,
        environment: [String: String]? = nil
    ) {
        self.id = id
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.exitCodeFile = NSTemporaryDirectory() + "xroads_exit_\(id.uuidString)"
    }

    deinit {
        terminate()
    }

    // MARK: - Public Methods

    /// Launch the process with PTY via the `script` command
    func launch(
        onOutput: @escaping OutputHandler,
        onTermination: @escaping TerminationHandler
    ) throws {
        self.outputHandler = onOutput
        self.terminationHandler = onTermination

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        // Use script command to provide a PTY
        // script -q /dev/null <command> runs command with a pseudo-terminal
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")

        // Build the command to run
        let shellCommand = buildShellCommand()

        // script arguments: -q (quiet) -F (flush) /dev/null (no transcript)
        // Use bash -c to run the actual command
        process.arguments = ["-q", "-F", "/dev/null", "/bin/bash", "-c", shellCommand]

        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        // Setup environment
        var env = ProcessInfo.processInfo.environment

        // Set TERM for proper terminal emulation
        env["TERM"] = "xterm-256color"

        // Force color output for various tools
        env["CLICOLOR_FORCE"] = "1"
        env["FORCE_COLOR"] = "1"

        // Merge custom environment
        if let customEnv = environment {
            for (key, value) in customEnv {
                env[key] = value
            }
        }

        process.environment = env

        // Setup pipes
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Setup output handlers
        setupOutputHandler(pipe: stdoutPipe, onOutput: onOutput)
        setupOutputHandler(pipe: stderrPipe, onOutput: onOutput)

        // Setup termination handler
        // NOTE: macOS `script` command does NOT propagate the inner command's exit code.
        // terminatedProcess.terminationStatus is always 0. We read the real exit code
        // from a temp file written by our wrapper in buildShellCommand().
        let exitFile = self.exitCodeFile
        process.terminationHandler = { [weak self] terminatedProcess in
            guard let self = self else { return }
            var exitCode = terminatedProcess.terminationStatus
            // Read real exit code from temp file
            if let contents = try? String(contentsOfFile: exitFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               let realCode = Int32(contents) {
                exitCode = realCode
            }
            // Cleanup temp file
            try? FileManager.default.removeItem(atPath: exitFile)
            self.terminationHandler?(exitCode)
        }

        // Store references
        lock.lock()
        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        lock.unlock()

        // Launch
        do {
            try process.run()
        } catch {
            throw PTYError.launchFailed(reason: error.localizedDescription)
        }
    }

    /// Send text to the process
    func sendInput(_ text: String) throws {
        lock.lock()
        let pipe = stdinPipe
        let isRunning = process?.isRunning ?? false
        lock.unlock()

        guard isRunning else {
            throw PTYError.processNotRunning
        }

        guard let stdinPipe = pipe else {
            throw PTYError.processNotRunning
        }

        // Ensure text ends with newline for interactive CLIs
        let textToSend = text.hasSuffix("\n") ? text : text + "\n"

        guard let data = textToSend.data(using: .utf8) else {
            throw PTYError.writeFailed(reason: "Failed to encode text as UTF-8")
        }

        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            throw PTYError.writeFailed(reason: error.localizedDescription)
        }
    }

    /// Terminate the process
    func terminate() {
        lock.lock()
        let proc = process
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        lock.unlock()

        if let proc = proc, proc.isRunning {
            // Send SIGTERM first
            proc.terminate()

            // Give it a moment, then SIGKILL if needed
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if proc.isRunning {
                    kill(proc.processIdentifier, SIGKILL)
                }
            }
        }

        // Cleanup exit code temp file
        try? FileManager.default.removeItem(atPath: exitCodeFile)
    }

    // MARK: - Private Methods

    /// Build the shell command with proper escaping.
    /// Wraps the real command to capture its exit code into a temp file,
    /// because macOS `script` does not propagate exit codes.
    private func buildShellCommand() -> String {
        // Escape the executable and arguments for shell
        let escapedExecutable = shellEscape(executable)
        let escapedArgs = arguments.map { shellEscape($0) }

        var parts = [escapedExecutable]
        parts.append(contentsOf: escapedArgs)

        let cmd = parts.joined(separator: " ")
        // Capture exit code via EXIT trap — runs even when the script calls `exit N`.
        // We can't use `cmd; echo $?` because `exit` terminates bash immediately.
        let escapedFile = shellEscape(exitCodeFile)
        return "trap 'echo $? > \(escapedFile)' EXIT; \(cmd)"
    }

    /// Escape a string for shell usage
    private func shellEscape(_ string: String) -> String {
        // If string contains no special characters, return as-is
        let needsEscaping = string.contains(where: { " '\"\\$`!*?[]{}()&|;<>" .contains($0) })

        if !needsEscaping && !string.isEmpty {
            return string
        }

        // Wrap in single quotes and escape any single quotes
        return "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

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
                onOutput(text)
            }
        }
    }
}

// MARK: - PTYProcessRunner Actor

/// Thread-safe actor for managing PTY-based processes
actor PTYProcessRunner {

    // MARK: - Types

    typealias OutputHandler = @MainActor @Sendable (String) -> Void
    typealias TerminationHandler = @MainActor @Sendable (Int32) -> Void

    private struct ManagedPTYProcess {
        let process: PTYProcess
        var isTerminated: Bool = false
    }

    // MARK: - Properties

    /// When true, all launch/terminate calls are no-ops returning mock values.
    /// Used by MockServiceContainer to prevent real I/O in tests and previews.
    let testMode: Bool

    private var processes: [UUID: ManagedPTYProcess] = [:]

    init(testMode: Bool = false) {
        self.testMode = testMode
    }

    // MARK: - Public Methods

    /// Launch a process with PTY support
    func launch(
        executable: String,
        arguments: [String] = [],
        workingDirectory: String,
        environment: [String: String]? = nil,
        onOutput: @escaping OutputHandler,
        onTermination: TerminationHandler? = nil
    ) async throws -> UUID {
        // In test mode, return a mock UUID without launching any process
        if testMode { return UUID() }

        let processId = UUID()

        let process = PTYProcess(
            id: processId,
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment
        )

        // Create sendable wrapper for handlers
        let outputWrapper: PTYProcess.OutputHandler = { text in
            Task { @MainActor in
                onOutput(text)
            }
        }

        let terminationWrapper: PTYProcess.TerminationHandler = { [weak self] exitCode in
            Task { [weak self] in
                await self?.markTerminated(id: processId)
                if let onTermination = onTermination {
                    await MainActor.run {
                        onTermination(exitCode)
                    }
                }
            }
        }

        try process.launch(onOutput: outputWrapper, onTermination: terminationWrapper)

        processes[processId] = ManagedPTYProcess(process: process)

        return processId
    }

    /// Send input to a process
    func sendInput(id: UUID, text: String) throws {
        guard let managed = processes[id] else {
            throw ProcessError.processNotFound(id: id)
        }

        guard !managed.isTerminated else {
            throw ProcessError.processAlreadyTerminated(id: id)
        }

        try managed.process.sendInput(text)
    }

    /// Terminate a process
    func terminate(id: UUID) throws {
        guard let managed = processes[id] else {
            throw ProcessError.processNotFound(id: id)
        }

        managed.process.terminate()
    }

    /// Check if a process is running
    func isRunning(id: UUID) -> Bool {
        guard let managed = processes[id] else {
            return false
        }
        return managed.process.running && !managed.isTerminated
    }

    /// Get process info
    func getProcessInfo(id: UUID) -> ManagedProcessInfo? {
        guard let managed = processes[id] else {
            return nil
        }

        return ManagedProcessInfo(
            id: id,
            executable: managed.process.executable,
            arguments: managed.process.arguments,
            workingDirectory: managed.process.workingDirectory,
            startedAt: Date(),
            pid: managed.process.processIdentifier
        )
    }

    /// Remove a terminated process
    func removeProcess(id: UUID) {
        processes.removeValue(forKey: id)
    }

    /// Get all running process IDs
    var runningProcessIds: [UUID] {
        return processes.compactMap { id, managed in
            managed.process.running && !managed.isTerminated ? id : nil
        }
    }

    // MARK: - Private Methods

    private func markTerminated(id: UUID) {
        guard var managed = processes[id] else { return }
        managed.isTerminated = true
        processes[id] = managed
    }
}
