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
                "Views/PRDLoaderSheet.swift",
                "Views/OrchestrationHistorySheet.swift",
                "Views/GitDashboardView.swift",
                "Views/Components/MacTextField.swift",
                "Views/Components/ModalPanel.swift",
                "Views/Components/FloatingInputWindow.swift",
                "Views/Components/TerminalInputBar.swift",
                "Views/Components/ActionPickerMenu.swift",
                "Views/Components/QuickActionBar.swift",
                // Dashboard v3 Views
                "Views/Dashboard/XRoadsDashboardView.swift",
                "Views/Dashboard/TerminalSlotView.swift",
                "Views/Dashboard/TerminalGridLayout.swift",
                "Views/Dashboard/OrchestratorCreatureView.swift",
                "Views/Dashboard/NeonBrainView.swift",
                "Views/Dashboard/GitInfoPanel.swift",
                // US-V4-013: Orchestrator Chat Views
                "Views/Orchestrator/OrchestratorChatView.swift",
                "Views/Orchestrator/ChatMessageView.swift",
                "Views/Orchestrator/ChatInputBar.swift",
                "Resources/Theme.swift",
                "Models/AgentType.swift",
                "Models/ActionType.swift",
                "Models/Skill.swift",
                "Models/AgentStatus.swift",
                "Models/AgentDashboardEntry.swift",
                "Models/AgentHealth.swift",
                "Models/LogLevel.swift",
                "Models/Agent.swift",
                "Models/Worktree.swift",
                "Models/LogEntry.swift",
                "Models/Session.swift",
                "Models/NotificationNames.swift",
                // Dashboard v3 Models
                "Models/TerminalSlot.swift",
                "Models/DashboardMode.swift",
                "Models/OrchestratorVisualState.swift",
                // US-V4-013: Chat Model
                "Models/ChatMessage.swift",
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
                "Services/ActionRegistry.swift",
                "Services/SkillRegistry.swift",
                "Services/SkillLoader.swift",
                "Services/ActionRunner.swift",
                "Services/SkillAdapters/SkillAdapter.swift",
                "Services/SkillAdapters/ClaudeSkillAdapter.swift",
                "Services/SkillAdapters/GeminiSkillAdapter.swift",
                "Services/SkillAdapters/CodexSkillAdapter.swift",
                "Services/RepoDetector.swift",
                // US-V4-013: Orchestrator Service
                "Services/OrchestratorService.swift",
                // Actions
                "Actions/ImplementAction.swift",
                "Actions/ReviewAction.swift",
                "Actions/IntegrationTestAction.swift",
                "ViewModels/AppState.swift",
                "ViewModels/SessionViewModel.swift",
                "ViewModels/PRDLoaderViewModel.swift",
                "Services/OrchestrationHistoryService.swift",
                "Models/OrchestrationRecord.swift"
            ],
            resources: [
                .copy("Resources/Skills")
            ]
        )
    ]
)
