//
//  XRoadsDashboardView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Main dashboard view with Single/Agentic mode toggle
//

import SwiftUI

// MARK: - XRoadsDashboardView

struct XRoadsDashboardView: View {
    @Environment(\.appState) private var appState
    @Binding var dashboardMode: DashboardMode
    @Binding var terminalSlots: [TerminalSlot]
    @Binding var orchestratorState: OrchestratorVisualState

    /// Whether to show the internal Git panel (set to false when parent handles it)
    var showGitPanel: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with mode toggle and progress
            DashboardTopBar(
                mode: $dashboardMode,
                progress: globalProgress,
                activeAgents: activeAgentCount,
                totalAgents: configuredSlotCount,
                onStartAll: startAllAgents,
                onStopAll: stopAllAgents
            )

            Divider()
                .background(Color.borderMuted)

            // Center - Terminal Grid or Single Terminal (no internal Git panel)
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.bgApp)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        // Always show the 6-slot grid layout (agentic mode)
        TerminalGridLayout(
            slots: $terminalSlots,
            orchestratorState: orchestratorState,
            onStartSlot: startSlot,
            onStopSlot: stopSlot,
            onSendInput: { [appState] slotNumber, text in
                Task {
                    await appState.sendInputToSlot(slotNumber, text: text)
                }
            }
        )
        .padding(Theme.Spacing.md)
    }

    // MARK: - Computed Properties

    private var globalProgress: Double {
        let configured = terminalSlots.filter { $0.isConfigured }
        guard !configured.isEmpty else { return 0 }

        let totalProgress = configured.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(configured.count)
    }

    private var activeAgentCount: Int {
        terminalSlots.filter { $0.status.isActive }.count
    }

    private var configuredSlotCount: Int {
        terminalSlots.filter { $0.isConfigured }.count
    }

    // MARK: - Actions

    private func startSlot(_ slotNumber: Int) {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else {
            print("[Dashboard] Slot \(slotNumber) not found")
            return
        }

        let slot = terminalSlots[index]
        print("[Dashboard] Starting slot \(slotNumber): configured=\(slot.isConfigured), agent=\(slot.agentType?.rawValue ?? "nil"), worktree=\(slot.worktree?.branch ?? "nil"), action=\(slot.actionType?.rawValue ?? "nil")")

        // Check configuration and provide feedback
        guard slot.worktree != nil else {
            print("[Dashboard] Slot \(slotNumber) missing worktree")
            appState.addLog(LogEntry(level: .warn, source: "dashboard", worktree: nil, message: "Slot \(slotNumber): Please select a branch/worktree first"))
            return
        }
        guard slot.agentType != nil else {
            print("[Dashboard] Slot \(slotNumber) missing agent")
            appState.addLog(LogEntry(level: .warn, source: "dashboard", worktree: nil, message: "Slot \(slotNumber): Please select an agent first"))
            return
        }

        // Auto-set action if missing
        if slot.actionType == nil {
            terminalSlots[index].actionType = .implement
            print("[Dashboard] Auto-set action to .implement for slot \(slotNumber)")
        }

        terminalSlots[index].status = .starting
        updateOrchestratorState()

        Task {
            // Use unified action execution via AppState
            await appState.executeActionInSlot(
                slotNumber,
                slot: terminalSlots[index],
                mode: dashboardMode
            )

            await MainActor.run {
                // Sync slot state from AppState after execution starts
                if let updatedSlot = appState.terminalSlots.first(where: { $0.slotNumber == slotNumber }) {
                    terminalSlots[index] = updatedSlot
                }
                updateOrchestratorState()
            }
        }
    }

    private func stopSlot(_ slotNumber: Int) {
        guard let index = terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }

        Task {
            await appState.stopSlot(slotNumber)

            await MainActor.run {
                // Sync slot state from AppState after stop
                if let updatedSlot = appState.terminalSlots.first(where: { $0.slotNumber == slotNumber }) {
                    terminalSlots[index] = updatedSlot
                } else {
                    terminalSlots[index].status = .ready
                    terminalSlots[index].progress = 0
                    terminalSlots[index].currentTask = nil
                    terminalSlots[index].processId = nil
                }
                updateOrchestratorState()
            }
        }
    }

    private func startAllAgents() {
        for index in terminalSlots.indices where terminalSlots[index].isConfigured {
            startSlot(terminalSlots[index].slotNumber)
        }
    }

    private func stopAllAgents() {
        for index in terminalSlots.indices where terminalSlots[index].status.isActive {
            stopSlot(terminalSlots[index].slotNumber)
        }
    }

    private func updateOrchestratorState() {
        let activeCount = activeAgentCount
        let configuredCount = configuredSlotCount
        let hasErrors = terminalSlots.contains { $0.status == .error }
        let hasNeedsInput = terminalSlots.contains { $0.status == .needsInput }
        let allCompleted = configuredCount > 0 && terminalSlots.filter { $0.isConfigured }.allSatisfy { $0.status == .completed }

        if allCompleted {
            orchestratorState = .celebrating
        } else if hasErrors || hasNeedsInput {
            orchestratorState = .concerned
        } else if activeCount > 0 {
            orchestratorState = .monitoring
        } else if configuredCount > 0 {
            orchestratorState = .idle
        } else {
            orchestratorState = .sleeping
        }
    }
}

