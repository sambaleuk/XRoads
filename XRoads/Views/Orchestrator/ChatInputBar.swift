//
//  ChatInputBar.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-013: Input bar for orchestrator chat with mode toggle
//

import SwiftUI

// MARK: - ChatInputBar

/// Input bar for the orchestrator chat with mode toggle and send functionality
struct ChatInputBar: View {
    @Binding var text: String
    @Binding var mode: OrchestratorMode
    let isLoading: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool
    @State private var textEditorHeight: CGFloat = 36

    /// Maximum height for the text editor
    private let maxTextEditorHeight: CGFloat = 120
    /// Minimum height for the text editor
    private let minTextEditorHeight: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.borderMuted)

            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                // Mode toggle
                modeToggle

                // Text input area
                textInputArea

                // Send/Stop button
                actionButton
            }
            .padding(Theme.Spacing.md)
            .background(Color.bgSurface)
        }
    }

    // MARK: - Mode Toggle

    @ViewBuilder
    private var modeToggle: some View {
        Menu {
            ForEach(OrchestratorMode.allCases, id: \.self) { orchestratorMode in
                Button {
                    mode = orchestratorMode
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(orchestratorMode.displayName)
                            Text(orchestratorMode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: orchestratorMode.iconName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 12))
                Text(mode.displayName)
                    .font(.xs)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .background(Color.bgElevated)
            .cornerRadius(Theme.Radius.sm)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Toggle between API mode (fast) and Terminal mode (full capabilities)")
    }

    // MARK: - Text Input

    @ViewBuilder
    private var textInputArea: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholderText)
                    .font(.body14)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.sm)
                    .allowsHitTesting(false)
            }

            // Text editor
            TextEditor(text: $text)
                .font(.body14)
                .foregroundStyle(Color.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(minHeight: minTextEditorHeight, maxHeight: maxTextEditorHeight)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xs)
                .onSubmit {
                    if !text.isEmpty && !isLoading {
                        onSend()
                    }
                }
        }
        .background(Color.bgCanvas)
        .cornerRadius(Theme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(isFocused ? Color.borderAccent : Color.borderDefault, lineWidth: 1)
        )
    }

    private var placeholderText: String {
        switch mode {
        case .api:
            return "Ask about features, request PRDs, or get help..."
        case .terminal:
            return "Enter a command for Claude to execute..."
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        Button {
            if isLoading {
                onStop()
            } else {
                if !text.isEmpty {
                    onSend()
                }
            }
        } label: {
            Image(systemName: isLoading ? "stop.fill" : "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(buttonColor)
        }
        .buttonStyle(.plain)
        .disabled(!isLoading && text.isEmpty)
        .keyboardShortcut(.return, modifiers: .command)
        .help(isLoading ? "Stop generation (Cmd+.)" : "Send message (Cmd+Return)")
    }

    private var buttonColor: Color {
        if isLoading {
            return Color.statusError
        }
        return text.isEmpty ? Color.textTertiary : Color.accentPrimary
    }
}

// MARK: - Context Bar

/// Optional context bar showing current project info
struct ChatContextBar: View {
    let projectPath: String?
    let branch: String?
    let mode: DashboardMode
    var onOpenProject: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Project info
            if let path = projectPath {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.xs)
                }
                .foregroundStyle(Color.textSecondary)
                .onTapGesture {
                    onOpenProject?()
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 10))
                    Text("No project")
                        .font(.xs)
                }
                .foregroundStyle(Color.textTertiary)
            }

            // Branch info
            if let branch = branch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text(branch)
                        .font(.xs)
                }
                .foregroundStyle(Color.terminalCyan)
            }

            Spacer()

            // Dashboard mode badge
            HStack(spacing: 4) {
                Image(systemName: mode == .single ? "square" : "square.grid.2x2")
                    .font(.system(size: 10))
                Text(mode == .single ? "Single" : "Agentic")
                    .font(.xs)
            }
            .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.bgSurface)
    }
}

// MARK: - Preview

#if DEBUG
struct ChatInputBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            Spacer()

            ChatContextBar(
                projectPath: "/Users/dev/Projects/MyApp",
                branch: "main",
                mode: .agentic
            )

            ChatInputBar(
                text: .constant(""),
                mode: .constant(.api),
                isLoading: false,
                onSend: {},
                onStop: {}
            )
        }
        .background(Color.bgApp)
        .frame(width: 600, height: 200)
    }
}

struct ChatInputBar_Loading_Previews: PreviewProvider {
    static var previews: some View {
        ChatInputBar(
            text: .constant("Creating a login feature..."),
            mode: .constant(.terminal),
            isLoading: true,
            onSend: {},
            onStop: {}
        )
        .background(Color.bgApp)
        .frame(width: 600, height: 100)
    }
}
#endif
