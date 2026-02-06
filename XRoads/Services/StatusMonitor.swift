//
//  StatusMonitor.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Monitors status.json and triggers layer progression
//

import Foundation

// MARK: - Status Update Event

struct StatusUpdateEvent: Sendable {
    let storyId: String
    let oldStatus: StoryOrchestrationStatus
    let newStatus: StoryOrchestrationStatus
    let timestamp: Date
}

// MARK: - Layer Completion Event

struct LayerCompletionEvent: Sendable {
    let layerIndex: Int
    let completedStories: [String]
    let nextLayerStories: [String]
    let timestamp: Date
}

// MARK: - StatusMonitor

/// Actor that monitors the central status.json file and emits events
actor StatusMonitor {

    private let statusFilePath: URL
    private let pollInterval: TimeInterval
    private var isMonitoring = false
    private var lastKnownStatus: OrchestrationStatusFile?
    private var monitorTask: Task<Void, Never>?

    // Callbacks
    private var onStoryComplete: ((StatusUpdateEvent) -> Void)?
    private var onLayerComplete: ((LayerCompletionEvent) -> Void)?
    private var onAllComplete: (() -> Void)?
    private var onError: ((Error) -> Void)?

    init(statusFilePath: URL, pollInterval: TimeInterval = 5.0) {
        self.statusFilePath = statusFilePath
        self.pollInterval = pollInterval
    }

    // MARK: - Public API

    /// Start monitoring the status file
    func startMonitoring(
        onStoryComplete: @escaping (StatusUpdateEvent) -> Void,
        onLayerComplete: @escaping (LayerCompletionEvent) -> Void,
        onAllComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !isMonitoring else { return }

        self.onStoryComplete = onStoryComplete
        self.onLayerComplete = onLayerComplete
        self.onAllComplete = onAllComplete
        self.onError = onError

        isMonitoring = true

        monitorTask = Task { [weak self] in
            await self?.monitorLoop()
        }

        let path = statusFilePath.path
        Log.status.info("Started monitoring: \(path)")
    }

    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
        Log.status.info("Stopped monitoring")
    }

    /// Get current status
    func getCurrentStatus() -> OrchestrationStatusFile? {
        return lastKnownStatus
    }

    /// Get stories ready to start (dependencies satisfied)
    func getReadyStories() -> [String] {
        guard let status = lastKnownStatus else { return [] }

        return status.stories.values
            .filter { story in
                story.status == .ready || story.status == .pending
            }
            .filter { story in
                // Check all dependencies are complete
                story.dependsOn.allSatisfy { depId in
                    status.stories[depId]?.status == .complete
                }
            }
            .map { $0.id }
    }

    /// Get completion percentage
    func getCompletionPercentage() -> Double {
        guard let status = lastKnownStatus else { return 0 }
        let total = status.stories.count
        guard total > 0 else { return 0 }
        let completed = status.stories.values.filter { $0.status == .complete }.count
        return Double(completed) / Double(total)
    }

    /// Get stories by status
    func getStoriesByStatus() -> [StoryOrchestrationStatus: [String]] {
        guard let status = lastKnownStatus else { return [:] }

        var result: [StoryOrchestrationStatus: [String]] = [:]
        for (id, story) in status.stories {
            result[story.status, default: []].append(id)
        }
        return result
    }

    // MARK: - Private

    private func monitorLoop() async {
        while isMonitoring && !Task.isCancelled {
            do {
                try await checkForUpdates()
            } catch {
                onError?(error)
            }

            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    private func checkForUpdates() async throws {
        guard FileManager.default.fileExists(atPath: statusFilePath.path) else {
            return
        }

        let data = try Data(contentsOf: statusFilePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let currentStatus = try decoder.decode(OrchestrationStatusFile.self, from: data)

        // First load - just store it
        guard let previousStatus = lastKnownStatus else {
            lastKnownStatus = currentStatus
            return
        }

        // Check for story status changes
        var completedStories: [String] = []

        for (storyId, currentStory) in currentStatus.stories {
            if let previousStory = previousStatus.stories[storyId] {
                if previousStory.status != currentStory.status {
                    let event = StatusUpdateEvent(
                        storyId: storyId,
                        oldStatus: previousStory.status,
                        newStatus: currentStory.status,
                        timestamp: Date()
                    )

                    if currentStory.status == .complete {
                        completedStories.append(storyId)
                        onStoryComplete?(event)
                    }
                }
            }
        }

        // Check if a layer was completed
        if !completedStories.isEmpty {
            checkLayerCompletion(currentStatus: currentStatus, completedStories: completedStories)
        }

        // Check if all stories are complete
        let allComplete = currentStatus.stories.values.allSatisfy { $0.status == .complete }
        if allComplete && !previousStatus.stories.values.allSatisfy({ $0.status == .complete }) {
            onAllComplete?()
        }

        lastKnownStatus = currentStatus
    }

    private func checkLayerCompletion(currentStatus: OrchestrationStatusFile, completedStories: [String]) {
        // Find which layer just completed
        for (layerIndex, layerStoryIds) in currentStatus.layers.enumerated() {
            let layerComplete = layerStoryIds.allSatisfy { storyId in
                currentStatus.stories[storyId]?.status == .complete
            }

            if layerComplete {
                // Check if next layer exists and has ready stories
                let nextLayerIndex = layerIndex + 1
                if nextLayerIndex < currentStatus.layers.count {
                    let nextLayerStories = currentStatus.layers[nextLayerIndex]

                    // Only emit if some stories in next layer just became ready
                    let newlyReady = nextLayerStories.filter { storyId in
                        guard let story = currentStatus.stories[storyId] else { return false }
                        // Story is ready if all its dependencies are complete
                        return story.dependsOn.allSatisfy { depId in
                            currentStatus.stories[depId]?.status == .complete
                        }
                    }

                    if !newlyReady.isEmpty {
                        let event = LayerCompletionEvent(
                            layerIndex: layerIndex,
                            completedStories: completedStories,
                            nextLayerStories: newlyReady,
                            timestamp: Date()
                        )
                        onLayerComplete?(event)
                    }
                }
            }
        }
    }
}
