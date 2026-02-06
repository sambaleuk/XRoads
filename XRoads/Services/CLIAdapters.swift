import Foundation

// MARK: - CLIAdapterError

/// Errors that can occur during CLI adapter operations
enum CLIAdapterError: Error, LocalizedError, Sendable {
    case executableNotFound(cli: String, path: String)
    case processNotRunning
    case launchFailed(reason: String)
    case sendCommandFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let cli, let path):
            return "\(cli) CLI not found at: \(path)"
        case .processNotRunning:
            return "CLI process is not running"
        case .launchFailed(let reason):
            return "Failed to launch CLI: \(reason)"
        case .sendCommandFailed(let reason):
            return "Failed to send command: \(reason)"
        }
    }
}

// MARK: - CLIAdapter Protocol

/// Protocol for CLI adapter implementations
/// Each adapter handles the specific configuration and arguments for its CLI
protocol CLIAdapter: Sendable {
    /// The type of CLI this adapter handles
    var cliType: AgentType { get }

    /// Path to the CLI executable
    var executablePath: String { get }

    /// Display name for the CLI
    var displayName: String { get }

    /// Checks if the CLI executable exists at the configured path
    func isAvailable() -> Bool

    /// Returns the arguments to launch the CLI for a given worktree
    /// - Parameter worktreePath: Path to the git worktree directory
    /// - Returns: Array of command-line arguments
    func launchArguments(worktreePath: String) -> [String]

    /// Returns the arguments to send a command/prompt to the CLI
    /// - Parameter command: The command or prompt to send
    /// - Returns: Formatted command string for stdin
    func formatCommand(_ command: String) -> String
}

// MARK: - Default Implementation

extension CLIAdapter {
    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: executablePath)
    }

    func formatCommand(_ command: String) -> String {
        // Default: just pass the command as-is with newline
        command.hasSuffix("\n") ? command : command + "\n"
    }
}

// MARK: - ClaudeAdapter

/// Adapter for Claude Code CLI
struct ClaudeAdapter: CLIAdapter {
    let cliType: AgentType = .claude

    /// Configurable path, auto-detected or custom
    var executablePath: String

    /// Optional conversation ID for `--resume` support (context handoff)
    var resumeConversationId: String?

    var displayName: String { "Claude Code" }

    init(executablePath: String? = nil, resumeConversationId: String? = nil) {
        self.executablePath = executablePath ?? Self.detectClaudePath()
        self.resumeConversationId = resumeConversationId
    }

    /// Attempts to find claude CLI in common locations
    private static func detectClaudePath() -> String {
        let possiblePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.nvm/versions/node/v20.19.4/bin/claude",
            "\(NSHomeDirectory())/.nvm/versions/node/v22.0.0/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback: try to find via shell
        if let path = try? shellWhich("claude") {
            return path
        }

        return "/usr/local/bin/claude"
    }

    /// Uses shell to find executable
    private static func shellWhich(_ command: String) throws -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(command)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    func launchArguments(worktreePath: String) -> [String] {
        // Claude Code CLI in interactive mode
        // Working directory is set by ProcessRunner
        var args: [String] = []

        // If we have a conversation ID from a previous session, resume it
        if let conversationId = resumeConversationId, !conversationId.isEmpty {
            args.append(contentsOf: ["--resume", conversationId])
        }

        return args
    }

    func formatCommand(_ command: String) -> String {
        // Claude accepts prompts directly via stdin
        command.hasSuffix("\n") ? command : command + "\n"
    }
}

// MARK: - GeminiAdapter

/// Adapter for Gemini CLI
struct GeminiAdapter: CLIAdapter {
    let cliType: AgentType = .gemini

    /// Configurable path, auto-detected or custom
    var executablePath: String

    var displayName: String { "Gemini CLI" }

    init(executablePath: String? = nil) {
        self.executablePath = executablePath ?? Self.detectGeminiPath()
    }

