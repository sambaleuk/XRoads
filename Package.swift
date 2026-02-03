// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XRoads",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "XRoads", targets: ["XRoads"])
    ],
    targets: [
        .executableTarget(
            name: "XRoads",
            path: "XRoads",
            exclude: [
                "XRoads.entitlements",
                "Resources/Assets.xcassets"
            ],
            sources: [
                "App/XRoadsApp.swift",
                "Views/ContentView.swift",
                "Views/MainWindowView.swift",
                "Views/SidebarView.swift",
                "Views/TerminalView.swift",
                "Views/WorktreeCard.swift",
                "Views/WorktreeCreateSheet.swift",
                "Views/CommandPaletteView.swift",
                "Views/SettingsView.swift",
                "Views/ConflictResolutionSheet.swift",
                "Views/ProgressDashboardView.swift",
                "Views/PRDLoaderSheet.swift",
                "Views/OrchestrationHistorySheet.swift",
                "Views/GitDashboardView.swift",
                "Views/Components/MacTextField.swift",
                "Views/Components/ModalPanel.swift",
                "Views/Components/FloatingInputWindow.swift",
                "Resources/Theme.swift",
                "Models/AgentType.swift",
                "Models/AgentStatus.swift",
                "Models/AgentDashboardEntry.swift",
                "Models/AgentHealth.swift",
                "Models/LogLevel.swift",
                "Models/Agent.swift",
                "Models/Worktree.swift",
                "Models/LogEntry.swift",
                "Models/Session.swift",
                "Models/NotificationNames.swift",
                "Services/GitService.swift",
                "Services/ProcessRunner.swift",
                "Services/MCPClient.swift",
                "Services/ServiceContainer.swift",
                "Services/Orchestrator.swift",
                "Services/ClaudeOrchestrator.swift",
                "Services/AgentLauncher.swift",
                "Services/AgentEventBus.swift",
                "Services/AgentStatusMonitor.swift",
                "Services/NotesSyncService.swift",
                "Services/MergeCoordinator.swift",
                "Services/WorktreeFactory.swift",
                "Services/PRDParser.swift",
                "Services/CLIAdapters.swift",
                "Services/ConfigChecker.swift",
                "ViewModels/AppState.swift",
                "ViewModels/SessionViewModel.swift",
                "ViewModels/PRDLoaderViewModel.swift",
                "Services/OrchestrationHistoryService.swift",
                "Models/OrchestrationRecord.swift"
            ]
        )
    ]
)
