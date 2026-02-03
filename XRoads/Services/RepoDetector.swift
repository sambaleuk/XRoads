//
//  RepoDetector.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Service for auto-detecting git repositories and providing quick actions
//

import Foundation

// MARK: - RepoInfo

/// Information about a detected git repository
struct RepoInfo: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let path: String
    let name: String
    let branch: String
    let lastAccessedAt: Date

    var displayName: String {
        name.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : name
    }

    init(
        id: UUID = UUID(),
        path: String,
        name: String = "",
        branch: String = "main",
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.name = name.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : name
        self.branch = branch
        self.lastAccessedAt = lastAccessedAt
    }
}

// MARK: - RepoDetectorError

/// Errors that can occur during repo detection
enum RepoDetectorError: Error, LocalizedError, Sendable {
    case notAGitRepository(path: String)
    case pathNotFound(path: String)
    case gitCommandFailed(String)
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAGitRepository(let path):
            return "Not a git repository: \(path)"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)"
        case .persistenceFailed(let message):
            return "Failed to persist repo data: \(message)"
        }
    }
}

// MARK: - RepoDetectionResult

/// Result of auto-detecting a repository
struct RepoDetectionResult: Sendable {
    let isGitRepo: Bool
    let repoInfo: RepoInfo?
    let recentRepos: [RepoInfo]

    static let notARepo = RepoDetectionResult(isGitRepo: false, repoInfo: nil, recentRepos: [])
}

// MARK: - RepoDetector Actor

