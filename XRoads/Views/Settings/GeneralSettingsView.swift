//
//  GeneralSettingsView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-019: General application settings view
//

import SwiftUI

// MARK: - GeneralSettingsView

/// General application settings including appearance, behavior, and keyboard shortcuts
public struct GeneralSettingsView: View {

    // MARK: - State

    /// Reference to app settings
    @State private var settings = AppSettings.shared

    /// Whether shortcut editor is shown
    @State private var showShortcutEditor = false

    /// Currently editing shortcut
    @State private var editingShortcut: ShortcutEditItem?

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            // Appearance Section
            appearanceSection

            // Behavior Section
            behaviorSection

            // Keyboard Shortcuts Section
            keyboardShortcutsSection

            // Reset Section
            resetSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgSurface)
        .padding()
        .sheet(item: $editingShortcut) { item in
            ShortcutEditorSheet(
                shortcutItem: item,
                onSave: { newShortcut in
                    updateShortcut(item: item, newShortcut: newShortcut)
                }
            )
        }
    }

    // MARK: - Sections

    /// Appearance settings section
    private var appearanceSection: some View {
        Section {
            // Appearance Mode
            Picker("Appearance", selection: $settings.appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .foregroundStyle(Color.textPrimary)

            // Accent Color
            HStack {
                Text("Accent Color")
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(AccentColorChoice.allCases, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: settings.accentColorChoice == color ? 2 : 0)
                            )
                            .onTapGesture {
                                settings.accentColorChoice = color
                            }
                    }
                }
            }
        } header: {
            Label("Appearance", systemImage: "paintbrush")
                .foregroundStyle(Color.textPrimary)
        } footer: {
            Text("Customize the look and feel of XRoads")
                .foregroundStyle(Color.textTertiary)
        }
    }

    /// Behavior settings section
    private var behaviorSection: some View {
        Section {
            // Launch at Login
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .foregroundStyle(Color.textPrimary)

            // Auto-start Log Streaming
            Toggle("Auto-start Log Streaming", isOn: $settings.autoStartLogStreaming)
                .foregroundStyle(Color.textPrimary)

            // Max Log Entries
            Picker("Max Log Entries", selection: $settings.maxLogEntries) {
                Text("250").tag(250)
                Text("500").tag(500)
                Text("1000").tag(1000)
                Text("2000").tag(2000)
            }
            .foregroundStyle(Color.textPrimary)

            Divider()
                .padding(.vertical, Theme.Spacing.xs)

            // Notifications Toggle
            Toggle("Enable Notifications", isOn: $settings.enableNotifications)
                .foregroundStyle(Color.textPrimary)

            if settings.enableNotifications {
                Toggle("Notify on Agent Complete", isOn: $settings.notifyOnAgentComplete)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.leading, Theme.Spacing.md)

                Toggle("Notify on Agent Error", isOn: $settings.notifyOnAgentError)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.leading, Theme.Spacing.md)
            }
        } header: {
            Label("Behavior", systemImage: "gearshape.2")
                .foregroundStyle(Color.textPrimary)
        } footer: {
            Text("Configure application startup and notification behavior")
                .foregroundStyle(Color.textTertiary)
        }
    }

    /// Keyboard shortcuts section
    private var keyboardShortcutsSection: some View {
        Section {
            ShortcutRow(
                label: "New Worktree",
                shortcut: settings.shortcutNewWorktree,
                onEdit: { editingShortcut = ShortcutEditItem(id: "newWorktree", label: "New Worktree", current: settings.shortcutNewWorktree) }
            )

            ShortcutRow(
                label: "Close Worktree",
                shortcut: settings.shortcutCloseWorktree,
                onEdit: { editingShortcut = ShortcutEditItem(id: "closeWorktree", label: "Close Worktree", current: settings.shortcutCloseWorktree) }
            )

            ShortcutRow(
                label: "Stop Agent",
                shortcut: settings.shortcutStopAgent,
                onEdit: { editingShortcut = ShortcutEditItem(id: "stopAgent", label: "Stop Agent", current: settings.shortcutStopAgent) }
            )

            ShortcutRow(
                label: "Command Palette",
                shortcut: settings.shortcutCommandPalette,
                onEdit: { editingShortcut = ShortcutEditItem(id: "commandPalette", label: "Command Palette", current: settings.shortcutCommandPalette) }
            )

            ShortcutRow(
                label: "Clear Logs",
                shortcut: settings.shortcutClearLogs,
                onEdit: { editingShortcut = ShortcutEditItem(id: "clearLogs", label: "Clear Logs", current: settings.shortcutClearLogs) }
            )

            ShortcutRow(
                label: "Toggle Chat Panel",
                shortcut: settings.shortcutToggleChatPanel,
                onEdit: { editingShortcut = ShortcutEditItem(id: "toggleChatPanel", label: "Toggle Chat Panel", current: settings.shortcutToggleChatPanel) }
            )
        } header: {
            HStack {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button("Reset Shortcuts") {
                    settings.resetShortcutsToDefaults()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            }
        } footer: {
            Text("Click on a shortcut to customize it")
                .foregroundStyle(Color.textTertiary)
        }
    }

    /// Reset to defaults section
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                settings.resetGeneralToDefaults()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All General Settings to Defaults")
                }
            }
            .foregroundStyle(Color.statusError)
        }
    }

    // MARK: - Helpers

    /// Update a specific shortcut
    private func updateShortcut(item: ShortcutEditItem, newShortcut: KeyboardShortcutConfig) {
        switch item.id {
        case "newWorktree":
            settings.shortcutNewWorktree = newShortcut
        case "closeWorktree":
            settings.shortcutCloseWorktree = newShortcut
        case "stopAgent":
            settings.shortcutStopAgent = newShortcut
        case "commandPalette":
            settings.shortcutCommandPalette = newShortcut
        case "clearLogs":
            settings.shortcutClearLogs = newShortcut
        case "toggleChatPanel":
            settings.shortcutToggleChatPanel = newShortcut
        default:
            break
        }
    }
}

