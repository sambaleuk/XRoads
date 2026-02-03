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
        case .needsInput: return "Needs Input"
        }
    }

    var isActive: Bool {
        switch self {
        case .starting, .running:
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
        case .starting, .running, .needsInput:
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
    var processId: UUID?
    var logs: [LogEntry]
    var status: TerminalSlotStatus
    var currentTask: String?
    var progress: Double  // 0.0 - 1.0

    init(
        id: UUID = UUID(),
        slotNumber: Int,
        worktree: Worktree? = nil,
        agentType: AgentType? = nil,
        processId: UUID? = nil,
        logs: [LogEntry] = [],
        status: TerminalSlotStatus = .empty,
        currentTask: String? = nil,
        progress: Double = 0.0
    ) {
        self.id = id
        self.slotNumber = slotNumber
        self.worktree = worktree
        self.agentType = agentType
        self.processId = processId
        self.logs = logs
        self.status = status
        self.currentTask = currentTask
        self.progress = progress
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
    var isConfigured: Bool {
        worktree != nil && agentType != nil
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

    /// Add a log entry, keeping only the last 50
    mutating func addLog(_ entry: LogEntry) {
        logs.append(entry)
        if logs.count > 50 {
            logs.removeFirst(logs.count - 50)
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
        processId = nil
        logs.removeAll()
        status = .empty
        currentTask = nil
        progress = 0.0
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
        lhs.status == rhs.status &&
        lhs.currentTask == rhs.currentTask &&
        lhs.progress == rhs.progress &&
        lhs.logs.count == rhs.logs.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
