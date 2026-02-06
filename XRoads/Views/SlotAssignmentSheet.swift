//
//  SlotAssignmentSheet.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Manual slot assignment for PRD dispatch
//

import SwiftUI

/// Assignment of stories to a slot
struct SlotStoryAssignment: Identifiable {
    let id = UUID()
    var slotNumber: Int
    var agentType: AgentType
    var actionType: ActionType  // Role/action for this slot
    var storyIds: [String]
    var worktreePath: String
}

/// Sheet for manually assigning PRD stories to terminal slots
struct SlotAssignmentSheet: View {
    let prd: PRDDocument
    let repoPath: URL
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState

    @State private var assignments: [Int: SlotStoryAssignment] = [:]
    @State private var selectedSlot: Int? = 1
    @State private var isStarting = false
    @State private var errorMessage: String?

    // Dispatch progress
    @State private var dispatchPhase: DispatchPhase = .idle
    @State private var dispatchMessage: String = ""
    @State private var dispatchProgress: DispatchProgress?
    @State private var slotStatuses: [Int: SlotLaunchInfo] = [:]
    @State private var isDispatching = false

    // Available agents
    private let agents: [AgentType] = [.claude, .gemini, .codex]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isDispatching {
                dispatchProgressView
            } else {
                content
            }
            Divider()
            footer
        }
        .frame(width: 1100, height: 700)
        .background(Color.bgApp)
    }

    // MARK: - Dispatch Progress View

    private var dispatchProgressView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            // Phase indicator
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: phaseIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(phaseColor)
                    .symbolEffect(.pulse, options: .repeating)

                Text(dispatchPhase.rawValue.uppercased())
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(dispatchMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            // Progress bar
            if let progress = dispatchProgress {
                VStack(spacing: Theme.Spacing.sm) {
                    ProgressView(value: Double(progress.storiesComplete), total: Double(max(1, progress.totalStories)))
                        .tint(Color.statusSuccess)
                        .frame(width: 300)

                    Text("Layer \(progress.currentLayer)/\(progress.totalLayers) • \(progress.storiesComplete)/\(progress.totalStories) stories")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Slot statuses
            if !slotStatuses.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(slotStatuses.values.sorted(by: { $0.slotNumber < $1.slotNumber })) { info in
                        HStack {
                            Circle()
                                .fill(slotStatusColor(info.status))
                                .frame(width: 8, height: 8)

                            Text("Slot \(info.slotNumber)")
                                .font(.caption.bold())
                                .foregroundStyle(Color.textPrimary)

                            Text(info.agentType.displayName)
                                .font(.caption)
                                .foregroundStyle(info.agentType.neonColor)

                            Spacer()

                            Text(info.status.rawValue)
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .padding()
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .frame(maxWidth: 400)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }

    private var phaseIcon: String {
        switch dispatchPhase {
        case .idle: return "circle"
        case .preparingWorktrees: return "folder.badge.plus"
        case .validatingWorktrees: return "checkmark.circle"
        case .launchingLayer: return "play.circle"
        case .monitoring: return "eye.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var phaseColor: Color {
        switch dispatchPhase {
        case .idle: return Color.textTertiary
        case .preparingWorktrees, .validatingWorktrees: return Color.accentPrimary
        case .launchingLayer, .monitoring: return Color.statusWarning
        case .completed: return Color.statusSuccess
        case .failed: return Color.statusError
        }
    }

    private func slotStatusColor(_ status: SlotLaunchInfo.SlotLaunchStatus) -> Color {
        switch status {
        case .pending: return Color.textTertiary
        case .worktreeCreated: return Color.accentPrimary
        case .launching: return Color.statusWarning
        case .running: return Color.statusSuccess
        case .completed: return Color.statusSuccess
        case .failed: return Color.statusError
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "square.grid.3x3")
                    .font(.title2)
                    .foregroundStyle(Color.accentPrimary)
                Text("Assign Stories to Slots")
                    .font(.title2.bold())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text("PRD: \(prd.featureName) • \(prd.userStories.count) stories")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Content

    private var content: some View {
        HStack(spacing: 0) {
            // Left: Story List
            storyList
                .frame(width: 300)

            Divider()

            // Center: Slot Grid
            slotGrid
                .frame(maxWidth: .infinity)

            Divider()

            // Right: Slot Details
            slotDetails
                .frame(width: 280)
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("STORIES")
                .font(.caption.bold())
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.xs) {
                    ForEach(prd.userStories) { story in
                        StoryRowView(
                            story: story,
                            isAssigned: isStoryAssigned(story.id),
                            assignedTo: slotForStory(story.id)
                        )
                        .onTapGesture {
                            toggleStoryAssignment(story.id)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .background(Color.bgSurface)
    }

    // MARK: - Slot Grid

    private var slotGrid: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("SLOT CONFIGURATION")
                .font(.caption.bold())
                .foregroundStyle(Color.textSecondary)

            // 2x3 Grid of slots
            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    slotCard(1)
                    slotCard(2)
                    slotCard(3)
                }
                HStack(spacing: Theme.Spacing.md) {
                    slotCard(4)
                    slotCard(5)
                    slotCard(6)
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }

    private func slotCard(_ slotNumber: Int) -> some View {
        let assignment = assignments[slotNumber]
        let isSelected = selectedSlot == slotNumber
        let storyCount = assignment?.storyIds.count ?? 0

        return VStack(spacing: Theme.Spacing.sm) {
            // Slot header
            HStack {
                Text("SLOT \(slotNumber)")
                    .font(.caption.bold())
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if let agent = assignment?.agentType {
                    Text(agent.shortName)
                        .font(.caption.bold())
                        .foregroundStyle(agent.neonColor)
                }
            }

            // Agent picker
            if let agent = assignment?.agentType {
                HStack {
                    Image(systemName: agent.iconName)
                        .foregroundStyle(agent.neonColor)
                    Text(agent.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.textPrimary)
                }
            } else {
                Text("No agent")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }

            Divider()

            // Story count
            if storyCount > 0 {
                Text("\(storyCount) stories")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 140, height: 120)
        .background(isSelected ? Color.accentPrimary.opacity(0.1) : Color.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(isSelected ? Color.accentPrimary : Color.borderMuted, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .onTapGesture {
            selectedSlot = slotNumber
        }
    }

    // MARK: - Slot Details

    private var slotDetails: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let slotNumber = selectedSlot {
                Text("SLOT \(slotNumber) DETAILS")
                    .font(.caption.bold())
                    .foregroundStyle(Color.textSecondary)

                // Agent selector
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Agent")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(agents, id: \.self) { agent in
                            agentButton(agent, for: slotNumber)
                        }
                    }
                }

                Divider()

                // Action/Role selector
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Action/Role")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.xs) {
                            ForEach(ActionType.allCases, id: \.self) { action in
                                actionButton(action, for: slotNumber)
                            }
                        }
                    }

                    // Show action description
                    if let assignment = assignments[slotNumber] {
                        Text(assignment.actionType.description)
                            .font(.caption2)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(2)
                    }
                }

                Divider()

                // Assigned stories
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Assigned Stories")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    if let assignment = assignments[slotNumber], !assignment.storyIds.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                ForEach(assignment.storyIds, id: \.self) { storyId in
                                    if let story = prd.userStories.first(where: { $0.id == storyId }) {
                                        HStack {
                                            Text(story.id)
                                                .font(.caption.bold())
                                                .foregroundStyle(Color.accentPrimary)
                                            Text(story.title)
                                                .font(.caption)
                                                .foregroundStyle(Color.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            Button(action: { removeStory(storyId, from: slotNumber) }) {
                                                Image(systemName: "xmark.circle")
                                                    .foregroundStyle(Color.textSecondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Click stories to assign them")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                // Clear slot button
                if assignments[slotNumber] != nil {
                    Button(action: { clearSlot(slotNumber) }) {
                        Label("Clear Slot", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.statusError)
                }
            } else {
                Text("Select a slot to configure")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgSurface)
    }

    private func agentButton(_ agent: AgentType, for slotNumber: Int) -> some View {
        let isSelected = assignments[slotNumber]?.agentType == agent

        return Button(action: { setAgent(agent, for: slotNumber) }) {
            VStack(spacing: 4) {
                Image(systemName: agent.iconName)
                    .font(.title3)
                Text(agent.shortName)
                    .font(.caption2.bold())
            }
            .frame(width: 50, height: 50)
            .background(isSelected ? agent.neonColor.opacity(0.2) : Color.bgCanvas)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? agent.neonColor : Color.borderMuted, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? agent.neonColor : Color.textSecondary)
    }

    private func actionButton(_ action: ActionType, for slotNumber: Int) -> some View {
        let isSelected = assignments[slotNumber]?.actionType == action
        let actionColor = actionTypeColor(action)

        return Button(action: { setAction(action, for: slotNumber) }) {
            VStack(spacing: 2) {
                Image(systemName: action.iconName)
                    .font(.caption)
                Text(action.displayName)
                    .font(.caption2.bold())
                    .lineLimit(1)
            }
            .frame(width: 70, height: 44)
            .background(isSelected ? actionColor.opacity(0.2) : Color.bgCanvas)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? actionColor : Color.borderMuted, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? actionColor : Color.textSecondary)
    }

    private func actionTypeColor(_ action: ActionType) -> Color {
        switch action {
        case .implement: return Color.statusSuccess
        case .review: return Color.accentPrimary
        case .integrationTest: return Color.statusWarning
        case .write: return Color(hex: "#bc8cff")
        case .custom: return Color.textSecondary
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Summary
            let totalAssigned = assignments.values.reduce(0) { $0 + $1.storyIds.count }
            let totalStories = prd.userStories.count
            let slotsUsed = assignments.filter { !$0.value.storyIds.isEmpty }.count

            VStack(alignment: .leading, spacing: 2) {
                Text("\(totalAssigned)/\(totalStories) stories assigned")
                    .font(.caption)
                    .foregroundStyle(totalAssigned == totalStories ? Color.statusSuccess : Color.textSecondary)
                Text("\(slotsUsed) slots configured")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.statusError)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button {
                startDispatch()
            } label: {
                if isStarting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Label("Start Loops", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.statusSuccess)
            .disabled(!canStart || isStarting)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Logic

    private var canStart: Bool {
        let hasAssignments = !assignments.isEmpty
        let allHaveAgents = assignments.values.allSatisfy { $0.agentType != nil }
        let allHaveStories = assignments.values.allSatisfy { !$0.storyIds.isEmpty }
        return hasAssignments && allHaveAgents && allHaveStories
    }

    private func isStoryAssigned(_ storyId: String) -> Bool {
        assignments.values.contains { $0.storyIds.contains(storyId) }
    }

    private func slotForStory(_ storyId: String) -> Int? {
        for (slot, assignment) in assignments {
            if assignment.storyIds.contains(storyId) {
                return slot
            }
        }
        return nil
    }

    private func toggleStoryAssignment(_ storyId: String) {
        guard let slotNumber = selectedSlot else { return }

        // Remove from any existing assignment
        for (slot, var assignment) in assignments {
            if assignment.storyIds.contains(storyId) {
                assignment.storyIds.removeAll { $0 == storyId }
                if assignment.storyIds.isEmpty && assignment.agentType == nil {
                    assignments.removeValue(forKey: slot)
                } else {
                    assignments[slot] = assignment
                }
            }
        }

        // If story was already in this slot, we just removed it (toggle off)
        if slotForStory(storyId) == slotNumber {
            return
        }

        // Add to selected slot
        if var assignment = assignments[slotNumber] {
            assignment.storyIds.append(storyId)
            assignments[slotNumber] = assignment
        } else {
            // Create new assignment with default agent and action
            assignments[slotNumber] = SlotStoryAssignment(
                slotNumber: slotNumber,
                agentType: .claude,
                actionType: .implement,  // Default action
                storyIds: [storyId],
                worktreePath: repoPath.appendingPathComponent("worktree-slot-\(slotNumber)").path
            )
        }
    }

    private func setAgent(_ agent: AgentType, for slotNumber: Int) {
        if var assignment = assignments[slotNumber] {
            assignment.agentType = agent
            assignments[slotNumber] = assignment
        } else {
            assignments[slotNumber] = SlotStoryAssignment(
                slotNumber: slotNumber,
                agentType: agent,
                actionType: .implement,  // Default action
                storyIds: [],
                worktreePath: repoPath.appendingPathComponent("worktree-slot-\(slotNumber)").path
            )
        }
    }

    private func setAction(_ action: ActionType, for slotNumber: Int) {
        if var assignment = assignments[slotNumber] {
            assignment.actionType = action
            assignments[slotNumber] = assignment
        } else {
            assignments[slotNumber] = SlotStoryAssignment(
                slotNumber: slotNumber,
                agentType: .claude,
                actionType: action,
                storyIds: [],
                worktreePath: repoPath.appendingPathComponent("worktree-slot-\(slotNumber)").path
            )
        }
    }

    private func removeStory(_ storyId: String, from slotNumber: Int) {
        guard var assignment = assignments[slotNumber] else { return }
        assignment.storyIds.removeAll { $0 == storyId }
        if assignment.storyIds.isEmpty && assignment.agentType == nil {
            assignments.removeValue(forKey: slotNumber)
        } else {
            assignments[slotNumber] = assignment
        }
    }

    private func clearSlot(_ slotNumber: Int) {
        assignments.removeValue(forKey: slotNumber)
    }

    private func startDispatch() {
        isStarting = true
        errorMessage = nil

        // Build slot assignments map with action types
        var slotAssignmentsTyped: [Int: (agentType: AgentType, actionType: ActionType, storyIds: [String])] = [:]
        for (slot, assignment) in assignments {
            slotAssignmentsTyped[slot] = (agentType: assignment.agentType, actionType: assignment.actionType, storyIds: assignment.storyIds)

            // Use centralized path resolver for consistency
            let worktreePath = WorktreePathResolver.resolve(
                repoPath: repoPath,
                slotNumber: slot,
                agentType: assignment.agentType,
                storyIds: assignment.storyIds
            )
            let branchName = WorktreePathResolver.branchName(
                slotNumber: slot,
                agentType: assignment.agentType,
                storyIds: assignment.storyIds
            )

            // Ensure worktrees parent directory exists (but don't create the actual worktree yet)
            // LayeredDispatcher will create the real git worktrees
            try? WorktreePathResolver.ensureWorktreesDirectory(repoPath: repoPath)

            // Configure the terminal slot in AppState
            let worktree = Worktree(
                id: UUID(),
                path: worktreePath.path,
                branch: branchName,
                createdAt: Date()
            )

            // Configure slot with worktree and agent
            appState.configureSlot(slot, worktree: worktree, agentType: assignment.agentType)

            // Also set the actionType to .implement (required for isConfigured)
            if let index = appState.terminalSlots.firstIndex(where: { $0.slotNumber == slot }) {
                appState.terminalSlots[index].actionType = .implement
            }
        }

        // Update AppState with PRD info
        appState.currentPRD = prd
        appState.dispatchPhase = .preparingWorktrees
        appState.dispatchMessage = "Preparing worktrees..."

        // Close the sheet - progress will show in dashboard
        dismiss()
        onComplete?()

        // Start dispatch via UnifiedDispatcher - single entry point for all dispatch operations
        Task {
            // Create unified dispatch request
            let request = DispatchRequest.prd(
                prd: prd,
                slotAssignments: slotAssignmentsTyped,
                repoPath: repoPath,
                source: .prdLoader
            )

            // Create unified callbacks that route to AppState
            let callbacks = DispatchCallbacks(
                onProgress: { progress in
                    Task { @MainActor in
                        appState.dispatchPhase = progress.phase
                        appState.dispatchMessage = progress.message
                        appState.dispatchProgress = progress
                        appState.currentDispatchLayer = progress.currentLayer
                        appState.totalDispatchLayers = progress.totalLayers
                    }
                },
                onSlotUpdate: { info in
                    Task { @MainActor in
                        // Update terminal slot status based on dispatch info
                        if let index = appState.terminalSlots.firstIndex(where: { $0.slotNumber == info.slotNumber }) {
                            switch info.status {
                            case .pending:
                                appState.terminalSlots[index].status = .configuring
                            case .worktreeCreated:
                                appState.terminalSlots[index].status = .ready
                            case .launching:
                                appState.terminalSlots[index].status = .starting
                            case .running:
                                appState.terminalSlots[index].status = .running
                            case .completed:
                                appState.terminalSlots[index].status = .completed
                            case .failed:
                                appState.terminalSlots[index].status = .error
                            }
                        }
                    }
                },
                onSlotOutput: { slotNumber, output in
                    Task { @MainActor in
                        // Forward output to terminal slot as log entry
                        if let index = appState.terminalSlots.firstIndex(where: { $0.slotNumber == slotNumber }) {
                            let agentType = appState.terminalSlots[index].agentType
                            let worktreePath = appState.terminalSlots[index].worktree?.path
                            let logEntry = LogEntry(
                                level: .info,
                                source: agentType?.rawValue ?? "slot-\(slotNumber)",
                                worktree: worktreePath,
                                message: output
                            )
                            // Add to slot logs
                            appState.terminalSlots[index].addLog(logEntry)
                        }
                    }
                },
                onLog: { logEntry in
                    Task { @MainActor in
                        // Route all logs to global MCP logs panel
                        appState.addLog(logEntry)
                    }
                },
                onComplete: {
                    Task { @MainActor in
                        appState.dispatchPhase = .completed
                        appState.dispatchMessage = "All stories completed! 🎉"
                        appState.orchestratorVisualState = .celebrating
                    }
                },
                onError: { error in
                    Task { @MainActor in
                        appState.dispatchPhase = .failed
                        appState.dispatchMessage = "Error: \(error.localizedDescription)"
                        appState.orchestratorVisualState = .concerned
                    }
                }
            )

            // Dispatch via unified system
            _ = try? await appState.services.unifiedDispatcher.dispatch(request, callbacks: callbacks)
        }
    }
}

// MARK: - Story Row View

private struct StoryRowView: View {
    let story: PRDUserStory
    let isAssigned: Bool
    let assignedTo: Int?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(story.id)
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentPrimary)
                Text(story.title)
                    .font(.caption)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
            }

            Spacer()

            if let slot = assignedTo {
                Text("S\(slot)")
                    .font(.caption.bold())
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.statusSuccess)
                    .clipShape(Capsule())
            }
        }
        .padding(Theme.Spacing.sm)
        .background(isAssigned ? Color.statusSuccess.opacity(0.1) : Color.bgCanvas)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(isAssigned ? Color.statusSuccess.opacity(0.3) : Color.borderMuted, lineWidth: 1)
        )
    }

    private var priorityColor: Color {
        switch story.priority {
        case .critical:
            return Color.statusError
        case .high:
            return Color.statusWarning
        case .medium:
            return Color.accentPrimary
        case .low:
            return Color.textTertiary
        }
    }
}
