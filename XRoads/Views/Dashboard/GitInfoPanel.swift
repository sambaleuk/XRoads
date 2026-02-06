//
//  GitInfoPanel.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Left sidebar Git panel matching the neon dashboard design
//

import SwiftUI

// MARK: - GitInfoPanel

struct GitInfoPanel: View {
    @Environment(\.appState) private var appState

    @State private var repoPath: String = ""
    @State private var currentBranch: String = ""
    @State private var commits: [GitService.CommitInfo] = []
    @State private var isLoading: Bool = true
    @State private var isRefreshing: Bool = false
    @State private var isGitRepo: Bool = true
    @State private var isInitializingGit: Bool = false
    @State private var showNewFolderSheet: Bool = false
    @State private var newFolderName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // GIT Header
            gitHeader

            Divider()
                .background(Color.borderMuted)

            if isLoading {
                loadingView
            } else if !isGitRepo {
                // Not a git repo - show setup options
                noGitRepoView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Quick Actions
                        quickActionsSection

                        // Branch & repo info
                        branchSection

                        // Recent PRDs dropdown
                        recentPRDsSection

                        // Recent Commits
                        recentCommitsSection

                        // Worktrees
                        worktreesSection
                    }
                    .padding(Theme.Spacing.md)
                }
            }
        }
        .frame(width: 210)
        .background(Color.bgSurface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color.borderMuted.opacity(0.5), lineWidth: 1)
        )
        .task {
            await loadGitInfo()
        }
    }

    // MARK: - Git Header

    private var gitHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)

            Text("GIT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .tracking(1)

            Spacer()

            Button {
                Task { await refreshGitInfo() }
            } label: {
                Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(height: 40)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section header
            SectionHeader(title: "QUICK ACTIONS")

            // Action buttons
            VStack(spacing: Theme.Spacing.xs) {
                QuickActionButton(
                    title: "New Feature",
                    icon: "doc.text.fill",
                    color: Color.accentPrimary
                ) {
                    NotificationCenter.default.post(name: .openPRDAssistant, object: nil)
                }

                QuickActionButton(
                    title: "Art Direction",
                    icon: "paintpalette.fill",
                    color: Color.terminalYellow
                ) {
                    NotificationCenter.default.post(name: .openArtDirection, object: nil)
                }

                QuickActionButton(
                    title: "Quick Loop",
                    icon: "arrow.triangle.2.circlepath",
                    color: Color.statusSuccess,
                    subtitle: currentBranch.isEmpty ? nil : "on \(currentBranch)"
                ) {
                    NotificationCenter.default.post(name: .launchQuickLoop, object: currentBranch)
                }
            }
        }
    }

    // MARK: - Branch Section

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Branch name with status dot and context menu
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(Color.statusSuccess)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.statusSuccess.opacity(0.6), radius: 3)

                Text(currentBranch.isEmpty ? "loading..." : currentBranch)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.terminalGreen)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgElevated)
            .cornerRadius(Theme.Radius.sm)
            .contextMenu {
                branchContextMenuItems
            }

            // Repo path
            if !repoPath.isEmpty {
                Text(formatRepoPath(repoPath))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .padding(.horizontal, Theme.Spacing.xs)
            }
        }
    }

    // MARK: - Branch Context Menu

    @ViewBuilder
    private var branchContextMenuItems: some View {
        Button {
            NotificationCenter.default.post(name: .launchQuickLoop, object: currentBranch)
        } label: {
            Label("Start Loop on Branch", systemImage: "arrow.triangle.2.circlepath")
        }

        Button {
            NotificationCenter.default.post(name: .openPRDAssistant, object: nil)
        } label: {
            Label("Create Feature PRD", systemImage: "doc.text.fill")
        }

        Divider()

        Button {
            NotificationCenter.default.post(name: .showNewWorktreeSheet, object: nil)
        } label: {
            Label("Create Worktree", systemImage: "plus.rectangle.on.folder")
        }

        Divider()

        Button {
            copyBranchName()
        } label: {
            Label("Copy Branch Name", systemImage: "doc.on.doc")
        }
    }

    private func copyBranchName() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentBranch, forType: .string)
    }

    // MARK: - Recent PRDs Section

    private var recentPRDsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section header
            SectionHeader(
                title: "RECENT PRDS",
                count: recentPRDs.isEmpty ? nil : recentPRDs.count
            )

            // PRDs list or empty state
            if recentPRDs.isEmpty {
                emptyPRDsView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentPRDs.prefix(5).enumerated()), id: \.element.id) { index, record in
                        RecentPRDRow(record: record) {
                            loadPRD(record)
                        }

                        if index < min(recentPRDs.count - 1, 4) {
                            Divider()
                                .background(Color.borderMuted.opacity(0.3))
                        }
                    }
                }
                .background(Color.bgCanvas.opacity(0.5))
                .cornerRadius(Theme.Radius.sm)
            }
        }
    }

    private var emptyPRDsView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary.opacity(0.5))

            Text("No recent PRDs")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.bgCanvas.opacity(0.3))
        .cornerRadius(Theme.Radius.sm)
    }

    /// Returns recent PRDs from orchestration history
    private var recentPRDs: [OrchestrationRecord] {
        appState.historyRecords.filter { $0.prdPath != nil }
    }

    private func loadPRD(_ record: OrchestrationRecord) {
        guard let path = record.prdPath else { return }
        NotificationCenter.default.post(
            name: .loadPRDFromPath,
            object: path
        )
    }

    // MARK: - Recent Commits Section

    private var recentCommitsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section header
            SectionHeader(
                title: "COMMITS",
                count: commits.isEmpty ? nil : commits.count
            )

            // Commits list
            if commits.isEmpty {
                emptyCommitsView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(commits.prefix(6).enumerated()), id: \.element.id) { index, commit in
                        CommitRow(commit: commit)

                        if index < min(commits.count - 1, 5) {
                            Divider()
                                .background(Color.borderMuted.opacity(0.3))
                        }
                    }
                }
                .background(Color.bgCanvas.opacity(0.5))
                .cornerRadius(Theme.Radius.sm)
            }
        }
    }

    private var emptyCommitsView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary.opacity(0.5))

            Text("No commits yet")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.bgCanvas.opacity(0.3))
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Worktrees Section

    private var worktreesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section header
            SectionHeader(
                title: "WORKTREES",
                count: appState.worktrees.isEmpty ? nil : appState.worktrees.count,
                actionIcon: "plus",
                onAction: {
                    NotificationCenter.default.post(name: .showNewWorktreeSheet, object: nil)
                }
            )

            // Worktrees list or empty state
            if appState.worktrees.isEmpty {
                emptyWorktreesView
            } else {
                VStack(spacing: 4) {
                    ForEach(appState.worktrees) { worktree in
                        WorktreeListRow(worktree: worktree)
                    }
                }
            }
        }
    }

    private var emptyWorktreesView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28))
                .foregroundStyle(Color.textTertiary.opacity(0.5))

            VStack(spacing: Theme.Spacing.xs) {
                Text("No active worktrees.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)

                Text("Create one to start working with agents.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                NotificationCenter.default.post(name: .showNewWorktreeSheet, object: nil)
            } label: {
                Text("Create Worktree")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color.accentPrimary.opacity(0.2))
                    .cornerRadius(Theme.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(Color.accentPrimary.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(Color.bgCanvas.opacity(0.3))
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading git info...")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Git Repo View

    private var noGitRepoView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Warning icon
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.statusWarning)

                    Text("No Git Repository")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Initialize a git repo to start working with branches and agents.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.sm)
                }
                .padding(.top, Theme.Spacing.lg)

                // Current path
                if let projectPath = appState.projectPath {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("CURRENT PATH")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                            .tracking(0.5)

                        Text(formatRepoPath(projectPath))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.sm)
                    .background(Color.bgCanvas.opacity(0.5))
                    .cornerRadius(Theme.Radius.sm)
                }

                // Action buttons
                VStack(spacing: Theme.Spacing.sm) {
                    // Initialize Git
                    Button {
                        initializeGitRepo()
                    } label: {
                        HStack {
                            if isInitializingGit {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "plus.square.fill")
                                    .font(.system(size: 12))
                            }
                            Text(isInitializingGit ? "Initializing..." : "Initialize Git Here")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.statusSuccess)
                        .foregroundStyle(Color.white)
                        .cornerRadius(Theme.Radius.sm)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInitializingGit || appState.projectPath == nil)

                    // Create new folder
                    Button {
                        showNewFolderSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 12))
                            Text("Create New Project Folder")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.accentPrimary)
                        .foregroundStyle(Color.white)
                        .cornerRadius(Theme.Radius.sm)
                    }
                    .buttonStyle(.plain)

                    // Open different folder
                    Button {
                        openProjectPicker()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                            Text("Open Different Folder")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .foregroundStyle(Color.textPrimary)
                        .cornerRadius(Theme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(Theme.Spacing.md)
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewProjectFolderSheet(
                folderName: $newFolderName,
                onCreate: createNewProjectFolder
            )
        }
    }

    // MARK: - Git Actions

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
                        // Reload git info
                        Task { await loadGitInfo() }
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

    private func openProjectPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project folder"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            appState.projectPath = url.path
            Task { await loadGitInfo() }
        }
    }

    private func createNewProjectFolder() {
        guard !newFolderName.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to create '\(newFolderName)'"
        panel.prompt = "Create Here"

        if panel.runModal() == .OK, let parentURL = panel.url {
            let newFolderURL = parentURL.appendingPathComponent(newFolderName)

            do {
                try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
                appState.projectPath = newFolderURL.path
                newFolderName = ""
                showNewFolderSheet = false
                Task { await loadGitInfo() }
            } catch {
                // Handle error
            }
        }
    }

    // MARK: - Helpers

    private func formatRepoPath(_ path: String) -> String {
        // Show path starting from home directory
        if let home = ProcessInfo.processInfo.environment["HOME"],
           path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }

    // MARK: - Data Loading

    private func loadGitInfo() async {
        isLoading = true

        let projectPath = appState.projectPath ?? FileManager.default.currentDirectoryPath

        // First check if it's a git repo
        let gitPath = (projectPath as NSString).appendingPathComponent(".git")
        let isRepo = FileManager.default.fileExists(atPath: gitPath)

        await MainActor.run {
            isGitRepo = isRepo
        }

        if !isRepo {
            await MainActor.run {
                isLoading = false
                repoPath = projectPath
                currentBranch = ""
                commits = []
            }
            return
        }

        let gitService = appState.services.gitService

        do {
            repoPath = try await gitService.getRepoRoot(path: projectPath)

            async let branchTask = gitService.getCurrentBranch(path: repoPath)
            async let commitsTask = gitService.getRecentCommits(path: repoPath, count: 8)

            currentBranch = try await branchTask
            commits = try await commitsTask
        } catch {
            currentBranch = "unknown"
            commits = []
        }

        isLoading = false
    }

    private func refreshGitInfo() async {
        isRefreshing = true

        let gitService = appState.services.gitService

        // Try to fetch from remote first
        if !repoPath.isEmpty {
            try? await gitService.fetchAll(path: repoPath)
        }

        // Reload info
        do {
            async let branchTask = gitService.getCurrentBranch(path: repoPath)
            async let commitsTask = gitService.getRecentCommits(path: repoPath, count: 8)

            currentBranch = try await branchTask
            commits = try await commitsTask
        } catch {
            // Keep existing values on error
        }

        isRefreshing = false
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    var count: Int? = nil
    var actionIcon: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
                .tracking(1)

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textTertiary.opacity(0.6))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.bgElevated)
                    .cornerRadius(3)
            }

            if let icon = actionIcon, let action = onAction {
                Button(action: action) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: Theme.Component.sectionHeaderHeight)
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                // Icon with glow on hover
                ZStack {
                    if isHovered {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .blur(radius: 4)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(color)
                        .frame(width: 16)
                }
                .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isHovered ? Color.textPrimary : Color.textSecondary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(isHovered ? color.opacity(0.8) : Color.textTertiary.opacity(0.4))
                    .offset(x: isHovered ? 2 : 0)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isHovered ? Color.bgElevated : Color.bgCanvas.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isHovered ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recent PRD Row

private struct RecentPRDRow: View {
    let record: OrchestrationRecord
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.prdName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(formatDate(record.startedAt))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                // Completion rate badge
                Text("\(Int(record.completionRate * 100))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isHovered ? Color.bgElevated : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var statusColor: Color {
        if record.completionRate >= 1.0 {
            return Color.statusSuccess
        } else if record.completionRate > 0 {
            return Color.statusWarning
        } else {
            return Color.statusError
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Commit Row

private struct CommitRow: View {
    let commit: GitService.CommitInfo

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Commit hash
            Text(commit.shortSha)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.terminalYellow)

            // Commit message
            Text(formatMessage(commit.message))
                .font(.system(size: 10))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func formatMessage(_ message: String) -> String {
        // Extract first line and truncate if needed
        let firstLine = message.components(separatedBy: .newlines).first ?? message
        return firstLine
    }
}

// MARK: - Worktree List Row

private struct WorktreeListRow: View {
    let worktree: Worktree
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10))
                .foregroundStyle(Color.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.branch)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(worktree.name)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(isHovered ? Color.bgElevated : Color.bgCanvas.opacity(0.5))
        .cornerRadius(Theme.Radius.sm)
        .onHover { isHovered = $0 }
    }
}

// MARK: - New Project Folder Sheet

private struct NewProjectFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var folderName: String
    let onCreate: () -> Void

    @State private var initGit: Bool = true

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header
            HStack {
                Text("Create New Project")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

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

            Divider()
                .background(Color.borderMuted)

            // Folder name input
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Project Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)

                TextField("my-awesome-project", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            // Initialize git toggle
            Toggle(isOn: $initGit) {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(Color.statusSuccess)
                    Text("Initialize Git repository")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Create") {
                    onCreate()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentPrimary)
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 350, height: 280)
        .background(Color.bgSurface)
    }
}

// MARK: - Preview

#if DEBUG
struct GitInfoPanel_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            GitInfoPanel()
            Spacer()
        }
        .frame(width: 400, height: 600)
        .padding()
        .background(Color.bgApp)
    }
}
#endif
