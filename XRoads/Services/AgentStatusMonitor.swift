import Foundation

private struct AgentStatusFile: Codable {
    let agentId: String
    let agentType: AgentType?
    let worktreePath: String?
    let state: AgentRunState
    let message: String
    let currentStory: String?
    let progress: Double?
    let timestamp: Date

    func snapshot(enrichedWith assignment: TaskAssignment?) -> AgentStatusSnapshot {
        let inferredWorktree = assignment?.worktreePath ?? worktreePath.map { URL(fileURLWithPath: $0) }
        return AgentStatusSnapshot(
            agentId: agentId,
            agentType: agentType ?? assignment?.agentType,
            worktreePath: enrichedWorktree(from: inferredWorktree ?? assignment?.worktreePath),
            state: state,
            currentStoryId: currentStory,
            progress: progress ?? 0,
            message: message,
            timestamp: timestamp
        )
    }

    private func enrichedWorktree(from url: URL?) -> URL? {
        guard let url else { return nil }
        return url.standardizedFileURL
    }
}

/// Polls agent status files (agent-{sessionId}.json) and emits snapshots.
actor AgentStatusMonitor {

    private let directory: URL
    private let pollInterval: TimeInterval
    private let staleInterval: TimeInterval
    private let fileManager: FileManager = .default
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(
        directory: URL = URL(fileURLWithPath: "/tmp/crossroads/agents", isDirectory: true),
        pollInterval: TimeInterval = 0.5,
        staleInterval: TimeInterval = 300
    ) {
        self.directory = directory
        self.pollInterval = pollInterval
        self.staleInterval = staleInterval
    }

    func monitor(sessionID: UUID, assignments: [TaskAssignment]) -> AsyncStream<AgentStatusSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                var lastTimestamps: [String: Date] = [:]
                let assignmentLookup = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id.uuidString, $0) })

                while !Task.isCancelled {
                    await pollDirectory(
                        sessionID: sessionID,
                        assignmentLookup: assignmentLookup,
                        lastTimestamps: &lastTimestamps,
                        continuation: continuation
                    )

                    try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Polling

    private func pollDirectory(
        sessionID: UUID,
        assignmentLookup: [String: TaskAssignment],
        lastTimestamps: inout [String: Date],
        continuation: AsyncStream<AgentStatusSnapshot>.Continuation
    ) async {
        do {
            try ensureDirectoryExists()
        } catch {
            continuation.yield(
                AgentStatusSnapshot(
                    agentId: "system",
                    agentType: nil,
                    worktreePath: nil,
                    state: .error,
                    currentStoryId: nil,
                    progress: 0,
                    message: "AgentStatusMonitor failed to access \(directory.path): \(error.localizedDescription)",
                    timestamp: Date()
                )
            )
            return
        }

        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let prefix = "agent-\(sessionID.uuidString.lowercased())"

        for file in files {
            guard file.lastPathComponent.lowercased().hasPrefix(prefix) else { continue }

            guard let data = try? Data(contentsOf: file),
                  let statusFile = try? decoder.decode(AgentStatusFile.self, from: data) else {
                continue
            }

            let assignment = assignmentLookup[statusFile.agentId]
            var snapshot = statusFile.snapshot(enrichedWith: assignment)

            let lastTimestamp = lastTimestamps[file.path]
            guard lastTimestamp == nil || snapshot.timestamp > lastTimestamp! else {
                continue
            }
            lastTimestamps[file.path] = snapshot.timestamp

            if Date().timeIntervalSince(snapshot.timestamp) > staleInterval {
                try? fileManager.removeItem(at: file)
                snapshot = AgentStatusSnapshot(
                    agentId: snapshot.agentId,
                    agentType: snapshot.agentType ?? assignment?.agentType,
                    worktreePath: snapshot.worktreePath ?? assignment?.worktreePath,
                    state: .blocked,
                    currentStoryId: snapshot.currentStoryId,
                    progress: snapshot.progress,
                    message: "[STALE] \(snapshot.message)",
                    timestamp: snapshot.timestamp
                )
            }

            continuation.yield(snapshot)
        }
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
