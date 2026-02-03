//
//  MainWindowView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-02.
//  Main window layout with NavigationSplitView (sidebar, content, inspector)
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - MainWindowView

struct MainWindowView: View {
    @Environment(\.appState) private var appState

    /// Column visibility state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// Controls the inspector visibility
    @State private var showInspector: Bool = true

    /// Controls the new worktree sheet
    @State private var showNewWorktreeSheet: Bool = false

    /// Controls the command palette
    @State private var showCommandPalette: Bool = false

    /// Controls the PRD loader sheet
    @State private var showPRDLoaderSheet: Bool = false

    @AppStorage(UserDefaults.Keys.fullAgenticMode) private var isFullAgenticMode: Bool = false

    var body: some View {
        mainContent
            .background(Color.bgApp)
            .preferredColorScheme(.dark)
            .modifier(SheetsModifier(
                showNewWorktreeSheet: $showNewWorktreeSheet,
                showPRDLoaderSheet: $showPRDLoaderSheet,
                conflictSheetBinding: conflictSheetBinding,
                historySheetBinding: historySheetBinding
            ))
            .modifier(NotificationHandlersModifier(
                showNewWorktreeSheet: $showNewWorktreeSheet,
                showCommandPalette: $showCommandPalette,
                closeSelectedWorktree: closeSelectedWorktree,
                stopSelectedAgent: stopSelectedAgent,
                clearLogs: { appState.clearLogs() },
                requestQuit: {
                    Task { @MainActor in
                        await appState.cleanup()
                        NSApplication.shared.terminate(nil)
                    }
                }
            ))
            .modifier(LifecycleModifier(
                isFullAgenticMode: isFullAgenticMode,
                showPRDLoaderSheet: $showPRDLoaderSheet,
                startEventStream: { appState.startAgentEventStream() },
                stopEventStream: { appState.stopAgentEventStream() },
                pendingPRDURL: appState.pendingPRDURL
            ))
            .modifier(HealthDialogModifier(
                presentedIssue: appState.presentedHealthIssue,
                handleAction: { appState.handleHealthAction($0) },
                dialogTitle: healthDialogTitle
            ))
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            navigationContent
            commandPaletteOverlay
        }
    }

    @ViewBuilder
    private var navigationContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(showNewWorktreeSheet: $showNewWorktreeSheet)
                .navigationSplitViewColumnWidth(min: 200, ideal: Theme.Layout.sidebarWidth, max: 300)
        } content: {
            ContentColumn(isFullAgenticMode: isFullAgenticMode)
        } detail: {
            if showInspector {
                InspectorColumn()
                    .navigationSplitViewColumnWidth(min: 280, ideal: Theme.Layout.inspectorWidth, max: 400)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var commandPaletteOverlay: some View {
        if showCommandPalette {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showCommandPalette = false }

            VStack {
                CommandPaletteView(onCommand: handleCommand)
                    .padding(.top, 100)
                Spacer()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            toolbarButtons
        }
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        Button { showNewWorktreeSheet = true } label: {
            Label("New Worktree", systemImage: "plus.rectangle.on.folder")
        }
        .help("Create a new worktree (⌘N)")

        Button {
            withAnimation(.easeInOut(duration: Theme.Animation.normal)) {
                showInspector.toggle()
            }
        } label: {
            Label(showInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing")
        }
        .help("Toggle logs panel")

        Divider()

        Toggle(isOn: $isFullAgenticMode) {
            Label("Full Agentic Mode", systemImage: "chart.bar.doc.horizontal")
        }
        .toggleStyle(.switch)
        .help("Switch between manual worktree view and orchestration dashboard")

        Divider()

        Button { showPRDLoaderSheet = true } label: {
            Label("Load PRD", systemImage: "doc.text")
        }
        .help("Select a prd.json file to preview before orchestration")

        Button { appState.showHistorySheet = true } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
        .help("View past orchestrations")

        SettingsLink {
            Label("Settings", systemImage: "gearshape")
        }
        .help("Open settings (⌘,)")
    }

    // MARK: - Command Handlers

    private func handleCommand(_ command: PaletteCommand) {
        switch command.id {
        case "new-worktree":
            showNewWorktreeSheet = true
        case "close-worktree":
            closeSelectedWorktree()
        case "stop-agent":
            stopSelectedAgent()
        case "start-agent":
            startSelectedAgent()
        case "clear-logs":
            appState.clearLogs()
        default:
            break
        }
    }

    private func closeSelectedWorktree() {
        guard let worktree = appState.selectedWorktree else { return }
        appState.removeWorktree(worktree)
    }

    private func stopSelectedAgent() {
        guard let worktree = appState.selectedWorktree else { return }
        Task {
            let viewModel = SessionViewModel(services: appState.services)
            await viewModel.stopAgent(worktreeId: worktree.id)
        }
    }

    private func startSelectedAgent() {
        guard let worktree = appState.selectedWorktree else { return }
        Task {
            let viewModel = SessionViewModel(services: appState.services)
            await viewModel.startAgent(worktreeId: worktree.id)
        }
    }

    private var conflictSheetBinding: Binding<Bool> {
        Binding(
            get: { appState.isConflictSheetPresented },
            set: { appState.isConflictSheetPresented = $0 }
        )
    }

    private var historySheetBinding: Binding<Bool> {
        Binding(
            get: { appState.showHistorySheet },
            set: { appState.showHistorySheet = $0 }
        )
    }

    private func healthDialogTitle(for issue: AgentHealthIssue) -> String {
        let agentName = issue.agentType?.displayName ?? String(issue.agentId.prefix(6))
        return "\(agentName) Needs Attention"
    }
}

// MARK: - Content Column

private struct ContentColumn: View {
    @Environment(\.appState) private var appState
    let isFullAgenticMode: Bool

    var body: some View {
        Group {
            if isFullAgenticMode {
                ProgressDashboardView()
            } else if let worktree = appState.selectedWorktree {
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

                // MCP Connection Status Indicator
                MCPStatusBadge(status: appState.mcpConnectionStatus, isStreaming: appState.isStreamingLogs)

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
        .task {
            // Auto-start log streaming when view appears
            await appState.startLogStreaming()
        }
    }
}

// MARK: - MCP Status Badge

/// Badge showing MCP connection status
private struct MCPStatusBadge: View {
    let status: MCPConnectionStatus
    let isStreaming: Bool

    @State private var isPulsing: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing && isStreaming ? 1.2 : 1.0)
                .animation(
                    isStreaming ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                    value: isPulsing
                )

            // Status text
            Text(statusText)
                .font(.xs)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgElevated.opacity(0.5))
        .cornerRadius(Theme.Radius.sm)
        .onAppear {
            isPulsing = true
        }
        .onChange(of: isStreaming) { _, newValue in
            isPulsing = newValue
        }
    }

    private var statusColor: Color {
        switch status {
        case .disconnected:
            return Color.textTertiary
        case .connecting:
            return Color.statusWarning
        case .connected:
            return Color.statusSuccess
        case .error:
            return Color.statusError
        }
    }

    private var statusText: String {
        switch status {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return isStreaming ? "Streaming" : "Connected"
        case .error(let message):
            return "Error: \(message.prefix(20))"
        }
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

// MARK: - Sheets Modifier

private struct SheetsModifier: ViewModifier {
    @Binding var showNewWorktreeSheet: Bool
    @Binding var showPRDLoaderSheet: Bool
    let conflictSheetBinding: Binding<Bool>
    let historySheetBinding: Binding<Bool>
    @Environment(\.appState) private var appState

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showNewWorktreeSheet) {
                WorktreeCreateSheet()
            }
            .sheet(isPresented: conflictSheetBinding) {
                ConflictResolutionSheet()
            }
            .sheet(isPresented: $showPRDLoaderSheet, onDismiss: {
                appState.clearPendingPRDURL()
            }) {
                PRDLoaderSheet(initialURL: appState.pendingPRDURL)
            }
            .sheet(isPresented: historySheetBinding) {
                OrchestrationHistorySheet()
            }
    }
}

// MARK: - Notification Handlers Modifier

private struct NotificationHandlersModifier: ViewModifier {
    @Binding var showNewWorktreeSheet: Bool
    @Binding var showCommandPalette: Bool
    let closeSelectedWorktree: () -> Void
    let stopSelectedAgent: () -> Void
    let clearLogs: () -> Void
    let requestQuit: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .showNewWorktreeSheet)) { _ in
                showNewWorktreeSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeSelectedWorktree)) { _ in
                closeSelectedWorktree()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopSelectedAgent)) { _ in
                stopSelectedAgent()
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearLogs)) { _ in
                clearLogs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
                showCommandPalette = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestAppQuit)) { _ in
                requestQuit()
            }
    }
}

