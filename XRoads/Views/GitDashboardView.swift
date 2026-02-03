//
//  GitDashboardView.swift
//  XRoads
//
//  Quick Start view showing Git repo overview: recent commits, remotes, push status
//

import SwiftUI

// MARK: - GitDashboardView

struct GitDashboardView: View {
    @Environment(\.appState) private var appState

    @State private var repoPath: String = ""
    @State private var currentBranch: String = ""
    @State private var commits: [GitService.CommitInfo] = []
    @State private var remotes: [GitService.RemoteInfo] = []
    @State private var trackingInfo: GitService.TrackingInfo?
    @State private var isLoading: Bool = true
    @State private var error: String?
    @State private var isFetching: Bool = false
    @State private var isPulling: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header with repo info
                headerSection

                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else {
                    // Tracking Status (ahead/behind)
                    if let tracking = trackingInfo {
                        trackingSection(tracking)
                    }

                    // Quick Actions
                    quickActionsSection

                    // Recent Commits
                    commitsSection

                    // Remotes
                    remotesSection
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Color.bgApp)
        .task {
            await loadDashboard()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentPrimary)

            Text("Git Dashboard")
                .font(.h1)
                .foregroundStyle(Color.textPrimary)

            if !currentBranch.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(Color.terminalGreen)
                    Text(currentBranch)
                        .font(.code)
                        .foregroundStyle(Color.terminalGreen)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Color.bgElevated)
                .cornerRadius(Theme.Radius.sm)
            }

            if !repoPath.isEmpty {
                Text(repoPath)
                    .font(.small)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Theme.Spacing.md)
    }

    // MARK: - Tracking Section

    private func trackingSection(_ tracking: GitService.TrackingInfo) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            if let remote = tracking.remoteBranch {
                // Ahead indicator
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(tracking.ahead > 0 ? Color.statusWarning : Color.textTertiary)
                        Text("\(tracking.ahead)")
                            .font(.h2)
                            .foregroundStyle(tracking.ahead > 0 ? Color.statusWarning : Color.textTertiary)
                    }
                    Text("ahead")
                        .font(.xs)
                        .foregroundStyle(Color.textSecondary)
                }

                // Behind indicator
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(tracking.behind > 0 ? Color.accentPrimary : Color.textTertiary)
                        Text("\(tracking.behind)")
                            .font(.h2)
                            .foregroundStyle(tracking.behind > 0 ? Color.accentPrimary : Color.textTertiary)
                    }
                    Text("behind")
                        .font(.xs)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                // Remote branch name
                Text(remote)
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.sm)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.statusWarning)
                    Text("No upstream branch configured")
                        .font(.small)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgCanvas)
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Fetch button
            Button {
                Task { await performFetch() }
            } label: {
                HStack {
                    if isFetching {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("Fetch")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isFetching || isPulling)

            // Pull button
            Button {
                Task { await performPull() }
            } label: {
                HStack {
                    if isPulling {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                    Text("Pull")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.accentPrimary)
            .disabled(isFetching || isPulling || (trackingInfo?.behind ?? 0) == 0)

            // Refresh button
            Button {
                Task { await loadDashboard() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Commits Section

    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Color.terminalCyan)
                Text("Recent Commits")
                    .font(.h3)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(commits.count)")
                    .font(.small)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.bottom, Theme.Spacing.xs)

            if commits.isEmpty {
                Text("No commits found")
                    .font(.small)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(commits) { commit in
                        CommitRow(commit: commit)

                        if commit.id != commits.last?.id {
                            Divider()
                                .background(Color.borderMuted)
                        }
                    }
                }
                .background(Color.bgCanvas)
                .cornerRadius(Theme.Radius.md)
            }
        }
    }

    // MARK: - Remotes Section

    private var remotesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(Color.terminalMagenta)
                Text("Remotes")
                    .font(.h3)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(remotes.count)")
                    .font(.small)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.bottom, Theme.Spacing.xs)

            if remotes.isEmpty {
                Text("No remotes configured")
                    .font(.small)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(remotes) { remote in
                        RemoteRow(remote: remote)

                        if remote.id != remotes.last?.id {
                            Divider()
                                .background(Color.borderMuted)
                        }
                    }
                }
                .background(Color.bgCanvas)
                .cornerRadius(Theme.Radius.md)
            }
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading repository info...")
                .font(.body14)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.statusError)

            Text("Error Loading Repository")
                .font(.h2)
                .foregroundStyle(Color.textPrimary)

            Text(message)
                .font(.small)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await loadDashboard() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - Data Loading

    private func loadDashboard() async {
        isLoading = true
        error = nil

        // Use current directory or project path from settings
        let projectPath = appState.projectPath ?? FileManager.default.currentDirectoryPath
        let gitService = appState.services.gitService

        do {
            // Get repo root
            repoPath = try await gitService.getRepoRoot(path: projectPath)

            // Load all data in parallel
            async let branchTask = gitService.getCurrentBranch(path: repoPath)
            async let commitsTask = gitService.getRecentCommits(path: repoPath, count: 10)
            async let remotesTask = gitService.getRemotes(path: repoPath)
            async let trackingTask: GitService.TrackingInfo? = {
                do {
                    return try await gitService.getTrackingInfo(path: repoPath)
                } catch {
                    return nil
                }
            }()

            currentBranch = try await branchTask
            commits = try await commitsTask
            remotes = try await remotesTask
            trackingInfo = await trackingTask

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func performFetch() async {
        isFetching = true
        let gitService = appState.services.gitService

        do {
            try await gitService.fetchAll(path: repoPath)
            // Reload tracking info after fetch
            trackingInfo = try? await gitService.getTrackingInfo(path: repoPath)
        } catch {
            // Show error in logs
            appState.addLog(LogEntry(
                level: .error,
                source: "git",
                worktree: nil,
                message: "Fetch failed: \(error.localizedDescription)"
            ))
        }

        isFetching = false
    }

    private func performPull() async {
        isPulling = true
        let gitService = appState.services.gitService

        do {
            try await gitService.pull(path: repoPath)
            // Reload dashboard after pull
            await loadDashboard()
        } catch {
            appState.addLog(LogEntry(
                level: .error,
                source: "git",
                worktree: nil,
                message: "Pull failed: \(error.localizedDescription)"
            ))
        }

        isPulling = false
    }
}

// MARK: - Commit Row

private struct CommitRow: View {
    let commit: GitService.CommitInfo

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // SHA badge
            Text(commit.shortSha)
                .font(.code)
                .foregroundStyle(Color.terminalYellow)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 2)
                .background(Color.bgElevated)
                .cornerRadius(Theme.Radius.xs)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.body14)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(commit.author)
                        .font(.xs)
                        .foregroundStyle(Color.textSecondary)

                    Text("•")
                        .foregroundStyle(Color.textTertiary)

                    Text(commit.relativeDate)
                        .font(.xs)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - Remote Row

private struct RemoteRow: View {
    let remote: GitService.RemoteInfo

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Remote name
            Text(remote.name)
                .font(.code)
                .foregroundStyle(Color.terminalMagenta)
                .frame(width: 60, alignment: .leading)

            // URL
            VStack(alignment: .leading, spacing: 2) {
                Text(remote.fetchURL)
                    .font(.small)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if remote.fetchURL != remote.pushURL {
                    HStack(spacing: 4) {
                        Text("push:")
                            .font(.xs)
                            .foregroundStyle(Color.textTertiary)
                        Text(remote.pushURL)
                            .font(.xs)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - Preview

#if DEBUG
struct GitDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        GitDashboardView()
            .frame(width: 600, height: 800)
            .environment(\.appState, AppState(services: MockServiceContainer()))
    }
}
#endif
