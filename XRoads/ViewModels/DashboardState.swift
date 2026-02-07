import Foundation
import SwiftUI

// MARK: - DashboardState

/// Manages dashboard visual state: terminal slots, orchestrator visualization,
/// display mode, git info, and MCP tool availability.
/// Extracted from AppState (CR-301) to reduce God Object complexity.
@MainActor
@Observable
final class DashboardState {

    // MARK: - Dashboard Mode

    /// Current dashboard display mode (Single/Agentic)
    var dashboardMode: DashboardMode = .agentic

    // MARK: - Terminal Slots

    /// Terminal slots for the hexagonal dashboard (6 slots)
    var terminalSlots: [TerminalSlot] = (1...6).map { TerminalSlot(slotNumber: $0) }

    // MARK: - Orchestrator Visualization

    /// Visual state of the central orchestrator creature
    var orchestratorVisualState: OrchestratorVisualState = .sleeping

    // MARK: - MCP Tools

    /// Available MCP tools for checking skill dependencies
    var availableMCPTools: Set<String> = Set(["git", "file-read", "file-edit", "bash", "web-search"])

    // MARK: - Git Info

    /// Recent git commits for the right side panel
    var recentCommits: [GitCommit] = []

    /// Whether the current project path is a git repository
    var isGitRepository: Bool = false

    /// Whether git initialization is in progress
    var isInitializingGit: Bool = false

    // MARK: - Computed Properties

    /// Active terminal slots (slots that are currently running)
    var activeSlots: [TerminalSlot] {
        terminalSlots.filter { $0.status.isActive }
    }

    /// Configured terminal slots (slots with worktree and agent assigned)
    var configuredSlots: [TerminalSlot] {
        terminalSlots.filter { $0.isConfigured }
    }

    /// Angles of active slots for orchestrator visualization
    var activeSlotAngles: [Double] {
        activeSlots.map { $0.positionAngle }
    }

    /// Global progress across all configured terminal slots
    var terminalSlotsProgress: Double {
        let configured = configuredSlots
        guard !configured.isEmpty else { return 0 }
        let totalProgress = configured.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(configured.count)
    }

    // MARK: - Orchestrator Visual State Updates

    /// Updates the orchestrator visual state based on slot states.
    /// - Parameter isDispatching: Whether a layered dispatch is actively in progress.
    ///   When true, prevents retrograding to `.idle` between layers.
    func updateOrchestratorVisualState(isDispatching: Bool = false) {
        let activeCount = activeSlots.count
        let configuredCount = configuredSlots.count
        let hasErrors = terminalSlots.contains { $0.status == .error }
        let hasNeedsInput = terminalSlots.contains { $0.status == .needsInput }
        let allCompleted = configuredCount > 0 && configuredSlots.allSatisfy { $0.status == .completed }

        if allCompleted {
            orchestratorVisualState = .celebrating
        } else if hasErrors || hasNeedsInput {
            orchestratorVisualState = .concerned
        } else if activeCount > 0 {
            orchestratorVisualState = .monitoring
        } else if isDispatching {
            // Between layers: slots finished but next layer hasn't launched yet.
            // Stay in monitoring to avoid "Waiting for instructions" flicker.
            orchestratorVisualState = .monitoring
        } else if configuredCount > 0 {
            orchestratorVisualState = .idle
        } else {
            orchestratorVisualState = .sleeping
        }
    }

    /// Update orchestrator visual state after a slot terminates.
    /// - Parameter isDispatching: Whether a layered dispatch is actively in progress.
    func updateOrchestratorStateAfterTermination(isDispatching: Bool = false) {
        let runningSlots = terminalSlots.filter { $0.status == .running }
        let completedSlots = terminalSlots.filter { $0.status == .completed }
        let failedSlots = terminalSlots.filter { $0.status == .error }
        let configuredSlots = terminalSlots.filter { $0.isConfigured }

        if runningSlots.isEmpty {
            if !failedSlots.isEmpty {
                orchestratorVisualState = .concerned
            } else if completedSlots.count == configuredSlots.count && !configuredSlots.isEmpty {
                orchestratorVisualState = .celebrating
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    self?.orchestratorVisualState = .idle
                }
            } else if isDispatching {
                // Between layers: keep monitoring instead of idle
                orchestratorVisualState = .monitoring
            } else {
                orchestratorVisualState = .idle
            }
        }
    }
}
