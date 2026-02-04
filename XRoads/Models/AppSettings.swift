//
//  AppSettings.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-019: Application settings model with persistence
//

import Foundation
import SwiftUI

// MARK: - UserDefaults Keys Extension

/// Keys for XRoads settings stored in UserDefaults
public enum SettingsKey: String, CaseIterable {
    // General - Repository
    case defaultRepoPath = "defaultRepoPath"

    // General - Appearance
    case appearanceMode = "appearanceMode"
    case accentColorChoice = "accentColorChoice"

    // General - Behavior
    case autoStartLogStreaming = "autoStartLogStreaming"
    case maxLogEntries = "maxLogEntries"
    case enableNotifications = "enableNotifications"
    case notifyOnAgentComplete = "notifyOnAgentComplete"
    case notifyOnAgentError = "notifyOnAgentError"
    case launchAtLogin = "launchAtLogin"

    // General - Keyboard Shortcuts
    case shortcutNewWorktree = "shortcutNewWorktree"
    case shortcutCloseWorktree = "shortcutCloseWorktree"
    case shortcutStopAgent = "shortcutStopAgent"
    case shortcutCommandPalette = "shortcutCommandPalette"
    case shortcutClearLogs = "shortcutClearLogs"
    case shortcutToggleChatPanel = "shortcutToggleChatPanel"

    // CLI Paths
    case claudeCliPath = "claudeCliPath"
    case geminiCliPath = "geminiCliPath"
    case codexCliPath = "codexCliPath"

    // Orchestrator
    case fullAgenticMode = "fullAgenticMode"

    // Chat Panel
    case chatPanelExpanded = "chatPanelExpanded"
    case chatPanelWidth = "chatPanelWidth"
}

// MARK: - AppearanceMode

/// Appearance mode for the application
public enum AppearanceMode: String, Codable, Sendable, CaseIterable {
    case system
    case dark
    case light

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// MARK: - AccentColorChoice

/// Predefined accent color choices
public enum AccentColorChoice: String, Codable, Sendable, CaseIterable {
    case blue
    case purple
    case green
    case orange
    case red
    case pink
    case teal

    public var displayName: String {
        rawValue.capitalized
    }

    public var color: Color {
        switch self {
        case .blue: return .accentPrimary
        case .purple: return Color(hex: "#A855F7")
        case .green: return .statusSuccess
        case .orange: return .statusWarning
        case .red: return .statusError
        case .pink: return Color(hex: "#EC4899")
        case .teal: return .statusInfo
        }
    }
}

// MARK: - KeyboardShortcut Model

/// Represents a keyboard shortcut configuration
public struct KeyboardShortcutConfig: Codable, Sendable, Equatable {
    public var key: String
    public var modifiers: [String]

    public init(key: String, modifiers: [String] = ["command"]) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Display string for the shortcut (e.g., "⌘N")
    public var displayString: String {
        var result = ""
        if modifiers.contains("control") { result += "⌃" }
        if modifiers.contains("option") { result += "⌥" }
        if modifiers.contains("shift") { result += "⇧" }
        if modifiers.contains("command") { result += "⌘" }
        result += key.uppercased()
        return result
    }

    /// Default shortcuts
    public static let defaultNewWorktree = KeyboardShortcutConfig(key: "n", modifiers: ["command"])
    public static let defaultCloseWorktree = KeyboardShortcutConfig(key: "w", modifiers: ["command"])
    public static let defaultStopAgent = KeyboardShortcutConfig(key: ".", modifiers: ["command"])
    public static let defaultCommandPalette = KeyboardShortcutConfig(key: "k", modifiers: ["command"])
    public static let defaultClearLogs = KeyboardShortcutConfig(key: "l", modifiers: ["command"])
    public static let defaultToggleChatPanel = KeyboardShortcutConfig(key: "o", modifiers: ["command", "shift"])
}

// MARK: - AppSettings

/// Central manager for all application settings with type-safe access
@MainActor
@Observable
public final class AppSettings {

