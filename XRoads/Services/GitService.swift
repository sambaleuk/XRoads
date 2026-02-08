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

    /// When true, all git operations are no-ops returning mock values.
    /// Used by MockServiceContainer to prevent real I/O in tests and previews.
    let testMode: Bool

    init(gitPath: String = "/usr/bin/git", testMode: Bool = false) {
        self.gitPath = gitPath
        self.testMode = testMode
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

    // MARK: - Merge Operations

    /// Checks out the specified branch in the repository
    func checkout(branch: String, repoPath: String) async throws {
        try await runGit(arguments: ["checkout", branch], currentDirectory: repoPath)
    }

    /// Performs a git merge with optional flags
    func merge(
        branch: String,
        repoPath: String,
        noCommit: Bool = false,
        noFastForward: Bool = true
    ) async throws {
        var arguments = ["merge"]
        if noCommit { arguments.append("--no-commit") }
        if noFastForward { arguments.append("--no-ff") }
        arguments.append(branch)
        try await runGit(arguments: arguments, currentDirectory: repoPath)
    }

    /// Aborts the current merge operation
    func abortMerge(repoPath: String) async throws {
        try await runGit(arguments: ["merge", "--abort"], currentDirectory: repoPath)
    }

    /// Performs a hard reset to the specified reference (default HEAD)
    func resetHard(repoPath: String, reference: String = "HEAD") async throws {
        try await runGit(arguments: ["reset", "--hard", reference], currentDirectory: repoPath)
    }

    /// Checks if a local branch exists
    func branchExists(name: String, repoPath: String) async -> Bool {
        if testMode { return false }
        do {
            let output = try await runGit(
                arguments: ["branch", "--list", name],
                currentDirectory: repoPath
            )
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    /// Deletes a local branch
    func deleteBranch(name: String, repoPath: String, force: Bool = false) async throws {
        let flag = force ? "-D" : "-d"
        try await runGit(arguments: ["branch", flag, name], currentDirectory: repoPath)
    }

    /// Creates a worktree from an existing branch (without -b flag)
    func addWorktreeFromBranch(repoPath: String, branch: String, worktreePath: String) async throws {
        try await runGit(
            arguments: ["worktree", "add", worktreePath, branch],
            currentDirectory: repoPath
        )
    }

    /// Prunes stale worktree entries (e.g. after manual deletion of worktree directories)
    func pruneWorktrees(repoPath: String) async throws {
        try await runGit(arguments: ["worktree", "prune"], currentDirectory: repoPath)
    }

    /// Lists files currently in conflict
    func listConflictedFiles(repoPath: String) async throws -> [String] {
        let output = try await runGit(
            arguments: ["diff", "--name-only", "--diff-filter=U"],
            currentDirectory: repoPath
        )
        return output
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Applies the specified version of a conflicted file (ours/theirs)
    func resolveConflict(
        repoPath: String,
        file: String,
        keepOurs: Bool
    ) async throws {
        let flag = keepOurs ? "--ours" : "--theirs"
        try await runGit(
            arguments: ["checkout", flag, "--", file],
            currentDirectory: repoPath
        )
    }

    /// Stages a file (marks conflict as resolved)
    func stageFile(repoPath: String, file: String) async throws {
        try await runGit(arguments: ["add", file], currentDirectory: repoPath)
    }

    // MARK: - Repository Initialization

    /// Initializes a new git repository at the specified path
    /// - Parameter path: Path where the repository should be created
    /// - Throws: GitError if the operation fails
    func initializeRepository(path: String) async throws {
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Initialize the repository
        try await runGit(arguments: ["init"], currentDirectory: path)

        // Create initial commit with .gitkeep
        let gitkeepPath = (path as NSString).appendingPathComponent(".gitkeep")
        FileManager.default.createFile(atPath: gitkeepPath, contents: nil, attributes: nil)

        try await runGit(arguments: ["add", ".gitkeep"], currentDirectory: path)
        try await runGit(
            arguments: ["commit", "-m", "Initial commit"],
            currentDirectory: path
        )
    }

    /// Checks if a path is inside a git repository
    /// - Parameter path: Path to check
    /// - Returns: true if the path is in a git repository
    func isGitRepository(path: String) async -> Bool {
        do {
            _ = try await runGit(
                arguments: ["rev-parse", "--is-inside-work-tree"],
                currentDirectory: path
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - Quick Start / Dashboard Operations

    /// Information about a commit for display
    struct CommitInfo: Sendable, Identifiable {
        let sha: String
        let shortSha: String
        let message: String
        let author: String
        let date: Date
        let relativeDate: String

        var id: String { sha }
    }

    /// Information about a remote
    struct RemoteInfo: Sendable, Identifiable {
        let name: String
        let fetchURL: String
        let pushURL: String

        var id: String { name }
    }

    /// Ahead/behind tracking info
    struct TrackingInfo: Sendable {
        let ahead: Int
        let behind: Int
        let remoteBranch: String?
    }

    /// Gets recent commits for the repository
    /// - Parameters:
    ///   - path: Path to repository or worktree
    ///   - count: Number of commits to fetch (default 10)
    /// - Returns: Array of CommitInfo
    func getRecentCommits(path: String, count: Int = 10) async throws -> [CommitInfo] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw GitError.pathNotFound(path: path)
        }

        // Format: sha|shortSha|message|author|timestamp|relativeDate
        let output = try await runGit(
            arguments: [
                "log",
                "-\(count)",
                "--format=%H|%h|%s|%an|%ct|%cr"
            ],
            currentDirectory: path
        )

        var commits: [CommitInfo] = []
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 6 else { continue }

            let timestamp = TimeInterval(parts[4]) ?? 0
            let date = Date(timeIntervalSince1970: timestamp)

            commits.append(CommitInfo(
                sha: parts[0],
                shortSha: parts[1],
                message: parts[2],
                author: parts[3],
                date: date,
                relativeDate: parts[5]
            ))
        }

        return commits
    }

    /// Gets all configured remotes
    /// - Parameter path: Path to repository
    /// - Returns: Array of RemoteInfo
    func getRemotes(path: String) async throws -> [RemoteInfo] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw GitError.pathNotFound(path: path)
        }

        let output = try await runGit(
            arguments: ["remote", "-v"],
            currentDirectory: path
        )

        var remotes: [String: (fetch: String, push: String)] = [:]
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        for line in lines {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count >= 2 else { continue }

            let name = String(parts[0])
            let urlAndType = String(parts[1])

            if urlAndType.hasSuffix("(fetch)") {
                let url = urlAndType.replacingOccurrences(of: " (fetch)", with: "")
                remotes[name, default: (fetch: "", push: "")].fetch = url
            } else if urlAndType.hasSuffix("(push)") {
                let url = urlAndType.replacingOccurrences(of: " (push)", with: "")
                remotes[name, default: (fetch: "", push: "")].push = url
            }
        }

        return remotes.map { RemoteInfo(name: $0.key, fetchURL: $0.value.fetch, pushURL: $0.value.push) }
            .sorted { $0.name < $1.name }
    }

    /// Gets tracking info (ahead/behind) for current branch
    /// - Parameter path: Path to repository
    /// - Returns: TrackingInfo with ahead/behind counts
    func getTrackingInfo(path: String) async throws -> TrackingInfo {
        guard FileManager.default.fileExists(atPath: path) else {
            throw GitError.pathNotFound(path: path)
        }

        // Get upstream branch
        let upstreamOutput = try? await runGit(
            arguments: ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            currentDirectory: path
        )
        let remoteBranch = upstreamOutput?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let remote = remoteBranch, !remote.isEmpty else {
            return TrackingInfo(ahead: 0, behind: 0, remoteBranch: nil)
        }

        // Get ahead/behind counts
        let countOutput = try await runGit(
            arguments: ["rev-list", "--left-right", "--count", "HEAD...@{u}"],
            currentDirectory: path
        )

        let counts = countOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\t")
            .compactMap { Int($0) }

        let ahead = counts.first ?? 0
        let behind = counts.count > 1 ? counts[1] : 0

        return TrackingInfo(ahead: ahead, behind: behind, remoteBranch: remote)
    }

    /// Gets the repository root path
    /// - Parameter path: Any path within the repository
    /// - Returns: Root path of the repository
    func getRepoRoot(path: String) async throws -> String {
        let output = try await runGit(
            arguments: ["rev-parse", "--show-toplevel"],
            currentDirectory: path
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fetches from all remotes
    /// - Parameter path: Path to repository
    func fetchAll(path: String) async throws {
        try await runGit(arguments: ["fetch", "--all"], currentDirectory: path)
    }

    /// Pulls current branch
    /// - Parameter path: Path to repository
    func pull(path: String) async throws {
        try await runGit(arguments: ["pull"], currentDirectory: path)
    }

    // MARK: - Private Helpers

    /// Runs a git command and returns the output
    /// Uses async/await to avoid blocking the actor
    @discardableResult
    private func runGit(arguments: [String], currentDirectory: String) async throws -> String {
        // In test mode, return empty string without running any git command
        if testMode { return "" }

        // Verify git exists
        guard FileManager.default.fileExists(atPath: gitPath) else {
            throw GitError.gitNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gitPath)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Setup termination handler to resume continuation
            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: stdout)
                } else {
                    // Check for specific error cases
                    if stderr.contains("not a git repository") {
                        continuation.resume(throwing: GitError.notARepository(path: currentDirectory))
                    } else {
                        continuation.resume(throwing: GitError.commandFailed(
                            command: "git \(arguments.joined(separator: " "))",
                            exitCode: proc.terminationStatus,
                            stderr: stderr
                        ))
                    }
                }
            }

            // Launch the process
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GitError.commandFailed(
                    command: "git \(arguments.joined(separator: " "))",
                    exitCode: -1,
                    stderr: error.localizedDescription
                ))
            }
        }
    }
}
