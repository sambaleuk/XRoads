---
name: file-operations
description: File and directory operations using FileManager for reading, writing, copying, moving, and managing files and directories. Use when working with the file system, managing session directories, logging to files, reading/writing configuration, or organizing project files. Essential for apps that manage files, logs, or user data.
---

# File Operations - FileManager and File System

Master file and directory operations in Swift for managing files, logs, and configurations.

## Quick Start

### New to File Operations?
1. Read [file-essentials.md](references/file-essentials.md) for complete FileManager guide
2. Understand URL-based paths vs String paths
3. Review Maestro-specific patterns (session directories, logs management, config files)

### Basic File Operations

**Check if file exists:**
```swift
let fileManager = FileManager.default
if fileManager.fileExists(atPath: "/path/to/file.txt") {
    print("File exists")
}
```

**Read file:**
```swift
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")
let content = try String(contentsOf: fileURL, encoding: .utf8)
```

**Write file:**
```swift
let content = "Hello, World!"
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")
try content.write(to: fileURL, atomically: true, encoding: .utf8)
```

**Create directory:**
```swift
let directoryURL = URL(fileURLWithPath: "/path/to/directory")
try fileManager.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: true
)
```

**List directory contents:**
```swift
let directoryURL = URL(fileURLWithPath: "/path/to/directory")
let fileURLs = try fileManager.contentsOfDirectory(
    at: directoryURL,
    includingPropertiesForKeys: nil
)
for url in fileURLs {
    print(url.lastPathComponent)
}
```

## When to Use This Skill

Trigger this skill when:
- Reading or writing files (text, JSON, binary)
- Creating or deleting directories
- Listing directory contents
- Copying or moving files
- Managing session directories
- Writing logs to files
- Reading/writing configuration files
- Checking file existence or attributes
- Questions about FileManager

## Core Concepts

### 1. FileManager - Your File System Interface

```swift
let fileManager = FileManager.default

// Common directories
let homeDirectory = fileManager.homeDirectoryForCurrentUser
let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
let temporaryDirectory = fileManager.temporaryDirectory
```

### 2. URL vs String Paths

**Always prefer URL over String:**

```swift
// ✅ Good - use URL
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")
try fileManager.createDirectory(at: fileURL, withIntermediateDirectories: true)

// ❌ Less good - String path
let path = "/path/to/file.txt"
try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
```

### 3. Reading Files

```swift
// Text file
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")
let content = try String(contentsOf: fileURL, encoding: .utf8)

// JSON file
struct Config: Codable {
    let repoPath: String
}

let data = try Data(contentsOf: fileURL)
let config = try JSONDecoder().decode(Config.self, from: data)

// Binary file
let binaryData = try Data(contentsOf: fileURL)
```

### 4. Writing Files

```swift
// Text file
let content = "Hello, World!"
try content.write(to: fileURL, atomically: true, encoding: .utf8)

// JSON file
let config = Config(repoPath: "/Users/me/repo")
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let data = try encoder.encode(config)
try data.write(to: fileURL)

// Binary file
let data = Data([0x00, 0x01, 0x02])
try data.write(to: fileURL)
```

### 5. Directory Operations

```swift
// Create directory (including parents)
try fileManager.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: true
)

// List contents
let fileURLs = try fileManager.contentsOfDirectory(
    at: directoryURL,
    includingPropertiesForKeys: nil
)

// Delete directory
try fileManager.removeItem(at: directoryURL)

// Copy directory
try fileManager.copyItem(at: sourceURL, to: destinationURL)

// Move directory
try fileManager.moveItem(at: sourceURL, to: destinationURL)
```

## Common Patterns for Maestro-like Apps

### Pattern 1: Session Directory Manager

Manage session directories with worktree, logs, and metadata:

