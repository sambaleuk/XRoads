//
//  LayeredDispatcher.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Dispatches loops by dependency layer with proper sequencing
//

import Foundation
import os

// MARK: - Dispatch State

enum DispatchPhase: String, Sendable {
    case idle
    case preparingWorktrees
    case validatingWorktrees
    case launchingLayer
    case monitoring
    case completed
    case failed
}

// MARK: - Slot Launch Info

struct SlotLaunchInfo: Sendable, Identifiable {
    let id: UUID
    let slotNumber: Int
    let agentType: AgentType
    let actionType: ActionType  // Role/action for this slot
    let storyIds: [String]
    let worktreePath: URL
    let branchName: String
    var processId: UUID?
    var status: SlotLaunchStatus

    enum SlotLaunchStatus: String, Sendable {
        case pending
        case worktreeCreated
        case launching
        case running
        case completed
        case failed
    }
}

// MARK: - Dispatch Progress

struct DispatchProgress: Sendable {
    let phase: DispatchPhase
    let currentLayer: Int
    let totalLayers: Int
    let slotsLaunched: Int
    let totalSlots: Int
    let storiesComplete: Int
    let totalStories: Int
    let message: String
}

// MARK: - LayeredDispatcher

/// Actor that manages layered dispatch of loops with dependency awareness
actor LayeredDispatcher {

    private let loopLauncher: LoopLauncher
    private let gitService: GitService
    private var statusMonitor: StatusMonitor?

    private var currentPhase: DispatchPhase = .idle
    private var slotInfos: [Int: SlotLaunchInfo] = [:]
    private var statusFilePath: URL?
    private var repoPath: URL?
    private var prd: PRDDocument?
    private var layers: [[String]] = []
    private var currentLayerIndex: Int = 0
    private var completedStoryIds: Set<String> = []  // Track actually completed stories

    // Callbacks
    private var onProgress: ((DispatchProgress) -> Void)?
    private var onSlotUpdate: ((SlotLaunchInfo) -> Void)?
    private var onSlotOutput: ((Int, String) -> Void)?  // (slotNumber, output)
    private var onSlotTermination: ((Int, Int32) -> Void)?  // (slotNumber, exitCode)
    private var onComplete: (() -> Void)?
    private var onError: ((Error) -> Void)?

    init(
        loopLauncher: LoopLauncher = LoopLauncher(),
        gitService: GitService = GitService()
    ) {
        self.loopLauncher = loopLauncher
        self.gitService = gitService
    }

    // MARK: - Public API

    /// Start the layered dispatch process
    func startDispatch(
        prd: PRDDocument,
        slotAssignments: [Int: (agentType: AgentType, actionType: ActionType, storyIds: [String])],
        repoPath: URL,
        onProgress: @escaping (DispatchProgress) -> Void,
        onSlotUpdate: @escaping (SlotLaunchInfo) -> Void,
        onSlotOutput: @escaping (Int, String) -> Void,
        onSlotTermination: @escaping (Int, Int32) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        self.prd = prd
        self.repoPath = repoPath
        self.onProgress = onProgress
        self.onSlotUpdate = onSlotUpdate
        self.onSlotOutput = onSlotOutput
        self.onSlotTermination = onSlotTermination
        self.onComplete = onComplete
        self.onError = onError

        do {
            // Phase 1: Initialize
            currentPhase = .preparingWorktrees
            emitProgress("Phase 1/6: Calculating dependency layers...")

            // Calculate dependency layers
            layers = await loopLauncher.calculateDependencyLayers(stories: prd.userStories)
                .map { $0.storyIds }
            emitProgress("Computed \(layers.count) dependency layer(s) with \(prd.userStories.count) stories")

            // Initialize status file
            let sessionId = UUID()
            emitProgress("Phase 1/6: Creating status file...")
            statusFilePath = try await loopLauncher.initializeSession(
                repoPath: repoPath,
                sessionId: sessionId,
                prd: prd
            )
            emitProgress("Status file created at \(statusFilePath?.lastPathComponent ?? "unknown")")

            // Phase 2: Create all worktrees upfront
            emitProgress("Phase 2/6: Creating \(slotAssignments.count) worktrees...")
            try await createAllWorktrees(slotAssignments: slotAssignments)

            // Phase 3: Validate worktrees
            currentPhase = .validatingWorktrees
            emitProgress("Phase 3/6: Validating worktrees...")
            try await validateWorktrees()

            // Phase 4: Start monitoring
            emitProgress("Phase 4/6: Starting status monitor...")
            await startStatusMonitor()

            // Phase 5: Launch first layer
            currentPhase = .launchingLayer
            currentLayerIndex = 0
            emitProgress("Phase 5/6: Launching layer 1/\(layers.count)...")
            try await launchCurrentLayer()

            // Phase 6: Now in monitoring mode
            currentPhase = .monitoring
            emitProgress("Phase 6/6: All slots launched. Monitoring progress...")

        } catch {
            currentPhase = .failed
            Log.dispatcher.error("Dispatch failed: \(error.localizedDescription)")
            emitProgress("DISPATCH FAILED: \(error.localizedDescription)")
            onError(error)
        }
    }

    /// Stop all running loops
    func stopAll() async {
        for (_, info) in slotInfos {
            if let processId = info.processId {
                try? await loopLauncher.stopLoop(processId: processId)
            }
        }
        await statusMonitor?.stopMonitoring()
        currentPhase = .idle
    }

    /// Get current dispatch state
    func getState() -> (phase: DispatchPhase, slots: [SlotLaunchInfo]) {
        return (currentPhase, Array(slotInfos.values))
    }

    // MARK: - Private: Worktree Creation

    private func createAllWorktrees(
        slotAssignments: [Int: (agentType: AgentType, actionType: ActionType, storyIds: [String])]
    ) async throws {
        guard let repoPath = repoPath, let prd = prd else {
            throw DispatcherError.notInitialized
        }

        for (slotNumber, assignment) in slotAssignments {
            let storyIdsSuffix = assignment.storyIds.prefix(2).joined(separator: "-").lowercased()
            let branchName = "xroads/slot-\(slotNumber)-\(assignment.agentType.rawValue)-\(storyIdsSuffix)"

            // Build configuration with action type for skills loading
            let stories = prd.userStories.filter { assignment.storyIds.contains($0.id) }
            let config = LoopConfiguration(
                slotNumber: slotNumber,
                agentType: assignment.agentType,
                repoPath: repoPath,
                branchName: branchName,
                stories: stories,
                fullPRD: prd,
                actionType: assignment.actionType,
                statusFilePath: statusFilePath
            )

            // Create slot info with action type
            var info = SlotLaunchInfo(
                id: UUID(),
                slotNumber: slotNumber,
                agentType: assignment.agentType,
                actionType: assignment.actionType,
                storyIds: assignment.storyIds,
                worktreePath: config.worktreePath,
                branchName: branchName,
                status: .pending
            )

            // Create worktree with robust recovery from previous dispatch attempts
            let worktreePath = config.worktreePath
            let gitFile = worktreePath.appendingPathComponent(".git")

            if FileManager.default.fileExists(atPath: gitFile.path) {
                // Worktree already exists and is valid — reuse it
                emitProgress("Reusing existing worktree for slot \(slotNumber)")
            } else {
                // Remove any existing empty/broken directory
                if FileManager.default.fileExists(atPath: worktreePath.path) {
                    try? FileManager.default.removeItem(at: worktreePath)
                }

                // Ensure parent directory exists
                try FileManager.default.createDirectory(
                    at: worktreePath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                // Check if branch already exists from a previous dispatch attempt
                let branchAlreadyExists = await gitService.branchExists(
                    name: branchName,
                    repoPath: repoPath.path
                )

                if branchAlreadyExists {
                    // Branch exists but worktree doesn't — clean up stale branch
                    // and prune any orphaned worktree registrations first
                    emitProgress("Cleaning up stale branch '\(branchName)' from previous dispatch")
                    try? await gitService.deleteBranch(name: branchName, repoPath: repoPath.path, force: true)
                    try? await gitService.pruneWorktrees(repoPath: repoPath.path)
                }

                do {
                    try await gitService.createWorktree(
                        repoPath: repoPath.path,
                        branch: branchName,
                        worktreePath: worktreePath.path
                    )
                } catch {
                    emitProgress("ERROR: Failed to create worktree for slot \(slotNumber): \(error.localizedDescription)")
                    throw error
                }
            }

            info.status = .worktreeCreated
            slotInfos[slotNumber] = info
            onSlotUpdate?(info)

            emitProgress("Created worktree for slot \(slotNumber)")
        }
    }

    private func validateWorktrees() async throws {
        for (slotNumber, info) in slotInfos {
            let gitFile = info.worktreePath.appendingPathComponent(".git")
            guard FileManager.default.fileExists(atPath: gitFile.path) else {
                throw DispatcherError.worktreeValidationFailed(slot: slotNumber)
            }
        }
        emitProgress("All worktrees validated ✓")
    }

    // MARK: - Private: Monitoring

    private func startStatusMonitor() async {
        guard let statusFilePath = statusFilePath else { return }

        statusMonitor = StatusMonitor(statusFilePath: statusFilePath, pollInterval: 5.0)

        await statusMonitor?.startMonitoring(
            onStoryComplete: { [weak self] event in
                Task { await self?.handleStoryComplete(event) }
            },
            onLayerComplete: { [weak self] event in
                Task { await self?.handleLayerComplete(event) }
            },
            onAllComplete: { [weak self] in
                Task { await self?.handleAllComplete() }
            },
            onError: { [weak self] error in
                Task { await self?.handleError(error) }
            }
        )
    }

    private func handleError(_ error: Error) async {
        if let errorHandler = onError {
            errorHandler(error)
        }
    }

    private func handleStoryComplete(_ event: StatusUpdateEvent) async {
        Log.dispatcher.info("Story completed: \(event.storyId)")
        completedStoryIds.insert(event.storyId)
        emitProgress("Story \(event.storyId) completed! ✅")

        // Unblock dependent stories in status.json so agents see "ready" instead of "blocked"
        await unblockReadyStories()
    }

    /// Re-reads status.json from disk, transitions blocked→ready for stories whose deps are all complete, writes back.
    private func unblockReadyStories() async {
        guard let path = statusFilePath else { return }

        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var statusFile = try decoder.decode(OrchestrationStatusFile.self, from: data)

            var unblocked: [String] = []
            for (storyId, var story) in statusFile.stories {
                if story.status == .blocked {
                    let depsComplete = story.dependsOn.allSatisfy { depId in
                        statusFile.stories[depId]?.status == .complete
                    }
                    if depsComplete {
                        story.status = .ready
                        statusFile.stories[storyId] = story
                        unblocked.append(storyId)
                    }
                }
            }

            if !unblocked.isEmpty {
                statusFile.updatedAt = Date()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let updatedData = try encoder.encode(statusFile)
                try updatedData.write(to: path, options: .atomic)
                Log.dispatcher.info("Unblocked \(unblocked.count) stories: \(unblocked.joined(separator: ", "))")
                emitProgress("Unblocked stories: \(unblocked.joined(separator: ", "))")
            }
        } catch {
            Log.dispatcher.error("Failed to unblock stories: \(error)")
        }
    }

    private func handleLayerComplete(_ event: LayerCompletionEvent) async {
        Log.dispatcher.info("Layer \(event.layerIndex) completed, next stories: \(event.nextLayerStories)")

        // Update layer index
        currentLayerIndex = event.layerIndex + 1

        // Launch next layer if there are stories ready
        if !event.nextLayerStories.isEmpty {
            currentPhase = .launchingLayer
            do {
                try await launchCurrentLayer()
                currentPhase = .monitoring
            } catch {
                onError?(error)
            }
        }
    }

    private func handleAllComplete() async {
        Log.dispatcher.info("All stories complete!")
        currentPhase = .completed
        await statusMonitor?.stopMonitoring()
        onComplete?()
        emitProgress("All stories completed! 🎉")
    }

    // MARK: - Private: Launching

    private func launchCurrentLayer() async throws {
        guard currentLayerIndex < layers.count else {
            Log.dispatcher.info("No more layers to launch")
            return
        }

        let layerStoryIds = layers[currentLayerIndex]
        emitProgress("Launching layer \(currentLayerIndex + 1)/\(layers.count)...")

        // Find slots that have stories in this layer
        for (slotNumber, var info) in slotInfos {
            let slotStoriesInLayer = info.storyIds.filter { layerStoryIds.contains($0) }

            if !slotStoriesInLayer.isEmpty && info.status != .running && info.status != .completed {
                // This slot has stories to launch in this layer
                info.status = .launching
                slotInfos[slotNumber] = info
                onSlotUpdate?(info)

                do {
                    let processId = try await launchSlot(slotNumber: slotNumber)
                    info.processId = processId
                    info.status = .running
                    slotInfos[slotNumber] = info
                    onSlotUpdate?(info)
                    emitProgress("Slot \(slotNumber) running with \(info.agentType.displayName)")
                } catch {
                    info.status = .failed
                    slotInfos[slotNumber] = info
                    onSlotUpdate?(info)
                    Log.dispatcher.error("Failed to launch slot \(slotNumber): \(error)")
                }
            }
        }
    }

    private func launchSlot(slotNumber: Int) async throws -> UUID {
        guard let info = slotInfos[slotNumber],
              let repoPath = repoPath,
              let prd = prd else {
            throw DispatcherError.slotNotFound(slot: slotNumber)
        }

        let stories = prd.userStories.filter { info.storyIds.contains($0.id) }

        let config = LoopConfiguration(
            slotNumber: slotNumber,
            agentType: info.agentType,
            repoPath: repoPath,
            branchName: info.branchName,
            stories: stories,
            fullPRD: prd,
            actionType: info.actionType,
            statusFilePath: statusFilePath
        )

        // Capture the callbacks to avoid actor isolation issues
        let outputCallback = onSlotOutput
        let terminationCallback = onSlotTermination

        let processId = try await loopLauncher.launchLoop(
            config: config,
            onOutput: { output in
                // Forward output to UI
                outputCallback?(slotNumber, output)
            },
            onTermination: { slot, exitCode in
                // Handle slot termination
                Task { [weak self] in
                    await self?.handleSlotTermination(slotNumber: slot, exitCode: exitCode)
                }
                // Forward to external callback
                terminationCallback?(slot, exitCode)
            }
        )

        return processId
    }

    /// Handle slot termination and update internal state
    private func handleSlotTermination(slotNumber: Int, exitCode: Int32) async {
        guard var info = slotInfos[slotNumber] else { return }

        // Update slot status based on exit code
        if exitCode == 0 {
            info.status = .completed
            emitProgress("Slot \(slotNumber) completed successfully ✅")
        } else {
            info.status = .failed
            emitProgress("Slot \(slotNumber) failed with code \(exitCode) ❌")
        }

        info.processId = nil
        slotInfos[slotNumber] = info
        onSlotUpdate?(info)

        // Check if all slots are done
        let allDone = slotInfos.values.allSatisfy {
            $0.status == .completed || $0.status == .failed || $0.status == .pending
        }
        let anyRunning = slotInfos.values.contains { $0.status == .running || $0.status == .launching }

        if allDone && !anyRunning {
            // Check if we should launch the next layer
            let pendingSlots = slotInfos.values.filter { $0.status == .pending }
            if pendingSlots.isEmpty {
                // All slots done, no pending - dispatch complete
                currentPhase = .completed
                onComplete?()
                emitProgress("All slots completed! 🎉")
            }
        }
    }

    // MARK: - Private: Progress

    private func emitProgress(_ message: String) {
        Log.dispatcher.info("\(message)")

        let totalStories = prd?.userStories.count ?? 0

        let progress = DispatchProgress(
            phase: currentPhase,
            currentLayer: currentLayerIndex + 1,
            totalLayers: layers.count,
            slotsLaunched: slotInfos.values.filter { $0.status == .running || $0.status == .completed }.count,
            totalSlots: slotInfos.count,
            storiesComplete: completedStoryIds.count,  // Use actual completed story count
            totalStories: totalStories,
            message: message
        )

        onProgress?(progress)
    }
}

// MARK: - Errors

enum DispatcherError: LocalizedError {
    case notInitialized
    case worktreeValidationFailed(slot: Int)
    case slotNotFound(slot: Int)
    case launchFailed(slot: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Dispatcher not initialized"
        case .worktreeValidationFailed(let slot):
            return "Worktree validation failed for slot \(slot)"
        case .slotNotFound(let slot):
            return "Slot \(slot) not found"
        case .launchFailed(let slot, let reason):
            return "Failed to launch slot \(slot): \(reason)"
        }
    }
}
