import SwiftUI

public struct XRoadsApp: App {

    /// Global application state
    @State private var appState = AppState()

    /// NSApplicationDelegate for lifecycle events
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.appState, appState)
                .frame(
                    minWidth: Theme.Layout.minWindowWidth,
                    minHeight: Theme.Layout.minWindowHeight
                )
                .onAppear {
                    // Store reference for cleanup
                    appDelegate.appState = appState

                    // Initialize project path to current working directory
                    Task {
                        let cwd = FileManager.default.currentDirectoryPath
                        await appState.setProjectPath(cwd)
                    }
                }
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: Theme.Layout.defaultWindowWidth,
            height: Theme.Layout.defaultWindowHeight
        )
        .commands {
            XRoadsCommands(appState: appState)
        }

        // Settings window (US-019)
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - App Delegate

/// App delegate to handle lifecycle events and cleanup
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CRITICAL: Set activation policy to regular for proper keyboard handling
        // This is essential when running via `swift run` (not as a bundled .app)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Ensure the app appears in the Dock and can receive keyboard focus
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }

        #if DEBUG
        print("[AppDelegate] App launched with activation policy: regular")
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Force cleanup of all resources before termination
        if let appState = appState {
            // Run synchronously to ensure cleanup completes
            let semaphore = DispatchSemaphore(value: 0)
            Task { @MainActor in
                await appState.cleanup()
                semaphore.signal()
            }
            // Wait max 2 seconds for cleanup
            _ = semaphore.wait(timeout: .now() + 2)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Commands

/// Custom commands for XRoads with keyboard shortcuts
struct XRoadsCommands: Commands {
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
            
            Divider()
            
            Button("Quit XRoads") {
                // Trigger cleanup notification before quit
                NotificationCenter.default.post(name: .requestAppQuit, object: nil)
            }
            .keyboardShortcut("q", modifiers: .command)
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