    /// Attempts to find gemini CLI in common locations
    private static func detectGeminiPath() -> String {
        let possiblePaths = [
            "/opt/homebrew/bin/gemini",
            "/usr/local/bin/gemini",
            "\(NSHomeDirectory())/.local/bin/gemini",
            "\(NSHomeDirectory())/.nvm/versions/node/v20.19.4/bin/gemini",
            "\(NSHomeDirectory())/.nvm/versions/node/v22.0.0/bin/gemini"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback: try to find via shell
        if let path = try? shellWhich("gemini") {
            return path
        }

        return "/opt/homebrew/bin/gemini"
    }

    /// Uses shell to find executable
    private static func shellWhich(_ command: String) throws -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(command)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    func launchArguments(worktreePath: String) -> [String] {
        // Gemini CLI in interactive mode
        // Working directory is set by ProcessRunner
        // Sandbox mode is controlled by ~/.gemini/settings.json, not CLI flags
        return []  // No flags needed for interactive mode
    }

    func formatCommand(_ command: String) -> String {
        // Gemini accepts prompts directly
        command.hasSuffix("\n") ? command : command + "\n"
    }
}

// MARK: - CodexAdapter

/// Adapter for OpenAI Codex CLI
struct CodexAdapter: CLIAdapter {
    let cliType: AgentType = .codex

    /// Configurable path, auto-detected or custom
    var executablePath: String

    var displayName: String { "Codex" }

    init(executablePath: String? = nil) {
        self.executablePath = executablePath ?? Self.detectCodexPath()
    }

    /// Attempts to find codex CLI in common locations
    private static func detectCodexPath() -> String {
        let possiblePaths = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(NSHomeDirectory())/.nvm/versions/node/v20.19.4/bin/codex",
            "\(NSHomeDirectory())/.nvm/versions/node/v22.0.0/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex",
            "\(NSHomeDirectory())/bin/codex"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback: try to find via shell
        if let path = try? shellWhich("codex") {
            return path
        }

        return "/usr/local/bin/codex"
    }

    /// Uses shell to find executable
    private static func shellWhich(_ command: String) throws -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(command)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    func launchArguments(worktreePath: String) -> [String] {
        // Codex CLI in interactive mode
        // Working directory is set by ProcessRunner
        // Note: codex uses --full-auto not --approval-mode
        return [
            "--full-auto"  // Approve all changes automatically
        ]
    }

    func formatCommand(_ command: String) -> String {
        // Codex accepts prompts directly
        command.hasSuffix("\n") ? command : command + "\n"
    }
}

// MARK: - CLIType Factory

extension AgentType {
    /// Creates the appropriate CLI adapter for this agent type
    /// - Parameters:
    ///   - customPath: Optional custom executable path
    ///   - resumeConversationId: Optional conversation ID for Claude Code `--resume`
    /// - Returns: A CLIAdapter configured for this agent type
    func adapter(customPath: String? = nil, resumeConversationId: String? = nil) -> any CLIAdapter {
        switch self {
        case .claude:
            return ClaudeAdapter(
                executablePath: customPath,
                resumeConversationId: resumeConversationId
            )

        case .gemini:
            if let path = customPath {
                return GeminiAdapter(executablePath: path)
            }
            return GeminiAdapter()

        case .codex:
            if let path = customPath {
                return CodexAdapter(executablePath: path)
            }
            return CodexAdapter()
        }
    }

    /// Default executable path for this agent type (used as fallback)
    var defaultExecutablePath: String {
        switch self {
        case .claude: return ClaudeAdapter().executablePath
        case .gemini: return GeminiAdapter().executablePath
        case .codex: return CodexAdapter().executablePath
        }
    }
}

// MARK: - CLIAdapterRegistry

/// Registry for managing CLI adapters with custom configurations
struct CLIAdapterRegistry: Sendable {
    /// Custom paths for CLIs (persisted in settings)
    private var customPaths: [AgentType: String]

    init(customPaths: [AgentType: String] = [:]) {
        self.customPaths = customPaths
    }

    /// Gets an adapter for the specified agent type
    /// - Parameter type: The agent type
    /// - Returns: Configured CLI adapter
    func adapter(for type: AgentType) -> any CLIAdapter {
        type.adapter(customPath: customPaths[type])
    }

    /// Updates the custom path for a CLI
    /// - Parameters:
    ///   - type: The agent type
    ///   - path: The custom executable path
    mutating func setCustomPath(_ path: String?, for type: AgentType) {
        if let path = path {
            customPaths[type] = path
        } else {
            customPaths.removeValue(forKey: type)
        }
    }

    /// Gets the custom path for a CLI if set
    /// - Parameter type: The agent type
    /// - Returns: Custom path or nil if using default
    func customPath(for type: AgentType) -> String? {
        customPaths[type]
    }

    /// Checks which CLIs are available on this system
    /// - Returns: Dictionary of agent types to availability status
    func checkAvailability() -> [AgentType: Bool] {
        var result: [AgentType: Bool] = [:]
        for type in AgentType.allCases {
            result[type] = adapter(for: type).isAvailable()
        }
        return result
    }
}
