import Foundation

// MARK: - MCP Error Types

/// Errors that can occur during MCP operations
enum MCPError: Error, LocalizedError, Sendable {
    case serverNotStarted
    case serverAlreadyRunning
    case serverLaunchFailed(reason: String)
    case serverTerminated(exitCode: Int32)
    case invalidResponse(reason: String)
    case requestFailed(method: String, reason: String)
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case timeout(method: String)
    case serverNotFound(path: String)

    var errorDescription: String? {
        switch self {
        case .serverNotStarted:
            return "MCP server is not started"
        case .serverAlreadyRunning:
            return "MCP server is already running"
        case .serverLaunchFailed(let reason):
            return "Failed to launch MCP server: \(reason)"
        case .serverTerminated(let exitCode):
            return "MCP server terminated with exit code: \(exitCode)"
        case .invalidResponse(let reason):
            return "Invalid response from MCP server: \(reason)"
        case .requestFailed(let method, let reason):
            return "MCP request '\(method)' failed: \(reason)"
        case .encodingFailed(let reason):
            return "Failed to encode MCP request: \(reason)"
        case .decodingFailed(let reason):
            return "Failed to decode MCP response: \(reason)"
        case .timeout(let method):
            return "MCP request '\(method)' timed out"
        case .serverNotFound(let path):
            return "MCP server not found at: \(path)"
        }
    }
}

// MARK: - JSON-RPC Types

/// JSON-RPC 2.0 request for tool calls
private struct ToolCallRequest: Codable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: ToolCallParams

    init(id: Int, name: String, arguments: [String: AnyCodable]?) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = "tools/call"
        self.params = ToolCallParams(name: name, arguments: arguments)
    }
}

/// JSON-RPC params for tool calls
private struct ToolCallParams: Codable {
    let name: String
    let arguments: [String: AnyCodable]?
}

/// JSON-RPC 2.0 request for initialize
private struct InitializeRequest: Codable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: InitializeParams

    init(id: Int) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = "initialize"
        self.params = InitializeParams(
            protocolVersion: "2024-11-05",
            capabilities: InitializeParams.ClientCapabilities(),
            clientInfo: InitializeParams.ClientInfo(name: "XRoads", version: "1.0.0")
        )
    }
}

/// JSON-RPC params for initialize
private struct InitializeParams: Codable {
    let protocolVersion: String
    let capabilities: ClientCapabilities
    let clientInfo: ClientInfo

    struct ClientCapabilities: Codable {
        // Empty for now - we don't expose any client capabilities
    }

    struct ClientInfo: Codable {
        let name: String
        let version: String
    }
}

/// JSON-RPC 2.0 notification (no id)
private struct JSONRPCNotification: Codable {
    let jsonrpc: String
    let method: String

    init(method: String) {
        self.jsonrpc = "2.0"
        self.method = method
    }
}

/// JSON-RPC 2.0 response structure
private struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: Int?
    let result: JSONRPCResult?
    let error: JSONRPCError?
}

/// JSON-RPC result wrapper
private struct JSONRPCResult: Codable {
    let content: [JSONRPCContent]?
    let tools: [JSONRPCTool]?
}

/// JSON-RPC content item
private struct JSONRPCContent: Codable {
    let type: String
    let text: String?
}

/// JSON-RPC tool definition
private struct JSONRPCTool: Codable {
    let name: String
    let description: String?
}

/// JSON-RPC error object
private struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

/// Type-erased Codable wrapper for dynamic JSON values
/// Thread-safe Sendable implementation using enum instead of Any
struct AnyCodable: Codable, Sendable {
    enum Value: Sendable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyCodable])
        case dictionary([String: AnyCodable])
    }

    let value: Value

    init(_ value: Any) {
        switch value {
        case is NSNull:
            self.value = .null
        case let bool as Bool:
            self.value = .bool(bool)
        case let int as Int:
            self.value = .int(int)
        case let double as Double:
            self.value = .double(double)
        case let string as String:
            self.value = .string(string)
        case let array as [Any]:
            self.value = .array(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            self.value = .dictionary(dict.mapValues { AnyCodable($0) })
        default:
            self.value = .null
        }
    }

    /// Convenience accessor for the underlying Swift value
    var anyValue: Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let bool):
            return bool
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .string(let string):
            return string
        case .array(let array):
            return array.map { $0.anyValue }
        case .dictionary(let dict):
            return dict.mapValues { $0.anyValue }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = .null
        } else if let bool = try? container.decode(Bool.self) {
            self.value = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self.value = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self.value = .double(double)
        } else if let string = try? container.decode(String.self) {
            self.value = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dict):
            try container.encode(dict)
        }
    }
}

