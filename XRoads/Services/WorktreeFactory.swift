import Foundation
import CryptoKit

struct WorktreeFactory {
    private let gitService: GitService
    private let notesService: NotesSyncService
    private let fileManager: FileManager = .default

    init(gitService: GitService, notesService: NotesSyncService = NotesSyncService()) {
        self.gitService = gitService
        self.notesService = notesService
    }

    func createWorktreesForTasks(
        taskGroups: [TaskGroup],
        repoPath: URL
    ) async throws -> [WorktreeAssignment] {
        try ensureBaseDirectories(for: repoPath)
        try await cleanupOrphanWorktrees(for: repoPath)

        var assignments: [WorktreeAssignment] = []
        for group in taskGroups {
            let branchName = branchName(for: group)
            let worktreePath = WorktreePathBuilder.worktreePath(for: repoPath, branchName: branchName)

            try ensureParentDirectoryExists(for: worktreePath)
            try await gitService.createWorktree(
                repoPath: repoPath.path,
                branch: branchName,
                worktreePath: worktreePath.path
            )

            let assignment = WorktreeAssignment(
                id: UUID(),
                taskGroup: group,
                agentType: group.preferredAgent,
                branchName: branchName,
                worktreePath: worktreePath
            )

            try notesService.syncNotesToWorktree(repoPath: repoPath, assignment: assignment)

            assignments.append(assignment)
        }

        return assignments
    }

    // MARK: - Helpers

    private func ensureBaseDirectories(for repoPath: URL) throws {
        let base = WorktreePathBuilder.repoDirectory(for: repoPath)
        if !fileManager.fileExists(atPath: base.path) {
            try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }
    }

    private func ensureParentDirectoryExists(for worktreePath: URL) throws {
        let parent = worktreePath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
    }

    private func cleanupOrphanWorktrees(for repoPath: URL) async throws {
        let repoDir = WorktreePathBuilder.repoDirectory(for: repoPath)
        guard fileManager.fileExists(atPath: repoDir.path) else { return }

        let gitWorktrees = try await gitService.listWorktrees(repoPath: repoPath.path)
        let trackedPaths = Set(gitWorktrees.map { URL(fileURLWithPath: $0).standardizedFileURL.path })

        let directories = try fileManager.contentsOfDirectory(
            at: repoDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for directory in directories {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            if !trackedPaths.contains(directory.standardizedFileURL.path) {
                try? fileManager.removeItem(at: directory)
            }
        }
    }

    private func branchName(for group: TaskGroup) -> String {
        let slug = sanitizeIdentifier(group.id)
        return "agent/\(group.preferredAgent.rawValue)-\(slug)"
    }

    private func sanitizeIdentifier(_ value: String) -> String {
        let allowed = value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return allowed.isEmpty ? value.replacingOccurrences(of: "/", with: "-") : allowed
    }
}

enum WorktreePathBuilder {
    static func repoDirectory(for repoPath: URL) -> URL {
        baseDirectory()
            .appendingPathComponent(repoHash(for: repoPath), isDirectory: true)
    }

    static func worktreePath(for repoPath: URL, branchName: String) -> URL {
        repoDirectory(for: repoPath)
            .appendingPathComponent(branchName, isDirectory: true)
    }

    private static func baseDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".crossroads/worktrees", isDirectory: true)
    }

    private static func repoHash(for repoPath: URL) -> String {
        let normalizedPath = repoPath.standardizedFileURL.path.lowercased()
        let data = Data(normalizedPath.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
