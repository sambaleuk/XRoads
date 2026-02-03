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
}