// MARK: - Dashboard Top Bar

struct DashboardTopBar: View {
    @Environment(\.appState) private var appState
    @Binding var mode: DashboardMode
    let progress: Double
    let activeAgents: Int
    let totalAgents: Int
    let onStartAll: () -> Void
    let onStopAll: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Orchestration status (replaces mode toggle)
            orchestrationStatus

            Divider()
                .frame(height: 24)
                .background(Color.borderMuted)

            // Progress indicator
            progressSection

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(height: Theme.Component.headerHeight)
        .background(Color.bgSurface)
        .onAppear {
            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.4
            }
        }
    }

    // MARK: - Orchestration Status

    private var orchestrationStatus: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Status indicator - pulsing dot for READY, icon for other states
            ZStack {
                if appState.dispatchPhase == .idle {
                    // Pulsing dot for READY state
                    Circle()
                        .fill(Color.statusSuccess.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .scaleEffect(pulseScale)

                    Circle()
                        .fill(Color.statusSuccess)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.statusSuccess.opacity(0.6), radius: 4)
                } else {
                    Image(systemName: orchestrationIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(orchestrationColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: appState.isDispatching)
                }
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                // Phase name
                Text(appState.dispatchPhase == .idle ? "READY" : appState.dispatchPhase.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)

                // Message or PRD name
                if let prd = appState.currentPRD {
                    Text(prd.featureName)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                } else if !appState.dispatchMessage.isEmpty {
                    Text(appState.dispatchMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                } else if appState.dispatchPhase == .idle {
                    Text("Awaiting instructions")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }

            // Layer indicator when dispatching
            if appState.isDispatching && appState.totalDispatchLayers > 0 {
                Text("L\(appState.currentDispatchLayer)/\(appState.totalDispatchLayers)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentPrimary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(minWidth: 180, alignment: .leading)
    }

    @State private var pulseScale: CGFloat = 1.0

    private var orchestrationIcon: String {
        switch appState.dispatchPhase {
        case .idle: return "circle"
        case .preparingWorktrees: return "folder.badge.plus"
        case .validatingWorktrees: return "checkmark.shield"
        case .launchingLayer: return "play.circle"
        case .monitoring: return "eye.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var orchestrationColor: Color {
        switch appState.dispatchPhase {
        case .idle: return Color.textTertiary
        case .preparingWorktrees, .validatingWorktrees: return Color.accentPrimary
        case .launchingLayer: return Color.statusWarning
        case .monitoring: return Color.statusSuccess
        case .completed: return Color.statusSuccess
        case .failed: return Color.statusError
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Story progress when dispatching
            if let dispatchProgress = appState.dispatchProgress {
                VStack(alignment: .leading, spacing: 3) {
                    // Custom progress bar with better contrast
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.borderMuted.opacity(0.5))
                                .frame(height: 4)

                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.statusSuccess)
                                .frame(width: geo.size.width * Double(dispatchProgress.storiesComplete) / Double(max(1, dispatchProgress.totalStories)), height: 4)
                                .shadow(color: Color.statusSuccess.opacity(0.5), radius: 2)
                        }
                    }
                    .frame(width: 140, height: 4)

                    Text("\(dispatchProgress.storiesComplete)/\(dispatchProgress.totalStories) stories")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                // Fallback to slot progress
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.borderMuted.opacity(0.5))
                                .frame(height: 4)

                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentPrimary)
                                .frame(width: geo.size.width * progress, height: 4)
                                .shadow(color: Color.accentPrimary.opacity(0.5), radius: 2)
                        }
                    }
                    .frame(width: 120, height: 4)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                }
            }

            // Divider
            Divider()
                .frame(height: 20)
                .background(Color.borderMuted)

            // Active agents count with better styling
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(activeAgents > 0 ? Color.statusSuccess : Color.textTertiary)
                    .frame(width: 6, height: 6)
                    .shadow(color: activeAgents > 0 ? Color.statusSuccess.opacity(0.5) : .clear, radius: 3)

                Text("\(activeAgents)/\(totalAgents)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(activeAgents > 0 ? Color.textPrimary : Color.textSecondary)

                Text("agents")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if appState.isDispatching {
                Button(action: onStopAll) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("Stop")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Color.statusError.opacity(0.15))
                    .foregroundStyle(Color.statusError)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(Color.statusError.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onStartAll) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Start All")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(totalAgents == 0 ? Color.textTertiary.opacity(0.15) : Color.statusSuccess.opacity(0.2))
                    .foregroundStyle(totalAgents == 0 ? Color.textTertiary : Color.statusSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(totalAgents == 0 ? Color.borderMuted : Color.statusSuccess.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(totalAgents == 0)

                Button(action: onStopAll) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("Stop")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(activeAgents == 0 ? Color.textTertiary.opacity(0.1) : Color.borderMuted.opacity(0.5))
                    .foregroundStyle(activeAgents == 0 ? Color.textTertiary : Color.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(Color.borderMuted, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(activeAgents == 0)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct XRoadsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        XRoadsDashboardView(
            dashboardMode: .constant(.agentic),
            terminalSlots: .constant(previewSlots),
            orchestratorState: .constant(.monitoring)
        )
        .frame(width: 1280, height: 800)
        .environment(\.appState, previewAppState())
    }

    static var previewSlots: [TerminalSlot] {
        [
            TerminalSlot(
                slotNumber: 1,
                worktree: Worktree(path: "/test/wt1", branch: "feature/auth"),
                agentType: .claude,
                status: .running,
                currentTask: "Implementing login flow...",
                progress: 0.45
            ),
            TerminalSlot(
                slotNumber: 2,
                worktree: Worktree(path: "/test/wt2", branch: "feature/api"),
                agentType: .gemini,
                status: .running,
                currentTask: "Building API endpoints...",
                progress: 0.30
            ),
            TerminalSlot(
                slotNumber: 3,
                worktree: Worktree(path: "/test/wt3", branch: "feature/ui"),
                agentType: .codex,
                status: .completed,
                progress: 1.0
            ),
            TerminalSlot(slotNumber: 4, status: .empty),
            TerminalSlot(slotNumber: 5, status: .empty),
            TerminalSlot(
                slotNumber: 6,
                worktree: Worktree(path: "/test/wt6", branch: "fix/bug"),
                agentType: .claude,
                status: .error
            )
        ]
    }

    static func previewAppState() -> AppState {
        let state = AppState()
        state.worktrees = [
            Worktree(path: "/test/wt1", branch: "feature/auth"),
            Worktree(path: "/test/wt2", branch: "feature/api"),
            Worktree(path: "/test/wt3", branch: "feature/ui")
        ]
        return state
    }
}
#endif