// MARK: - MCP State Types

/// Agent state from MCP server
struct MCPAgentState: Codable, Sendable, Hashable {
    let agent: String
    let worktree: String
    let status: String
    let task: String?
    let progress: Double?
    let updatedAt: String
}

/// Worktree info from MCP server
struct MCPWorktreeInfo: Codable, Sendable, Hashable {
    let path: String
    let agent: String?
    let status: String
}

/// Complete MCP state response
struct MCPState: Codable, Sendable {
    let agents: [MCPAgentState]
    let logs: [MCPLogEntry]
    let worktrees: [MCPWorktreeInfo]
}

/// Log entry from MCP server
struct MCPLogEntry: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let timestamp: String
    let level: String
    let source: String
    let worktree: String
    let message: String
    let metadata: [String: AnyCodable]?

    /// Convert to app LogEntry model
    func toLogEntry() -> LogEntry {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: timestamp) ?? Date()

        let logLevel: LogLevel
        switch level.lowercased() {
        case "debug": logLevel = .debug
        case "info": logLevel = .info
        case "warn": logLevel = .warn
        case "error": logLevel = .error
        default: logLevel = .info
        }

        // Convert metadata to [String: String]
        var stringMetadata: [String: String]?
        if let meta = metadata {
            stringMetadata = [:]
            for (key, value) in meta {
                // Access anyValue to get the underlying Swift value
                let anyVal = value.anyValue
                
                // Type-check and format appropriately
                if let strValue = anyVal as? String {
                    stringMetadata?[key] = strValue
                } else if let intValue = anyVal as? Int {
                    stringMetadata?[key] = "\(intValue)"
                } else if let doubleValue = anyVal as? Double {
                    stringMetadata?[key] = String(format: "%.2f", doubleValue)
                } else if let boolValue = anyVal as? Bool {
                    stringMetadata?[key] = boolValue ? "true" : "false"
                } else if let arrValue = anyVal as? [Any] {
                    stringMetadata?[key] = "[\(arrValue.count) items]"
                } else if let dictValue = anyVal as? [String: Any] {
                    stringMetadata?[key] = "{\(dictValue.count) keys}"
                } else {
                    stringMetadata?[key] = String(describing: anyVal)
                }
            }
        }

        return LogEntry(
            timestamp: date,
            level: logLevel,
            source: source,
            worktree: worktree,
            message: message,
            metadata: stringMetadata
        )
    }
}

// Make MCPLogEntry Hashable by excluding metadata
extension MCPLogEntry {
    static func == (lhs: MCPLogEntry, rhs: MCPLogEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - MCP Connection Status

/// Represents the current connection status of the MCP client
enum MCPConnectionStatus: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - MCP Client Actor

/// Thread-safe MCP client for communicating with xroads-mcp server
actor MCPClient {

    // MARK: - Properties

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var requestId: Int = 0
    private var pendingResponses: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]
    private var responseBuffer: String = ""
    private var isRunning: Bool = false

    /// Current connection status
    private var connectionStatus: MCPConnectionStatus = .disconnected

    /// Log streaming task
    private var logStreamTask: Task<Void, Never>?

    /// Continuation for the log stream
    private var logStreamContinuation: AsyncStream<LogEntry>.Continuation?

    /// Track last seen log IDs to avoid duplicates
    private var lastSeenLogIds: Set<String> = []

    /// Polling interval for log streaming (in nanoseconds)
    private let pollingInterval: UInt64 = 500_000_000 // 500ms

    /// Path to the MCP server directory
    private let mcpServerPath: String

    /// Path to Node.js executable
    private let nodePath: String

    /// When true, all server start/call operations are no-ops.
    /// Used by MockServiceContainer to prevent real I/O in tests and previews.
    let testMode: Bool

    // MARK: - Initialization

    init(
        mcpServerPath: String = "",
        nodePath: String = "",
        testMode: Bool = false
    ) {
        self.testMode = testMode

        // In test mode, skip expensive path resolution
        if testMode {
            self.nodePath = "/usr/bin/node"
            self.mcpServerPath = ""
            return
        }

        // Find node dynamically if not provided
        if nodePath.isEmpty {
            self.nodePath = Self.findNodePath()
        } else {
            self.nodePath = nodePath
        }
        // Default to xroads-mcp - search multiple locations
        if mcpServerPath.isEmpty {
            self.mcpServerPath = Self.findMCPServerPath()
        } else {
            self.mcpServerPath = mcpServerPath
        }
    }

    /// Find Node.js executable path
    static func findNodePath() -> String {
        let fileManager = FileManager.default
        let home = NSHomeDirectory()

        // 1. NVM: glob all installed versions and pick the latest
        if let nvmNode = findLatestNVMNode(home: home, fileManager: fileManager) {
            return nvmNode
        }

        // 2. Static candidate paths (Homebrew, system)
        let candidates: [String] = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ]

        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
        }