```swift
actor SessionDirectoryManager {
    private let fileManager = FileManager.default
    private let baseDirectory: URL

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    func createSessionDirectory(sessionId: UUID) async throws -> URL {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString)

        // Create structure:
        // ~/maestro-sessions/
        //   └── session-uuid/
        //       ├── worktree/
        //       ├── logs/
        //       └── metadata.json

        try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        let worktreeDir = sessionDir.appendingPathComponent("worktree")
        let logsDir = sessionDir.appendingPathComponent("logs")

        try fileManager.createDirectory(at: worktreeDir, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: false)

        // Create metadata.json
        let metadata = SessionMetadata(
            id: sessionId,
            createdAt: Date(),
            status: .created
        )

        let metadataURL = sessionDir.appendingPathComponent("metadata.json")
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)

        return sessionDir
    }

    func deleteSessionDirectory(sessionId: UUID) async throws {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString)
        try fileManager.removeItem(at: sessionDir)
    }

    func listAllSessions() async throws -> [UUID] {
        let contents = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        return contents.compactMap { url in
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true,
                  let uuid = UUID(uuidString: url.lastPathComponent) else {
                return nil
            }
            return uuid
        }
    }

    func worktreeDirectory(for sessionId: UUID) -> URL {
        baseDirectory
            .appendingPathComponent(sessionId.uuidString)
            .appendingPathComponent("worktree")
    }

    func logsDirectory(for sessionId: UUID) -> URL {
        baseDirectory
            .appendingPathComponent(sessionId.uuidString)
            .appendingPathComponent("logs")
    }
}

struct SessionMetadata: Codable {
    let id: UUID
    let createdAt: Date
    var status: SessionStatus
}

enum SessionStatus: String, Codable {
    case created, running, stopped, error
}
```

### Pattern 2: Logs Manager

Write and manage log files:

```swift
actor LogsManager {
    private let fileManager = FileManager.default
    private let logsDirectory: URL

    init(sessionId: UUID, directoryManager: SessionDirectoryManager) {
        self.logsDirectory = directoryManager.logsDirectory(for: sessionId)
    }

    func appendLog(_ message: String, to logFile: String = "output.log") async throws {
        let logURL = logsDirectory.appendingPathComponent(logFile)

        // Create log file if doesn't exist
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil)
        }

        // Append message
        let fileHandle = try FileHandle(forWritingTo: logURL)
        defer { try? fileHandle.close() }

        fileHandle.seekToEndOfFile()

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        if let data = logLine.data(using: .utf8) {
            fileHandle.write(data)
        }
    }

    func readLogs(from logFile: String = "output.log") async throws -> String {
        let logURL = logsDirectory.appendingPathComponent(logFile)
        return try String(contentsOf: logURL, encoding: .utf8)
    }

    func clearLogs(logFile: String = "output.log") async throws {
        let logURL = logsDirectory.appendingPathComponent(logFile)
        try "".write(to: logURL, atomically: true, encoding: .utf8)
    }

    func rotateLogs(logFile: String = "output.log", maxSize: Int = 10_000_000) async throws {
        let logURL = logsDirectory.appendingPathComponent(logFile)

        guard let attributes = try? fileManager.attributesOfItem(atPath: logURL.path),
              let size = attributes[.size] as? Int,
              size > maxSize else {
            return
        }

        // Rotate: output.log -> output.1234567890.log
        let timestamp = Int(Date().timeIntervalSince1970)
        let rotatedURL = logsDirectory.appendingPathComponent("output.\(timestamp).log")

        try fileManager.moveItem(at: logURL, to: rotatedURL)

        // Create new empty log
        fileManager.createFile(atPath: logURL.path, contents: nil)
    }
}
```

### Pattern 3: Config File Manager

Read and write configuration files:

```swift
actor ConfigManager {
    private let fileManager = FileManager.default
    private let configURL: URL

    init(configPath: String = "~/.maestro/config.json") {
        let expandedPath = NSString(string: configPath).expandingTildeInPath
        self.configURL = URL(fileURLWithPath: expandedPath)
    }

    func loadConfig() async throws -> MaestroConfig {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return MaestroConfig.default
        }

        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(MaestroConfig.self, from: data)
    }

    func saveConfig(_ config: MaestroConfig) async throws {
        // Create directory if needed
        let directory = configURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        try data.write(to: configURL, options: .atomic)
    }

    func updateConfig(_ update: (inout MaestroConfig) -> Void) async throws {
        var config = try await loadConfig()
        update(&config)
        try await saveConfig(config)
    }
}

struct MaestroConfig: Codable {
    var sessionsDirectory: String
    var maxSessions: Int
    var defaultRepoPath: String?
    var claudePath: String

    static let `default` = MaestroConfig(
        sessionsDirectory: "~/maestro-sessions",
        maxSessions: 10,
        defaultRepoPath: nil,
        claudePath: "/usr/local/bin/claude"
    )
}
```

### Pattern 4: Temporary Files

```swift
func createTempSessionDirectory() throws -> URL {
    let fileManager = FileManager.default
    let tempDirectory = fileManager.temporaryDirectory

    let sessionDir = tempDirectory.appendingPathComponent(UUID().uuidString)
    try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)

    return sessionDir
}

// Usage
let tempDir = try createTempSessionDirectory()
// Work in tempDir...
// Clean up when done
try fileManager.removeItem(at: tempDir)
```

