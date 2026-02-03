import Foundation

// MARK: - ConfigStatus

/// Status of a single configuration check
struct ConfigCheckResult: Sendable, Codable, Hashable {
    let tool: String
    let isAvailable: Bool
    let path: String?
    let version: String?
    let error: String?

    static func available(tool: String, path: String, version: String? = nil) -> ConfigCheckResult {
        ConfigCheckResult(tool: tool, isAvailable: true, path: path, version: version, error: nil)
    }

    static func unavailable(tool: String, error: String? = nil) -> ConfigCheckResult {
        ConfigCheckResult(tool: tool, isAvailable: false, path: nil, version: nil, error: error)
    }
}

/// Overall configuration status with details for each tool
struct ConfigStatus: Sendable, Codable {
    let git: ConfigCheckResult
    let claude: ConfigCheckResult
    let gemini: ConfigCheckResult
    let codex: ConfigCheckResult
    let checkedAt: Date

    /// Returns true if all required tools are available
    var allRequiredAvailable: Bool {
        git.isAvailable
    }

    /// Returns true if at least one agent CLI is available
    var anyAgentAvailable: Bool {
        claude.isAvailable || gemini.isAvailable || codex.isAvailable
    }

    /// Returns list of unavailable tools
    var unavailableTools: [String] {
        var tools: [String] = []
        if !git.isAvailable { tools.append("git") }
        if !claude.isAvailable { tools.append("claude") }
        if !gemini.isAvailable { tools.append("gemini") }
        if !codex.isAvailable { tools.append("codex") }
        return tools
    }

    /// Returns list of available agent types
    var availableAgentTypes: [AgentType] {
        var types: [AgentType] = []
        if claude.isAvailable { types.append(.claude) }
        if gemini.isAvailable { types.append(.gemini) }
        if codex.isAvailable { types.append(.codex) }
        return types
    }

    /// User-friendly summary of configuration status
    var summary: String {
        if allRequiredAvailable && anyAgentAvailable {
            let agents = availableAgentTypes.map { $0.displayName }.joined(separator: ", ")
            return "Ready: \(agents)"
        } else if !allRequiredAvailable {
            return "Git not found - required for worktrees"
        } else {
            return "No agent CLIs found - install claude, gemini, or codex"
        }
    }
}

// MARK: - ConfigCheckerError

/// Errors from config checking operations
enum ConfigCheckerError: Error, LocalizedError, Sendable {
    case whichNotFound
    case checkFailed(tool: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .whichNotFound:
            return "The 'which' command was not found"
        case .checkFailed(let tool, let reason):
            return "Failed to check \(tool): \(reason)"
        }
    }
}

// MARK: - ConfigChecker Actor

