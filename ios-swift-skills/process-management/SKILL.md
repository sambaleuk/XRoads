---
name: process-management
description: Launch and manage system processes, shell commands, and external tools (git, claude code) from Swift. Use when executing command-line tools, capturing output, running interactive processes, managing git operations, or integrating with external CLIs. Essential for building developer tools, automation apps, and CI/CD systems.
---

# Process Management - Executing External Commands

Master launching and managing external processes from Swift for building developer tools and automation.

## Quick Start

### New to Process Management?
1. Read [process-essentials.md](references/process-essentials.md) for complete Process API guide
2. Review async ProcessManager actor patterns
3. See Claude Code and Git integration examples

### Common Tasks

**Launch simple command:**
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
process.arguments = ["status"]
try process.run()
process.waitUntilExit()
```

**Capture output:**
```swift
let pipe = Pipe()
process.standardOutput = pipe
try process.run()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: data, encoding: .utf8) ?? ""
```

**Async process management:**
```swift
let processManager = ProcessManager()
let id = try await processManager.launch(
    executable: "/usr/bin/ls",
    arguments: ["-la"]
) { output in
    print(output)
}
```

## When to Use This Skill

Trigger this skill when:
- Executing shell commands or command-line tools
- Running git operations (clone, commit, push, worktree)
- Launching interactive processes (PTY/terminal emulation)
- Integrating with external CLIs (claude code, npm, docker)
- Building developer tools or automation apps
- Capturing and streaming process output
- Managing long-running background processes

## Core Concepts Overview

### 1. Process - Foundation for Launching Commands

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/command")
process.arguments = ["arg1", "arg2"]
process.currentDirectoryURL = URL(fileURLWithPath: "/path/to/workdir")

// Set environment variables
var env = ProcessInfo.processInfo.environment
env["CUSTOM_VAR"] = "value"
process.environment = env

try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    // Handle error
}
```

### 2. Pipes - Capturing Output

```swift
let outputPipe = Pipe()
let errorPipe = Pipe()

process.standardOutput = outputPipe
process.standardError = errorPipe

try process.run()

let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: outputData, encoding: .utf8) ?? ""
```

### 3. Async Process Manager

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

        // Stream output asynchronously
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

### 4. PTY (Pseudo-Terminal) for Interactive Processes

For processes that need a terminal (like interactive shells):

```swift
import Darwin

class PTYProcess {
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var process: Process?

    func launch(command: String, args: [String]) throws {
        var master: Int32 = 0
        var slave: Int32 = 0

        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw ProcessError.ptyFailed
        }

        masterFD = master
        slaveFD = slave

        process = Process()
        process?.executableURL = URL(fileURLWithPath: command)
        process?.arguments = args

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
}
```

## Common Patterns for Maestro-like Apps

### Pattern 1: Claude Code Integration

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

### Pattern 2: Git Operations

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
        try await runGit(in: worktreePath, args: ["add", "-A"])
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

### Pattern 3: Shell Command Helper

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
let gitStatus = try await shell("cd /repo && git status")
```

### Pattern 4: Session Process Monitor (SwiftUI Integration)

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
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        status = .done
    }
}
```

## Error Handling

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

## Resources

### references/
- **process-essentials.md** - Complete guide to Process API, PTY for interactive processes, Claude Code integration, Git operations, async ProcessManager patterns, environment variables, and shell command execution

Read this file for detailed examples and advanced patterns.

## Best Practices

### 1. Use async/await with ProcessManager
```swift
// ✅ Async pattern
let processManager = ProcessManager()
let id = try await processManager.launch(executable: "git", arguments: ["status"]) { output in
    print(output)
}
```

### 2. Always capture stderr
```swift
// ✅ Capture both stdout and stderr
let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe  // Important for error messages
```

### 3. Check termination status
```swift
// ✅ Handle errors
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw ProcessError.launchFailed
}
```

### 4. Use actors for process management
```swift
// ✅ Thread-safe process tracking
actor ProcessManager {
    private var runningProcesses: [UUID: Process] = [:]
}
```

### 5. Set working directory for git operations
```swift
// ✅ Set currentDirectoryURL
process.currentDirectoryURL = URL(fileURLWithPath: worktreePath)
process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
```

### 6. Stream output asynchronously
```swift
// ✅ Use readabilityHandler for real-time output
pipe.fileHandleForReading.readabilityHandler = { fileHandle in
    let data = fileHandle.availableData
    if !data.isEmpty {
        onOutput(String(data: data, encoding: .utf8) ?? "")
    }
}
```

## Common Mistakes

### ❌ Forgetting to call run()
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/ls")
// ❌ Process never starts!
```

### ❌ Not capturing stderr
```swift
process.standardOutput = pipe
// ❌ Error messages go to nowhere
```

### ❌ Blocking main thread
```swift
// ❌ Blocks UI
process.waitUntilExit()
```

**✅ Solution:**
```swift
Task {
    try await processManager.launch(...)
}
```

## Integration with Other Skills

- **swift-concurrency** - Use async/await and actors for process management
- **mvvm-architecture** - Integrate processes into ViewModels with @MainActor
- **swiftui** - Display process output in terminal-style views
- **file-operations** - Combine with file operations for complete automation

## Key Takeaways

✅ **Process** is the foundation for launching external commands
✅ **Pipes** capture stdout and stderr
✅ **Async ProcessManager** for non-blocking process execution
✅ **PTY** required for interactive processes
✅ **Git operations** use currentDirectoryURL for working directory
✅ **Actors** provide thread-safe process tracking
✅ **readabilityHandler** streams output in real-time
✅ **Check terminationStatus** for error handling
