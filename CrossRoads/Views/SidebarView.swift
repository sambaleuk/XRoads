//
//  SidebarView.swift
//  CrossRoads
//
//  Created by Nexus on 2026-02-02.
//  Sidebar view displaying worktrees list with WorktreeCard components.
//

import SwiftUI

// MARK: - SidebarView

/// Main sidebar component showing worktrees list
struct SidebarView: View {
    @Environment(\.appState) private var appState
    @Binding var showNewWorktreeSheet: Bool

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            SidebarHeader(
                worktreeCount: appState.worktrees.count,
                onAddTapped: { showNewWorktreeSheet = true }
            )

            Divider()
                .background(Color.borderMuted)

            // MARK: - Worktrees List
            if appState.worktrees.isEmpty {
                SidebarEmptyState {
                    showNewWorktreeSheet = true
                }
            } else {
                WorktreesList()
            }
        }
        .background(Color.bgSurface)
    }
}

// MARK: - SidebarHeader

/// Header with "Worktrees" title, count badge, and add button
private struct SidebarHeader: View {
    let worktreeCount: Int
    let onAddTapped: () -> Void

    var body: some View {
        HStack {
            // Section title
            Text("Worktrees")
                .font(.h2)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            // Count badge
            Text("\(worktreeCount)")
                .font(.small)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Color.bgElevated)
                .clipShape(Capsule())

            // Add button
            Button {
                onAddTapped()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.bgElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Add Worktree")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - WorktreesList

/// List of worktrees with WorktreeCard components
private struct WorktreesList: View {
    @Environment(\.appState) private var appState

    var body: some View {
        List(selection: worktreeSelection) {
            ForEach(appState.worktrees) { worktree in
                WorktreeListItem(worktree: worktree)
                    .tag(worktree.id)
                    .listRowInsets(EdgeInsets(
                        top: Theme.Spacing.xs,
                        leading: Theme.Spacing.sm,
                        bottom: Theme.Spacing.xs,
                        trailing: Theme.Spacing.sm
                    ))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var worktreeSelection: Binding<UUID?> {
        Binding(
            get: { appState.selectedWorktree?.id },
            set: { id in
                if let id = id {
                    appState.selectWorktree(appState.worktrees.first { $0.id == id })
                } else {
                    appState.selectWorktree(nil)
                }
            }
        )
    }
}

// MARK: - WorktreeListItem

/// Individual worktree item using WorktreeCard
private struct WorktreeListItem: View {
    @Environment(\.appState) private var appState
    let worktree: Worktree

    var body: some View {
        WorktreeCard(
            worktree: worktree,
            agentType: agentType,
            status: agentStatus,
            isSelected: isSelected
        )
    }

    private var isSelected: Bool {
        appState.selectedWorktree?.id == worktree.id
    }

    private var agent: Agent? {
        appState.agent(for: worktree)
    }

    private var agentType: AgentType? {
        agent?.type
    }

    private var agentStatus: AgentStatus {
        agent?.status ?? .idle
    }
}

// MARK: - SidebarEmptyState

/// Empty state view when no worktrees exist
private struct SidebarEmptyState: View {
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            Text("No Worktrees")
                .font(.h2)
                .foregroundStyle(Color.textSecondary)

            Text("Create a worktree to start\nworking with AI agents")
                .font(.small)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)

            Button("Create Worktree") {
                onCreateTapped()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
            .padding(.top, Theme.Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With worktrees
            SidebarView(showNewWorktreeSheet: .constant(false))
                .frame(width: Theme.Layout.sidebarWidth, height: 600)
                .environment(\.appState, previewAppStateWithWorktrees())

            // Empty state
            SidebarView(showNewWorktreeSheet: .constant(false))
                .frame(width: Theme.Layout.sidebarWidth, height: 600)
                .environment(\.appState, AppState(services: MockServiceContainer()))
        }
    }

    static func previewAppStateWithWorktrees() -> AppState {
        let state = AppState(services: MockServiceContainer())

        // Create agents
        let claudeAgent = Agent(type: .claude, status: .running, worktreePath: "/dev/project/wt-auth")
        let geminiAgent = Agent(type: .gemini, status: .planning, worktreePath: "/dev/project/wt-api")
        let codexAgent = Agent(type: .codex, status: .error, worktreePath: "/dev/project/wt-tests")

        state.agents[claudeAgent.id] = claudeAgent
        state.agents[geminiAgent.id] = geminiAgent
        state.agents[codexAgent.id] = codexAgent

        // Create worktrees with agents
        state.worktrees = [
            Worktree(
                path: "/Users/dev/Projects/MyApp/worktrees/feature-auth",
                branch: "feature/authentication",
                agentId: claudeAgent.id
            ),
            Worktree(
                path: "/Users/dev/Projects/MyApp/worktrees/feature-api",
                branch: "feature/api-endpoints",
                agentId: geminiAgent.id
            ),
            Worktree(
                path: "/Users/dev/Projects/MyApp/worktrees/test-coverage",
                branch: "test/unit-tests",
                agentId: codexAgent.id
            ),
            Worktree(
                path: "/Users/dev/Projects/MyApp/worktrees/orphan",
                branch: "orphan-branch",
                agentId: nil
            )
        ]

        return state
    }
}
#endif
