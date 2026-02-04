//
//  TerminalSlotView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Individual terminal slot component for the dashboard - Redesigned to match reference
//

import SwiftUI

// MARK: - TerminalSlotView

struct TerminalSlotView: View {
    @Environment(\.appState) private var appState
    @Binding var slot: TerminalSlot
    let onStart: () -> Void
    let onStop: () -> Void
    var onSendInput: ((String) -> Void)?
    var showInputBar: Bool = true
    /// Callback to show Skills Browser filtered by this slot (US-V4-018)
    var onShowSkillsBrowser: (() -> Void)?

    @State private var isHovered: Bool = false
    @State private var showConfigPopover: Bool = false
    @State private var selectedAction: ActionType? = nil

    // Neon colors matching the brain
    private let neonCyan = Color(red: 0.0, green: 0.9, blue: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            slotHeader

            // Main content area
            if slot.isConfigured {
                terminalOutputArea
            } else {
                emptySlotContent
            }
        }
        .frame(width: 220, height: 160)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    slot.status.isActive ? agentColor.opacity(0.8) : Color(white: 0.2),
                    lineWidth: slot.status.isActive ? 1.5 : 1
                )
        )
        .shadow(
            color: slot.status.isActive ? agentColor.opacity(0.4) : .clear,
            radius: slot.status.isActive ? 12 : 0
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    // MARK: - Header

    private var slotHeader: some View {
        HStack(spacing: 6) {
            // Slot label
            Text("SLOT \(slot.slotNumber)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.9))

            // Agent indicator (colored dot + name)
            if let agent = slot.agentType {
                Circle()
                    .fill(agentColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: agentColor, radius: 3)

                Text(agent.cliDisplayName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(agentColor)
            }

            // Skills badge (US-V4-018)
            if slot.hasLoadedSkills {
                SkillsBadge(
                    skills: slot.loadedSkills,
                    availableMCPTools: appState.availableMCPTools,
                    onTap: { onShowSkillsBrowser?() }
                )
            }

            Spacer()

            // Config/Action button
            headerActionButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
    }

    // MARK: - Header Action Button

    @ViewBuilder
    private var headerActionButton: some View {
        if slot.status.canStart {
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.statusSuccess)
            }
            .buttonStyle(.plain)
        } else if slot.status.canStop {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.statusError)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showConfigPopover = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showConfigPopover, arrowEdge: .bottom) {
                SlotConfigPopover(
                    slot: $slot,
                    selectedAction: $selectedAction,
                    worktrees: appState.worktrees
                )
            }
        }
    }

    // MARK: - Terminal Output Area

    private var terminalOutputArea: some View {
        VStack(spacing: 0) {
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(slot.recentLogs) { log in
                            TerminalOutputLine(log: log, agentColor: agentColor)
                                .id(log.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .onChange(of: slot.logs.count) { _, _ in
                    if let lastLog = slot.recentLogs.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08))

            // Progress bar (when active)
            if slot.status.isActive && slot.progress > 0 {
                GeometryReader { geo in
                    Rectangle()
                        .fill(agentColor)
                        .frame(width: geo.size.width * slot.progress, height: 2)
                        .shadow(color: agentColor, radius: 3)
                }
                .frame(height: 2)
            }

            // Input bar (when process running)
            if showInputBar && slot.processId != nil {
                CompactTerminalInputBar(
                    onSubmit: { text in onSendInput?(text) },
                    isEnabled: slot.status.canStop,
                    isWaitingForInput: slot.status == .needsInput
                )
            }
        }
    }

    // MARK: - Empty Slot Content

    private var emptySlotContent: some View {
        VStack(spacing: 8) {
            Spacer()

            Text("Select Agent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))

            Text("Worktree needed")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.3))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
        .contentShape(Rectangle())
        .onTapGesture {
            showConfigPopover = true
        }
    }

    // MARK: - Computed

    private var agentColor: Color {
        slot.agentType?.neonColor ?? neonCyan
    }
}

// MARK: - Terminal Output Line

private struct TerminalOutputLine: View {
    let log: LogEntry
    let agentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(">")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(lineColor)

            Text(log.message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(lineColor)
                .lineLimit(2)
        }
    }

    private var lineColor: Color {
        switch log.level {
        case .error: return Color(red: 1.0, green: 0.4, blue: 0.4)
        case .warn: return Color(red: 1.0, green: 0.8, blue: 0.3)
        case .info: return agentColor
        case .debug: return Color.white.opacity(0.5)
        }
    }
}

// MARK: - Slot Config Popover

private struct SlotConfigPopover: View {
    @Binding var slot: TerminalSlot
    @Binding var selectedAction: ActionType?
    let worktrees: [Worktree]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text("Configure Slot \(slot.slotNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)

            Divider()
                .background(Color.white.opacity(0.2))

            // Agent selection
            VStack(alignment: .leading, spacing: 4) {
                Text("AGENT")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))

                HStack(spacing: 8) {
                    ForEach(AgentType.allCases, id: \.self) { agent in
                        AgentSelectButton(
                            agent: agent,
                            isSelected: slot.agentType == agent,
                            onSelect: {
                                slot.agentType = agent
                                selectedAction = nil
                            }
                        )
                    }
                }
            }

            // Action selection
            if slot.agentType != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTION")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))

                    Menu {
                        ForEach(ActionType.allCases, id: \.self) { action in
                            Button {
                                selectedAction = action
                            } label: {
                                Label(action.displayName, systemImage: action.iconName)
                            }
                        }
                    } label: {
                        HStack {
                            if let action = selectedAction {
                                Image(systemName: action.iconName)
                                Text(action.displayName)
                            } else {
                                Text("Select Action")
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)
                }
            }

            // Worktree selection
            VStack(alignment: .leading, spacing: 4) {
                Text("WORKTREE")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))

                Menu {
                    ForEach(worktrees) { worktree in
                        Button {
                            slot.worktree = worktree
                            if slot.agentType != nil {
                                slot.status = .ready
                            }
                        } label: {
                            Text(worktree.branch)
                        }
                    }

                    if worktrees.isEmpty {
                        Text("No worktrees available")
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                        if let wt = slot.worktree {
                            Text(wt.branch)
                        } else {
                            Text("Select Worktree")
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
    }
}

// MARK: - Agent Select Button

private struct AgentSelectButton: View {
    let agent: AgentType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(systemName: agent.iconName)
                    .font(.system(size: 14))

                Text(agent.shortName)
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(isSelected ? agent.neonColor : Color.white.opacity(0.5))
            .frame(width: 50, height: 45)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? agent.neonColor.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? agent.neonColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Action Type Badge

private struct ActionTypeBadge: View {
    let actionType: ActionType

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: actionType.iconName)
                .font(.system(size: 8))
            Text(shortName)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(Theme.Radius.xs)
    }

    private var shortName: String {
        switch actionType {
        case .implement: return "IMP"
        case .review: return "REV"
        case .integrationTest: return "TST"
        case .write: return "DOC"
        case .custom: return "CUS"
        }
    }

    private var badgeColor: Color {
        switch actionType.category {
        case .dev: return .statusInfo
        case .qa: return .statusSuccess
        case .ops: return .statusWarning
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
