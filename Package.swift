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
                "Resources/Theme.swift"
            ]
        )
    ]
)
