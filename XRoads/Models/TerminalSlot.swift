//
//  TerminalSlot.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Terminal slot model for the hexagonal dashboard layout
//

import Foundation

/// Status of a terminal slot in the dashboard
enum TerminalSlotStatus: String, Codable, Sendable, CaseIterable {
    case empty           // No worktree/agent assigned
    case configuring     // User is selecting worktree/agent
    case ready           // Configured but not started
    case starting        // Agent is starting up
    case running         // Agent is actively working
    case paused          // Agent is paused
    case completed       // Agent finished successfully
    case error           // Agent encountered an error
    case needsInput      // Agent needs user input
    case waitingForInput // Agent is blocked waiting for user input (alias for UI clarity)

    var displayName: String {
        switch self {
        case .empty: return "Empty"
        case .configuring: return "Configuring..."
        case .ready: return "Ready"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .error: return "Error"
        case .needsInput, .waitingForInput: return "Needs Input"
        }
    }

    var isActive: Bool {
        switch self {
        case .starting, .running, .needsInput, .waitingForInput:
            return true
        default:
            return false
        }
    }

    var canStart: Bool {
        switch self {
        case .ready, .paused, .completed, .error:
            return true
        default:
            return false
        }
    }

    var canStop: Bool {
        switch self {
        case .starting, .running, .needsInput, .waitingForInput:
            return true
        default:
            return false
        }
    }

    /// Whether this status indicates the agent is waiting for user input
    var isWaitingForInput: Bool {
        switch self {
        case .needsInput, .waitingForInput:
            return true
        default:
            return false
        }
    }
}

/// Represents a terminal slot in the hexagonal dashboard
struct TerminalSlot: Identifiable, Sendable {
    let id: UUID
    let slotNumber: Int  // 1-6 for hexagonal layout
    var worktree: Worktree?
    var agentType: AgentType?
    var actionType: ActionType?  // The action/loop being executed
    var loadedSkills: [Skill]  // Skills loaded for current action
    var processId: UUID?
    var logs: [LogEntry]
    var status: TerminalSlotStatus
    var currentTask: String?
    var progress: Double  // 0.0 - 1.0
    var inputHistory: [String]  // History of user inputs sent to this slot

    /// Maximum number of input history entries to keep
    static let maxInputHistoryCount = 50

    init(
        id: UUID = UUID(),
        slotNumber: Int,
        worktree: Worktree? = nil,
        agentType: AgentType? = nil,
        actionType: ActionType? = nil,
        loadedSkills: [Skill] = [],
        processId: UUID? = nil,
        logs: [LogEntry] = [],
        status: TerminalSlotStatus = .empty,
        currentTask: String? = nil,
        progress: Double = 0.0,
        inputHistory: [String] = []
    ) {
        self.id = id
        self.slotNumber = slotNumber
        self.worktree = worktree
        self.agentType = agentType
        self.actionType = actionType
        self.loadedSkills = loadedSkills
        self.processId = processId
        self.logs = logs
        self.status = status
        self.currentTask = currentTask
        self.progress = progress
        self.inputHistory = inputHistory
    }

    /// Position angle for hexagonal layout (60 degree spacing)
    /// Slot 1 is at top (270 degrees), proceeding clockwise
    var positionAngle: Double {
        // Start from top (270 degrees / -90 degrees) and go clockwise
        let startAngle: Double = -90
        let spacing: Double = 60
        return startAngle + Double(slotNumber - 1) * spacing
    }

    /// Whether this slot has a valid configuration
    /// A slot is configured when it has a worktree, agent type, AND action type
    var isConfigured: Bool {
        worktree != nil && agentType != nil && actionType != nil
    }

    /// Whether this slot has minimal configuration (worktree + agent, but action optional)
    var hasMinimalConfiguration: Bool {
        worktree != nil && agentType != nil
    }

    /// Whether the agent is currently waiting for user input
    var needsInput: Bool {
        status.isWaitingForInput
    }

