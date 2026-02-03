//
//  GitInfoPanel.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Compact Git info panel for Dashboard v3 left sidebar
//

import SwiftUI

// MARK: - GitInfoPanel

struct GitInfoPanel: View {
    @Environment(\.appState) private var appState

    @State private var repoPath: String = ""
    @State private var currentBranch: String = ""
    @State private var commits: [GitService.CommitInfo] = []
    @State private var trackingInfo: GitService.TrackingInfo?
    @State private var isLoading: Bool = true
    @State private var isFetching: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader

            Divider()
                .background(Color.borderMuted)

            if isLoading {
                loadingView
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        // Branch info
                        branchSection

                        // Tracking status
                        if let tracking = trackingInfo {
                            trackingSection(tracking)
                        }

                        Divider()
                            .background(Color.borderMuted)

                        // Recent commits
                        commitsSection

                        Divider()
                            .background(Color.borderMuted)

                        // Worktrees
                        worktreesSection
                    }
                    .padding(Theme.Spacing.sm)
                }
            }

            Spacer(minLength: 0)

            // Quick actions footer
            quickActionsFooter
        }
        .frame(width: 220)
        .background(Color.dashboardPanelBg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color.borderMuted, lineWidth: 1)
        )
        .task {
            await loadGitInfo()
        }
    }

    // MARK: - Panel Header

    private var panelHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(Color.accentPrimary)

            Text("Git")
                .font(.h3)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button {
                Task { await loadGitInfo() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(height: 36)
    }

    // MARK: - Branch Section

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Current Branch")
                .font(.xs)
                .foregroundStyle(Color.textTertiary)

            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(Color.statusSuccess)
                    .frame(width: 8, height: 8)

                Text(currentBranch.isEmpty ? "..." : currentBranch)
                    .font(.code)
                    .foregroundStyle(Color.terminalGreen)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgElevated)
            .cornerRadius(Theme.Radius.sm)

            if !repoPath.isEmpty {
                Text(repoPath)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - Tracking Section

    private func trackingSection(_ tracking: GitService.TrackingInfo) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Ahead
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10))
                    Text("\(tracking.ahead)")
                        .font(.small)
                        .fontWeight(.medium)
                }
                .foregroundStyle(tracking.ahead > 0 ? Color.statusWarning : Color.textTertiary)

                Text("ahead")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }

            // Behind
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10))
                    Text("\(tracking.behind)")
                        .font(.small)
                        .fontWeight(.medium)
                }
                .foregroundStyle(tracking.behind > 0 ? Color.accentPrimary : Color.textTertiary)

                Text("behind")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            if let remote = tracking.remoteBranch {
                Text(remote)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Color.bgCanvas)
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Commits Section

    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Recent Commits")
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text("\(commits.count)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }

            if commits.isEmpty {
                Text("No commits")
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(commits.prefix(5)) { commit in
                        CompactCommitRow(commit: commit)
                        if commit.id != commits.prefix(5).last?.id {
                            Divider()
                                .background(Color.borderMuted)
                        }
                    }
                }
                .background(Color.bgCanvas)
                .cornerRadius(Theme.Radius.sm)
            }
        }
    }

    // MARK: - Worktrees Section

    private var worktreesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Worktrees")
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text("\(appState.worktrees.count)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)

                Button {
                    NotificationCenter.default.post(name: .showNewWorktreeSheet, object: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if appState.worktrees.isEmpty {
                Text("No worktrees")
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                VStack(spacing: 2) {
                    ForEach(appState.worktrees) { worktree in
                        WorktreeRow(worktree: worktree)
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions Footer

    private var quickActionsFooter: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                Task { await performFetch() }
            } label: {
                HStack(spacing: 4) {
                    if isFetching {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                    }
                    Text("Fetch")
                        .font(.xs)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.textSecondary)
            .disabled(isFetching)

            Spacer()

            Button {
                NotificationCenter.default.post(name: .showNewWorktreeSheet, object: nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                    Text("New")
                        .font(.xs)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentPrimary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.bgElevated)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.xs)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadGitInfo() async {
        isLoading = true

        let projectPath = appState.projectPath ?? FileManager.default.currentDirectoryPath
        let gitService = appState.services.gitService

        do {
            repoPath = try await gitService.getRepoRoot(path: projectPath)

            async let branchTask = gitService.getCurrentBranch(path: repoPath)
            async let commitsTask = gitService.getRecentCommits(path: repoPath, count: 5)
            async let trackingTask: GitService.TrackingInfo? = {
                do {
                    return try await gitService.getTrackingInfo(path: repoPath)
                } catch {
                    return nil
                }
            }()

            currentBranch = try await branchTask
            commits = try await commitsTask
            trackingInfo = await trackingTask

        } catch {
            // Use defaults on error
            currentBranch = "unknown"
            commits = []
        }

        isLoading = false
    }

    private func performFetch() async {
        isFetching = true
        let gitService = appState.services.gitService

        do {
            try await gitService.fetchAll(path: repoPath)
            trackingInfo = try? await gitService.getTrackingInfo(path: repoPath)
        } catch {
            appState.addLog(LogEntry(
                level: .error,
                source: "git",
                worktree: nil,
                message: "Fetch failed: \(error.localizedDescription)"
            ))
        }

        isFetching = false
    }
}

// MARK: - Compact Commit Row

private struct CompactCommitRow: View {
    let commit: GitService.CommitInfo

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(commit.shortSha)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.terminalYellow)

            Text(commit.message)
                .font(.system(size: 10))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, 4)
    }
}

// MARK: - Worktree Row

private struct WorktreeRow: View {
    let worktree: Worktree

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9))
                .foregroundStyle(Color.accentPrimary)

            Text(worktree.branch)
                .font(.system(size: 10))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, 4)
        .background(Color.bgCanvas)
        .cornerRadius(Theme.Radius.xs)
    }
}

// MARK: - Preview

#if DEBUG
struct GitInfoPanel_Previews: PreviewProvider {
    static var previews: some View {
        GitInfoPanel()
            .frame(height: 500)
            .padding()
            .background(Color.bgApp)
    }
}
#endif
