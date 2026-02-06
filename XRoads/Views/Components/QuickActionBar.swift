//
//  QuickActionBar.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Quick action bar for one-click repo actions with auto-detection
//

import SwiftUI

// MARK: - QuickActionBar

/// Bar displaying quick action buttons for detected repository
struct QuickActionBar: View {
    @Environment(\.appState) private var appState

    let repoInfo: RepoInfo
    let onActionSelected: (ActionType, RepoInfo) -> Void
    let onSettingsPressed: (() -> Void)?

    @State private var selectedAction: ActionType?
    @State private var isLoadingAction: ActionType?
    @State private var availableSkills: [String: [Skill]] = [:]

    init(
        repoInfo: RepoInfo,
        onActionSelected: @escaping (ActionType, RepoInfo) -> Void,
        onSettingsPressed: (() -> Void)? = nil
    ) {
        self.repoInfo = repoInfo
        self.onActionSelected = onActionSelected
        self.onSettingsPressed = onSettingsPressed
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Repo header
            repoHeader

            Divider()
                .background(Color.borderMuted)

            // Action buttons
            actionButtons

            // Quick info
            quickInfo
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgSurface)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.borderMuted, lineWidth: 1)
        )
        .task {
            await loadSkillsForActions()
        }
    }

    // MARK: - Repo Header

    private var repoHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Repo icon
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(repoInfo.displayName)
                    .font(.h3)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text(repoInfo.branch)
                        .font(.code)
                }
                .foregroundStyle(Color.terminalGreen)
            }

            Spacer()

            // Settings button
            if let onSettings = onSettingsPressed {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Configure actions")
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(ActionType.primaryActions, id: \.self) { action in
                QuickActionButton(
                    action: action,
                    isLoading: isLoadingAction == action,
                    isSelected: selectedAction == action,
                    skillCount: availableSkills[action.rawValue]?.count ?? 0
                ) {
                    handleActionTap(action)
                }
            }
        }
    }

    // MARK: - Quick Info

    private var quickInfo: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Path
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                Text(truncatedPath(repoInfo.path))
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.textTertiary)
            .lineLimit(1)

            Spacer()

            // Last accessed
            Text(relativeDate(repoInfo.lastAccessedAt))
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Actions

    private func handleActionTap(_ action: ActionType) {
        guard isLoadingAction == nil else { return }

        selectedAction = action
        isLoadingAction = action

        // Delay to show loading state briefly
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            onActionSelected(action, repoInfo)
            isLoadingAction = nil
        }
    }

    private func loadSkillsForActions() async {
        let registry = SkillRegistry.shared
        for action in ActionType.primaryActions {
            let allSkills = await registry.skills(for: .claude)
            let actionSkills = allSkills.filter { action.requiredSkills.contains($0.id) }
            availableSkills[action.rawValue] = actionSkills
        }
    }

    // MARK: - Helpers

    private func truncatedPath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        if components.count > 3 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return path
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - QuickActionButton

/// Individual quick action button
private struct QuickActionButton: View {
    let action: ActionType
    let isLoading: Bool
    let isSelected: Bool
    let skillCount: Int
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.Spacing.xs) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(buttonBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(isSelected ? Color.accentPrimary : Color.borderMuted, lineWidth: 1)
                        )

                    // Icon or loading
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(Color.textPrimary)
                    } else {
                        Image(systemName: action.iconName)
                            .font(.system(size: 18))
                            .foregroundStyle(iconColor)
                    }
                }
                .frame(width: 48, height: 48)

                // Label
                Text(action.displayName)
                    .font(.xs)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)

                // Skill count badge
                if skillCount > 0 && !isLoading {
                    Text("\(skillCount) skills")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(action.description)
    }

    private var buttonBackground: Color {
        if isSelected {
            return Color.accentPrimary.opacity(0.15)
        } else if isHovered {
            return Color.bgElevated
        } else {
            return Color.bgCanvas
        }
    }

    private var iconColor: Color {
        if isSelected {
            return Color.accentPrimary
        } else {
            return action.accentColor
        }
    }
}

// MARK: - ActionType Extensions

extension ActionType {
    /// Primary actions shown in the quick action bar
    static var primaryActions: [ActionType] {
        [.implement, .review, .integrationTest, .write]
    }
}

// MARK: - Compact Quick Action Bar

/// Compact version for sidebar or smaller spaces
struct CompactQuickActionBar: View {
    let repoInfo: RepoInfo
    let onActionSelected: (ActionType, RepoInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Repo name
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentPrimary)

