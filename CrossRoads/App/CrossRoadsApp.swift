import SwiftUI

@main
struct CrossRoadsApp: App {

    /// Global application state
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.appState, appState)
                .frame(
                    minWidth: Theme.Layout.minWindowWidth,
                    minHeight: Theme.Layout.minWindowHeight
                )
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: Theme.Layout.defaultWindowWidth,
            height: Theme.Layout.defaultWindowHeight
        )
        .commands {
            CrossRoadsCommands(appState: appState)
        }

        // Settings window (US-019)
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - Commands

/// Custom commands for CrossRoads with keyboard shortcuts
struct CrossRoadsCommands: Commands {
    @ObservedObject var appState: ObservableAppStateWrapper

    init(appState: AppState) {
        self.appState = ObservableAppStateWrapper(appState: appState)
    }

    var body: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("New Worktree") {
                NotificationCenter.default.post(name: .showNewWorktreeSheet, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // Custom Commands Menu
        CommandMenu("Worktree") {
            Button("Close Worktree") {
                NotificationCenter.default.post(name: .closeSelectedWorktree, object: nil)
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(appState.selectedWorktree == nil)

            Divider()

            Button("Stop Agent") {
                NotificationCenter.default.post(name: .stopSelectedAgent, object: nil)
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(appState.selectedWorktree == nil)
        }

        // View menu commands
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Clear Logs") {
                NotificationCenter.default.post(name: .clearLogs, object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("Command Palette") {
                NotificationCenter.default.post(name: .showCommandPalette, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
        }
    }
}

// MARK: - Observable Wrapper for Commands

/// Wrapper to make @Observable AppState work with @ObservedObject in Commands
@MainActor
final class ObservableAppStateWrapper: ObservableObject {
    private let appState: AppState

    var selectedWorktree: Worktree? {
        appState.selectedWorktree
    }

    init(appState: AppState) {
        self.appState = appState
    }
}

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
}