    // MARK: - Singleton

    public static let shared = AppSettings()

    // MARK: - UserDefaults

    private let defaults: UserDefaults

    // MARK: - Initialization

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadAllSettings()
    }

    // MARK: - General - Repository Settings

    /// Default repository path for new worktrees
    public var defaultRepoPath: String = "" {
        didSet { save(defaultRepoPath, forKey: .defaultRepoPath) }
    }

    // MARK: - General - Appearance Settings

    /// Current appearance mode
    public var appearanceMode: AppearanceMode = .dark {
        didSet { save(appearanceMode.rawValue, forKey: .appearanceMode) }
    }

    /// Selected accent color
    public var accentColorChoice: AccentColorChoice = .blue {
        didSet { save(accentColorChoice.rawValue, forKey: .accentColorChoice) }
    }

    // MARK: - General - Behavior Settings

    /// Whether to auto-start log streaming on launch
    public var autoStartLogStreaming: Bool = true {
        didSet { save(autoStartLogStreaming, forKey: .autoStartLogStreaming) }
    }

    /// Maximum number of logs to keep in memory
    public var maxLogEntries: Int = 500 {
        didSet { save(maxLogEntries, forKey: .maxLogEntries) }
    }

    /// Whether notifications are enabled
    public var enableNotifications: Bool = true {
        didSet { save(enableNotifications, forKey: .enableNotifications) }
    }

    /// Notify when agent completes
    public var notifyOnAgentComplete: Bool = true {
        didSet { save(notifyOnAgentComplete, forKey: .notifyOnAgentComplete) }
    }

    /// Notify when agent encounters error
    public var notifyOnAgentError: Bool = true {
        didSet { save(notifyOnAgentError, forKey: .notifyOnAgentError) }
    }

    /// Launch at login
    public var launchAtLogin: Bool = false {
        didSet { save(launchAtLogin, forKey: .launchAtLogin) }
    }

    // MARK: - General - Keyboard Shortcuts

    /// Shortcut for new worktree
    public var shortcutNewWorktree: KeyboardShortcutConfig = .defaultNewWorktree {
        didSet { saveShortcut(shortcutNewWorktree, forKey: .shortcutNewWorktree) }
    }

    /// Shortcut for close worktree
    public var shortcutCloseWorktree: KeyboardShortcutConfig = .defaultCloseWorktree {
        didSet { saveShortcut(shortcutCloseWorktree, forKey: .shortcutCloseWorktree) }
    }

    /// Shortcut for stop agent
    public var shortcutStopAgent: KeyboardShortcutConfig = .defaultStopAgent {
        didSet { saveShortcut(shortcutStopAgent, forKey: .shortcutStopAgent) }
    }

    /// Shortcut for command palette
    public var shortcutCommandPalette: KeyboardShortcutConfig = .defaultCommandPalette {
        didSet { saveShortcut(shortcutCommandPalette, forKey: .shortcutCommandPalette) }
    }

    /// Shortcut for clear logs
    public var shortcutClearLogs: KeyboardShortcutConfig = .defaultClearLogs {
        didSet { saveShortcut(shortcutClearLogs, forKey: .shortcutClearLogs) }
    }

    /// Shortcut for toggle chat panel
    public var shortcutToggleChatPanel: KeyboardShortcutConfig = .defaultToggleChatPanel {
        didSet { saveShortcut(shortcutToggleChatPanel, forKey: .shortcutToggleChatPanel) }
    }

    // MARK: - CLI Paths

    /// Claude CLI executable path
    public var claudeCliPath: String = "/usr/local/bin/claude" {
        didSet { save(claudeCliPath, forKey: .claudeCliPath) }
    }

    /// Gemini CLI executable path
    public var geminiCliPath: String = "/usr/local/bin/gemini" {
        didSet { save(geminiCliPath, forKey: .geminiCliPath) }
    }

    /// Codex CLI executable path
    public var codexCliPath: String = "/usr/local/bin/codex" {
        didSet { save(codexCliPath, forKey: .codexCliPath) }
    }

