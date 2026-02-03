# Process Management for Maestro-like App

## Process Basics

### Launch Simple Command
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
process.arguments = ["status"]

try process.run()
process.waitUntilExit()
print("Exit code: \(process.terminationStatus)")
```

### Capture Output
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/ls")
process.arguments = ["-la"]

let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe

try process.run()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: data, encoding: .utf8) ?? ""
print(output)
```

## Async Process Management

### Process Manager Actor
```swift
actor ProcessManager {
    private var runningProcesses: [UUID: Process] = [:]

    func launch(
        executable: String,
        arguments: [String],
        onOutput: @escaping (String) -> Void
    ) async throws -> UUID {
        let id = UUID()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Read output asynchronously
        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                onOutput(output)
            }
        }

        runningProcesses[id] = process
        try process.run()

        return id
    }

    func terminate(id: UUID) {
        runningProcesses[id]?.terminate()
        runningProcesses.removeValue(forKey: id)
    }

    func isRunning(id: UUID) -> Bool {
        runningProcesses[id]?.isRunning ?? false
    }
}
```

## Interactive Process (Pseudo-TTY)

### PTY Helper (requires Objective-C bridge)
```swift
import Darwin

class PTYProcess {
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var process: Process?

    func launch(command: String, args: [String]) throws {
        // Open pseudo-terminal
        var master: Int32 = 0
        var slave: Int32 = 0

        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw ProcessError.ptyFailed
        }

        masterFD = master
        slaveFD = slave

        // Configure process
        process = Process()
        process?.executableURL = URL(fileURLWithPath: command)
        process?.arguments = args

        // Redirect to PTY
        let slaveFH = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        process?.standardInput = slaveFH
        process?.standardOutput = slaveFH
        process?.standardError = slaveFH

        try process?.run()
    }

    func write(_ input: String) {
        guard let data = input.data(using: .utf8) else { return }
        data.withUnsafeBytes { bytes in
            Darwin.write(masterFD, bytes.baseAddress, data.count)
        }
    }

    func readOutput(callback: @escaping (String) -> Void) {
        DispatchQueue.global().async {
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = Darwin.read(self.masterFD, &buffer, buffer.count)
                if count > 0 {
                    let data = Data(bytes: buffer, count: count)
                    if let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            callback(output)
                        }
                    }
                }
            }
        }
    }

    func terminate() {
        process?.terminate()
        close(masterFD)
        close(slaveFD)
    }
}
```

## Claude Code Integration

### Launch Claude Code
```swift
actor ClaudeCodeSession {
    private let processManager = ProcessManager()
    private var sessionId: UUID?
    private(set) var output: String = ""

    func start(
        repoPath: String,
        onOutput: @escaping (String) -> Void
    ) async throws {
        let id = try await processManager.launch(
            executable: "/usr/local/bin/claude",
            arguments: ["code", "--cwd", repoPath]
        ) { [weak self] newOutput in
            Task { @MainActor in
                await self?.appendOutput(newOutput)
                onOutput(newOutput)
            }
        }

        sessionId = id
    }

    func stop() async {
        guard let id = sessionId else { return }
        await processManager.terminate(id: id)
        sessionId = nil
    }

    private func appendOutput(_ text: String) async {
        output += text
    }
}
```

## Git Operations

### Git Service
```swift
actor GitService {
    func createWorktree(
        repoPath: String,
        branch: String,
        worktreePath: String
    ) async throws {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "add", worktreePath, branch]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitError.worktreeFailed(error)
        }
    }

    func commit(worktreePath: String, message: String) async throws {
        // git add -A
        try await runGit(in: worktreePath, args: ["add", "-A"])

        // git commit
        try await runGit(in: worktreePath, args: ["commit", "-m", message])
    }

    func push(worktreePath: String) async throws {
        try await runGit(in: worktreePath, args: ["push"])
    }

    private func runGit(in directory: String, args: [String]) async throws {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? ""
            throw GitError.commandFailed(error)
        }
    }
}
```

## Process Monitoring

### Session Process Monitor
```swift
@MainActor
class SessionViewModel: ObservableObject {
    @Published var output: String = ""
    @Published var status: SessionStatus = .idle

    private let processManager = ProcessManager()
    private var processId: UUID?

    func start(command: String, args: [String]) async {
        status = .working

        do {
            processId = try await processManager.launch(
                executable: command,
                arguments: args
            ) { [weak self] newOutput in
                Task { @MainActor in
                    self?.output += newOutput
                }
            }

            // Monitor completion
            Task {
                await monitorProcess()
            }
        } catch {
            status = .error
            output += "\nError: \(error.localizedDescription)"
        }
    }

    func stop() {
        Task {
            guard let id = processId else { return }
            await processManager.terminate(id: id)
            status = .idle
        }
    }

    private func monitorProcess() async {
        guard let id = processId else { return }

        while await processManager.isRunning(id: id) {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        status = .done
    }
}
```

## Environment Variables

### Set Custom Environment
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

// Copy current environment and add custom vars
var environment = ProcessInfo.processInfo.environment
environment["CUSTOM_VAR"] = "value"
environment["API_KEY"] = "secret"

process.environment = environment
try process.run()
```

## Shell Command Helper

### Execute Shell Commands
```swift
func shell(_ command: String) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    process.waitUntilExit()

    if process.terminationStatus != 0 {
        throw ShellError.commandFailed(output)
    }

    return output
}

// Usage
let files = try await shell("ls -la /tmp")
print(files)
```

## Error Handling

### Process Errors
```swift
enum ProcessError: Error {
    case launchFailed
    case ptyFailed
    case terminated
    case timeout
}

enum GitError: Error {
    case worktreeFailed(String)
    case commandFailed(String)
    case notARepository
}

enum ShellError: Error {
    case commandFailed(String)
}
```
