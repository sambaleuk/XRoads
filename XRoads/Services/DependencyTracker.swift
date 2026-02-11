//
//  DependencyTracker.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Tracks story dependencies and completion status across slots
//

import Foundation

// MARK: - Story Status

/// Status of a story in the orchestration
enum StoryOrchestrationStatus: String, Codable, Sendable {
    case pending       // Not started
    case blocked       // Waiting for dependencies
    case ready         // Dependencies satisfied, can start
    case inProgress    // Being worked on
    case complete      // Done
    case failed        // Failed
}

// MARK: - Story Tracking Info

/// Tracking info for a story
struct StoryTrackingInfo: Codable, Sendable, Identifiable {
    let id: String  // Story ID (e.g., "US-001")
    var status: StoryOrchestrationStatus
    var assignedToSlot: Int?
    var dependsOn: [String]
    var startedAt: Date?
    var completedAt: Date?
    var lastError: String?
}

// MARK: - Dependency Layer

/// A layer of stories that can be executed in parallel
struct DependencyLayer: Sendable {
    let level: Int
    let storyIds: [String]

    var description: String {
        "Layer \(level): \(storyIds.joined(separator: ", "))"
    }
}

// MARK: - Orchestration Status File

/// The shared status file structure
struct OrchestrationStatusFile: Codable, Sendable {
    var sessionId: UUID
    var prdName: String
    var startedAt: Date
    var stories: [String: StoryTrackingInfo]
    var layers: [[String]]  // Array of story ID arrays per layer
    var currentLayer: Int
    var updatedAt: Date

    init(sessionId: UUID, prdName: String, stories: [StoryTrackingInfo], layers: [[String]]) {
        self.sessionId = sessionId
        self.prdName = prdName
        self.startedAt = Date()
        self.stories = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
        self.layers = layers
        self.currentLayer = 0
        self.updatedAt = Date()
    }
}

// MARK: - DependencyTracker

