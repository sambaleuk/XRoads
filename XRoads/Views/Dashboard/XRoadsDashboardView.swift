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
        switch dashboardMode {
        case .single:
            SingleTerminalLayout(
                slot: $terminalSlots[0],
                onStart: { startSlot(1) },
                onStop: { stopSlot(1) },
                onSendInput: { [appState] text in
                    Task {
                        await appState.sendInputToSlot(1, text: text)
                    }
                }
            )
            .padding(Theme.Spacing.md)

        case .agentic:
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
    @Binding var mode: DashboardMode
    let progress: Double
    let activeAgents: Int
    let totalAgents: Int
    let onStartAll: () -> Void
    let onStopAll: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Mode toggle
            modeToggle

            Divider()
                .frame(height: 24)

            // Progress indicator
            progressSection

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(height: 48)
        .background(Color.bgSurface)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 2) {
            ForEach(DashboardMode.allCases, id: \.self) { dashboardMode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = dashboardMode
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: dashboardMode.iconName)
                            .font(.system(size: 12))
                        Text(dashboardMode.displayName)
                            .font(.small)
                    }
                    .foregroundStyle(mode == dashboardMode ? Color.textPrimary : Color.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(mode == dashboardMode ? Color.bgElevated : .clear)
                    .cornerRadius(Theme.Radius.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.bgApp)
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.accentPrimary)
                .frame(width: 120)

            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.small)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 40, alignment: .trailing)

            // Active agents count
            HStack(spacing: 4) {
                Circle()
                    .fill(activeAgents > 0 ? Color.statusSuccess : Color.textTertiary)
                    .frame(width: 6, height: 6)

                Text("\(activeAgents)/\(totalAgents)")
                    .font(.xs)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onStartAll) {
                Label("Start All", systemImage: "play.fill")
                    .font(.small)
            }
            .buttonStyle(.borderedProminent)
            .tint(.statusSuccess)
            .controlSize(.small)
            .disabled(totalAgents == 0)

            Button(action: onStopAll) {
                Label("Stop All", systemImage: "stop.fill")
                    .font(.small)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(activeAgents == 0)
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