/// Thread-safe service for checking CLI tool availability
actor ConfigChecker {

    // MARK: - Properties

    /// Path to the 'which' command
    private let whichPath = "/usr/bin/which"

    /// Cached config status
    private var cachedStatus: ConfigStatus?

    /// Cache duration in seconds (5 minutes)
    private let cacheDuration: TimeInterval = 300

    /// Last check timestamp
    private var lastCheckTime: Date?

    // MARK: - Public Methods

    /// Checks if git is available
    /// - Returns: true if git is found
    func checkGit() async -> Bool {
        let result = await runWhich(tool: "git")
        return result != nil
    }

    /// Checks if Claude CLI is available
    /// - Returns: true if claude is found
    func checkClaude() async -> Bool {
        let result = await runWhich(tool: "claude")
        return result != nil
    }

    /// Checks if Gemini CLI is available
    /// - Returns: true if gemini is found
    func checkGemini() async -> Bool {
        let result = await runWhich(tool: "gemini")
        return result != nil
    }

    /// Checks if Codex CLI is available
    /// - Returns: true if codex is found
    func checkCodex() async -> Bool {
        let result = await runWhich(tool: "codex")
        return result != nil
    }

    /// Performs comprehensive check of all tools
    /// - Parameter forceRefresh: If true, ignores cached results
    /// - Returns: ConfigStatus with details for each tool
    func checkAll(forceRefresh: Bool = false) async -> ConfigStatus {
        // Return cached if still valid
        if !forceRefresh,
           let cached = cachedStatus,
           let lastCheck = lastCheckTime,
           Date().timeIntervalSince(lastCheck) < cacheDuration {
            return cached
        }

        // Run all checks concurrently
        async let gitCheck = checkTool(name: "git")
        async let claudeCheck = checkTool(name: "claude")
        async let geminiCheck = checkTool(name: "gemini")
        async let codexCheck = checkTool(name: "codex")

        let status = await ConfigStatus(
            git: gitCheck,
            claude: claudeCheck,
            gemini: geminiCheck,
            codex: codexCheck,
            checkedAt: Date()
        )

        // Cache the result
        cachedStatus = status
        lastCheckTime = Date()

        return status
    }

    /// Checks if a specific agent type is available
    /// - Parameter agentType: The agent type to check
    /// - Returns: true if the agent CLI is available
    func isAgentAvailable(_ agentType: AgentType) async -> Bool {
        switch agentType {
        case .claude:
            return await checkClaude()
        case .gemini:
            return await checkGemini()
        case .codex:
            return await checkCodex()
        }
    }

    /// Clears the cached configuration status
    func clearCache() {
        cachedStatus = nil
        lastCheckTime = nil
    }

    // MARK: - Private Methods

    /// Runs 'which' command for a tool
    /// - Parameter tool: Name of the tool to find
    /// - Returns: Path to the tool if found, nil otherwise
    private func runWhich(tool: String) async -> String? {
        // First, try common known paths directly (for NVM, Homebrew, etc.)
        if let directPath = findToolDirectly(tool: tool) {
            return directPath
        }

        // Fall back to which command with enhanced PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whichPath)
        process.arguments = [tool]

        // Inherit environment and enhance PATH to include common locations
        var env = Foundation.ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let additionalPaths = [
            "\(home)/.nvm/versions/node/v20.19.4/bin",
            "\(home)/.nvm/versions/node/v22.0.0/bin",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin"
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = additionalPaths.joined(separator: ":") + ":" + currentPath
        process.environment = env

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else {
                return nil
            }

            return path
        } catch {
            return nil
        }
    }

    /// Searches for tool in common installation paths directly
    /// - Parameter tool: Name of the tool to find
    /// - Returns: Path to the tool if found, nil otherwise
    private func findToolDirectly(tool: String) -> String? {
        let fileManager = FileManager.default
        let home = NSHomeDirectory()

        // Common paths for CLI tools
        let searchPaths: [String] = [
            // NVM (Node-based CLIs like claude)
            "\(home)/.nvm/versions/node/v20.19.4/bin/\(tool)",
            "\(home)/.nvm/versions/node/v22.0.0/bin/\(tool)",
            "\(home)/.nvm/versions/node/v21.0.0/bin/\(tool)",
            "\(home)/.nvm/versions/node/v18.0.0/bin/\(tool)",
            // Homebrew
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            // System
            "/usr/bin/\(tool)",
            // Local
            "\(home)/.local/bin/\(tool)",
            "\(home)/bin/\(tool)"
        ]

        for path in searchPaths {
            if fileManager.fileExists(atPath: path) {
                // Verify it's executable
                if fileManager.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        return nil
    }

    /// Gets version of a tool if available
    /// - Parameters:
    ///   - path: Path to the executable
    ///   - versionFlag: Flag to get version (default: --version)
    /// - Returns: Version string if available
    private func getVersion(path: String, versionFlag: String = "--version") async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = [versionFlag]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                return nil
            }

            // Extract first line which usually contains version
            let firstLine = output.components(separatedBy: .newlines).first ?? output
            return firstLine
        } catch {
            return nil
        }
    }

    /// Performs full check for a single tool
    /// - Parameter name: Name of the tool
    /// - Returns: ConfigCheckResult with details
    private func checkTool(name: String) async -> ConfigCheckResult {
        guard let path = await runWhich(tool: name) else {
            return .unavailable(tool: name, error: "Not found in PATH")
        }

        let version = await getVersion(path: path)
        return .available(tool: name, path: path, version: version)
    }
}