/// Actor that tracks dependencies and manages story status across slots
actor DependencyTracker {

    private let fileManager = FileManager.default
    private var statusFilePath: URL?
    private var cachedStatus: OrchestrationStatusFile?

    // MARK: - Layer Calculation

    /// Calculate dependency layers from PRD stories
    /// Stories in the same layer can be executed in parallel
    func calculateLayers(stories: [PRDUserStory]) -> [DependencyLayer] {
        var layers: [DependencyLayer] = []
        var assigned: Set<String> = []
        var remaining = stories
        var level = 0

        while !remaining.isEmpty {
            // Find stories whose dependencies are all satisfied
            var layerStories: [String] = []

            for story in remaining {
                let depsAssigned = story.dependsOn.allSatisfy { assigned.contains($0) }
                if depsAssigned {
                    layerStories.append(story.id)
                }
            }

            // If no stories can be added, we have a circular dependency
            if layerStories.isEmpty && !remaining.isEmpty {
                // Add all remaining stories to break the cycle
                layerStories = remaining.map { $0.id }
            }

            if !layerStories.isEmpty {
                layers.append(DependencyLayer(level: level, storyIds: layerStories))
                assigned.formUnion(layerStories)
                remaining.removeAll { layerStories.contains($0.id) }
                level += 1
            }
        }

        return layers
    }

    /// Get suggested slot assignments based on dependencies
    /// Returns: [slotNumber: [storyIds]]
    func suggestSlotAssignments(
        stories: [PRDUserStory],
        availableSlots: Int
    ) -> [Int: [String]] {
        let layers = calculateLayers(stories: stories)
        var assignments: [Int: [String]] = [:]

        // Simple strategy: round-robin within each layer
        var slotIndex = 0

        for layer in layers {
            for storyId in layer.storyIds {
                let slot = (slotIndex % availableSlots) + 1
                if assignments[slot] == nil {
                    assignments[slot] = []
                }
                assignments[slot]?.append(storyId)
                slotIndex += 1
            }
        }

        return assignments
    }

    // MARK: - Status File Management

    /// Initialize the status file for an orchestration session.
    /// When `resumeIfExists` is true and a valid status.json already exists, it is reused
    /// rather than overwritten — preserving prior story completions for resumed orchestrations.
    func initializeStatusFile(
        repoPath: URL,
        sessionId: UUID,
        prd: PRDDocument,
        resumeIfExists: Bool = false
    ) throws -> URL {
        let crossroadsDir = repoPath.appendingPathComponent(".crossroads")
        try fileManager.createDirectory(at: crossroadsDir, withIntermediateDirectories: true)

        let statusPath = crossroadsDir.appendingPathComponent("status.json")
        self.statusFilePath = statusPath

        // In resume mode, reuse the existing status file if it's valid
        if resumeIfExists, fileManager.fileExists(atPath: statusPath.path) {
            if let existing = try? readStatusFile(from: statusPath, forceRefresh: true) {
                cachedStatus = existing
                return statusPath
            }
        }

        // Calculate layers
        let layers = calculateLayers(stories: prd.userStories)

        // Create tracking info for each story
        let trackingInfos = prd.userStories.map { story in
            StoryTrackingInfo(
                id: story.id,
                status: story.dependsOn.isEmpty ? .ready : .blocked,
                assignedToSlot: nil,
                dependsOn: story.dependsOn,
                startedAt: nil,
                completedAt: nil,
                lastError: nil
            )
        }

        let statusFile = OrchestrationStatusFile(
            sessionId: sessionId,
            prdName: prd.featureName,
            stories: trackingInfos,
            layers: layers.map { $0.storyIds }
        )

        try writeStatusFile(statusFile, to: statusPath)
        cachedStatus = statusFile

        return statusPath
    }

    /// Update story status
    func updateStoryStatus(
        storyId: String,
        status: StoryOrchestrationStatus,
        error: String? = nil
    ) throws {
        guard let path = statusFilePath else { return }
        var statusFile = try readStatusFile(from: path)

        guard var story = statusFile.stories[storyId] else { return }

        story.status = status
        if status == .inProgress && story.startedAt == nil {
            story.startedAt = Date()
        }
        if status == .complete {
            story.completedAt = Date()
        }
        if let error = error {
            story.lastError = error
        }

        statusFile.stories[storyId] = story
        statusFile.updatedAt = Date()

        // Update blocked stories that might now be ready
        updateBlockedStories(&statusFile)

        try writeStatusFile(statusFile, to: path)
        cachedStatus = statusFile
    }

    /// Assign story to a slot
    func assignStoryToSlot(storyId: String, slotNumber: Int) throws {
        guard let path = statusFilePath else { return }
        var statusFile = try readStatusFile(from: path)

        guard var story = statusFile.stories[storyId] else { return }
        story.assignedToSlot = slotNumber
        statusFile.stories[storyId] = story
        statusFile.updatedAt = Date()

        try writeStatusFile(statusFile, to: path)
        cachedStatus = statusFile
    }

    /// Get stories that are ready to be worked on
    func getReadyStories() throws -> [StoryTrackingInfo] {
        guard let path = statusFilePath else { return [] }
        let statusFile = try readStatusFile(from: path)

        return statusFile.stories.values.filter { $0.status == .ready }
    }

    /// Get stories blocked waiting for dependencies
    func getBlockedStories() throws -> [StoryTrackingInfo] {
        guard let path = statusFilePath else { return [] }
        let statusFile = try readStatusFile(from: path)

        return statusFile.stories.values.filter { $0.status == .blocked }
    }

    /// Check if a story's dependencies are satisfied
    func areDependenciesSatisfied(storyId: String) throws -> Bool {
        guard let path = statusFilePath else { return false }
        let statusFile = try readStatusFile(from: path)

        guard let story = statusFile.stories[storyId] else { return false }

        return story.dependsOn.allSatisfy { depId in
            statusFile.stories[depId]?.status == .complete
        }
    }

    /// Get completion percentage
    func getCompletionPercentage() throws -> Double {
        guard let path = statusFilePath else { return 0 }
        let statusFile = try readStatusFile(from: path)

        let total = statusFile.stories.count
        guard total > 0 else { return 0 }

        let completed = statusFile.stories.values.filter { $0.status == .complete }.count
        return Double(completed) / Double(total)
    }

    // MARK: - Private Helpers

    private func updateBlockedStories(_ statusFile: inout OrchestrationStatusFile) {
        for (storyId, var story) in statusFile.stories {
            if story.status == .blocked {
                let depsComplete = story.dependsOn.allSatisfy { depId in
                    statusFile.stories[depId]?.status == .complete
                }
                if depsComplete {
                    story.status = .ready
                    statusFile.stories[storyId] = story
                }
            }
        }
    }

    private func readStatusFile(from path: URL, forceRefresh: Bool = false) throws -> OrchestrationStatusFile {
        if !forceRefresh, let cached = cachedStatus {
            return cached
        }

        let data = try Data(contentsOf: path)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let status = try decoder.decode(OrchestrationStatusFile.self, from: data)
        cachedStatus = status
        return status
    }

    /// Re-reads status.json from disk (bypassing cache) and unblocks stories whose deps are complete.
    func refreshAndUnblockStories() throws {
        guard let path = statusFilePath else { return }
        var statusFile = try readStatusFile(from: path, forceRefresh: true)
        updateBlockedStories(&statusFile)
        try writeStatusFile(statusFile, to: path)
        cachedStatus = statusFile
    }

    private func writeStatusFile(_ statusFile: OrchestrationStatusFile, to path: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(statusFile)
        try data.write(to: path, options: .atomic)
    }
}

