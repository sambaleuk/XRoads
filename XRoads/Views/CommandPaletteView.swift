//
//  CommandPaletteView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-02.
//  Simple command palette for quick actions (⌘K)
//

import SwiftUI

// MARK: - Command Palette

/// A simple command palette for quick access to common actions
struct CommandPaletteView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0

    /// Callback when a command is executed
    var onCommand: ((PaletteCommand) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Search Field
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textTertiary)

                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body14)
                    .foregroundStyle(Color.textPrimary)
                    .onSubmit {
                        executeSelectedCommand()
                    }
            }
            .padding(Theme.Spacing.md)
            .background(Color.bgSurface)

            Divider()
                .background(Color.borderMuted)

            // Command List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                        CommandRow(
                            command: command,
                            isSelected: index == selectedIndex
                        )
                        .onTapGesture {
                            executeCommand(command)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 500)
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.return) {
            executeSelectedCommand()
            return .handled
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    // MARK: - Commands

    private var allCommands: [PaletteCommand] {
        var commands: [PaletteCommand] = [
            PaletteCommand(
                id: "new-worktree",
                title: "New Worktree",
                subtitle: "Create a new git worktree with an agent",
                icon: "plus.rectangle.on.folder",
                shortcut: "⌘N",
                category: .file
            ),
            PaletteCommand(
                id: "clear-logs",
                title: "Clear Logs",
                subtitle: "Clear all log entries",
                icon: "trash",
                shortcut: "⌘L",
                category: .view
            )
        ]

        // Add worktree-specific commands if a worktree is selected
        if appState.selectedWorktree != nil {
            commands.append(contentsOf: [
                PaletteCommand(
                    id: "close-worktree",
                    title: "Close Worktree",
                    subtitle: "Close the selected worktree",
                    icon: "xmark.rectangle",
                    shortcut: "⌘W",
                    category: .worktree
                ),
                PaletteCommand(
                    id: "stop-agent",
                    title: "Stop Agent",
                    subtitle: "Stop the running agent",
                    icon: "stop.fill",
                    shortcut: "⌘.",
                    category: .worktree
                ),
                PaletteCommand(
                    id: "start-agent",
                    title: "Start Agent",
                    subtitle: "Start the agent for this worktree",
                    icon: "play.fill",
                    shortcut: nil,
                    category: .worktree
                )
            ])
        }

        return commands
    }

    private var filteredCommands: [PaletteCommand] {
        guard !searchText.isEmpty else { return allCommands }
        let lowercased = searchText.lowercased()
        return allCommands.filter { command in
            command.title.lowercased().contains(lowercased) ||
            command.subtitle.lowercased().contains(lowercased)
        }
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        let count = filteredCommands.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func executeSelectedCommand() {
        guard selectedIndex < filteredCommands.count else { return }
        let command = filteredCommands[selectedIndex]
        executeCommand(command)
    }

    private func executeCommand(_ command: PaletteCommand) {
        onCommand?(command)
        dismiss()
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            Image(systemName: command.icon)
                .frame(width: 20)
                .foregroundStyle(command.category.color)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.body14)
                    .foregroundStyle(Color.textPrimary)

                Text(command.subtitle)
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            // Shortcut
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.code)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.bgSurface)
                    .cornerRadius(Theme.Radius.sm)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(isSelected ? Color.accentPrimary.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Palette Command

/// Represents a command in the palette
struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let shortcut: String?
    let category: CommandCategory
}

// MARK: - Command Category

enum CommandCategory {
    case file
    case worktree
    case view
    case settings

    var color: Color {
        switch self {
        case .file:
            return Color.accentPrimary
        case .worktree:
            return Color.statusSuccess
        case .view:
            return Color.terminalCyan
        case .settings:
            return Color.textSecondary
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CommandPaletteView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()

            CommandPaletteView()
                .environment(\.appState, AppState(services: MockServiceContainer()))
        }
        .frame(width: 600, height: 400)
    }
}
#endif
