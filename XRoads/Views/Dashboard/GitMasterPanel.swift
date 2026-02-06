//
//  GitMasterPanel.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  Dedicated UI panel for GitMaster intelligent resolver
//

import SwiftUI

// MARK: - GitMasterPanel

struct GitMasterPanel: View {
    @Environment(\.appState) private var appState

    @State private var isExpanded: Bool = true
    @State private var isHovered: Bool = false
    @State private var showMergeConfirmation: Bool = false
    @State private var selectedConflict: GitConflict? = nil

    private var state: GitMasterState {
        appState.gitMasterState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            if isExpanded {
                Divider()
                    .background(Color.borderMuted)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        // Status indicator
                        statusSection

                        // Tracked branches
                        if !state.trackedBranches.isEmpty {
                            branchesSection
                        }

                        // Conflicts section (if any)
                        if state.hasConflicts {
                            conflictsSection
                        }

                        // Actions
                        actionsSection
                    }
                    .padding(Theme.Spacing.md)
                }
            }
        }
        .background(Color.bgCanvas.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .sheet(item: $selectedConflict) { conflict in
            ConflictDetailSheet(conflict: conflict)
        }
        .confirmationDialog(
            "Merge All Branches",
            isPresented: $showMergeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Merge Now") {
                performMerge()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will merge \(state.branchesReadyToMerge) branch(es) into \(state.targetBranch).")
        }
    }

    // MARK: - Border Color

    private var borderColor: Color {
        switch state.status {
        case .needsAttention:
            return Color.terminalMagenta.opacity(0.6)
        case .error:
            return Color.statusError.opacity(0.6)
        case .success:
            return Color.statusSuccess.opacity(0.6)
        case .busy:
            return Color.accentPrimary.opacity(0.6)
        default:
            return Color.borderMuted.opacity(0.5)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                // Icon
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.terminalYellow)

                Text("GIT MASTER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
                    .tracking(1)

                Spacer()

                // Status badge
                statusBadge

                // Expand/collapse
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(height: 36)
            .background(isHovered ? Color.bgElevated : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.6), radius: 2)

            Text(state.status.displayName)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch state.status {
        case .ready: return Color.textSecondary
        case .busy: return Color.accentPrimary
        case .needsAttention: return Color.terminalMagenta
        case .error: return Color.statusError
        case .success: return Color.statusSuccess
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Mode icon
            Image(systemName: state.mode.iconName)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 24, height: 24)
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(state.mode.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textPrimary)

                Text("Target: \(state.targetBranch)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            // Quick stats
            if state.hasConflicts {
                conflictStats
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Color.bgElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private var conflictStats: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if state.autoResolvableCount > 0 {
                statPill(count: state.autoResolvableCount, label: "Auto", color: .statusSuccess)
            }
            if state.needsReviewCount > 0 {
                statPill(count: state.needsReviewCount, label: "Review", color: .statusWarning)
            }
            if state.manualCount > 0 {
                statPill(count: state.manualCount, label: "Manual", color: .statusError)
            }
        }
    }

    private func statPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 8))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Branches Section

    private var branchesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section header
            HStack {
                Text("BRANCHES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
                    .tracking(0.5)

                Spacer()

                Text("\(state.branchesReadyToMerge)/\(state.trackedBranches.count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
            }

            // Branch list
            VStack(spacing: 0) {
                ForEach(state.trackedBranches) { branch in
                    TrackedBranchRow(branch: branch)

                    if branch.id != state.trackedBranches.last?.id {
                        Divider()
                            .background(Color.borderMuted.opacity(0.3))
                    }
                }
            }
            .background(Color.bgCanvas.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
    }

    // MARK: - Conflicts Section

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section header
            HStack {
                Text("CONFLICTS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
                    .tracking(0.5)

                Spacer()

                Text("\(state.pendingConflicts.count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.statusWarning)
            }

            // Conflict list
            VStack(spacing: 4) {
                ForEach(state.pendingConflicts) { conflict in
                    ConflictRowView(conflict: conflict) {
                        selectedConflict = conflict
                    }
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Primary action
            if state.branchesReadyToMerge > 0 && !state.hasConflicts {
                Button {
                    showMergeConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 11))
                        Text("Merge All (\(state.branchesReadyToMerge))")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color.statusSuccess)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
            }

            // Resolve auto conflicts
            if state.autoResolvableCount > 0 {
                Button {
                    resolveAutoConflicts()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Auto-Resolve (\(state.autoResolvableCount))")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color.accentPrimary)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
            }

            // Secondary actions
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    refreshStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Color.bgElevated)
                        .foregroundStyle(Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.borderMuted, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    abortMerge()
                } label: {
                    Text("Abort")
                        .font(.system(size: 10, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Color.bgElevated)
                        .foregroundStyle(Color.statusError)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.statusError.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(state.mode == .idle)
            }
        }
    }

    // MARK: - Actions

    private func performMerge() {
        guard let projectPath = appState.projectPath else { return }
        let repoURL = URL(fileURLWithPath: projectPath)

        Task {
            let gitMaster = appState.services.gitMaster
            do {
                let result = try await gitMaster.performFullMerge(repoPath: repoURL)
                let newState = await gitMaster.state
                await MainActor.run {
                    appState.gitMasterState = newState
                    if result.success {
                        // Refresh git info
                        NotificationCenter.default.post(name: .gitInfoNeedsRefresh, object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    appState.gitMasterState.status = .error
                    appState.gitMasterState.lastError = error.localizedDescription
                }
            }
        }
    }

    private func resolveAutoConflicts() {
        guard let projectPath = appState.projectPath else { return }
        let repoURL = URL(fileURLWithPath: projectPath)

        Task {
            let gitMaster = appState.services.gitMaster
            do {
                _ = try await gitMaster.resolveAutoConflicts(repoPath: repoURL)
                let newState = await gitMaster.state
                await MainActor.run {
                    appState.gitMasterState = newState
                }
            } catch {
                await MainActor.run {
                    appState.gitMasterState.lastError = error.localizedDescription
                }
            }
        }
    }

    private func refreshStatus() {
        // Refresh tracked branches status from slots
        for slot in appState.terminalSlots where slot.worktree != nil {
            if slot.status == .completed {
                Task {
                    await appState.services.gitMaster.markBranchCompleted(
                        name: slot.worktree!.branch,
                        lastCommit: nil,
                        message: slot.currentTask
                    )
                    let newState = await appState.services.gitMaster.state
                    await MainActor.run {
                        appState.gitMasterState = newState
                    }
                }
            }
        }
    }

    private func abortMerge() {
        guard let projectPath = appState.projectPath else { return }

        Task {
            try? await appState.services.gitService.abortMerge(repoPath: projectPath)
            await appState.services.gitMaster.reset()
            let newState = await appState.services.gitMaster.state
            await MainActor.run {
                appState.gitMasterState = newState
            }
        }
    }
}

// MARK: - Tracked Branch Row

private struct TrackedBranchRow: View {
    let branch: TrackedBranch

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Status indicator
            Image(systemName: branch.status.iconName)
                .font(.system(size: 10))
                .foregroundStyle(statusColor)
                .frame(width: 16)

            // Branch info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(branch.name)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if let agent = branch.agentType {
                        Text("(\(agent.shortName))")
                            .font(.system(size: 9))
                            .foregroundStyle(agent.neonColor)
                    }
                }

                if let commit = branch.lastCommit {
                    Text(commit)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.terminalYellow)
                }
            }

            Spacer()

            // Status text
            Text(branch.status.displayName)
                .font(.system(size: 9))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var statusColor: Color {
        switch branch.status {
        case .pending: return Color.textTertiary
        case .inProgress: return Color.accentPrimary
        case .completed: return Color.statusSuccess
        case .merged: return Color.terminalGreen
        case .error: return Color.statusError
        }
    }
}

