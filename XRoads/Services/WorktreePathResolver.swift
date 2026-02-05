//
//  WorktreePathResolver.swift
//  XRoads
//
//  Centralized worktree path resolution to ensure consistency
//  across all components (SlotAssignmentSheet, LoopLauncher, LayeredDispatcher)
//

import Foundation

/// Centralized worktree path resolution to ensure consistency
enum WorktreePathResolver {

    /// Resolve the worktree path for a slot
    /// - Parameters:
    ///   - repoPath: The main repository path
    ///   - slotNumber: The slot number (1-6)
    ///   - agentType: The agent type
    ///   - storyIds: The story IDs assigned to this slot
    /// - Returns: The worktree path URL
    static func resolve(
        repoPath: URL,
        slotNumber: Int,
        agentType: AgentType,
        storyIds: [String]
    ) -> URL {
        let slotDir = directoryName(slotNumber: slotNumber, agentType: agentType, storyIds: storyIds)
        return repoPath
            .appendingPathComponent("worktrees")
            .appendingPathComponent(slotDir)
    }

    /// Resolve the branch name for a slot
    static func branchName(
        slotNumber: Int,
        agentType: AgentType,
        storyIds: [String]
    ) -> String {
        let storyIdsSuffix = storyIds.prefix(2).joined(separator: "-").lowercased()
        return "xroads/slot-\(slotNumber)-\(agentType.rawValue)-\(storyIdsSuffix)"
    }

    /// Get the directory name for a slot worktree
    static func directoryName(
        slotNumber: Int,
        agentType: AgentType,
        storyIds: [String]
    ) -> String {
        let storyIdsSuffix = storyIds.prefix(2).joined(separator: "-").lowercased()
        return "slot-\(slotNumber)-\(agentType.rawValue)-\(storyIdsSuffix)"
    }

    /// Create the worktrees parent directory if needed
    static func ensureWorktreesDirectory(repoPath: URL) throws {
        let worktreesDir = repoPath.appendingPathComponent("worktrees")
        if !FileManager.default.fileExists(atPath: worktreesDir.path) {
            try FileManager.default.createDirectory(
                at: worktreesDir,
                withIntermediateDirectories: true
            )
        }
    }
}
