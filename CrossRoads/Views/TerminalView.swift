//
//  TerminalView.swift
//  CrossRoads
//
//  Created by Nexus on 2026-02-02.
//  US-011: Real-time log display terminal with auto-scroll
//

import SwiftUI

// MARK: - TerminalView

/// A terminal-style view for displaying logs in real-time with auto-scroll
struct TerminalView: View {
    let logs: [LogEntry]

    /// Maximum number of logs to display for performance
    private let maxDisplayedLogs = 500

    /// Logs limited to maxDisplayedLogs for performance
    private var displayedLogs: [LogEntry] {
        if logs.count > maxDisplayedLogs {
            return Array(logs.suffix(maxDisplayedLogs))
        }
        return logs
    }

    var body: some View {
        if displayedLogs.isEmpty {
            EmptyLogsView()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(displayedLogs) { log in
                            LogLineView(log: log)
                                .id(log.id)
                        }
                    }
                    .padding(Theme.Spacing.sm)
                }
                .onChange(of: logs.count) { _, _ in
                    // Auto-scroll to bottom when new logs arrive
                    if let lastLog = displayedLogs.last {
                        withAnimation(.easeOut(duration: Theme.Animation.fast)) {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.bgCanvas)
        }
    }
}

// MARK: - LogLineView

/// Individual log line with timestamp, level, source, worktree, and message
struct LogLineView: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Timestamp [HH:mm:ss]
            Text(log.formattedTimestamp)
                .font(.terminal)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 76, alignment: .leading)

            // Level indicator (fixed width for alignment)
            Text(log.level.displayName)
                .font(.terminal)
                .foregroundStyle(levelColor)
                .frame(width: 44, alignment: .leading)

            // Source tag
            if !log.source.isEmpty {
                Text("[\(log.source)]")
                    .font(.terminal)
                    .foregroundStyle(Color.textSecondary)
            }

            // Worktree tag (if present)
            if let worktree = log.worktree, !worktree.isEmpty {
                Text("<\(truncatedWorktree(worktree))>")
                    .font(.terminal)
                    .foregroundStyle(Color.accentPrimary)
            }

            // Message (multi-line allowed)
            Text(log.message)
                .font(.terminal)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(nil)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    /// Color based on log level
    private var levelColor: Color {
        switch log.level {
        case .debug:
            return Color.textTertiary
        case .info:
            return Color.terminalCyan
        case .warn:
            return Color.terminalYellow
        case .error:
            return Color.terminalRed
        }
    }

    /// Truncate long worktree paths to just the name
    private func truncatedWorktree(_ path: String) -> String {
        if let lastComponent = path.split(separator: "/").last {
            return String(lastComponent)
        }
        return path
    }
}

// MARK: - Empty Logs View

/// Placeholder view when no logs are present
private struct EmptyLogsView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()

            Image(systemName: "text.alignleft")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)

            Text("No logs yet")
                .font(.small)
                .foregroundStyle(Color.textTertiary)

            Text("Logs will appear here when agents start running")
                .font(.xs)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgCanvas)
    }
}

// MARK: - Preview

#if DEBUG
struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // Header simulation
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(Color.terminalCyan)
                Text("Logs")
                    .font(.h2)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Color.bgCanvas)

            Divider()
                .background(Color.borderMuted)

            // Terminal view with sample logs
            TerminalView(logs: sampleLogs)
        }
        .frame(width: 400, height: 300)
        .background(Color.bgCanvas)
        .preferredColorScheme(.dark)
    }

    static var sampleLogs: [LogEntry] {
        [
            LogEntry(level: .info, source: "claude", worktree: nil, message: "Starting agent..."),
            LogEntry(level: .debug, source: "git", worktree: "/Users/dev/project/wt-feature", message: "Creating worktree"),
            LogEntry(level: .info, source: "mcp", worktree: nil, message: "Connected to CrossRoads MCP server"),
            LogEntry(level: .warn, source: "process", worktree: "wt-auth", message: "Process using high memory"),
            LogEntry(level: .error, source: "claude", worktree: "/Users/dev/project/wt-api", message: "Connection lost, retrying..."),
            LogEntry(level: .info, source: "gemini", worktree: nil, message: "Task completed successfully"),
            LogEntry(level: .debug, source: "system", worktree: nil, message: "Refreshing state from MCP")
        ]
    }
}

struct EmptyTerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView(logs: [])
            .frame(width: 400, height: 200)
            .preferredColorScheme(.dark)
    }
}
#endif