/// Thread-safe service for detecting git repositories and managing recent repos
actor RepoDetector {

    // MARK: - Properties

    private let gitService: GitService
    private let userDefaults: UserDefaults
    private let maxRecentRepos: Int
    private let recentReposKey = "xroads.recentRepos"

    /// Cached recent repositories
    private var recentReposCache: [RepoInfo]?

    // MARK: - Initialization

    init(
        gitService: GitService = GitService(),
        userDefaults: UserDefaults = .standard,
        maxRecentRepos: Int = 10
    ) {
        self.gitService = gitService
        self.userDefaults = userDefaults
        self.maxRecentRepos = maxRecentRepos
    }

    // MARK: - Public Methods

    /// Detects if the current working directory is a git repository
    /// - Returns: RepoDetectionResult with repo info if found
    func detectCurrentDirectory() async -> RepoDetectionResult {
        let cwd = FileManager.default.currentDirectoryPath
        return await detectRepository(at: cwd)
    }

    /// Detects if a given path is a git repository
    /// - Parameter path: Path to check
    /// - Returns: RepoDetectionResult with repo info if found
    func detectRepository(at path: String) async -> RepoDetectionResult {
        let recentRepos = loadRecentRepos()

        // Check if path exists
        guard FileManager.default.fileExists(atPath: path) else {
            return RepoDetectionResult(isGitRepo: false, repoInfo: nil, recentRepos: recentRepos)
        }

        // Try to get repo root
        do {
            let repoRoot = try await gitService.getRepoRoot(path: path)
            let branch = try await gitService.getCurrentBranch(path: repoRoot)

            let repoInfo = RepoInfo(
                path: repoRoot,
                name: URL(fileURLWithPath: repoRoot).lastPathComponent,
                branch: branch,
                lastAccessedAt: Date()
            )

            // Save to recent repos
            await addToRecentRepos(repoInfo)

            return RepoDetectionResult(
                isGitRepo: true,
                repoInfo: repoInfo,
                recentRepos: loadRecentRepos()
            )
        } catch {
            return RepoDetectionResult(isGitRepo: false, repoInfo: nil, recentRepos: recentRepos)
        }
    }

    /// Checks if a path is a git repository without caching
    /// - Parameter path: Path to check
    /// - Returns: True if the path is within a git repository
    func isGitRepository(at path: String) async -> Bool {
        do {
            _ = try await gitService.getRepoRoot(path: path)
            return true
        } catch {
            return false
        }
    }

    /// Gets detailed information about a repository
    /// - Parameter path: Path to the repository
    /// - Returns: RepoInfo if the path is a git repository
    func getRepoInfo(at path: String) async throws -> RepoInfo {
        guard FileManager.default.fileExists(atPath: path) else {
            throw RepoDetectorError.pathNotFound(path: path)
        }

        do {
            let repoRoot = try await gitService.getRepoRoot(path: path)
            let branch = try await gitService.getCurrentBranch(path: repoRoot)

            return RepoInfo(
                path: repoRoot,
                name: URL(fileURLWithPath: repoRoot).lastPathComponent,
                branch: branch,
                lastAccessedAt: Date()
            )
        } catch {
            throw RepoDetectorError.notAGitRepository(path: path)
        }
    }

    // MARK: - Recent Repos Management

    /// Loads recent repositories from persistent storage
    /// - Returns: Array of recently accessed repositories
    func loadRecentRepos() -> [RepoInfo] {
        if let cached = recentReposCache {
            return cached
        }

        guard let data = userDefaults.data(forKey: recentReposKey),
              let repos = try? JSONDecoder().decode([RepoInfo].self, from: data) else {
            return []
        }

        // Filter out repos that no longer exist
        let validRepos = repos.filter { FileManager.default.fileExists(atPath: $0.path) }
        recentReposCache = validRepos
        return validRepos
    }

    /// Adds a repository to the recent list
    /// - Parameter repoInfo: Repository to add
    func addToRecentRepos(_ repoInfo: RepoInfo) async {
        var recentRepos = loadRecentRepos()

        // Remove existing entry for the same path
        recentRepos.removeAll { $0.path == repoInfo.path }

        // Add new entry at the beginning
        recentRepos.insert(repoInfo, at: 0)

        // Limit to max recent repos
        if recentRepos.count > maxRecentRepos {
            recentRepos = Array(recentRepos.prefix(maxRecentRepos))
        }

        // Save to persistent storage
        saveRecentRepos(recentRepos)
    }

    /// Removes a repository from the recent list
    /// - Parameter path: Path of the repository to remove
    func removeFromRecentRepos(path: String) {
        var recentRepos = loadRecentRepos()
        recentRepos.removeAll { $0.path == path }
        saveRecentRepos(recentRepos)
    }

    /// Clears all recent repositories
    func clearRecentRepos() {
        recentReposCache = []
        userDefaults.removeObject(forKey: recentReposKey)
    }

    /// Gets the last used repository
    /// - Returns: Most recently accessed repository, if any
    func getLastUsedRepo() -> RepoInfo? {
        loadRecentRepos().first
    }

    // MARK: - Quick Action Helpers

    /// Generates a worktree branch name based on the action type
    /// - Parameters:
    ///   - actionType: The action type (implement, review, etc.)
    ///   - baseName: Base name for the branch (e.g., feature name)
    /// - Returns: Generated branch name
    func generateBranchName(for actionType: ActionType, baseName: String) -> String {
        let sanitized = baseName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        let prefix: String
        switch actionType {
        case .implement:
            prefix = "feat"
        case .review:
            prefix = "review"
        case .integrationTest:
            prefix = "test"
        case .write:
            prefix = "docs"
        case .custom:
            prefix = "task"
        }

        let timestamp = Int(Date().timeIntervalSince1970) % 10000
        return "\(prefix)/\(sanitized)-\(timestamp)"
    }

    /// Generates a deterministic worktree path
    /// - Parameters:
    ///   - repoPath: Path to the main repository
    ///   - branchName: Branch name for the worktree
    /// - Returns: Path for the new worktree
    func generateWorktreePath(repoPath: String, branchName: String) -> String {
        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
        let sanitizedBranch = branchName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")

        let xroadsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".xroads")
            .appendingPathComponent("worktrees")
            .appendingPathComponent(repoName)
            .appendingPathComponent(sanitizedBranch)

        return xroadsDir.path
    }

    // MARK: - Private Helpers

    private func saveRecentRepos(_ repos: [RepoInfo]) {
        recentReposCache = repos

        guard let data = try? JSONEncoder().encode(repos) else {
            return
        }

        userDefaults.set(data, forKey: recentReposKey)
    }
}

// MARK: - Shared Instance

extension RepoDetector {
    /// Shared instance for app-wide access
    static let shared = RepoDetector()
}
