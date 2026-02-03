//
//  TerminalInputBar.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  US-V3-004: Interactive terminal input bar for stdin interaction
//

import SwiftUI

// MARK: - TerminalInputBar

/// Input bar component for sending text to process stdin
/// Supports single-line and multi-line input (shift+enter for newlines)
struct TerminalInputBar: View {
    /// Callback when text is submitted
    let onSubmit: (String) -> Void

    /// Whether input is currently enabled (process is running)
    let isEnabled: Bool

    /// Whether the agent is waiting for input
    let isWaitingForInput: Bool

    /// Placeholder text
    var placeholder: String = "Type a message..."

    @State private var inputText: String = ""
    @State private var isMultiLine: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Waiting for input indicator
            if isWaitingForInput && isEnabled {
                waitingIndicator
            }

            // Input area
            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                // Text input field
                inputField

                // Send button
                sendButton
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.bgElevated)
        }
    }

    // MARK: - Waiting Indicator

    private var waitingIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(Color.statusWarning)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier())

            Text("Agent waiting for input")
                .font(.xs)
                .foregroundStyle(Color.statusWarning)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.statusWarning.opacity(0.1))
    }

    // MARK: - Input Field

    @ViewBuilder
    private var inputField: some View {
        if isMultiLine {
            // Multi-line text editor
            TextEditor(text: $inputText)
                .font(.terminal)
                .foregroundStyle(isEnabled ? Color.textPrimary : Color.textTertiary)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.xs)
                .frame(minHeight: 60, maxHeight: 120)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(isFocused ? Color.borderAccent : Color.borderDefault, lineWidth: 1)
                )
                .focused($isFocused)
                .disabled(!isEnabled)
        } else {
            // Single-line text field
            TextField(placeholder, text: $inputText, axis: .vertical)
                .font(.terminal)
                .foregroundStyle(isEnabled ? Color.textPrimary : Color.textTertiary)
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.xs)
                .frame(minHeight: 32)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(isFocused ? Color.borderAccent : Color.borderDefault, lineWidth: 1)
                )
                .focused($isFocused)
                .disabled(!isEnabled)
                .onSubmit {
                    submitInput()
                }
                .onKeyPress(.return, phases: .down) { event in
                    if event.modifiers.contains(.shift) {
                        // Shift+Enter: switch to multi-line mode
                        isMultiLine = true
                        inputText += "\n"
                        return .handled
                    }
                    // Plain Enter: submit
                    submitInput()
                    return .handled
                }
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button(action: submitInput) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(canSubmit ? Color.accentPrimary : Color.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .keyboardShortcut(.return, modifiers: isMultiLine ? .command : [])
        .help(isMultiLine ? "Send (⌘Return)" : "Send (Return)")
    }

    // MARK: - Computed Properties

    private var canSubmit: Bool {
        isEnabled && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty && isEnabled else { return }

        onSubmit(text)
        inputText = ""
        isMultiLine = false
    }
}

// MARK: - Pulse Modifier

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - TerminalInputBarStyle

/// Style options for the input bar
enum TerminalInputBarStyle {
    case compact    // Minimal height, for slot views
    case standard   // Standard height for main terminals
    case expanded   // Expanded for focused input
}

// MARK: - Compact Input Bar

/// Compact version of the input bar for terminal slots
struct CompactTerminalInputBar: View {
    let onSubmit: (String) -> Void
    let isEnabled: Bool
    let isWaitingForInput: Bool

    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            // Waiting indicator
            if isWaitingForInput && isEnabled {
                Circle()
                    .fill(Color.statusWarning)
                    .frame(width: 6, height: 6)
                    .modifier(PulseModifier())
            }

            // Input field
            TextField("Input...", text: $inputText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isEnabled ? Color.textPrimary : Color.textTertiary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.bgCanvas)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xs)
                        .stroke(isFocused ? Color.borderAccent : Color.borderMuted, lineWidth: 1)
                )
                .focused($isFocused)
                .disabled(!isEnabled)
                .onSubmit {
                    submitInput()
                }

            // Send button
            Button(action: submitInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(canSubmit ? Color.accentPrimary : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, 4)
        .background(Color.bgElevated)
    }

    private var canSubmit: Bool {
        isEnabled && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty && isEnabled else { return }

        onSubmit(text)
        inputText = ""
    }
}

// MARK: - Preview

#if DEBUG
struct TerminalInputBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Standard input bar - enabled
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Standard - Enabled")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
                TerminalInputBar(
                    onSubmit: { text in print("Submitted: \(text)") },
                    isEnabled: true,
                    isWaitingForInput: false
                )
            }

            // Standard input bar - waiting
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Standard - Waiting for Input")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
                TerminalInputBar(
                    onSubmit: { text in print("Submitted: \(text)") },
                    isEnabled: true,
                    isWaitingForInput: true
                )
            }

            // Standard input bar - disabled
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Standard - Disabled")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
                TerminalInputBar(
                    onSubmit: { text in print("Submitted: \(text)") },
                    isEnabled: false,
                    isWaitingForInput: false
                )
            }

            Divider()
                .background(Color.borderMuted)

            // Compact input bar
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Compact - For Terminal Slots")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
                CompactTerminalInputBar(
                    onSubmit: { text in print("Submitted: \(text)") },
                    isEnabled: true,
                    isWaitingForInput: true
                )
                .frame(width: 180)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Color.bgApp)
        .preferredColorScheme(.dark)
    }
}
#endif
