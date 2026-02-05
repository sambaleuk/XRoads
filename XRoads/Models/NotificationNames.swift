//
//  NotificationNames.swift
//  XRoads
//
//  Notification names used throughout the app for cross-component communication.
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// Notification to show the new worktree sheet
    static let showNewWorktreeSheet = Notification.Name("showNewWorktreeSheet")

    /// Notification to close the selected worktree
    static let closeSelectedWorktree = Notification.Name("closeSelectedWorktree")

    /// Notification to stop the agent of the selected worktree
    static let stopSelectedAgent = Notification.Name("stopSelectedAgent")

    /// Notification to clear logs
    static let clearLogs = Notification.Name("clearLogs")

    /// Notification to show command palette
    static let showCommandPalette = Notification.Name("showCommandPalette")

    /// Notification to request app quit with cleanup
    static let requestAppQuit = Notification.Name("requestAppQuit")

    /// Notification to open PRD Assistant
    static let openPRDAssistant = Notification.Name("openPRDAssistant")

    /// Notification to open Worktree Creator
    static let openWorktreeCreator = Notification.Name("openWorktreeCreator")

    /// Notification to open Art Direction pipeline
    static let openArtDirection = Notification.Name("openArtDirection")

    /// Notification to open Skills Browser
    static let openSkillsBrowser = Notification.Name("openSkillsBrowser")

    /// Notification to launch quick loop on current branch
    static let launchQuickLoop = Notification.Name("launchQuickLoop")

    /// Notification to load a PRD file from path
    static let loadPRDFromPath = Notification.Name("loadPRDFromPath")

    /// Notification to launch an agent loop with PRD
    /// UserInfo keys: agent (AgentType), prdPath (String), branch (String), projectPath (String)
    static let launchAgentLoop = Notification.Name("launchAgentLoop")
}
