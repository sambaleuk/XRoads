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
        ZStack {
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
            .frame(width: Theme.Component.slotCardWidth, height: Theme.Component.slotCardHeight)
            .background(Theme.SlotCard.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        borderColor,
                        lineWidth: slot.status.isActive ? 1.5 : 1
                    )
            )

            // State Overlays
            NeedsInputOverlay(isVisible: slot.status.isWaitingForInput)
            ErrorOverlay(isVisible: slot.status == .error, errorMessage: nil)
            CompletedOverlay(isVisible: slot.status == .completed)
        }
        .shadow(
            color: shadowColor,
            radius: slot.status.isActive ? 12 : 0
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: Theme.Animation.normal), value: isHovered)
        .animation(.easeInOut(duration: Theme.Animation.normal), value: slot.status)
        .onHover { isHovered = $0 }
    }

    // MARK: - Computed Colors

    private var borderColor: Color {
        if slot.status.isWaitingForInput {
            return Color.terminalMagenta.opacity(0.8)
        } else if slot.status == .error {
            return Color.statusError.opacity(0.8)
        } else if slot.status == .completed {
            return Color.accentPrimary.opacity(0.6)
        } else if slot.status.isActive {
            return agentColor.opacity(0.8)
        } else {
            return Theme.SlotCard.borderInactive
        }
    }

    private var shadowColor: Color {
        if slot.status.isWaitingForInput {
            return Color.terminalMagenta.opacity(0.4)
        } else if slot.status == .error {
            return Color.statusError.opacity(0.3)
        } else if slot.status.isActive {
            return agentColor.opacity(0.4)
        } else {
            return .clear
        }
    }

    // MARK: - Header

    private var slotHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Status indicator (replaces static slot label when configured)
            if slot.isConfigured {
                SlotStatusIndicator(status: slot.status, size: 6)
                    .frame(width: 16)
            }

            // Slot label
            Text("SLOT \(slot.slotNumber)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textSecondary)

            // Agent indicator (colored dot + name)
            if let agent = slot.agentType {
                Text("•")
                    .foregroundStyle(agentColor)

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
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(height: Theme.Component.slotHeaderHeight)
        .background(Theme.SlotCard.headerBackground)
    }

    // MARK: - Header Action Button

    @ViewBuilder
    private var headerActionButton: some View {
        HStack(spacing: Theme.Spacing.xs) {
            // Config/gear button - always visible until running
            if !slot.status.isActive {
                Button {
                    showConfigPopover = true
                } label: {
                    Image(systemName: slot.isConfigured ? "gearshape" : "plus.circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(slot.isConfigured ? Color.textTertiary : Color.accentPrimary.opacity(0.8))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
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

            // Play button - only when ready
            if slot.status.canStart {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.statusSuccess)
                        .frame(width: 20, height: 20)
                        .background(Color.statusSuccess.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Stop button - only when running
            if slot.status.canStop {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.statusError)
                        .frame(width: 20, height: 20)
                        .background(Color.statusError.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Terminal Output Area

    private var terminalOutputArea: some View {
        VStack(spacing: 0) {
            // Terminal content based on state
            Group {
                if slot.status == .starting {
                    // Starting state with spinner
                    StartingStateView(
                        agentColor: agentColor,
                        agentName: slot.agentType?.displayName
                    )
                } else if slot.recentLogs.isEmpty {
                    // Empty terminal placeholder
                    EmptyTerminalPlaceholder(isConfigured: slot.isConfigured)
                        .background(Theme.SlotCard.terminalBackground)
                } else {
                    // Terminal output
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(slot.recentLogs) { log in
                                    TerminalOutputLine(log: log, agentColor: agentColor)
                                        .id(log.id)
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.sm - 2)
                        }
                        .onChange(of: slot.logs.count) { _, _ in
                            if let lastLog = slot.recentLogs.last {
                                withAnimation(.easeOut(duration: Theme.Animation.fast)) {
                                    proxy.scrollTo(lastLog.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .background(Theme.SlotCard.terminalBackground)
                }
            }

            // Animated progress bar (when active)
            if slot.status.isActive && slot.progress > 0 {
                AnimatedProgressBar(
                    progress: slot.progress,
                    color: agentColor,
                    height: 2,
                    showGlow: true
                )
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
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()

            // Plus icon with hover effect
            ZStack {
                // Glow on hover
                if isHovered {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .blur(radius: 8)
                }

                Image(systemName: "plus.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(isHovered ? Color.accentPrimary : Color.textTertiary.opacity(0.5))
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            }
            .animation(.easeOut(duration: 0.2), value: isHovered)

            Text("Configure Slot")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Color.textPrimary : Color.textSecondary)

            Text("Click to select agent & branch")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
                .opacity(isHovered ? 1 : 0.7)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.SlotCard.terminalBackground
                .overlay(
                    isHovered ? Color.accentPrimary.opacity(0.03) : Color.clear
                )
        )
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
    @Environment(\.appState) private var appState
    @Binding var slot: TerminalSlot
    @Binding var selectedAction: ActionType?
    let worktrees: [Worktree]

    @State private var showNewBranchField = false
    @State private var newBranchName = ""
    @State private var isCreatingBranch = false
    @State private var isGitRepo = true
    @State private var isInitializingGit = false
    @State private var gitCheckDone = false

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
                                updateSlotStatus()
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
                                slot.actionType = action
                                updateSlotStatus()
                            } label: {
                                Label(action.displayName, systemImage: action.iconName)
                            }
                        }
                    } label: {
                        HStack {
                            if let action = selectedAction ?? slot.actionType {
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

            // Git Repository Check
            if !gitCheckDone {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Checking git status...")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.vertical, 8)
            } else if !isGitRepo {
                // Not a git repository - offer to initialize
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.statusWarning)
                        Text("No Git Repository")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.statusWarning)
                    }

                    Text("This directory is not a git repository. Initialize one to start working with branches.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        initializeGitRepo()
                    } label: {
                        HStack {
                            if isInitializingGit {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "plus.square.fill")
                            }
                            Text(isInitializingGit ? "Initializing..." : "Initialize Git Repository")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.statusSuccess)
                        .foregroundStyle(Color.white)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInitializingGit)
                }
                .padding(10)
                .background(Color.statusWarning.opacity(0.1))
                .cornerRadius(6)
            } else {
                // Worktree / Branch selection (only shown if git repo exists)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("BRANCH / WORKTREE")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))

                        Spacer()

                        // Toggle to create new
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNewBranchField.toggle()
                                if showNewBranchField {
                                    newBranchName = "feat/"
                                }
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: showNewBranchField ? "xmark" : "plus")
                                    .font(.system(size: 8))
                                Text(showNewBranchField ? "Cancel" : "New")
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(Color.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                if showNewBranchField {
                    // New branch creation field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.accentPrimary)

                            TextField("feat/my-feature", text: $newBranchName)
                                .font(.system(size: 11, design: .monospaced))
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.accentPrimary.opacity(0.1))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentPrimary.opacity(0.5), lineWidth: 1)
                        )

                        Button {
                            createNewBranch()
                        } label: {
                            HStack {
                                if isCreatingBranch {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text(isCreatingBranch ? "Creating..." : "Create & Use Branch")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.accentPrimary)
                            .foregroundStyle(Color.white)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(newBranchName.trimmingCharacters(in: .whitespaces).isEmpty || isCreatingBranch)
                    }
                } else {
                    // Existing worktrees menu
                    Menu {
                        // Existing worktrees section
                        if !worktrees.isEmpty {
                            Section("Existing Worktrees") {
                                ForEach(worktrees) { worktree in
                                    Button {
                                        selectWorktree(worktree)
                                    } label: {
                                        Label(worktree.branch, systemImage: "folder")
                                    }
                                }
                            }
                        }

                        // Current branch option (work in main repo)
                        Section("Current Repository") {
                            Button {
                                useCurrentBranch()
                            } label: {
                                Label("Use current branch", systemImage: "arrow.triangle.branch")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                            if let wt = slot.worktree {
                                Text(wt.branch)
                            } else {
                                Text("Select or create branch")
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
                } // End VStack for branch/worktree
            } // End else (isGitRepo)

            // Ready status indicator
            if slot.isConfigured && slot.status == .ready {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.statusSuccess)
                    Text("Ready to start")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.statusSuccess)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
        .onAppear {
            // Sync selectedAction with slot's actionType on appear
            selectedAction = slot.actionType
            // Check git status
            checkGitStatus()
        }
    }

    // MARK: - Git Actions

    private func checkGitStatus() {
        guard let projectPath = appState.projectPath else {
            gitCheckDone = true
            isGitRepo = false
            return
        }

        Task {
            let gitPath = (projectPath as NSString).appendingPathComponent(".git")
            let exists = FileManager.default.fileExists(atPath: gitPath)

            await MainActor.run {
                isGitRepo = exists
                gitCheckDone = true
            }
        }
    }

    private func initializeGitRepo() {
        guard let projectPath = appState.projectPath else { return }

        isInitializingGit = true

        Task {
            do {
                // Initialize git repository
                let initProcess = Process()
                initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                initProcess.arguments = ["init"]
                initProcess.currentDirectoryURL = URL(fileURLWithPath: projectPath)
                try initProcess.run()
                initProcess.waitUntilExit()

                if initProcess.terminationStatus == 0 {
                    // Create initial commit
                    let addProcess = Process()
                    addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    addProcess.arguments = ["add", "-A"]
                    addProcess.currentDirectoryURL = URL(fileURLWithPath: projectPath)
                    try addProcess.run()
                    addProcess.waitUntilExit()

                    let commitProcess = Process()
                    commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    commitProcess.arguments = ["commit", "-m", "Initial commit", "--allow-empty"]
                    commitProcess.currentDirectoryURL = URL(fileURLWithPath: projectPath)
                    try commitProcess.run()
                    commitProcess.waitUntilExit()

                    await MainActor.run {
                        isGitRepo = true
                        isInitializingGit = false
                    }
                } else {
                    await MainActor.run {
                        isInitializingGit = false
                    }
                }
            } catch {
                await MainActor.run {
                    isInitializingGit = false
                }
            }
        }
    }

    // MARK: - Worktree Actions

    private func selectWorktree(_ worktree: Worktree) {
        slot.worktree = worktree
        // Auto-set default action if agent is selected and no action yet
        if slot.agentType != nil && slot.actionType == nil {
            slot.actionType = .implement
            selectedAction = .implement
        }
        // Always update status based on full configuration
        updateSlotStatus()
    }

    /// Updates slot status based on configuration completeness
    private func updateSlotStatus() {
        if slot.worktree != nil && slot.agentType != nil {
            // Auto-set default action if missing
            if slot.actionType == nil {
                slot.actionType = .implement
                selectedAction = .implement
            }
            slot.status = .ready
            Log.dashboard.info("Slot \(slot.slotNumber) is now ready: \(slot.agentType?.rawValue ?? "?") on \(slot.worktree?.branch ?? "?")")
        } else if slot.agentType != nil || slot.worktree != nil {
            slot.status = .configuring
        } else {
            slot.status = .empty
        }
    }

    private func useCurrentBranch() {
        guard let projectPath = appState.projectPath else { return }

        Task {
            let gitService = GitService()
            if let currentBranch = try? await gitService.getCurrentBranch(path: projectPath) {
                await MainActor.run {
                    // Create a "virtual" worktree pointing to main repo
                    let worktree = Worktree(path: projectPath, branch: currentBranch)
                    selectWorktree(worktree)
                }
            }
        }
    }

    private func createNewBranch() {
        guard let projectPath = appState.projectPath else { return }
        let branchName = newBranchName.trimmingCharacters(in: .whitespaces)
        guard !branchName.isEmpty else { return }

        isCreatingBranch = true

        Task {
            do {
                // Create and checkout new branch
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["checkout", "-b", branchName]
                process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    await MainActor.run {
                        // Create worktree for this branch
                        let worktree = Worktree(path: projectPath, branch: branchName)
                        selectWorktree(worktree)
                        showNewBranchField = false
                        newBranchName = ""
                        isCreatingBranch = false
                    }
                } else {
                    await MainActor.run {
                        isCreatingBranch = false
                        // Branch might already exist, try to checkout
                        checkoutExistingBranch(branchName)
                    }
                }
            } catch {
                await MainActor.run {
                    isCreatingBranch = false
                }
            }
        }
    }

    private func checkoutExistingBranch(_ branchName: String) {
        guard let projectPath = appState.projectPath else { return }

        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["checkout", branchName]
            process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

            try? process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                await MainActor.run {
                    let worktree = Worktree(path: projectPath, branch: branchName)
                    selectWorktree(worktree)
                    showNewBranchField = false
                    newBranchName = ""
                }
            }
        }
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