    /// Set the slot status to needsInput
    mutating func setNeedsInput(_ needs: Bool) {
        if needs && status.isActive {
            status = .needsInput
        } else if !needs && status == .needsInput {
            status = .running
        }
    }

    /// Add an input to the history
    mutating func addInput(_ input: String) {
        inputHistory.append(input)
        // Keep history bounded
        if inputHistory.count > Self.maxInputHistoryCount {
            inputHistory.removeFirst(inputHistory.count - Self.maxInputHistoryCount)
        }
    }

    /// Clear the input history
    mutating func clearInputHistory() {
        inputHistory.removeAll()
    }

    /// Get the last input sent (if any)
    var lastInput: String? {
        inputHistory.last
    }

    /// Number of skills loaded for current action
    var loadedSkillCount: Int {
        loadedSkills.count
    }

    /// Names of loaded skills for display
    var loadedSkillNames: [String] {
        loadedSkills.map { $0.name }
    }

    /// Display name for the slot
    var displayName: String {
        if let worktree = worktree {
            return worktree.branch
        }
        return "Slot \(slotNumber)"
    }

    /// Last few log lines for mini display
    var recentLogs: [LogEntry] {
        Array(logs.suffix(8))
    }

    /// Add a log entry, keeping only the last 500
    mutating func addLog(_ entry: LogEntry) {
        logs.append(entry)
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }

    /// Clear all logs
    mutating func clearLogs() {
        logs.removeAll()
    }

    /// Reset the slot to empty state
    mutating func reset() {
        worktree = nil
        agentType = nil
        actionType = nil
        loadedSkills.removeAll()
        processId = nil
        logs.removeAll()
        status = .empty
        currentTask = nil
        progress = 0.0
        inputHistory.removeAll()
    }

    /// Configure the slot with a new action
    mutating func configureAction(_ action: ActionType, skills: [Skill] = []) {
        actionType = action
        loadedSkills = skills
    }

    /// Clear action configuration (but keep worktree and agent)
    mutating func clearAction() {
        actionType = nil
        loadedSkills.removeAll()
    }
}

// MARK: - Hashable & Equatable

extension TerminalSlot: Hashable {
    static func == (lhs: TerminalSlot, rhs: TerminalSlot) -> Bool {
        // Compare all UI-relevant properties for proper SwiftUI updates
        lhs.id == rhs.id &&
        lhs.slotNumber == rhs.slotNumber &&
        lhs.worktree?.id == rhs.worktree?.id &&
        lhs.agentType == rhs.agentType &&
        lhs.actionType == rhs.actionType &&
        lhs.loadedSkills.count == rhs.loadedSkills.count &&
        lhs.loadedSkills.map(\.id) == rhs.loadedSkills.map(\.id) &&
        lhs.status == rhs.status &&
        lhs.currentTask == rhs.currentTask &&
        lhs.progress == rhs.progress &&
        lhs.logs.count == rhs.logs.count &&
        lhs.inputHistory.count == rhs.inputHistory.count &&
        lhs.needsInput == rhs.needsInput
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Convenience Extensions

extension TerminalSlot {
    /// Create a slot pre-configured with an action and skills
    static func configured(
        slotNumber: Int,
        worktree: Worktree,
        agentType: AgentType,
        actionType: ActionType,
        loadedSkills: [Skill] = []
    ) -> TerminalSlot {
        TerminalSlot(
            slotNumber: slotNumber,
            worktree: worktree,
            agentType: agentType,
            actionType: actionType,
            loadedSkills: loadedSkills,
            status: .ready
        )
    }

    /// Description of the current action for display
    var actionDescription: String {
        guard let action = actionType else {
            return "No action selected"
        }
        return action.description
    }

    /// Icon name for the current action
    var actionIconName: String {
        actionType?.iconName ?? "questionmark.circle"
    }

    /// Whether this slot has skills loaded
    var hasLoadedSkills: Bool {
        !loadedSkills.isEmpty
    }
}