    /// Get CLI path for a specific agent type
    func cliPath(for agentType: AgentType) -> String {
        switch agentType {
        case .claude: return claudeCliPath
        case .gemini: return geminiCliPath
        case .codex: return codexCliPath
        }
    }

    // MARK: - Orchestrator Settings

    /// Whether Full Agentic Mode is enabled
    public var fullAgenticMode: Bool = false {
        didSet { save(fullAgenticMode, forKey: .fullAgenticMode) }
    }

    // MARK: - Chat Panel Settings

    /// Whether chat panel is expanded
    public var chatPanelExpanded: Bool = true {
        didSet { save(chatPanelExpanded, forKey: .chatPanelExpanded) }
    }

    /// Chat panel width
    public var chatPanelWidth: Double = 320 {
        didSet { save(chatPanelWidth, forKey: .chatPanelWidth) }
    }

    // MARK: - Reset to Defaults

    /// Reset all general settings to defaults
    public func resetGeneralToDefaults() {
        defaultRepoPath = ""
        appearanceMode = .dark
        accentColorChoice = .blue
        autoStartLogStreaming = true
        maxLogEntries = 500
        enableNotifications = true
        notifyOnAgentComplete = true
        notifyOnAgentError = true
        launchAtLogin = false
    }

    /// Reset keyboard shortcuts to defaults
    public func resetShortcutsToDefaults() {
        shortcutNewWorktree = .defaultNewWorktree
        shortcutCloseWorktree = .defaultCloseWorktree
        shortcutStopAgent = .defaultStopAgent
        shortcutCommandPalette = .defaultCommandPalette
        shortcutClearLogs = .defaultClearLogs
        shortcutToggleChatPanel = .defaultToggleChatPanel
    }

    /// Reset CLI paths to defaults
    public func resetCLIPathsToDefaults() {
        claudeCliPath = "/usr/local/bin/claude"
        geminiCliPath = "/usr/local/bin/gemini"
        codexCliPath = "/usr/local/bin/codex"
    }

    /// Reset all settings to defaults
    public func resetAllToDefaults() {
        resetGeneralToDefaults()
        resetShortcutsToDefaults()
        resetCLIPathsToDefaults()
        fullAgenticMode = false
        chatPanelExpanded = true
        chatPanelWidth = 320
    }

    // MARK: - Private Helpers

    /// Load all settings from UserDefaults
    private func loadAllSettings() {
        // Repository
        defaultRepoPath = defaults.string(forKey: SettingsKey.defaultRepoPath.rawValue) ?? ""

        // Appearance
        if let modeString = defaults.string(forKey: SettingsKey.appearanceMode.rawValue),
           let mode = AppearanceMode(rawValue: modeString) {
            appearanceMode = mode
        }

        if let colorString = defaults.string(forKey: SettingsKey.accentColorChoice.rawValue),
           let color = AccentColorChoice(rawValue: colorString) {
            accentColorChoice = color
        }

        // Behavior
        autoStartLogStreaming = defaults.object(forKey: SettingsKey.autoStartLogStreaming.rawValue) as? Bool ?? true
        let logEntries = defaults.integer(forKey: SettingsKey.maxLogEntries.rawValue)
        maxLogEntries = logEntries > 0 ? logEntries : 500
        enableNotifications = defaults.object(forKey: SettingsKey.enableNotifications.rawValue) as? Bool ?? true
        notifyOnAgentComplete = defaults.object(forKey: SettingsKey.notifyOnAgentComplete.rawValue) as? Bool ?? true
        notifyOnAgentError = defaults.object(forKey: SettingsKey.notifyOnAgentError.rawValue) as? Bool ?? true
        launchAtLogin = defaults.bool(forKey: SettingsKey.launchAtLogin.rawValue)

        // Keyboard shortcuts
        shortcutNewWorktree = loadShortcut(forKey: .shortcutNewWorktree) ?? .defaultNewWorktree
        shortcutCloseWorktree = loadShortcut(forKey: .shortcutCloseWorktree) ?? .defaultCloseWorktree
        shortcutStopAgent = loadShortcut(forKey: .shortcutStopAgent) ?? .defaultStopAgent
        shortcutCommandPalette = loadShortcut(forKey: .shortcutCommandPalette) ?? .defaultCommandPalette
        shortcutClearLogs = loadShortcut(forKey: .shortcutClearLogs) ?? .defaultClearLogs
        shortcutToggleChatPanel = loadShortcut(forKey: .shortcutToggleChatPanel) ?? .defaultToggleChatPanel

        // CLI Paths
        claudeCliPath = defaults.string(forKey: SettingsKey.claudeCliPath.rawValue) ?? "/usr/local/bin/claude"
        geminiCliPath = defaults.string(forKey: SettingsKey.geminiCliPath.rawValue) ?? "/usr/local/bin/gemini"
        codexCliPath = defaults.string(forKey: SettingsKey.codexCliPath.rawValue) ?? "/usr/local/bin/codex"

        // Orchestrator
        fullAgenticMode = defaults.bool(forKey: SettingsKey.fullAgenticMode.rawValue)

        // Chat Panel
        chatPanelExpanded = defaults.object(forKey: SettingsKey.chatPanelExpanded.rawValue) as? Bool ?? true
        let width = defaults.double(forKey: SettingsKey.chatPanelWidth.rawValue)
        chatPanelWidth = width > 0 ? width : 320
    }

