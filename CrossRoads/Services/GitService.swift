import Foundation

// MARK: - GitError

/// Errors that can occur during Git operations
enum GitError: Error, LocalizedError, Sendable {
    case gitNotFound
    case notARepository(path: String)
    case worktreeAlreadyExists(path: String)
    case worktreeNotFound(path: String)
    case branchNotFound(branch: String)
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case invalidOutput(command: String)
    case pathNotFound(path: String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "Git executable not found at /usr/bin/git"
        case .notARepository(let path):
            return "Not a git repository: \(path)"
        case .worktreeAlreadyExists(let path):
            return "Worktree already exists at: \(path)"
        case .worktreeNotFound(let path):
            return "Worktree not found at: \(path)"
        case .branchNotFound(let branch):
            return "Branch not found: \(branch)"
        case .commandFailed(let command, let exitCode, let stderr):
            return "Git command '\(command)' failed with exit code \(exitCode): \(stderr)"
        case .invalidOutput(let command):
            return "Invalid output from git command: \(command)"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        }
    }
}

// MARK: - GitService Actor

/// Thread-safe service for Git operations using Swift actors
actor GitService {

    private let gitPath: String

    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    // MARK: - Worktree Operations

    /// Creates a new worktree at the specified path
    /// - Parameters:
    ///   - repoPath: Path to the main repository
    ///   - branch: Branch name for the new worktree
    ///   - worktreePath: Path where the worktree will be created
    /// - Throws: GitError if the operation fails
    func createWorktree(repoPath: String, branch: String, worktreePath: String) async throws {
        // Verify repo exists
        guard FileManager.default.fileExists(atPath: repoPath) else {
            throw GitError.pathNotFound(path: repoPath)
        }

        // Check if worktree path already exists
        if FileManager.default.fileExists(atPath: worktreePath) {
            throw GitError.worktreeAlreadyExists(path: worktreePath)
        }

        // Create worktree with new branch
        try await runGit(
            arguments: ["worktree", "add", "-b", branch, worktreePath],
            currentDirectory: repoPath
        )
    }

    /// Lists all worktrees in the repository
    /// - Parameter repoPath: Path to the main repository
    /// - Returns: Array of worktree paths
    /// - Throws: GitError if the operation fails
    func listWorktrees(repoPath: String) async throws -> [String] {
        guard FileManager.default.fileExists(atPath: repoPath) else {
            throw GitError.pathNotFound(path: repoPath)
        }

        let output = try await runGit(
            arguments: ["worktree", "list", "--porcelain"],
            currentDirectory: repoPath
        )

        // Parse porcelain output - each worktree starts with "worktree <path>"
        var worktrees: [String] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            if line.hasPrefix("worktree ") {
                let path = String(line.dropFirst("worktree ".count))
                worktrees.append(path)
            }
        }

        return worktrees
    }

    /// Removes a worktree
    /// - Parameters:
    ///   - repoPath: Path to the main repository
    ///   - worktreePath: Path of the worktree to remove
    /// - Throws: GitError if the operation fails
    func removeWorktree(repoPath: String, worktreePath: String) async throws {
        guard FileManager.default.fileExists(atPath: repoPath) else {
            throw GitError.pathNotFound(path: repoPath)
        }

        // Verify worktree exists
        let worktrees = try await listWorktrees(repoPath: repoPath)
        guard worktrees.contains(worktreePath) else {
            throw GitError.worktreeNotFound(path: worktreePath)
        }

        // Remove worktree (--force removes even if there are changes)
        try await runGit(
            arguments: ["worktree", "remove", worktreePath, "--force"],
            currentDirectory: repoPath
        )
    }

    // MARK: - Branch Operations

    /// Gets the current branch name for a path
    /// - Parameter path: Path to repository or worktree
    /// - Returns: Current branch name
    /// - Throws: GitError if the operation fails
    func getCurrentBranch(path: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: path) else {
            throw GitError.pathNotFound(path: path)
        }

        let output = try await runGit(
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            currentDirectory: path
        )

        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !branch.isEmpty else {
            throw GitError.invalidOutput(command: "rev-parse --abbrev-ref HEAD")
        }

        return branch
    }

    // MARK: - Commit Operations

    /// Gets the last commit SHA and message
    /// - Parameter path: Path to repository or worktree
    /// - Returns: Tuple with SHA and message
    /// - Throws: GitError if the operation fails
    func getLastCommit(path: String) async throws -> (sha: String, message: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            throw GitError.pathNotFound(path: path)
        }

        // Get short SHA
        let shaOutput = try await runGit(
            arguments: ["rev-parse", "--short", "HEAD"],
            currentDirectory: path
        )
        let sha = shaOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Get commit message (first line only)
        let messageOutput = try await runGit(
            arguments: ["log", "-1", "--format=%s"],
            currentDirectory: path
        )
        let message = messageOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sha.isEmpty else {
            throw GitError.invalidOutput(command: "rev-parse --short HEAD")
        }

        return (sha: sha, message: message)
    }

    // MARK: - Private Helpers

    /// Runs a git command and returns the output
    @discardableResult
    private func runGit(arguments: [String], currentDirectory: String) async throws -> String {
        // Verify git exists
        guard FileManager.default.fileExists(atPath: gitPath) else {
            throw GitError.gitNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw GitError.commandFailed(
                command: "git \(arguments.joined(separator: " "))",
                exitCode: -1,
                stderr: error.localizedDescription
            )
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            // Check for specific error cases
            if stderr.contains("not a git repository") {
                throw GitError.notARepository(path: currentDirectory)
            }

            throw GitError.commandFailed(
                command: "git \(arguments.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: stderr
            )
        }

        return stdout
    }
}