// MARK: - Conflict Row View

struct ConflictRowView: View {
    let conflict: GitConflict
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                // Conflict type icon
                Image(systemName: conflict.conflictType.iconName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.statusWarning)
                    .frame(width: 16)

                // File info
                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.fileName)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(conflict.conflictType.displayName)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                // Complexity badge
                complexityBadge
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isHovered ? Color.bgElevated : Color.bgCanvas.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var complexityBadge: some View {
        Text(conflict.complexity.displayName.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var badgeColor: Color {
        switch conflict.complexity {
        case .auto: return Color.statusSuccess
        case .assisted: return Color.statusWarning
        case .manual: return Color.statusError
        }
    }
}

// MARK: - Conflict Detail Sheet

struct ConflictDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let conflict: GitConflict

    @State private var selectedStrategy: ResolutionStrategyType = .keepTheirs

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.fileName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("\(conflict.conflictType.displayName) conflict")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.lg)

            Divider()
                .background(Color.borderMuted)

            // Content comparison
            HStack(spacing: 0) {
                // Ours
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("OURS (\(conflict.oursBranch))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentPrimary)

                    ScrollView {
                        Text(conflict.oursContent)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Color.bgCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)

                Divider()
                    .background(Color.borderMuted)

                // Theirs
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("THEIRS (\(conflict.theirsBranch))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.terminalMagenta)

                    ScrollView {
                        Text(conflict.theirsContent)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Color.bgCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
            }

            Divider()
                .background(Color.borderMuted)

            // AI Analysis
            if let analysis = conflict.aiAnalysis {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "brain")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.terminalMagenta)

                    Text(analysis)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(Color.terminalMagenta.opacity(0.1))
            }

            // Actions
            HStack(spacing: Theme.Spacing.md) {
                // Strategy picker
                Picker("Strategy", selection: $selectedStrategy) {
                    ForEach(ResolutionStrategyType.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    applyResolution()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentPrimary)
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(width: 800, height: 600)
        .background(Color.bgSurface)
    }

    private func applyResolution() {
        // Apply resolution logic would go here
        dismiss()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let gitInfoNeedsRefresh = Notification.Name("gitInfoNeedsRefresh")
}

// MARK: - Preview

#if DEBUG
struct GitMasterPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            GitMasterPanel()
                .frame(width: 220)
        }
        .padding()
        .background(Color.bgApp)
    }
}
#endif
