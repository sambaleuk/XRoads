//
//  TerminalSlotView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Individual terminal slot component for the dashboard
//

import SwiftUI

// MARK: - TerminalSlotView

struct TerminalSlotView: View {
    @Environment(\.appState) private var appState
    @Binding var slot: TerminalSlot
    let onStart: () -> Void
    let onStop: () -> Void
    /// Callback for sending input to the process
    var onSendInput: ((String) -> Void)?
    /// Whether to show the input bar (defaults to true when configured)
    var showInputBar: Bool = true

    @State private var isHovered: Bool = false
    @State private var showAgentPicker: Bool = false
    @State private var showWorktreePicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            slotHeader

            Divider()
                .background(borderColor.opacity(0.5))

            // Content area
            if slot.isConfigured {
                terminalContent
            } else {
                configurationContent
            }
        }
        .frame(width: 200, height: showInputBar && slot.isConfigured ? 210 : 180)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(borderColor, lineWidth: isHovered || slot.status.isActive ? 2 : 1)
        )
        .shadow(color: slot.status.isActive ? borderColor.opacity(0.3) : .clear, radius: 8)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Slot Header

    private var slotHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(slot.status.isActive ? 1.5 : 1.0)
                        .opacity(slot.status.isActive ? 0.5 : 0)
                        .animation(
                            slot.status.isActive ?
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                                .default,
                            value: slot.status.isActive
                        )
                )

            // Slot title
            Text(slot.displayName)
                .font(.small)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer()

            // Agent type badge
            if let agentType = slot.agentType {
                AgentTypeBadge(agentType: agentType)
            }

            // Action button
            slotActionButton
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .frame(height: 32)
    }

    // MARK: - Action Button

    @ViewBuilder
    private var slotActionButton: some View {
        if slot.status.canStart {
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.statusSuccess)
            }
            .buttonStyle(.plain)
            .help("Start agent")
        } else if slot.status.canStop {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.statusError)
            }
            .buttonStyle(.plain)
            .help("Stop agent")
        } else if slot.status == .empty {
            Button {
                showAgentPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Configure slot")
            .popover(isPresented: $showAgentPicker) {
                AgentPickerMenu(selectedAgent: Binding(
                    get: { slot.agentType },
                    set: { slot.agentType = $0 }
                ), showWorktreePicker: $showWorktreePicker)
            }
        }
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        VStack(spacing: 0) {
            // Mini terminal output
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(slot.recentLogs) { log in
                        MiniLogLine(log: log)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.xs)
            .frame(maxHeight: .infinity)
            .background(Color.bgCanvas)

            // Progress bar (if running)
            if slot.status.isActive && slot.progress > 0 {
                ProgressView(value: slot.progress)
                    .progressViewStyle(.linear)
                    .tint(borderColor)
                    .frame(height: 3)
            }

            // Current task footer
            if let task = slot.currentTask {
                HStack {
                    Text(task)
                        .font(.xs)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 4)
                .background(Color.bgElevated)
            }

            // Input bar (when visible and process is running)
            if showInputBar && slot.processId != nil {
                CompactTerminalInputBar(
                    onSubmit: { text in
                        onSendInput?(text)
                    },
                    isEnabled: slot.status.canStop, // Only enable when process can be stopped (is running)
                    isWaitingForInput: slot.status == .needsInput
                )
            }
        }
    }

    // MARK: - Configuration Content

    private var configurationContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()

            // Agent picker
            VStack(spacing: Theme.Spacing.xs) {
                Text("Agent")
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)

                Menu {
                    ForEach(AgentType.allCases, id: \.self) { agent in
                        Button {
                            slot.agentType = agent
                        } label: {
                            Label(agent.displayName, systemImage: agent.iconName)
                        }
                    }
                } label: {
                    HStack {
                        if let agent = slot.agentType {
                            Image(systemName: agent.iconName)
                            Text(agent.displayName)
                        } else {
                            Text("Select Agent")
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.small)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.sm)
                }
                .menuStyle(.borderlessButton)
            }

            // Worktree picker
            VStack(spacing: Theme.Spacing.xs) {
                Text("Worktree")
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)

                Menu {
                    ForEach(appState.worktrees) { worktree in
                        Button {
                            slot.worktree = worktree
                            if slot.agentType != nil {
                                slot.status = .ready
                            }
                        } label: {
                            Text(worktree.branch)
                        }
                    }
                } label: {
                    HStack {
                        if let worktree = slot.worktree {
                            Image(systemName: "arrow.triangle.branch")
                            Text(worktree.branch)
                        } else {
                            Text("Select Worktree")
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.small)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.sm)
                }
                .menuStyle(.borderlessButton)
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
    }

    // MARK: - Computed Properties

    private var borderColor: Color {
        if let agentType = slot.agentType {
            return agentType.slotBorderColor
        }
        return .slotBorderEmpty
    }

    private var statusColor: Color {
        switch slot.status {
        case .empty, .configuring:
            return .textTertiary
        case .ready:
            return .statusInfo
        case .starting, .running:
            return .statusSuccess
        case .paused:
            return .statusWarning
        case .completed:
            return .accentPrimary
        case .error:
            return .statusError
        case .needsInput:
            return .statusWarning
        }
    }
}

