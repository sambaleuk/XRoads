import Foundation
import os

// MARK: - ProjectContextReaderError

enum ProjectContextReaderError: LocalizedError, Sendable {
    case invalidProjectPath(String)
    case notAGitRepository(String)
    case prdParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProjectPath(let path):
            return "Project path does not exist: \(path)"
        case .notAGitRepository(let path):
            return "Not a git repository: \(path)"
        case .prdParsingFailed(let reason):
            return "Failed to parse PRD: \(reason)"
        }
    }
}

// MARK: - ProjectContextReader

/// Reads project context (git log, PRD, branches, last session) and packages it
/// as ChairmanInput for cockpit-council Chairman deliberation.
///
/// Maps to CockpitLifecycle.activate action: read_project_context
actor ProjectContextReader {

    private let logger = Logger(subsystem: "com.xroads", category: "ContextReader")
    private let gitService: GitService
    private let repository: CockpitSessionRepository

    init(gitService: GitService, repository: CockpitSessionRepository) {
        self.gitService = gitService
        self.repository = repository
    }

    // MARK: - Guard: has_valid_project

    /// Validates the has_valid_project guard from CockpitLifecycle.
    /// Returns true if the path exists and is a git repository.
    func hasValidProject(at path: String) async -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }
        return await gitService.isGitRepository(path: path)
    }

    // MARK: - Read Context

    /// Reads the full project context and packages it as ChairmanInput.
    /// - Parameter projectPath: Path to the project directory (must be a valid git repo)
    /// - Throws: ProjectContextReaderError if the project is invalid
    /// - Returns: ChairmanInput ready for Chairman deliberation
    func readContext(projectPath: String) async throws -> ChairmanInput {
        // Validate project path
        guard FileManager.default.fileExists(atPath: projectPath) else {
            throw ProjectContextReaderError.invalidProjectPath(projectPath)
        }

        guard await gitService.isGitRepository(path: projectPath) else {
            throw ProjectContextReaderError.notAGitRepository(projectPath)
        }

        let path = projectPath
        logger.info("Reading project context at \(path, privacy: .public)")

        // Read all context in parallel
        async let gitLog = readGitLog(projectPath: projectPath)
        async let branches = readOpenBranches(projectPath: projectPath)
        async let prd = readPRDSummary(projectPath: projectPath)
        async let lastSession = readLastSession(projectPath: projectPath)

        return try await ChairmanInput(
            gitLog: gitLog,
            prdSummary: prd,
            openBranches: branches,
            lastSession: lastSession,
            projectPath: projectPath,
            collectedAt: Date()
        )
    }

    // MARK: - Private Readers

    /// Reads the last 20 commits from git log
    private func readGitLog(projectPath: String) async throws -> [GitLogEntry] {
        let commits = try await gitService.getRecentCommits(path: projectPath, count: 20)
        return commits.map { commit in
            GitLogEntry(
                sha: commit.sha,
                shortSha: commit.shortSha,
                message: commit.message,
                author: commit.author,
                date: commit.date
            )
        }
    }

    /// Reads open branches (excluding HEAD detached states)
    private func readOpenBranches(projectPath: String) async throws -> [String] {
        let output = try await runGitCommand(
            arguments: ["branch", "--format=%(refname:short)"],
            at: projectPath
        )
        return output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Reads and summarizes the active PRD JSON if present
    private func readPRDSummary(projectPath: String) async -> PRDSummary? {
        let prdPath = (projectPath as NSString).appendingPathComponent("prd.json")
        guard FileManager.default.fileExists(atPath: prdPath),
              let data = FileManager.default.contents(atPath: prdPath) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json else { return nil }

            let featureName = json["feature_name"] as? String ?? "Unknown"
            let status = json["status"] as? String ?? "unknown"
            let branch = json["branch"] as? String

            let stories = json["user_stories"] as? [[String: Any]] ?? []
            let totalStories = stories.count
            let completedStories = stories.filter { ($0["status"] as? String) == "complete" }.count
            let pendingStories = totalStories - completedStories

            return PRDSummary(
                featureName: featureName,
                status: status,
                branch: branch,
                totalStories: totalStories,
                pendingStories: pendingStories,
                completedStories: completedStories
            )
        } catch {
            logger.warning("Failed to parse PRD at \(prdPath, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }

    /// Reads the most recent cockpit session for this project
    private func readLastSession(projectPath: String) async -> LastSessionInfo? {
        do {
            // Check all sessions (including closed) for this project
            let sessions = try await repository.fetchAllSessions()
            let projectSessions = sessions.filter { $0.projectPath == projectPath }

            guard let last = projectSessions.first else { return nil }

            return LastSessionInfo(
                sessionId: last.id,
                status: last.status.rawValue,
                chairmanBrief: last.chairmanBrief,
                createdAt: last.createdAt
            )
        } catch {
            logger.warning("Failed to read last session: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Git Helper

    /// Runs a raw git command (for operations not in GitService)
    private func runGitCommand(arguments: [String], at path: String) async throws -> String {
        let gitPath = "/usr/bin/git"
        guard FileManager.default.fileExists(atPath: gitPath) else {
            throw ProjectContextReaderError.invalidProjectPath(path)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gitPath)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: path)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ProjectContextReaderError.notAGitRepository(path))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ProjectContextReaderError.invalidProjectPath(path))
            }
        }
    }
}
