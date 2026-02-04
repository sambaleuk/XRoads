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

            MCPSettingsView()
                .tabItem {
                    Label("MCP", systemImage: "server.rack")
                }
                .tag(SettingsTab.mcp)

            APIKeysSettingsView()
                .tabItem {
                    Label("API Keys", systemImage: "key.fill")
                }
                .tag(SettingsTab.apiKeys)
        }
        .frame(width: 550, height: 600)
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

// Note: CLISettingsView has been moved to Views/Settings/CLISettingsView.swift
// for US-V4-020 with enhanced functionality

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
