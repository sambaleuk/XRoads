import Foundation

// MARK: - SessionPersistenceError

enum SessionPersistenceError: LocalizedError {
    case invalidRepoPath(String)
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepoPath(let path):
            return "Invalid repo path: \(path)"
        case .readFailed(let reason):
            return "Failed to read sessions: \(reason)"
        case .writeFailed(let reason):
            return "Failed to write sessions: \(reason)"
        }
    }
}

// MARK: - SessionPersistenceService

/// Persists session metadata to `<repoPath>/.crossroads/sessions.json`
/// Each repo gets its own sessions file for portability.
actor SessionPersistenceService {

    private let fileManager = FileManager.default

    /// Directory name inside each repo
    private static let crossroadsDir = ".crossroads"

    /// File name for session storage
    private static let sessionsFile = "sessions.json"

    // MARK: - Public API

    /// Save (upsert) a session into the repo's sessions file
    func saveSession(_ session: Session) async throws {
        guard let repoPath = session.repoPath, !repoPath.isEmpty else {
            throw SessionPersistenceError.invalidRepoPath(session.repoPath ?? "<nil>")
        }

        var sessions = try loadSessionsFromDisk(repoPath: repoPath)

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }

        try writeSessionsToDisk(sessions, repoPath: repoPath)
    }

    /// Load all sessions for a given repo
    func loadSessions(for repoPath: String) async throws -> [Session] {
        return try loadSessionsFromDisk(repoPath: repoPath)
    }

    /// Get the most recent session for a repo (by updatedAt)
    func lastSession(for repoPath: String) async throws -> Session? {
        let sessions = try loadSessionsFromDisk(repoPath: repoPath)
        return sessions.max(by: { $0.updatedAt < $1.updatedAt })
    }

    /// Store a handoff payload on a session
    func updateHandoff(sessionId: UUID, repoPath: String, payload: String) async throws {
        var sessions = try loadSessionsFromDisk(repoPath: repoPath)
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].handoffPayload = payload
        sessions[index].updatedAt = Date()
        try writeSessionsToDisk(sessions, repoPath: repoPath)
    }

    /// Store a conversation ID for an agent on a session
    func updateConversationId(sessionId: UUID, repoPath: String, agent: String, conversationId: String) async throws {
        var sessions = try loadSessionsFromDisk(repoPath: repoPath)
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].conversationIds[agent] = conversationId
        sessions[index].updatedAt = Date()
        try writeSessionsToDisk(sessions, repoPath: repoPath)
    }

    // MARK: - Private Helpers

    /// Path to `.crossroads/sessions.json` inside a repo
    private func sessionsFilePath(repoPath: String) -> URL {
        URL(fileURLWithPath: repoPath)
            .appendingPathComponent(Self.crossroadsDir)
            .appendingPathComponent(Self.sessionsFile)
    }

    /// Ensure `.crossroads/` exists (and add to .gitignore if needed)
    private func ensureDirectory(repoPath: String) throws {
        let dirURL = URL(fileURLWithPath: repoPath)
            .appendingPathComponent(Self.crossroadsDir)

        if !fileManager.fileExists(atPath: dirURL.path) {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }

        // Ensure .crossroads is in .gitignore
        let gitignorePath = URL(fileURLWithPath: repoPath).appendingPathComponent(".gitignore")
        let entry = ".crossroads/"
        if fileManager.fileExists(atPath: gitignorePath.path) {
            let contents = (try? String(contentsOf: gitignorePath, encoding: .utf8)) ?? ""
            if !contents.contains(entry) {
                let amended = contents.hasSuffix("\n") ? contents + entry + "\n" : contents + "\n" + entry + "\n"
                try? amended.write(to: gitignorePath, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Read sessions from disk
    private func loadSessionsFromDisk(repoPath: String) throws -> [Session] {
        let filePath = sessionsFilePath(repoPath: repoPath)

        guard fileManager.fileExists(atPath: filePath.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Session].self, from: data)
        } catch {
            throw SessionPersistenceError.readFailed(error.localizedDescription)
        }
    }

    /// Write sessions to disk
    private func writeSessionsToDisk(_ sessions: [Session], repoPath: String) throws {
        try ensureDirectory(repoPath: repoPath)

        let filePath = sessionsFilePath(repoPath: repoPath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(sessions)
            try data.write(to: filePath, options: .atomic)
        } catch {
            throw SessionPersistenceError.writeFailed(error.localizedDescription)
        }
    }
}
