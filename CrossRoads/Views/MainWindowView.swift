//
//  MainWindowView.swift
//  CrossRoads
//
//  Created by Nexus on 2026-02-02.
//  Main window layout with NavigationSplitView (sidebar, content, inspector)
//

import SwiftUI

// MARK: - MainWindowView

struct MainWindowView: View {
    @Environment(\.appState) private var appState

    /// Column visibility state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// Controls the inspector visibility
    @State private var showInspector: Bool = true

    /// Controls the new worktree sheet
    @State private var showNewWorktreeSheet: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar (240px)
            SidebarView(showNewWorktreeSheet: $showNewWorktreeSheet)
                .navigationSplitViewColumnWidth(min: 200, ideal: Theme.Layout.sidebarWidth, max: 300)
        } content: {
            // MARK: - Content Area
            ContentColumn()
        } detail: {
            // MARK: - Inspector Panel (320px) - Logs
            if showInspector {
                InspectorColumn()
                    .navigationSplitViewColumnWidth(min: 280, ideal: Theme.Layout.inspectorWidth, max: 400)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // New Worktree Button
                Button {
                    showNewWorktreeSheet = true
                } label: {
                    Label("New Worktree", systemImage: "plus.rectangle.on.folder")
                }
                .help("Create a new worktree (⌘N)")

                // Toggle Inspector Button
                Button {
                    withAnimation(.easeInOut(duration: Theme.Animation.normal)) {
                        showInspector.toggle()
                    }
                } label: {
                    Label(
                        showInspector ? "Hide Inspector" : "Show Inspector",
                        systemImage: showInspector ? "sidebar.trailing" : "sidebar.trailing"
                    )
                }
                .help("Toggle logs panel")

                Divider()

                // Settings Button
                Button {
                    // TODO: Open settings (US-019)
                    #if os(macOS)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    #endif
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open settings (⌘,)")
            }
        }
        .background(Color.bgApp)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Content Column

private struct ContentColumn: View {
    @Environment(\.appState) private var appState

    var body: some View {
        Group {
            if let worktree = appState.selectedWorktree {
                WorktreeDetailView(worktree: worktree)
            } else {
                EmptySelectionView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgApp)
    }
}

// MARK: - Inspector Column (Logs)

private struct InspectorColumn: View {
    @Environment(\.appState) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(Color.terminalCyan)

                Text("Logs")
                    .font(.h2)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    appState.clearLogs()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear logs (⌘L)")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(height: Theme.Component.logHeaderHeight)

            Divider()
                .background(Color.borderMuted)

            // Logs Area
            LogsListView(logs: appState.filteredLogs)
        }
        .background(Color.bgCanvas)
    }
}

// MARK: - Worktree Detail View (Placeholder)

private struct WorktreeDetailView: View {
    let worktree: Worktree

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentPrimary)

                Text(worktree.name)
                    .font(.h1)
                    .foregroundStyle(Color.textPrimary)

                Text(worktree.branch)
                    .font(.body14)
                    .foregroundStyle(Color.textSecondary)
            }

            Divider()
                .background(Color.borderMuted)
                .padding(.horizontal, Theme.Spacing.xl)

            // Path
            HStack {
                Text("Path:")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)

                Text(worktree.path)
                    .font(.code)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            // Action Buttons (Placeholder for US-013)
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    // TODO: Start agent (US-013)
                } label: {
                    Label("Start Agent", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.statusSuccess)

                Button {
                    // TODO: Stop agent (US-013)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Selection View

private struct EmptySelectionView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 64))
                .foregroundStyle(Color.textTertiary)

            Text("Select a Worktree")
                .font(.h1)
                .foregroundStyle(Color.textSecondary)

            Text("Choose a worktree from the sidebar\nor create a new one to get started")
                .font(.body14)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Logs List View (uses TerminalView from US-011)

private struct LogsListView: View {
    let logs: [LogEntry]

    var body: some View {
        TerminalView(logs: logs)
    }
}

// MARK: - Preview

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .frame(width: Theme.Layout.minWindowWidth, height: Theme.Layout.minWindowHeight)
            .environment(\.appState, previewAppState())
    }

    static func previewAppState() -> AppState {
        let state = AppState(services: MockServiceContainer())

        // Add sample worktrees
        state.worktrees = [
            Worktree(path: "/Users/dev/project/wt-feature-1", branch: "feature/auth", agentId: nil),
            Worktree(path: "/Users/dev/project/wt-feature-2", branch: "feature/api", agentId: nil),
            Worktree(path: "/Users/dev/project/wt-bugfix", branch: "bugfix/login", agentId: nil)
        ]

        // Add sample logs
        state.logs = [
            LogEntry(level: .info, source: "claude", worktree: nil, message: "Starting agent..."),
            LogEntry(level: .debug, source: "git", worktree: nil, message: "Creating worktree at /Users/dev/project/wt-feature-1"),
            LogEntry(level: .warn, source: "mcp", worktree: nil, message: "Connection retry in 5s"),
            LogEntry(level: .error, source: "process", worktree: nil, message: "Process terminated unexpectedly")
        ]

        return state
    }
}
#endif
