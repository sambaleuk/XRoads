// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrossRoads",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CrossRoads", targets: ["CrossRoads"])
    ],
    targets: [
        .executableTarget(
            name: "CrossRoads",
            path: "CrossRoads",
            exclude: [
                "CrossRoads.entitlements",
                "Resources/Assets.xcassets"
            ],
            sources: [
                "App/CrossRoadsApp.swift",
                "Views/ContentView.swift",
                "Views/MainWindowView.swift",
                "Views/SidebarView.swift",
                "Views/TerminalView.swift",
                "Views/WorktreeCard.swift",
                "Resources/Theme.swift",
                "Models/AgentType.swift",
                "Models/AgentStatus.swift",
                "Models/LogLevel.swift",
                "Models/Agent.swift",
                "Models/Worktree.swift",
                "Models/LogEntry.swift",
                "Models/Session.swift",
                "Services/GitService.swift",
                "Services/ProcessRunner.swift",
                "Services/MCPClient.swift",
                "Services/ServiceContainer.swift",
                "ViewModels/AppState.swift",
                "ViewModels/SessionViewModel.swift"
            ]
        )
    ]
)