                Text(repoInfo.displayName)
                    .font(.small)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(repoInfo.branch)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.terminalGreen)
            }

            // Action buttons row
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(ActionType.primaryActions, id: \.self) { action in
                    CompactActionButton(action: action) {
                        onActionSelected(action, repoInfo)
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Color.bgCanvas)
        .cornerRadius(Theme.Radius.sm)
    }
}

/// Compact action button for sidebar
private struct CompactActionButton: View {
    let action: ActionType
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: action.iconName)
                    .font(.system(size: 10))
                Text(action.shortName)
                    .font(.system(size: 10))
            }
            .foregroundStyle(isHovered ? Color.textPrimary : Color.textSecondary)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 4)
            .background(isHovered ? Color.bgElevated : Color.clear)
            .cornerRadius(Theme.Radius.xs)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(action.description)
    }
}

extension ActionType {
    /// Short name for compact displays
    var shortName: String {
        switch self {
        case .implement:
            return "Impl"
        case .review:
            return "Review"
        case .integrationTest:
            return "Test"
        case .write:
            return "Docs"
        case .custom:
            return "Custom"
        }
    }
}

// MARK: - Recent Repos List

/// List of recent repositories with quick actions
struct RecentReposList: View {
    let repos: [RepoInfo]
    let onRepoSelected: (RepoInfo) -> Void
    let onActionSelected: (ActionType, RepoInfo) -> Void
    let onRepoRemoved: ((RepoInfo) -> Void)?

    init(
        repos: [RepoInfo],
        onRepoSelected: @escaping (RepoInfo) -> Void,
        onActionSelected: @escaping (ActionType, RepoInfo) -> Void,
        onRepoRemoved: ((RepoInfo) -> Void)? = nil
    ) {
        self.repos = repos
        self.onRepoSelected = onRepoSelected
        self.onActionSelected = onActionSelected
        self.onRepoRemoved = onRepoRemoved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Header
            HStack {
                Text("Recent Repositories")
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text("\(repos.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }

            if repos.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(repos) { repo in
                        RecentRepoRow(
                            repo: repo,
                            onTap: { onRepoSelected(repo) },
                            onActionSelected: { action in onActionSelected(action, repo) },
                            onRemove: onRepoRemoved != nil ? { onRepoRemoved?(repo) } : nil
                        )

                        if repo.id != repos.last?.id {
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

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)
            Text("No recent repos")
                .font(.xs)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
    }
}

/// Row for a recent repository
private struct RecentRepoRow: View {
    let repo: RepoInfo
    let onTap: () -> Void
    let onActionSelected: (ActionType) -> Void
    let onRemove: (() -> Void)?

    @State private var isHovered: Bool = false
    @State private var showingActions: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Repo info
            Button(action: onTap) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.displayName)
                            .font(.small)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        Text(repo.branch)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.terminalGreen)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Quick action buttons or remove button
            if isHovered {
                HStack(spacing: Theme.Spacing.xs) {
                    // Quick implement button
                    Button {
                        onActionSelected(.implement)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.statusSuccess)
                    }
                    .buttonStyle(.plain)
                    .help("Start Implement action")

                    // More actions
                    Menu {
                        ForEach(ActionType.primaryActions, id: \.self) { action in
                            Button {
                                onActionSelected(action)
                            } label: {
                                Label(action.displayName, systemImage: action.iconName)
                            }
                        }

                        if let onRemove = onRemove {
                            Divider()
                            Button(role: .destructive) {
                                onRemove()
                            } label: {
                                Label("Remove from Recent", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(isHovered ? Color.bgElevated : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#if DEBUG
struct QuickActionBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            QuickActionBar(
                repoInfo: RepoInfo(
                    path: "/Users/dev/projects/my-app",
                    name: "my-app",
                    branch: "main"
                ),
                onActionSelected: { action, repo in
                    print("Selected \(action.displayName) for \(repo.displayName)")
                }
            )

            CompactQuickActionBar(
                repoInfo: RepoInfo(
                    path: "/Users/dev/projects/my-app",
                    name: "my-app",
                    branch: "feature/auth"
                ),
                onActionSelected: { action, repo in
                    print("Selected \(action.displayName) for \(repo.displayName)")
                }
            )

            RecentReposList(
                repos: [
                    RepoInfo(path: "/Users/dev/project1", name: "project1", branch: "main"),
                    RepoInfo(path: "/Users/dev/project2", name: "project2", branch: "develop"),
                    RepoInfo(path: "/Users/dev/project3", name: "project3", branch: "feature/ui")
                ],
                onRepoSelected: { _ in },
                onActionSelected: { _, _ in },
                onRepoRemoved: { _ in }
            )
        }
        .padding()
        .frame(width: 400)
        .background(Color.bgApp)
    }
}
#endif
