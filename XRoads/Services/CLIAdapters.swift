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

    /// Configurable path, defaults to standard installation location
    var executablePath: String

    var displayName: String { "Claude Code" }

    init(executablePath: String = "/usr/local/bin/claude") {
        self.executablePath = executablePath
    }

    func launchArguments(worktreePath: String) -> [String] {
        // Claude Code CLI typically uses interactive mode
        // --cwd sets the working directory
        return [
            "--cwd", worktreePath,
            "--dangerously-skip-permissions"  // Skip permission prompts for automation
        ]
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

    /// Configurable path, defaults to standard installation location
    var executablePath: String

    var displayName: String { "Gemini CLI" }

    init(executablePath: String = "/usr/local/bin/gemini") {
        self.executablePath = executablePath
    }

    func launchArguments(worktreePath: String) -> [String] {
        // Gemini CLI arguments for interactive mode with sandbox disabled
        return [
            "--sandbox=false",  // Allow file system access
            "--directory", worktreePath
        ]
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

    /// Configurable path, defaults to standard installation location
    var executablePath: String

    var displayName: String { "Codex" }

    init(executablePath: String = "/usr/local/bin/codex") {
        self.executablePath = executablePath
    }

    func launchArguments(worktreePath: String) -> [String] {
        // Codex CLI arguments
        // Uses approval mode to handle file changes
        return [
            "--approval-mode", "full-auto",  // Approve all changes automatically
            "--cwd", worktreePath
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
    /// - Parameter customPath: Optional custom executable path
    /// - Returns: A CLIAdapter configured for this agent type
    func adapter(customPath: String? = nil) -> any CLIAdapter {
        switch self {
        case .claude:
            if let path = customPath {
                return ClaudeAdapter(executablePath: path)
            }
            return ClaudeAdapter()

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

    /// Default executable path for this agent type
    var defaultExecutablePath: String {
        switch self {
        case .claude: return "/usr/local/bin/claude"
        case .gemini: return "/usr/local/bin/gemini"
        case .codex: return "/usr/local/bin/codex"
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
