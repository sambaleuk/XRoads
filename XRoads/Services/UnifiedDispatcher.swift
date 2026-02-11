//
//  UnifiedDispatcher.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  Single entry point for all dispatch operations
//  Resolves the dual-launch system inconsistency
//

import Foundation

// MARK: - Dispatch Mode

/// Determines how dispatch should be handled
enum DispatchMode: String, Sendable {
    case single     // Single slot, no PRD, no dependencies
    case prd        // PRD-based multi-slot with dependency layers
    case chat       // Chat-initiated action (future)
    case quickAction // Quick action button (future)
}

// MARK: - Dispatch Request

/// Unified request for any type of dispatch
struct DispatchRequest: Sendable {
    let id: UUID
    let mode: DispatchMode
    let source: DispatchSource

    // Single mode params
    let slotNumber: Int?
    let agentType: AgentType?
    let worktreePath: String?
    let actionType: ActionType?
    let taskDescription: String?

    // PRD mode params
    let prd: PRDDocument?
    let slotAssignments: [Int: (agentType: AgentType, actionType: ActionType, storyIds: [String])]?
    let repoPath: URL?

    // Chat mode params (future)
    let chatIntent: String?

    // Resume mode: preserve existing status.json and skip completed layers
    let resumeMode: Bool

    init(
        id: UUID = UUID(),
        mode: DispatchMode,
        source: DispatchSource,
        slotNumber: Int? = nil,
        agentType: AgentType? = nil,
        worktreePath: String? = nil,
        actionType: ActionType? = nil,
        taskDescription: String? = nil,
        prd: PRDDocument? = nil,
        slotAssignments: [Int: (agentType: AgentType, actionType: ActionType, storyIds: [String])]? = nil,
        repoPath: URL? = nil,
        chatIntent: String? = nil,
        resumeMode: Bool = false
    ) {
        self.id = id
        self.mode = mode
        self.source = source
        self.slotNumber = slotNumber
        self.agentType = agentType
        self.worktreePath = worktreePath
        self.actionType = actionType
        self.taskDescription = taskDescription
        self.prd = prd
        self.slotAssignments = slotAssignments
        self.repoPath = repoPath
        self.chatIntent = chatIntent
        self.resumeMode = resumeMode
    }

    /// Create a single slot dispatch request
    static func single(
        slotNumber: Int,
        agentType: AgentType,
        worktreePath: String,
        actionType: ActionType = .implement,
        taskDescription: String? = nil,
        source: DispatchSource = .slotPlayButton
    ) -> DispatchRequest {
        DispatchRequest(
            mode: .single,
            source: source,
            slotNumber: slotNumber,
            agentType: agentType,
            worktreePath: worktreePath,
            actionType: actionType,
            taskDescription: taskDescription
        )
    }

    /// Create a PRD-based dispatch request
    static func prd(
        prd: PRDDocument,
        slotAssignments: [Int: (agentType: AgentType, actionType: ActionType, storyIds: [String])],
        repoPath: URL,
        source: DispatchSource = .prdLoader,
        resumeMode: Bool = false
    ) -> DispatchRequest {
        DispatchRequest(
            mode: .prd,
            source: source,
            prd: prd,
            slotAssignments: slotAssignments,
            repoPath: repoPath,
            resumeMode: resumeMode
        )
    }

    /// Create a chat-initiated dispatch request (future)
    static func chat(
        intent: String,
        slotNumber: Int? = nil,
        agentType: AgentType? = nil
    ) -> DispatchRequest {
        DispatchRequest(
            mode: .chat,
            source: .chat,
            slotNumber: slotNumber,
            agentType: agentType,
            chatIntent: intent
        )
    }
}

// MARK: - Dispatch Source

/// Where the dispatch request originated
enum DispatchSource: String, Sendable {
    case prdLoader      // PRDLoaderSheet → SlotAssignmentSheet
    case slotPlayButton // TerminalSlotView play button
    case startAllButton // Dashboard "Start All" button
    case chat           // OrchestratorChatView
    case quickAction    // GitInfoPanel quick action
    case api            // External API (future)
}

// MARK: - Dispatch Result

