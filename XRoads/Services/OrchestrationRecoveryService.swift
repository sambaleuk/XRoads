import Foundation
import os

/// Scans the repository's `.crossroads/status.json` and `worktrees/` directory
/// to detect an interrupted orchestration that can be resumed.
actor OrchestrationRecoveryService {

    private let fileManager = FileManager.default

    /// Check if the given repository has an interrupted orchestration.
    /// Returns `nil` if there is nothing to recover.
    func checkForRecovery(repoPath: URL) -> RecoveredOrchestration? {
        let statusPath = repoPath.appendingPathComponent(".crossroads/status.json")

        guard fileManager.fileExists(atPath: statusPath.path) else {
            return nil
        }

        // Read and decode status.json
        guard let statusFile = readStatusFile(at: statusPath) else {
            return nil
        }

        // Determine completed vs remaining stories
        let completedIds = statusFile.stories.values
            .filter { $0.status == .complete }
            .map(\.id)
        let completedSet = Set(completedIds)

        let remaining = statusFile.stories.values
            .filter { $0.status != .complete }
            .map { story in
                RecoveredOrchestration.RemainingStory(
                    id: story.id,
                    status: story.status.rawValue,
                    dependsOn: story.dependsOn
                )
            }
            .sorted { $0.id < $1.id }

        // If all stories are complete, nothing to recover
        if remaining.isEmpty {
            return nil
        }

        // Scan worktree directories
        let slots = scanWorktreeDirectories(repoPath: repoPath, completedStoryIds: completedSet)

        return RecoveredOrchestration(
            prdName: statusFile.prdName,
            sessionId: statusFile.sessionId,
            startedAt: statusFile.startedAt,
            repoPath: repoPath,
            statusFilePath: statusPath,
            totalStories: statusFile.stories.count,
            completedStories: completedIds.count,
            remainingStories: remaining,
            slots: slots,
            layers: statusFile.layers
        )
    }

    // MARK: - Private

    private func readStatusFile(at path: URL) -> OrchestrationStatusFile? {
        guard let data = try? Data(contentsOf: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OrchestrationStatusFile.self, from: data)
    }

    /// Scan `<repoPath>/worktrees/` for directories matching `slot-N-agent-stories`.
    private func scanWorktreeDirectories(
        repoPath: URL,
        completedStoryIds: Set<String>
    ) -> [RecoveredOrchestration.RecoveredSlot] {
        let worktreesDir = repoPath.appendingPathComponent("worktrees")
        guard let entries = try? fileManager.contentsOfDirectory(
            at: worktreesDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        // Pattern: slot-1-gemini-us-001-us-002
        // Groups: slot number, agent name, story IDs suffix
        let regex = try? NSRegularExpression(pattern: #"^slot-(\d+)-(\w+?)-(.+)$"#)

        var slots: [RecoveredOrchestration.RecoveredSlot] = []

        for entry in entries {
            let dirName = entry.lastPathComponent
            let range = NSRange(dirName.startIndex..., in: dirName)

            guard let regex,
                  let match = regex.firstMatch(in: dirName, range: range),
                  match.numberOfRanges == 4 else { continue }

            // Validate it's actually a worktree (has .git file)
            let gitFile = entry.appendingPathComponent(".git")
            guard fileManager.fileExists(atPath: gitFile.path) else { continue }

            let slotNumber = Int(dirName[Range(match.range(at: 1), in: dirName)!]) ?? 0
            let agentName = String(dirName[Range(match.range(at: 2), in: dirName)!])
            let storySuffix = String(dirName[Range(match.range(at: 3), in: dirName)!])

            guard let agentType = AgentType(rawValue: agentName) else { continue }

            // Parse story IDs from suffix: "us-001-us-002" → ["US-001", "US-002"]
            let storyIds = parseStoryIds(from: storySuffix)

            let branchName = "xroads/\(dirName)"
            let allComplete = storyIds.allSatisfy { completedStoryIds.contains($0) }

            slots.append(RecoveredOrchestration.RecoveredSlot(
                slotNumber: slotNumber,
                agentType: agentType,
                storyIds: storyIds,
                branchName: branchName,
                worktreePath: entry,
                allStoriesComplete: allComplete
            ))
        }

        return slots.sorted { $0.slotNumber < $1.slotNumber }
    }

    /// Parse story IDs from a suffix like "us-001-us-002" → ["US-001", "US-002"].
    private func parseStoryIds(from suffix: String) -> [String] {
        // Split on pattern boundaries: each story ID starts with a letter prefix
        // Pattern: "us-001-us-002" or "story-1-story-2"
        // Strategy: split by common prefixes (us-, story-, etc.)
        let parts = suffix.components(separatedBy: "-")
        var storyIds: [String] = []
        var current: [String] = []

        for part in parts {
            // If this part looks like a story prefix (letters only) and we already
            // have accumulated parts, flush the current story ID
            let isPrefix = part.allSatisfy(\.isLetter)
            if isPrefix && !current.isEmpty {
                storyIds.append(current.joined(separator: "-").uppercased())
                current = [part]
            } else {
                current.append(part)
            }
        }

        // Flush remaining
        if !current.isEmpty {
            storyIds.append(current.joined(separator: "-").uppercased())
        }

        return storyIds
    }
}