// MARK: - ShortcutEditItem

/// Item for editing a shortcut
struct ShortcutEditItem: Identifiable {
    let id: String
    let label: String
    let current: KeyboardShortcutConfig
}

// MARK: - ShortcutRow

/// Row displaying a keyboard shortcut with edit button
struct ShortcutRow: View {
    let label: String
    let shortcut: KeyboardShortcutConfig
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button(action: onEdit) {
                Text(shortcut.displayString)
                    .font(.mono(12))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.sm)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - ShortcutEditorSheet

/// Sheet for editing a keyboard shortcut
struct ShortcutEditorSheet: View {
    let shortcutItem: ShortcutEditItem
    let onSave: (KeyboardShortcutConfig) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var key: String
    @State private var useCommand: Bool
    @State private var useOption: Bool
    @State private var useShift: Bool
    @State private var useControl: Bool

    init(shortcutItem: ShortcutEditItem, onSave: @escaping (KeyboardShortcutConfig) -> Void) {
        self.shortcutItem = shortcutItem
        self.onSave = onSave

        // Initialize state from current shortcut
        _key = State(initialValue: shortcutItem.current.key)
        _useCommand = State(initialValue: shortcutItem.current.modifiers.contains("command"))
        _useOption = State(initialValue: shortcutItem.current.modifiers.contains("option"))
        _useShift = State(initialValue: shortcutItem.current.modifiers.contains("shift"))
        _useControl = State(initialValue: shortcutItem.current.modifiers.contains("control"))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header
            Text("Edit Shortcut")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Text(shortcutItem.label)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            Divider()

            // Preview
            Text(previewShortcut.displayString)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accentPrimary)
                .padding()
                .background(Color.bgElevated)
                .cornerRadius(Theme.Radius.md)

            // Modifiers
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Modifiers")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: Theme.Spacing.md) {
                    Toggle("⌘ Command", isOn: $useCommand)
                    Toggle("⌥ Option", isOn: $useOption)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Toggle("⇧ Shift", isOn: $useShift)
                    Toggle("⌃ Control", isOn: $useControl)
                }
            }
            .foregroundStyle(Color.textPrimary)

            // Key Input
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Key")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                TextField("Key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .onChange(of: key) { _, newValue in
                        // Limit to single character
                        if newValue.count > 1 {
                            key = String(newValue.suffix(1))
                        }
                    }
            }

            Spacer()

            // Actions
            HStack(spacing: Theme.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    onSave(previewShortcut)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.isEmpty || (!useCommand && !useOption && !useShift && !useControl))
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 320, height: 380)
        .background(Color.bgSurface)
    }

    private var previewShortcut: KeyboardShortcutConfig {
        var modifiers: [String] = []
        if useControl { modifiers.append("control") }
        if useOption { modifiers.append("option") }
        if useShift { modifiers.append("shift") }
        if useCommand { modifiers.append("command") }
        return KeyboardShortcutConfig(key: key.lowercased(), modifiers: modifiers)
    }
}

// MARK: - Preview

#if DEBUG
struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
            .frame(width: 500, height: 600)
    }
}
#endif