// MARK: - Lifecycle Modifier

private struct LifecycleModifier: ViewModifier {
    let isFullAgenticMode: Bool
    @Binding var showPRDLoaderSheet: Bool
    let startEventStream: () -> Void
    let stopEventStream: () -> Void
    let pendingPRDURL: URL?
    
    @Environment(\.appState) private var appState

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Start MCP log streaming when app launches
                Task {
                    await appState.startLogStreaming()
                }
                
                if isFullAgenticMode {
                    startEventStream()
                } else {
                    stopEventStream()
                }
            }
            .onChange(of: isFullAgenticMode) { _, newValue in
                if newValue {
                    startEventStream()
                } else {
                    stopEventStream()
                }
            }
            .onChange(of: pendingPRDURL) { _, newURL in
                if newURL != nil {
                    showPRDLoaderSheet = true
                }
            }
    }
}

// MARK: - Health Dialog Modifier

private struct HealthDialogModifier: ViewModifier {
    let presentedIssue: AgentHealthIssue?
    let handleAction: (AgentHealthAction) -> Void
    let dialogTitle: (AgentHealthIssue) -> String

    private var isPresented: Binding<Bool> {
        Binding(
            get: { presentedIssue != nil },
            set: { if !$0 { handleAction(.wait) } }
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                presentedIssue.map { dialogTitle($0) } ?? "Agent Issue",
                isPresented: isPresented,
                presenting: presentedIssue
            ) { issue in
                Button("Wait (Remind Me Later)") { handleAction(.wait) }
                Button("Restart Agent") { handleAction(.restart) }
                Button("Reassign Task") { handleAction(.reassign) }
                Button("Abort Agent", role: .destructive) { handleAction(.abort) }
                Button("Cancel", role: .cancel) { handleAction(.wait) }
            } message: { issue in
                Text(issue.message)
            }
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