// MARK: - Dependency-Aware AGENT.md Generator

extension DependencyTracker {

    /// Generate AGENT.md content with dependency awareness
    func generateAgentMd(
        slotNumber: Int,
        agentType: AgentType,
        assignedStories: [PRDUserStory],
        fullPRD: PRDDocument,
        statusFilePath: URL,
        worktreePath: URL
    ) -> String {
        let storyList = assignedStories.map { story in
            let deps = story.dependsOn.isEmpty ? "None" : story.dependsOn.joined(separator: ", ")
            return "- **\(story.id)**: \(story.title)\n  - Priority: \(story.priority.rawValue)\n  - Depends on: \(deps)"
        }.joined(separator: "\n")

        return """
        # AGENT BRIEF – \(agentType.displayName)

        ## Session Overview
        - **Feature:** \(fullPRD.featureName)
        - **Slot:** \(slotNumber)
        - **Worktree:** \(worktreePath.path)
        - **Status File:** \(statusFilePath.path)

        ## Your Assigned Stories

        \(storyList)

        ## CRITICAL: Dependency Management

        Before starting ANY story, you MUST check if its dependencies are complete:

        1. Read the status file: `\(statusFilePath.path)`
        2. Check that ALL stories in `dependsOn` have `status: "complete"`
        3. If dependencies are NOT complete:
           - Log: "Waiting for dependencies: [list them]"
           - Skip this story and check the next one
           - Or wait and re-check every 30 seconds

        4. When you COMPLETE a story:
           - Update the status file: set your story's status to "complete"
           - This will unblock other agents waiting on you!

        ## Status File Format

        ```json
        {
          "stories": {
            "US-001": { "status": "complete", ... },
            "US-002": { "status": "inProgress", ... }
          }
        }
        ```

        Valid statuses: pending, blocked, ready, inProgress, complete, failed

        ## Full Feature Context

        \(fullPRD.description)

        ## Coordination Rules

        1. Always update `.crossroads/status.json` when:
           - Starting a story → set status to "inProgress"
           - Completing a story → set status to "complete"
           - Encountering an error → set status to "failed" with lastError

        2. Use MCP `emit_log` to report progress
        3. Document decisions in `notes/decisions.md`

        ---
        *Generated by XRoads Orchestrator with Dependency Tracking*
        """
    }
}