    /// Save a value to UserDefaults
    private func save(_ value: Any?, forKey key: SettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    /// Save a keyboard shortcut to UserDefaults
    private func saveShortcut(_ shortcut: KeyboardShortcutConfig, forKey key: SettingsKey) {
        if let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: key.rawValue)
        }
    }

    /// Load a keyboard shortcut from UserDefaults
    private func loadShortcut(forKey key: SettingsKey) -> KeyboardShortcutConfig? {
        guard let data = defaults.data(forKey: key.rawValue),
              let shortcut = try? JSONDecoder().decode(KeyboardShortcutConfig.self, from: data) else {
            return nil
        }
        return shortcut
    }
}

// MARK: - AppSettings Static Accessors (Backward Compatibility)

extension AppSettings {
    /// Static accessor for default repo path (backward compatibility)
    public static var defaultRepoPathValue: String {
        get { shared.defaultRepoPath }
        set { shared.defaultRepoPath = newValue }
    }

    /// Static accessor for auto-start log streaming (backward compatibility)
    public static var autoStartLogStreamingValue: Bool {
        get { shared.autoStartLogStreaming }
        set { shared.autoStartLogStreaming = newValue }
    }

    /// Static accessor for max log entries (backward compatibility)
    public static var maxLogEntriesValue: Int {
        get { shared.maxLogEntries }
        set { shared.maxLogEntries = newValue }
    }

    /// Static accessor for Claude CLI path (backward compatibility)
    public static var claudeCliPathValue: String {
        get { shared.claudeCliPath }
        set { shared.claudeCliPath = newValue }
    }

    /// Static accessor for Gemini CLI path (backward compatibility)
    public static var geminiCliPathValue: String {
        get { shared.geminiCliPath }
        set { shared.geminiCliPath = newValue }
    }

    /// Static accessor for Codex CLI path (backward compatibility)
    public static var codexCliPathValue: String {
        get { shared.codexCliPath }
        set { shared.codexCliPath = newValue }
    }

    /// Static accessor for Full Agentic Mode (backward compatibility)
    public static var fullAgenticModeValue: Bool {
        get { shared.fullAgenticMode }
        set { shared.fullAgenticMode = newValue }
    }
}

// MARK: - Testing Support

extension AppSettings {
    /// Create a test instance with custom UserDefaults
    /// Only for testing - not for production use
    static func createForTesting(defaults: UserDefaults) -> AppSettings {
        let settings = AppSettings(defaults: defaults)
        return settings
    }
}