        // 3. Try running 'which node' as fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["node"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // Ignore
        }

        // Default fallback
        return "/usr/local/bin/node"
    }

    /// Discover the latest NVM-installed Node.js by globbing ~/.nvm/versions/node/*/bin/node
    /// and sorting version directories in descending semver order.
    static func findLatestNVMNode(
        home: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> String? {
        let nvmVersionsDir = (home as NSString).appendingPathComponent(".nvm/versions/node")
        guard fileManager.fileExists(atPath: nvmVersionsDir) else { return nil }

        guard let entries = try? fileManager.contentsOfDirectory(atPath: nvmVersionsDir) else {
            return nil
        }

        // Filter to directories starting with "v" and having a valid node binary
        let validVersions = entries
            .filter { $0.hasPrefix("v") }
            .compactMap { entry -> (dir: String, version: [Int])? in
                let nodeBin = (nvmVersionsDir as NSString)
                    .appendingPathComponent(entry)
                    .appending("/bin/node")
                guard fileManager.fileExists(atPath: nodeBin) else { return nil }
                let parts = parseVersion(entry)
                guard !parts.isEmpty else { return nil }
                return (nodeBin, parts)
            }

        // Sort descending by version components to prefer the latest
        let sorted = validVersions.sorted { lhs, rhs in
            for (l, r) in zip(lhs.version, rhs.version) {
                if l != r { return l > r }
            }
            return lhs.version.count > rhs.version.count
        }

        return sorted.first?.dir
    }

    /// Parse a version string like "v20.19.4" into [20, 19, 4]
    static func parseVersion(_ versionString: String) -> [Int] {
        let stripped = versionString.hasPrefix("v")
            ? String(versionString.dropFirst())
            : versionString
        return stripped.split(separator: ".").compactMap { Int($0) }
    }

    /// Find the MCP server path by checking multiple locations
    private static func findMCPServerPath() -> String {
        let fileManager = FileManager.default

        // Candidate paths to check
        let candidates: [String] = [
            // 0. App bundle Resources (for .app distribution via DMG)
            Bundle.main.resourcePath.map {
                ($0 as NSString).appendingPathComponent("xroads-mcp")
            } ?? "",
            // 1. Search up from executable path (most reliable — independent of CWD)
            {
                guard let execPath = Bundle.main.executablePath else { return "" }
                var path = (execPath as NSString).deletingLastPathComponent
                for _ in 0..<10 {
                    let mcpPath = (path as NSString).appendingPathComponent("xroads-mcp")
                    let script = (mcpPath as NSString).appendingPathComponent("dist/index.js")
                    if fileManager.fileExists(atPath: script) {
                        return mcpPath
                    }
                    let parent = (path as NSString).deletingLastPathComponent
                    if parent == path { break }
                    path = parent
                }
                return ""
            }(),
            // 1. Relative to source file (best for Xcode development)
            {
                // Try to find the project root by looking for Package.swift or .git
                var searchPath = fileManager.currentDirectoryPath
                
                // If we're in DerivedData, try to find the actual project
                if searchPath.contains("DerivedData") {
                    // Common project locations
                    let home = fileManager.homeDirectoryForCurrentUser.path
                    let projectNames = ["CrossRoads", "XRoads"]
                    let baseDirs = ["Projets", "Projects", "Documents", "Desktop"]
                    var possibleProjects: [String] = []

                    if let envPath = getenv("CROSSROADS_PROJECT_DIR") {
                        possibleProjects.append(String(cString: envPath))
                    }

                    for base in baseDirs {
                        for projectName in projectNames {
                            possibleProjects.append("\(home)/\(base)/\(projectName)")
                        }
                    }
                    
                    for projectPath in possibleProjects {
                        let mcpPath = (projectPath as NSString).appendingPathComponent("xroads-mcp")
                        if fileManager.fileExists(atPath: mcpPath) {
                            return mcpPath
                        }
                    }
                }
                
                // Otherwise, search up from current directory
                for _ in 0..<10 {
                    let mcpPath = (searchPath as NSString).appendingPathComponent("xroads-mcp")
                    if fileManager.fileExists(atPath: mcpPath) {
                        return mcpPath
                    }
                    
                    // Check for project markers
                    let packageSwift = (searchPath as NSString).appendingPathComponent("Package.swift")
                    let gitDir = (searchPath as NSString).appendingPathComponent(".git")
                    
                    if fileManager.fileExists(atPath: packageSwift) || fileManager.fileExists(atPath: gitDir) {
                        return (searchPath as NSString).appendingPathComponent("xroads-mcp")
                    }
                    
                    // Go up one level
                    let parentPath = (searchPath as NSString).deletingLastPathComponent
                    if parentPath == searchPath { break } // Reached root
                    searchPath = parentPath
                }
                
                return ""
            }(),
            // 2. Current working directory (for swift run)
            (fileManager.currentDirectoryPath as NSString).appendingPathComponent("xroads-mcp"),
            // 3. Project root based on bundle (for Xcode runs)
            {
                let bundlePath = Bundle.main.bundlePath
                // Go up from .build/debug/XRoads to project root
                var path = bundlePath
                for _ in 0..<3 {
                    path = (path as NSString).deletingLastPathComponent
                }
                return (path as NSString).appendingPathComponent("xroads-mcp")
            }(),
            // 4. Relative to bundle's parent (original logic)
            {
                let bundlePath = Bundle.main.bundlePath
                let parentDir = (bundlePath as NSString).deletingLastPathComponent
                return (parentDir as NSString).appendingPathComponent("xroads-mcp")
            }(),
            // 5. Environment variable for custom path
            {
                if let envPath = getenv("CROSSROADS_MCP_PATH") {
                    return String(cString: envPath)
                }
                return ""
            }(),
            // 6. User home directory fallback
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("xroads-mcp")
                .path
        ].filter { !$0.isEmpty }

        Log.mcp.debug("Searching for MCP server...")
        Log.mcp.debug("  Bundle path: \(Bundle.main.bundlePath)")
        Log.mcp.debug("  Current directory: \(fileManager.currentDirectoryPath)")
        Log.mcp.debug("  Checking \(candidates.count) candidate paths:")

        // Check each candidate for dist/index.js
        for (index, candidate) in candidates.enumerated() {
            let serverScript = (candidate as NSString).appendingPathComponent("dist/index.js")
            Log.mcp.debug("  [\(index + 1)] \(candidate)")
            Log.mcp.debug("      → dist/index.js exists: \(fileManager.fileExists(atPath: serverScript))")
            
            if fileManager.fileExists(atPath: serverScript) {
                Log.mcp.info("Found MCP server at: \(candidate)")
                return candidate
            }
        }

        Log.mcp.error("MCP server not found in any candidate path")
        Log.mcp.info("You can set CROSSROADS_MCP_PATH environment variable to specify custom path")

        // Return first candidate as fallback (will fail with clear error)
        return candidates.first ?? "xroads-mcp"
    }

    // MARK: - Lifecycle

    /// Starts the MCP server process
    /// - Throws: MCPError if server fails to start
    func start() async throws {
        // In test mode, skip server launch entirely
        if testMode { return }

        guard !isRunning else {
            throw MCPError.serverAlreadyRunning
        }

        connectionStatus = .connecting

        // Verify node exists
        guard FileManager.default.fileExists(atPath: nodePath) else {
            connectionStatus = .error("Node.js not found")
            throw MCPError.serverNotFound(path: nodePath)
        }

        // Verify MCP server directory exists
        let serverScript = (mcpServerPath as NSString).appendingPathComponent("dist/index.js")
        guard FileManager.default.fileExists(atPath: serverScript) else {
            connectionStatus = .error("MCP server script not found")
            throw MCPError.serverNotFound(path: serverScript)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [serverScript]
        process.currentDirectoryURL = URL(fileURLWithPath: mcpServerPath)

        // Setup pipes
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Setup stdout handler for responses
        // Note: readabilityHandler runs on a background thread, so we must
        // dispatch to the actor explicitly to avoid data races
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            if let text = String(data: data, encoding: .utf8) {
                // Capture self to ensure actor context
                Task { [self] in
                    await self.handleServerOutput(text)
                }
            }
        }

        // Setup stderr handler for error/debug output
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            if let text = String(data: data, encoding: .utf8) {
                Task { [self] in
                    await self.handleServerError(text)
                }
            }
        }

        // Setup termination handler
        process.terminationHandler = { [weak self] proc in
            Task { [weak self] in
                await self?.handleTermination(exitCode: proc.terminationStatus)
            }
        }

        // Launch
        do {
            try process.run()
        } catch {
            connectionStatus = .error("Failed to launch: \(error.localizedDescription)")
            throw MCPError.serverLaunchFailed(reason: error.localizedDescription)
        }

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.isRunning = true

        // Initialize the MCP connection
        do {
            try await initialize()
            connectionStatus = .connected
        } catch {
            connectionStatus = .error("Initialization failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Stops the MCP server process
    func stop() {
        guard isRunning, let process = process else { return }

        // Stop log streaming first
        stopPollingLoop()

        // Close stdin to signal EOF
        stdinPipe?.fileHandleForWriting.closeFile()

        // Terminate if still running
        if process.isRunning {
            process.terminate()
        }

        // Cleanup
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        self.process = nil
        self.stdinPipe = nil
        self.stdoutPipe = nil
        self.stderrPipe = nil
        self.isRunning = false
        self.connectionStatus = .disconnected

        // Cancel pending requests
        for (_, continuation) in pendingResponses {
            continuation.resume(throwing: MCPError.serverNotStarted)
        }
        pendingResponses.removeAll()
    }

    /// Check if the server is running
    var serverIsRunning: Bool {
        return isRunning
    }

    /// Get the current connection status
    var status: MCPConnectionStatus {
        return connectionStatus
    }

    // MARK: - Log Streaming

    /// Creates an AsyncStream that emits LogEntry items from the MCP server
    /// The stream polls getState() at the specified interval and yields new logs
    /// - Returns: AsyncStream of LogEntry that yields new logs as they arrive
    func logStream() -> AsyncStream<LogEntry> {
        // Cancel any existing stream task
        logStreamContinuation?.finish()
        logStreamTask?.cancel()

        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.setLogStreamContinuation(continuation)

                // Start polling loop
                await self?.startPollingLoop()
            }

            // Handle stream termination
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.stopPollingLoop()
                }
            }
        }
    }

    /// Sets the log stream continuation
    private func setLogStreamContinuation(_ continuation: AsyncStream<LogEntry>.Continuation) {
        self.logStreamContinuation = continuation
    }

    /// Starts the polling loop for log streaming
    private func startPollingLoop() {
        // Clear seen logs when starting fresh
        lastSeenLogIds.removeAll()

        logStreamTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                // Get polling interval once per iteration (it's a constant, no await needed)
                let interval = self.pollingInterval

                // Only poll if server is running
                guard await self.serverIsRunning else {
                    // Server not running, wait and retry
                    try? await Task.sleep(nanoseconds: interval)
                    continue
                }

                do {
                    let state = try await self.getState()

                    // Find new logs that we haven't seen before
                    for mcpLog in state.logs {
                        let shouldYield = await self.shouldYieldLog(mcpLog)
                        if shouldYield {
                            let logEntry = mcpLog.toLogEntry()
                            await self.yieldLog(logEntry)
                            await self.markLogSeen(mcpLog.id)
                        }
                    }
                } catch {
                    // Log error but continue polling
                    // Don't flood with errors - just skip this iteration
                    if !(error is CancellationError) {
                        // Could emit error log here if needed
                    }
                }

                // Wait before next poll
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    /// Stops the polling loop
    private func stopPollingLoop() {
        logStreamTask?.cancel()
        logStreamTask = nil
        logStreamContinuation?.finish()
        logStreamContinuation = nil
    }

    /// Check if a log should be yielded (not seen before)
    private func shouldYieldLog(_ mcpLog: MCPLogEntry) -> Bool {
        return !lastSeenLogIds.contains(mcpLog.id)
    }

    /// Mark a log ID as seen
    private func markLogSeen(_ logId: String) {
        lastSeenLogIds.insert(logId)
        // Limit the set size to prevent unbounded growth
        // Keep in sync with AppState log limit (500) + buffer for polling window
        if lastSeenLogIds.count > 1000 {
            // Remove arbitrary elements to reduce memory usage
            let toRemove = Array(lastSeenLogIds.prefix(500))
            for id in toRemove {
                lastSeenLogIds.remove(id)
            }
        }
    }

    /// Yields a log entry to the stream
    private func yieldLog(_ logEntry: LogEntry) {
        logStreamContinuation?.yield(logEntry)
    }

    /// Stops log streaming explicitly
    func stopLogStream() {
        stopPollingLoop()
    }

    // MARK: - MCP Tool Methods

    /// Emit a log entry to the MCP server
    /// - Parameters:
    ///   - level: Log level (debug, info, warn, error)
    ///   - source: Source of the log (claude, gemini, codex, system)
    ///   - worktree: Worktree path associated with the log
    ///   - message: Log message content
    ///   - metadata: Optional metadata dictionary
    /// - Throws: MCPError if request fails
    func emitLog(
        level: LogLevel,
        source: String,
        worktree: String,
        message: String,
        metadata: [String: Any]? = nil
    ) async throws {
        var args: [String: AnyCodable] = [
            "level": AnyCodable(level.rawValue),
            "source": AnyCodable(source),
            "worktree": AnyCodable(worktree),
            "message": AnyCodable(message)
        ]

        if let metadata = metadata {
            args["metadata"] = AnyCodable(metadata)
        }

        _ = try await callTool(name: "emit_log", arguments: args)
    }

    /// Update agent status on the MCP server
    /// - Parameters:
    ///   - agent: Agent identifier (claude, gemini, codex)
    ///   - worktree: Worktree path the agent is working on
    ///   - status: Current status
    ///   - task: Optional current task description
    ///   - progress: Optional progress percentage (0-100)
    /// - Throws: MCPError if request fails
    func updateStatus(
        agent: String,
        worktree: String,
        status: AgentStatus,
        task: String? = nil,
        progress: Double? = nil
    ) async throws {
        var args: [String: AnyCodable] = [
            "agent": AnyCodable(agent),
            "worktree": AnyCodable(worktree),
            "status": AnyCodable(status.rawValue)
        ]

        if let task = task {
            args["task"] = AnyCodable(task)
        }

        if let progress = progress {
            args["progress"] = AnyCodable(progress)
        }

        _ = try await callTool(name: "update_status", arguments: args)
    }

    /// Get the current state from the MCP server
    /// - Returns: MCPState with agents, logs, and worktrees
    /// - Throws: MCPError if request fails
    func getState() async throws -> MCPState {
        let response = try await callTool(name: "get_state", arguments: [:])

        // Parse the response content
        guard let content = response.result?.content?.first,
              let text = content.text else {
            throw MCPError.invalidResponse(reason: "No content in response")
        }

        guard let data = text.data(using: .utf8) else {
            throw MCPError.decodingFailed(reason: "Failed to convert response to data")
        }

        do {
            let state = try JSONDecoder().decode(MCPState.self, from: data)
            return state
        } catch {
            throw MCPError.decodingFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// Initialize the MCP connection
    private func initialize() async throws {
        requestId += 1
        let request = InitializeRequest(id: requestId)
        _ = try await sendEncodableRequest(request, method: "initialize")

        // Send initialized notification (no response expected)
        try sendNotification(method: "notifications/initialized")
    }

    /// Call an MCP tool
    private func callTool(name: String, arguments: [String: AnyCodable]) async throws -> JSONRPCResponse {
        requestId += 1
        let request = ToolCallRequest(id: requestId, name: name, arguments: arguments)
        return try await sendEncodableRequest(request, method: "tools/call")
    }

    /// Send any encodable JSON-RPC request and wait for response
    private func sendEncodableRequest<T: Encodable>(_ request: T, method: String) async throws -> JSONRPCResponse {
        guard isRunning else {
            throw MCPError.serverNotStarted
        }

        guard let data = try? JSONEncoder().encode(request),
              var jsonString = String(data: data, encoding: .utf8) else {
            throw MCPError.encodingFailed(reason: "Failed to encode request")
        }

        // JSON-RPC messages are newline-delimited
        jsonString += "\n"

        guard let requestData = jsonString.data(using: .utf8) else {
            throw MCPError.encodingFailed(reason: "Failed to convert to data")
        }

        // Write to stdin
        do {
            try stdinPipe?.fileHandleForWriting.write(contentsOf: requestData)
        } catch {
            throw MCPError.requestFailed(method: method, reason: error.localizedDescription)
        }

        // Wait for response with timeout
        let currentId = requestId
        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses[currentId] = continuation

            // Timeout after 30 seconds
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                
                // Only timeout if not already cancelled
                guard !Task.isCancelled else { return }
                
                // Try to remove and resume with timeout error
                // This will only succeed if the request hasn't been fulfilled yet
                Task { @MainActor in
                    if let cont = await self.removePendingResponse(id: currentId) {
                        cont.resume(throwing: MCPError.timeout(method: method))
                    }
                }
            }
        }
    }

    /// Send a notification (no response expected)
    private func sendNotification(method: String) throws {
        guard isRunning else {
            throw MCPError.serverNotStarted
        }

        let notification = JSONRPCNotification(method: method)

        guard let data = try? JSONEncoder().encode(notification),
              var jsonString = String(data: data, encoding: .utf8) else {
            throw MCPError.encodingFailed(reason: "Failed to encode notification")
        }

        jsonString += "\n"

        guard let notificationData = jsonString.data(using: .utf8) else {
            throw MCPError.encodingFailed(reason: "Failed to convert to data")
        }

        try stdinPipe?.fileHandleForWriting.write(contentsOf: notificationData)
    }

    /// Handle output from the server
    private func handleServerOutput(_ text: String) {
        responseBuffer += text

        // Process complete JSON-RPC messages (newline-delimited)
        while let newlineIndex = responseBuffer.firstIndex(of: "\n") {
            let line = String(responseBuffer[..<newlineIndex])
            responseBuffer = String(responseBuffer[responseBuffer.index(after: newlineIndex)...])

            guard !line.isEmpty else { continue }

            // Parse the JSON-RPC response
            guard let data = line.data(using: .utf8) else { continue }

            do {
                let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

                // Match to pending request
                if let id = response.id, let continuation = pendingResponses.removeValue(forKey: id) {
                    if let error = response.error {
                        continuation.resume(throwing: MCPError.requestFailed(
                            method: "unknown",
                            reason: error.message
                        ))
                    } else {
                        continuation.resume(returning: response)
                    }
                }
            } catch {
                // Log parsing error with details for debugging
                Log.mcp.error("Failed to parse JSON-RPC response: \(error)")
                Log.mcp.debug("  Line: \(line)")
            }
        }
    }

    /// Handle error output from the server (stderr)
    private func handleServerError(_ text: String) {
        // Log all stderr output for debugging
        Log.mcp.debug("stderr: \(text)")

        // Check for critical error patterns
        if text.contains("FATAL") || text.contains("Error:") || text.contains("Exception") {
            connectionStatus = .error("Server error: \(text)")
        }
    }

    /// Handle server termination
    private func handleTermination(exitCode: Int32) {
        isRunning = false
        connectionStatus = .error("Server terminated (exit code: \(exitCode))")

        // Stop log streaming
        stopPollingLoop()

        // Cancel all pending requests
        for (_, continuation) in pendingResponses {
            continuation.resume(throwing: MCPError.serverTerminated(exitCode: exitCode))
        }
        pendingResponses.removeAll()
    }

    /// Remove and return a pending response continuation
    private func removePendingResponse(id: Int) -> CheckedContinuation<JSONRPCResponse, Error>? {
        return pendingResponses.removeValue(forKey: id)
    }
}
