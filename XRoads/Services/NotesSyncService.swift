import Foundation

/// Safety: @unchecked Sendable is justified because all stored properties are `let` bindings.
/// The `ISO8601DateFormatter` is a reference type but is private, never shared, and only
/// used via its `string(from:)` method which does not mutate observable state.
struct NotesSyncService: @unchecked Sendable {

    private let fileManager: FileManager = .default
    private let files = ["decisions.md", "learnings.md", "blockers.md"]
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func syncNotesToWorktree(repoPath: URL, assignment: WorktreeAssignment) throws {
        let repoNotes = repoNotesDirectory(for: repoPath, branch: assignment.branchName)
        let worktreeNotes = assignment.worktreePath.appendingPathComponent("notes", isDirectory: true)

        try ensureDirectory(repoNotes)
        try ensureDirectory(worktreeNotes)

        for file in files {
            let repoFile = repoNotes.appendingPathComponent(file)
            let worktreeFile = worktreeNotes.appendingPathComponent(file)

            if !fileManager.fileExists(atPath: repoFile.path) {
                let header = "# \(fileTitle(file)) Log\n\n"
                try header.write(to: repoFile, atomically: true, encoding: .utf8)
            }

            let contents = try String(contentsOf: repoFile, encoding: .utf8)
            try contents.write(to: worktreeFile, atomically: true, encoding: .utf8)
        }
    }

    func syncNotesBack(repoPath: URL, assignment: WorktreeAssignment) throws {
        let repoNotes = repoNotesDirectory(for: repoPath, branch: assignment.branchName)
        let worktreeNotes = assignment.worktreePath.appendingPathComponent("notes", isDirectory: true)

        guard fileManager.fileExists(atPath: worktreeNotes.path) else { return }
        try ensureDirectory(repoNotes)

        for file in files {
            let worktreeFile = worktreeNotes.appendingPathComponent(file)
            guard fileManager.fileExists(atPath: worktreeFile.path) else { continue }

            let content = try String(contentsOf: worktreeFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }

            let repoFile = repoNotes.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: repoFile.path) {
                try "# \(fileTitle(file)) Log\n\n".write(to: repoFile, atomically: true, encoding: .utf8)
            }

            let timestamp = formatter.string(from: Date())
            let header = "\n\n## \(timestamp) – \(assignment.branchName)\n"
            let entry = header + content + "\n"

            if let handle = try? FileHandle(forWritingTo: repoFile) {
                try handle.seekToEnd()
                if let data = entry.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try entry.write(to: repoFile, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Helpers

    private func ensureDirectory(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func repoNotesDirectory(for repoPath: URL, branch: String) -> URL {
        repoPath
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent(sanitize(branch), isDirectory: true)
    }

    private func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
    }

    private func fileTitle(_ filename: String) -> String {
        filename.replacingOccurrences(of: ".md", with: "").capitalized
    }
}