// MARK: - Agent Type Extension

extension AgentType {
    var slotBorderColor: Color {
        switch self {
        case .claude: return .slotBorderClaude
        case .gemini: return .slotBorderGemini
        case .codex: return .slotBorderCodex
        }
    }
}

// MARK: - Agent Type Badge

private struct AgentTypeBadge: View {
    let agentType: AgentType

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: agentType.iconName)
                .font(.system(size: 8))
            Text(shortName)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(agentType.slotBorderColor)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(agentType.slotBorderColor.opacity(0.15))
        .cornerRadius(Theme.Radius.xs)
    }

    private var shortName: String {
        switch agentType {
        case .claude: return "CC"
        case .gemini: return "GM"
        case .codex: return "CX"
        }
    }
}

// MARK: - Mini Log Line

private struct MiniLogLine: View {
    let log: LogEntry

    var body: some View {
        HStack(spacing: 4) {
            Text(log.formattedTimestamp)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.textTertiary)

            Text(log.message)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(logColor)
                .lineLimit(1)
        }
    }

    private var logColor: Color {
        switch log.level {
        case .error: return .terminalRed
        case .warn: return .terminalYellow
        case .info: return .terminalCyan
        case .debug: return .textSecondary
        }
    }
}

// MARK: - Agent Picker Menu

private struct AgentPickerMenu: View {
    @Binding var selectedAgent: AgentType?
    @Binding var showWorktreePicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Select Agent")
                .font(.h3)
                .foregroundStyle(Color.textPrimary)

            ForEach(AgentType.allCases, id: \.self) { agent in
                Button {
                    selectedAgent = agent
                    showWorktreePicker = true
                } label: {
                    HStack {
                        Image(systemName: agent.iconName)
                            .foregroundStyle(agent.slotBorderColor)
                            .frame(width: 20)
                        Text(agent.displayName)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if selectedAgent == agent {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 200)
        .background(Color.bgSurface)
    }
}

// MARK: - Preview

#if DEBUG
struct TerminalSlotView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Empty slot
            TerminalSlotView(
                slot: .constant(TerminalSlot(slotNumber: 1)),
                onStart: {},
                onStop: {}
            )

            // Configured and running
            TerminalSlotView(
                slot: .constant(TerminalSlot(
                    slotNumber: 2,
                    worktree: Worktree(path: "/test/worktree", branch: "feature/auth"),
                    agentType: .claude,
                    status: .running,
                    currentTask: "Implementing login flow...",
                    progress: 0.45
                )),
                onStart: {},
                onStop: {}
            )

            // Completed
            TerminalSlotView(
                slot: .constant(TerminalSlot(
                    slotNumber: 3,
                    worktree: Worktree(path: "/test/worktree2", branch: "feature/api"),
                    agentType: .gemini,
                    status: .completed,
                    progress: 1.0
                )),
                onStart: {},
                onStop: {}
            )
        }
        .padding(Theme.Spacing.lg)
        .background(Color.bgApp)
    }
}
#endif