## File Attributes

```swift
let fileManager = FileManager.default
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")

// Get file size
let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
if let fileSize = resourceValues.fileSize {
    print("Size: \(fileSize) bytes")
}

// Get modification date
let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
if let modificationDate = attributes[.modificationDate] as? Date {
    print("Modified: \(modificationDate)")
}

// Check permissions
if fileManager.isReadableFile(atPath: fileURL.path) {
    print("Can read")
}
if fileManager.isWritableFile(atPath: fileURL.path) {
    print("Can write")
}
```

## Error Handling

```swift
enum FileOperationError: Error {
    case fileNotFound(String)
    case accessDenied(String)
    case directoryNotEmpty(String)
    case invalidPath(String)
    case operationFailed(String)
}

// Usage
func readFile(at url: URL) throws -> String {
    guard fileManager.fileExists(atPath: url.path) else {
        throw FileOperationError.fileNotFound(url.path)
    }

    guard fileManager.isReadableFile(atPath: url.path) else {
        throw FileOperationError.accessDenied(url.path)
    }

    return try String(contentsOf: url, encoding: .utf8)
}
```

## Resources

### references/
- **file-essentials.md** - Complete FileManager guide covering reading/writing files (text, JSON, binary), directory operations, file attributes, session directory structures, logs management, config files, file watching, permissions, bookmarks, temporary files, and best practices

Read this file for detailed patterns and advanced file operations.

## Best Practices

### 1. Always use URL
```swift
// ✅ Good
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")
try fileManager.createDirectory(at: fileURL, withIntermediateDirectories: true)

// ❌ Less good
let path = "/path/to/file.txt"
try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
```

### 2. Handle errors gracefully
```swift
// ✅ Good
do {
    let content = try String(contentsOf: fileURL)
} catch {
    print("Failed to read file: \(error)")
}

// ❌ Bad - will crash
let content = try! String(contentsOf: fileURL)
```

### 3. Use async for I/O
```swift
// ✅ Good - non-blocking
func readFile(at url: URL) async throws -> String {
    try String(contentsOf: url)
}

Task {
    let content = try await readFile(at: url)
}
```

### 4. Always create intermediate directories
```swift
// ✅ Good - creates entire path
try fileManager.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: true
)

// ❌ Bad - fails if parent doesn't exist
try fileManager.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: false
)
```

### 5. Clean up resources
```swift
// ✅ Good - always close
func processFile(at url: URL) throws {
    let fileHandle = try FileHandle(forReadingFrom: url)
    defer {
        try? fileHandle.close()
    }

    // Use fileHandle...
}
```

### 6. Use actors for thread safety
```swift
// ✅ Good - thread-safe file operations
actor FileManager {
    func writeLog(_ message: String) async throws {
        // Thread-safe
    }
}
```

## Common Mistakes

### ❌ Not checking if file exists
```swift
// ❌ Bad - may crash
let content = try String(contentsOfFile: filePath)

// ✅ Good - check first
if fileManager.fileExists(atPath: filePath) {
    let content = try String(contentsOfFile: filePath)
}
```

### ❌ Forgetting to close FileHandle
```swift
// ❌ Bad - resource leak
let fileHandle = try FileHandle(forReadingFrom: url)
// Use fileHandle...
// ❌ Never closed!

// ✅ Good - always close
let fileHandle = try FileHandle(forReadingFrom: url)
defer { try? fileHandle.close() }
```

### ❌ Blocking the main thread
```swift
// ❌ Bad - blocks UI
let content = try String(contentsOf: fileURL)

// ✅ Good - async
Task {
    let content = try await readFile(at: fileURL)
}
```

### ❌ Not handling errors
```swift
// ❌ Bad - crashes on error
try! fileManager.removeItem(at: url)

// ✅ Good - handle error
do {
    try fileManager.removeItem(at: url)
} catch {
    print("Failed to delete: \(error)")
}
```

## Integration with Other Skills

- **process-management** - Write process output to log files
- **mvvm-architecture** - Manage files in ViewModels with actors
- **swift-concurrency** - Use async/await for non-blocking I/O
- **swiftui** - Display file contents in Views

## Key Takeaways

✅ **FileManager** is your interface to the file system
✅ **URL** is preferred over String for paths
✅ **async** makes I/O non-blocking
✅ **try/catch** handles file operation errors
✅ **withIntermediateDirectories: true** creates full directory paths
✅ **defer** ensures resources are cleaned up
✅ **Actors** provide thread-safe file operations
✅ **Check existence** before operating on files
✅ **Close FileHandles** to avoid resource leaks
