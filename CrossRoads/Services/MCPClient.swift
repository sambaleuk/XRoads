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

/// JSON-RPC 2.0 request structure
private struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: JSONRPCParams?

    init(id: Int, method: String, params: JSONRPCParams? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC params wrapper
private struct JSONRPCParams: Codable {
    let name: String?
    let arguments: [String: AnyCodable]?

    init(name: String? = nil, arguments: [String: AnyCodable]? = nil) {
        self.name = name
        self.arguments = arguments
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
/// Note: Sendable conformance is unchecked due to Any type
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
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
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Cannot encode AnyCodable"
                )
            )
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
                if let strValue = value.value as? String {
                    stringMetadata?[key] = strValue
                } else {
                    stringMetadata?[key] = String(describing: value.value)
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

// MARK: - MCP Client Actor

/// Thread-safe MCP client for communicating with crossroads-mcp server
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

    /// Path to the MCP server directory
    private let mcpServerPath: String

    /// Path to Node.js executable
    private let nodePath: String

    // MARK: - Initialization

    init(
        mcpServerPath: String = "",
        nodePath: String = "/usr/local/bin/node"
    ) {
        // Default to crossroads-mcp relative to the bundle or current directory
        if mcpServerPath.isEmpty {
            // Try to find crossroads-mcp relative to the executable
            let bundlePath = Bundle.main.bundlePath
            let parentDir = (bundlePath as NSString).deletingLastPathComponent
            self.mcpServerPath = (parentDir as NSString).appendingPathComponent("crossroads-mcp")
        } else {
            self.mcpServerPath = mcpServerPath
        }
        self.nodePath = nodePath
    }

    // MARK: - Lifecycle

    /// Starts the MCP server process
    /// - Throws: MCPError if server fails to start
    func start() async throws {
        guard !isRunning else {
            throw MCPError.serverAlreadyRunning
        }

        // Verify node exists
        guard FileManager.default.fileExists(atPath: nodePath) else {
            throw MCPError.serverNotFound(path: nodePath)
        }

        // Verify MCP server directory exists
        let serverScript = (mcpServerPath as NSString).appendingPathComponent("dist/index.js")
        guard FileManager.default.fileExists(atPath: serverScript) else {
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
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            if let text = String(data: data, encoding: .utf8) {
                Task { [weak self] in
                    await self?.handleServerOutput(text)
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
            throw MCPError.serverLaunchFailed(reason: error.localizedDescription)
        }

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.isRunning = true

        // Initialize the MCP connection
        try await initialize()
    }

    /// Stops the MCP server process
    func stop() {
        guard isRunning, let process = process else { return }

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
        // Send initialize request
        let initParams = JSONRPCParams(
            name: nil,
            arguments: [
                "protocolVersion": AnyCodable("2024-11-05"),
                "capabilities": AnyCodable(["tools": [:] as [String: Any]]),
                "clientInfo": AnyCodable([
                    "name": "CrossRoads",
                    "version": "1.0.0"
                ])
            ]
        )

        _ = try await sendRequest(method: "initialize", params: initParams)

        // Send initialized notification (no response expected)
        try sendNotification(method: "notifications/initialized", params: nil)
    }

    /// Call an MCP tool
    private func callTool(name: String, arguments: [String: AnyCodable]) async throws -> JSONRPCResponse {
        let params = JSONRPCParams(name: name, arguments: arguments)
        return try await sendRequest(method: "tools/call", params: params)
    }

    /// Send a JSON-RPC request and wait for response
    private func sendRequest(method: String, params: JSONRPCParams?) async throws -> JSONRPCResponse {
        guard isRunning else {
            throw MCPError.serverNotStarted
        }

        requestId += 1
        let id = requestId

        let request = JSONRPCRequest(id: id, method: method, params: params)

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
        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses[id] = continuation

            // Timeout after 30 seconds
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                let cont = await self.removePendingResponse(id: id)
                if let cont = cont {
                    cont.resume(throwing: MCPError.timeout(method: method))
                }
            }
        }
    }

    /// Send a notification (no response expected)
    private func sendNotification(method: String, params: JSONRPCParams?) throws {
        guard isRunning else {
            throw MCPError.serverNotStarted
        }

        // Notifications use null id
        struct Notification: Codable {
            let jsonrpc: String
            let method: String
            let params: JSONRPCParams?
        }

        let notification = Notification(jsonrpc: "2.0", method: method, params: params)

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
                // Log parsing error but don't crash
                print("MCPClient: Failed to parse response: \(error)")
            }
        }
    }

    /// Handle server termination
    private func handleTermination(exitCode: Int32) {
        isRunning = false

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
