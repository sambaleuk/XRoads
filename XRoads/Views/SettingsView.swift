//
//  SettingsView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-019: Main settings view with tabs for different settings categories
//

import SwiftUI

// MARK: - SettingsView

/// Main settings view for XRoads preferences
public struct SettingsView: View {

    // MARK: - State

    /// Selected settings tab
    @State private var selectedTab: SettingsTab = .general

    public init() {}

    // MARK: - Body

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            CLISettingsView()
                .tabItem {
                    Label("CLI Paths", systemImage: "terminal")
                }
                .tag(SettingsTab.cli)
        }
        .frame(width: 550, height: 500)
        .background(Color.bgApp)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Settings Tabs

public enum SettingsTab: Hashable, Sendable {
    case general
    case cli
    case mcp
    case apiKeys
}

// MARK: - CLISettingsView

/// CLI executable path settings
public struct CLISettingsView: View {

    // MARK: - State

    @State private var settings = AppSettings.shared

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            Section {
                CLIPathRow(
                    name: "Claude Code",
                    icon: "brain.head.profile",
                    iconColor: Color.accentPrimary,
                    path: $settings.claudeCliPath,
                    defaultPath: "/usr/local/bin/claude"
                )

                CLIPathRow(
                    name: "Gemini CLI",
                    icon: "sparkles",
                    iconColor: Color.statusWarning,
                    path: $settings.geminiCliPath,
                    defaultPath: "/usr/local/bin/gemini"
                )

                CLIPathRow(
                    name: "Codex",
                    icon: "terminal",
                    iconColor: Color.statusSuccess,
                    path: $settings.codexCliPath,
                    defaultPath: "/usr/local/bin/codex"
                )
            } header: {
                Label("CLI Executable Paths", systemImage: "terminal")
                    .foregroundStyle(Color.textPrimary)
            } footer: {
                Text("Configure custom paths if CLIs are not in standard locations")
                    .foregroundStyle(Color.textTertiary)
            }

            Section {
                Button(role: .destructive) {
                    settings.resetCLIPathsToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset CLI Paths to Defaults")
                    }
                }
                .foregroundStyle(Color.statusError)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgSurface)
        .padding()
    }
}

// MARK: - CLIPathRow

/// Row component for CLI path configuration
struct CLIPathRow: View {
    let name: String
    let icon: String
    let iconColor: Color
    @Binding var path: String
    let defaultPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                Text(name)
                    .font(.body14)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                StatusIndicator(isAvailable: isAvailable)
            }

            HStack {
                TextField("Path", text: $path)
                    .textFieldStyle(DarkProTextFieldStyle())
                    .font(.mono(12))

                Button("Browse...") {
                    browseForExecutable()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Computed Properties

    private var isAvailable: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Actions

    private func browseForExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select \(name) executable"
        panel.prompt = "Select"

        // Start in the directory of the current path
        if !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        }

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

// MARK: - StatusIndicator

/// Small indicator showing CLI availability status
struct StatusIndicator: View {
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(isAvailable ? Color.statusSuccess : Color.statusError)
                .frame(width: 8, height: 8)

            Text(isAvailable ? "Available" : "Not found")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - UserDefaults Keys Extension (Backward Compatibility)

extension UserDefaults {
    /// Keys for XRoads settings (backward compatibility with @AppStorage)
    enum Keys {
        static let defaultRepoPath = SettingsKey.defaultRepoPath.rawValue
        static let autoStartLogStreaming = SettingsKey.autoStartLogStreaming.rawValue
        static let maxLogEntries = SettingsKey.maxLogEntries.rawValue
        static let claudeCliPath = SettingsKey.claudeCliPath.rawValue
        static let geminiCliPath = SettingsKey.geminiCliPath.rawValue
        static let codexCliPath = SettingsKey.codexCliPath.rawValue
        static let fullAgenticMode = SettingsKey.fullAgenticMode.rawValue
        static let chatPanelExpanded = SettingsKey.chatPanelExpanded.rawValue
        static let chatPanelWidth = SettingsKey.chatPanelWidth.rawValue
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
