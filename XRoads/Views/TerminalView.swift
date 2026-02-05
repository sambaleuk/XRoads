//
//  TerminalView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-02.
//  US-011: Real-time log display terminal with auto-scroll
//

import SwiftUI

// MARK: - Terminal Display Style

/// Display style for terminal logs
enum TerminalDisplayStyle {
    /// Wide layout with columns for timestamp, level, source, message
    case wide
    /// Compact layout optimized for narrow panels (stacked layout)
    case compact
}

// MARK: - TerminalView

/// A terminal-style view for displaying logs in real-time with auto-scroll
struct TerminalView: View {
    let logs: [LogEntry]
    var style: TerminalDisplayStyle = .wide

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
                    LazyVStack(alignment: .leading, spacing: style == .compact ? 6 : 2) {
                        ForEach(displayedLogs) { log in
                            Group {
                                switch style {
                                case .wide:
                                    LogLineView(log: log)
                                case .compact:
                                    CompactLogLineView(log: log)
                                }
                            }
                            .id(log.id)
                        }
                    }
                    .padding(style == .compact ? Theme.Spacing.xs : Theme.Spacing.sm)
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

// MARK: - Compact Log Line View

/// Compact log line optimized for narrow panels (280px)
/// Uses vertical stacking: header row (time + level + source) and message row
struct CompactLogLineView: View {
    let log: LogEntry
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row: level indicator + time + source
            HStack(spacing: 6) {
                // Level dot
                Circle()
                    .fill(levelColor)
                    .frame(width: 6, height: 6)

                // Time (short format)
                Text(shortTimestamp)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)

                // Source badge
                Text(log.source)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(sourceColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(sourceColor.opacity(0.15))
                    .cornerRadius(3)

                // Worktree (if present, truncated)
                if let worktree = log.worktree, !worktree.isEmpty {
                    Text(truncatedWorktree(worktree))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.accentPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            // Message row (full width, wraps)
            Text(log.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(isExpanded ? nil : 3)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            // Show expand hint if message is long
            if log.message.count > 100 && !isExpanded {
                Text("Tap to expand...")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(levelBackgroundColor)
        .cornerRadius(4)
    }

    /// Short timestamp format "HH:mm"
    private var shortTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: log.timestamp)
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

    /// Background color based on level (subtle)
    private var levelBackgroundColor: Color {
        switch log.level {
        case .debug:
            return Color.clear
        case .info:
            return Color.terminalCyan.opacity(0.05)
        case .warn:
            return Color.terminalYellow.opacity(0.08)
        case .error:
            return Color.terminalRed.opacity(0.1)
        }
    }

    /// Source tag color
    private var sourceColor: Color {
        switch log.source.lowercased() {
        case "claude":
            return Color.accentPrimary
        case "gemini":
            return Color.terminalYellow
        case "codex":
            return Color.statusSuccess
        case "system", "orchestrator":
            return Color.terminalMagenta
        case "git":
            return Color.statusWarning
        case "mcp":
            return Color.terminalCyan
        case "user":
            return Color.textSecondary
        default:
            return Color.textSecondary
        }
    }

    /// Truncate long worktree paths to just the name
    private func truncatedWorktree(_ path: String) -> String {
        if let lastComponent = path.split(separator: "/").last {
            let name = String(lastComponent)
            return name.count > 15 ? String(name.prefix(12)) + "..." : name
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
            LogEntry(level: .info, source: "mcp", worktree: nil, message: "Connected to XRoads MCP server"),
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

struct CompactTerminalView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // Header simulation (like MCP Logs panel)
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(Color.terminalCyan)
                    .font(.system(size: 12))

                Text("MCP LOGS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                // Simulated clear button
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.bgSurface)

            // Compact terminal view
            TerminalView(logs: compactSampleLogs, style: .compact)
        }
        .frame(width: 280, height: 400)
        .background(Color.bgCanvas)
        .preferredColorScheme(.dark)
    }

    static var compactSampleLogs: [LogEntry] {
        [
            LogEntry(level: .info, source: "claude", worktree: nil, message: "Starting agent with PTY support..."),
            LogEntry(level: .debug, source: "git", worktree: "/Users/dev/project/wt-feature", message: "Creating worktree for feature branch"),
            LogEntry(level: .info, source: "mcp", worktree: nil, message: "Connected to XRoads MCP server on port 3000"),
            LogEntry(level: .warn, source: "system", worktree: "wt-auth", message: "Process using high memory (512MB). Consider optimizing or restarting."),
            LogEntry(level: .error, source: "claude", worktree: "/Users/dev/project/wt-api", message: "Connection lost to Claude API. Retrying in 5 seconds... This is a longer error message that should wrap properly in the compact view."),
            LogEntry(level: .info, source: "gemini", worktree: nil, message: "Task completed successfully"),
            LogEntry(level: .debug, source: "orchestrator", worktree: nil, message: "All agents idle, ready for next task"),
            LogEntry(level: .info, source: "user", worktree: "wt-feature", message: "▶ implement the login feature")
        ]
    }
}
#endif