/// Result of a dispatch operation
struct DispatchResult: Sendable {
    let requestId: UUID
    let success: Bool
    let processIds: [UUID]
    let error: Error?
    let startedAt: Date
    let mode: DispatchMode
}

// MARK: - Dispatch Callbacks

/// Callbacks for dispatch events
struct DispatchCallbacks: Sendable {
    let onProgress: @Sendable (DispatchProgress) -> Void
    let onSlotUpdate: @Sendable (SlotLaunchInfo) -> Void
    let onSlotOutput: @Sendable (Int, String) -> Void
    let onSlotTermination: @Sendable (Int, Int32) -> Void  // (slotNumber, exitCode)
    let onLog: @Sendable (LogEntry) -> Void
    let onComplete: @Sendable () -> Void
    let onError: @Sendable (Error) -> Void

    static let empty = DispatchCallbacks(
        onProgress: { _ in },
        onSlotUpdate: { _ in },
        onSlotOutput: { _, _ in },
        onSlotTermination: { _, _ in },
        onLog: { _ in },
        onComplete: { },
        onError: { _ in }
    )
}

// MARK: - UnifiedDispatcher

/// Central dispatcher that routes all execution requests
/// Resolves the dual-launch system by providing a single entry point
actor UnifiedDispatcher {

    // MARK: - Dependencies

    private let layeredDispatcher: LayeredDispatcher
    private let actionRunner: ActionRunner
    private let gitService: GitService

    // MARK: - State

    private var activeRequests: [UUID: DispatchRequest] = [:]
    private var requestResults: [UUID: DispatchResult] = [:]

    // MARK: - Initialization

    init(
        layeredDispatcher: LayeredDispatcher? = nil,
        actionRunner: ActionRunner? = nil,
        gitService: GitService? = nil
    ) {
        self.layeredDispatcher = layeredDispatcher ?? LayeredDispatcher()
        self.actionRunner = actionRunner ?? ActionRunner()
        self.gitService = gitService ?? GitService()
    }

    // MARK: - Public API

    /// Dispatch a request through the unified system
    /// - Parameters:
    ///   - request: The dispatch request
    ///   - callbacks: Callbacks for events
    /// - Returns: The dispatch result
    func dispatch(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        // Track the request
        activeRequests[request.id] = request

        // Log dispatch start
        callbacks.onLog(LogEntry(
            level: .info,
            source: "dispatcher",
            worktree: nil,
            message: "[\(request.source.rawValue)] Starting \(request.mode.rawValue) dispatch"
        ))

        let result: DispatchResult

        do {
            switch request.mode {
            case .single:
                result = try await dispatchSingle(request, callbacks: callbacks)

            case .prd:
                result = try await dispatchPRD(request, callbacks: callbacks)

            case .chat:
                result = try await dispatchChat(request, callbacks: callbacks)

            case .quickAction:
                result = try await dispatchQuickAction(request, callbacks: callbacks)
            }

            requestResults[request.id] = result

            // For PRD mode, onComplete is deferred to LayeredDispatcher
            // (fires when all slots actually finish, not when launch returns)
            if request.mode != .prd {
                callbacks.onComplete()
            }

            return result

        } catch {
            let errorResult = DispatchResult(
                requestId: request.id,
                success: false,
                processIds: [],
                error: error,
                startedAt: Date(),
                mode: request.mode
            )

            requestResults[request.id] = errorResult
            callbacks.onError(error)

            return errorResult
        }
    }

    /// Cancel an active dispatch
    func cancel(_ requestId: UUID) async {
        guard let request = activeRequests[requestId] else { return }

        switch request.mode {
        case .prd:
            await layeredDispatcher.stopAll()
        case .single:
            // Stop via ActionRunner if process ID is tracked
            break
        default:
            break
        }

        activeRequests.removeValue(forKey: requestId)
    }

    /// Get status of a dispatch request
    func status(_ requestId: UUID) -> (active: Bool, result: DispatchResult?) {
        let isActive = activeRequests[requestId] != nil
        let result = requestResults[requestId]
        return (isActive, result)
    }

    // MARK: - Private: Single Mode Dispatch

    private func dispatchSingle(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        guard let slotNumber = request.slotNumber,
              let agentType = request.agentType,
              let worktreePath = request.worktreePath else {
            throw UnifiedDispatcherError.missingParameters(mode: .single)
        }

        let actionType = request.actionType ?? .implement

        // Create ActionRunRequest
        let runRequest = ActionRunRequest(
            actionType: actionType,
            agentType: agentType,
            worktreePath: worktreePath,
            sessionID: request.id,
            taskDescription: request.taskDescription
        )

        // Run via ActionRunner with unified output handling
        let runResult = try await actionRunner.run(request: runRequest) { output in
            // Route to callbacks
            callbacks.onSlotOutput(slotNumber, output)

            // Create log entry
            let logEntry = LogEntry(
                level: .info,
                source: agentType.rawValue,
                worktree: worktreePath,
                message: output
            )
            callbacks.onLog(logEntry)
        }

        return DispatchResult(
            requestId: request.id,
            success: true,
            processIds: [runResult.processID],
            error: nil,
            startedAt: runResult.startedAt,
            mode: .single
        )
    }

    // MARK: - Private: PRD Mode Dispatch

    private func dispatchPRD(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        guard let prd = request.prd,
              let slotAssignments = request.slotAssignments,
              let repoPath = request.repoPath else {
            throw UnifiedDispatcherError.missingParameters(mode: .prd)
        }

        // Track process IDs as they're created
        var processIds: [UUID] = []
        let startedAt = Date()

        // Use LayeredDispatcher with unified callbacks
        await layeredDispatcher.startDispatch(
            prd: prd,
            slotAssignments: slotAssignments,
            repoPath: repoPath,
            resumeMode: request.resumeMode,
            onProgress: { progress in
                callbacks.onProgress(progress)
            },
            onSlotUpdate: { slotInfo in
                if let processId = slotInfo.processId {
                    processIds.append(processId)
                }
                callbacks.onSlotUpdate(slotInfo)
            },
            onSlotOutput: { slotNumber, output in
                callbacks.onSlotOutput(slotNumber, output)

                // Also route to global logs
                let logEntry = LogEntry(
                    level: .info,
                    source: "slot-\(slotNumber)",
                    worktree: nil,
                    message: output
                )
                callbacks.onLog(logEntry)
            },
            onSlotTermination: { slotNumber, exitCode in
                // Forward slot termination to callbacks
                callbacks.onSlotTermination(slotNumber, exitCode)

                // Log the termination
                let level: LogLevel = exitCode == 0 ? .info : .error
                let status = exitCode == 0 ? "completed" : "failed (code \(exitCode))"
                let logEntry = LogEntry(
                    level: level,
                    source: "slot-\(slotNumber)",
                    worktree: nil,
                    message: "Loop \(status)"
                )
                callbacks.onLog(logEntry)
            },
            onComplete: {
                callbacks.onComplete()
            },
            onError: { error in
                callbacks.onError(error)
            }
        )

        return DispatchResult(
            requestId: request.id,
            success: true,
            processIds: processIds,
            error: nil,
            startedAt: startedAt,
            mode: .prd
        )
    }

    // MARK: - Private: Chat Mode Dispatch

    private func dispatchChat(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        guard let intent = request.chatIntent else {
            throw UnifiedDispatcherError.missingParameters(mode: .chat)
        }

        callbacks.onLog(LogEntry(
            level: .info,
            source: "dispatcher",
            worktree: nil,
            message: "[chat] Processing intent: \(intent)"
        ))

        switch intent {
        case "launch_slot":
            return try await dispatchChatLaunchSlot(request, callbacks: callbacks)

        case "stop_slot":
            return try await dispatchChatStopSlot(request, callbacks: callbacks)

        case "start_all":
            return try await dispatchChatStartAll(request, callbacks: callbacks)

        case "stop_all":
            return try await dispatchChatStopAll(request, callbacks: callbacks)

        case "configure_slot":
            // Configuration is UI-only, return success immediately
            callbacks.onLog(LogEntry(
                level: .info,
                source: "dispatcher",
                worktree: nil,
                message: "[chat] Slot configuration requested via chat - triggering UI update"
            ))
            return DispatchResult(
                requestId: request.id,
                success: true,
                processIds: [],
                error: nil,
                startedAt: Date(),
                mode: .chat
            )

        default:
            throw UnifiedDispatcherError.dispatchFailed(reason: "Unknown chat intent: \(intent)")
        }
    }

    // MARK: - Chat Intent Handlers

    private func dispatchChatLaunchSlot(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        guard let slotNumber = request.slotNumber else {
            throw UnifiedDispatcherError.dispatchFailed(reason: "Missing slot number for launch")
        }

        guard let agentType = request.agentType else {
            throw UnifiedDispatcherError.dispatchFailed(reason: "Missing agent type for slot \(slotNumber)")
        }

        guard let worktreePath = request.worktreePath else {
            throw UnifiedDispatcherError.dispatchFailed(reason: "Missing worktree path for slot \(slotNumber)")
        }

        callbacks.onLog(LogEntry(
            level: .info,
            source: "dispatcher",
            worktree: worktreePath,
            message: "[chat] Launching slot \(slotNumber) with \(agentType.displayName)"
        ))

        // Create single dispatch request and delegate
        let singleRequest = DispatchRequest.single(
            slotNumber: slotNumber,
            agentType: agentType,
            worktreePath: worktreePath,
            actionType: request.actionType ?? .implement,
            taskDescription: request.taskDescription,
            source: .chat
        )

        return try await dispatchSingle(singleRequest, callbacks: callbacks)
    }

    private func dispatchChatStopSlot(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        guard let slotNumber = request.slotNumber else {
            throw UnifiedDispatcherError.dispatchFailed(reason: "Missing slot number for stop")
        }

        callbacks.onLog(LogEntry(
            level: .info,
            source: "dispatcher",
            worktree: nil,
            message: "[chat] Stop request for slot \(slotNumber)"
        ))

        // Note: Actual stopping would require tracking process IDs in state
        // For now, we signal success and let the UI handle the stop
        return DispatchResult(
            requestId: request.id,
            success: true,
            processIds: [],
            error: nil,
            startedAt: Date(),
            mode: .chat
        )
    }

    private func dispatchChatStartAll(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        callbacks.onLog(LogEntry(
            level: .info,
            source: "dispatcher",
            worktree: nil,
            message: "[chat] Start all slots requested - this requires PRD or slot configuration"
        ))

        // Check if we have PRD info
        guard let prd = request.prd,
              let slotAssignments = request.slotAssignments,
              let repoPath = request.repoPath else {
            // No PRD context - return error suggesting PRD load
            throw UnifiedDispatcherError.dispatchFailed(
                reason: "Start all requires PRD configuration. Use 'load PRD' first."
            )
        }

        // Delegate to PRD dispatch
        let prdRequest = DispatchRequest.prd(
            prd: prd,
            slotAssignments: slotAssignments,
            repoPath: repoPath,
            source: .chat
        )

        return try await dispatchPRD(prdRequest, callbacks: callbacks)
    }

    private func dispatchChatStopAll(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        callbacks.onLog(LogEntry(
            level: .info,
            source: "dispatcher",
            worktree: nil,
            message: "[chat] Stop all agents requested"
        ))

        // Use layered dispatcher to stop all
        await layeredDispatcher.stopAll()

        return DispatchResult(
            requestId: request.id,
            success: true,
            processIds: [],
            error: nil,
            startedAt: Date(),
            mode: .chat
        )
    }

    // MARK: - Private: Quick Action Dispatch (Future)

    private func dispatchQuickAction(
        _ request: DispatchRequest,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        // Quick action dispatch is not yet implemented.
        // Falls back to single mode when slot parameters are available.
        if request.slotNumber != nil && request.agentType != nil && request.worktreePath != nil {
            return try await dispatchSingle(request, callbacks: callbacks)
        }

        throw UnifiedDispatcherError.notImplemented(feature: "quick action dispatch")
    }
}

// MARK: - Errors

enum UnifiedDispatcherError: LocalizedError {
    case missingParameters(mode: DispatchMode)
    case notImplemented(feature: String)
    case dispatchFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .missingParameters(let mode):
            return "Missing required parameters for \(mode.rawValue) dispatch"
        case .notImplemented(let feature):
            return "\(feature) is not yet implemented"
        case .dispatchFailed(let reason):
            return "Dispatch failed: \(reason)"
        }
    }
}
