// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XRoads",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "XRoads", targets: ["XRoads"]),
        .library(name: "XRoadsLib", targets: ["XRoadsLib"])
    ],
    targets: [
        // Main library for testability
        .target(
            name: "XRoadsLib",
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
                "Views/StartSessionSheet.swift",
                "Views/CommandPaletteView.swift",
                "Views/SettingsView.swift",
                // US-V4-019: General Settings View
                "Views/Settings/GeneralSettingsView.swift",
                // US-V4-020: CLI Settings View
                "Views/Settings/CLISettingsView.swift",
                // US-V4-021: MCP Settings View
                "Views/Settings/MCPSettingsView.swift",
                // US-V4-022: API Keys Settings View
                "Views/Settings/APIKeysSettingsView.swift",
                "Views/ConflictResolutionSheet.swift",
                "Views/PRDLoaderSheet.swift",
                "Views/SlotAssignmentSheet.swift",
                // US-V4-023: PRD Assistant Views
                "Views/PRD/PRDAssistantView.swift",
                "Views/PRD/PRDWizardSteps.swift",
                "Views/PRD/PRDPreviewView.swift",
                // US-V4-024: Art Direction Preview View
                "Views/ArtDirection/ArtBiblePreviewView.swift",
                // US-V4-025: Asset PRD Preview View
                "Views/ArtDirection/AssetPRDPreviewView.swift",
                // US-V4-027: Art Direction View and Pipeline Progress
                "Views/ArtDirection/ArtDirectionView.swift",
                "Views/ArtDirection/ArtPipelineProgress.swift",
                "Views/OrchestrationHistorySheet.swift",
                "Views/GitDashboardView.swift",
                "Views/Components/MacTextField.swift",
                "Views/Components/ModalPanel.swift",
                "Views/Components/FloatingInputWindow.swift",
                "Views/Components/TerminalInputBar.swift",
                "Views/Components/ActionPickerMenu.swift",
                "Views/Components/QuickActionBar.swift",
                // US-V4-015: Collapsible Panel
                "Views/Components/CollapsiblePanel.swift",
                // US-V4-018: Skills Badge
                "Views/Components/SkillsBadge.swift",
                // Loop Configuration Panel
                "Views/Components/LoopConfigurationPanel.swift",
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
                // PRD Auto-Detection System
                "Views/Orchestrator/PRDProposalView.swift",
                "Views/Orchestrator/PRDPreviewSheet.swift",
                // US-V4-016: Skills Browser Views
                "Views/Skills/SkillsBrowserView.swift",
                "Views/Skills/SkillRowView.swift",
                // US-V4-017: Skill Detail Sheet
                "Views/Skills/SkillDetailSheet.swift",
                "Views/Skills/SkillTemplateView.swift",
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
                // US-V4-014: API Config
                "Models/APIConfig.swift",
                // US-V4-023: PRD Template Models
                "Models/PRDTemplate.swift",
                // US-V4-024: Art Bible Model
                "Models/ArtBible.swift",
                // Git Commit Model for Right Side Panel
                "Models/GitCommit.swift",
                // US-V4-019: App Settings Model
                "Models/AppSettings.swift",
                "Services/GitService.swift",
                "Services/ProcessRunner.swift",
                "Services/PTYProcess.swift",
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
                // US-V4-025: Asset PRD Generator
                "Services/AssetPRDGenerator.swift",
                // US-V4-026: Component Context Builder
                "Services/ComponentContextBuilder.swift",
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
                // PRD Auto-Detection
                "Services/PRDDetector.swift",
                // US-V4-014: Anthropic API Client
                "Services/AnthropicClient.swift",
                // US-V4-021: Keychain Service
                "Services/KeychainService.swift",
                "Services/LoopScriptLocator.swift",
                "Services/LoopLauncher.swift",
                "Services/DependencyTracker.swift",
                "Services/StatusMonitor.swift",
                "Services/LayeredDispatcher.swift",
                "Services/WorktreePathResolver.swift",
                // Actions
                "Actions/ImplementAction.swift",
                "Actions/ReviewAction.swift",
                "Actions/IntegrationTestAction.swift",
                "ViewModels/AppState.swift",
                "ViewModels/SessionViewModel.swift",
                "ViewModels/PRDLoaderViewModel.swift",
                // US-V4-016: Skills ViewModel
                "ViewModels/SkillsViewModel.swift",
                // US-V4-027: Art Direction ViewModel
                "ViewModels/ArtDirectionViewModel.swift",
                "Services/OrchestrationHistoryService.swift",
                "Models/OrchestrationRecord.swift"
            ],
            resources: [
                .copy("Resources/Skills")
            ]
        ),
        // Executable target that depends on the library
        .executableTarget(
            name: "XRoads",
            dependencies: ["XRoadsLib"],
            path: "XRoadsMain",
            sources: ["main.swift"]
        ),
        // Test target
        .testTarget(
            name: "XRoadsTests",
            dependencies: ["XRoadsLib"],
            path: "XRoadsTests",
            sources: [
                "Services/AnthropicClientTests.swift",
                // US-V4-015: Dashboard Layout Tests
                "Dashboard/DashboardLayoutTests.swift",
                // US-V4-016: Skills Browser Tests
                "Skills/SkillsBrowserViewTests.swift",
                // US-V4-017: Skill Detail Sheet Tests
                "Skills/SkillDetailSheetTests.swift",
                // US-V4-018: Skills Badge Tests
                "Components/SkillsBadgeTests.swift",
                // US-V4-019: General Settings Tests
                "Settings/GeneralSettingsTests.swift",
                // US-V4-020: CLI Settings Tests
                "Settings/CLISettingsTests.swift",
                // US-V4-021: MCP Settings Tests
                "Settings/MCPSettingsTests.swift",
                // US-V4-022: API Keys Tests
                "Settings/APIKeysTests.swift",
                // US-V4-023: PRD Assistant Tests
                "PRD/PRDAssistantTests.swift",
                // US-V4-024: Art Director Skill Tests
                "ArtDirection/ArtDirectorSkillTests.swift",
                // US-V4-025: Asset PRD Generator Tests
                "ArtDirection/AssetPRDGeneratorTests.swift",
                // US-V4-026: Component Context Tests
                "ArtDirection/ComponentContextTests.swift",
                // US-V4-027: Art Direction View Tests
                "ArtDirection/ArtDirectionViewTests.swift",
                // US-V4-028: Git Info Panel Quick Actions Tests
                "Dashboard/GitInfoPanelTests.swift",
                // Orchestration Workflow Tests
                "Orchestrator/OrchestrationWorkflowTests.swift"
            ]
        )
    ]
)
