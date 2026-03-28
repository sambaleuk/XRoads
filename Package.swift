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
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        // Main library for testability
        // SPM auto-discovers all .swift files under path "XRoads/"
        .target(
            name: "XRoadsLib",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "XRoads",
            exclude: [
                "XRoads.entitlements",
                "Resources/Assets.xcassets"
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
        // SPM auto-discovers all .swift files under path "XRoadsTests/"
        .testTarget(
            name: "XRoadsTests",
            dependencies: [
                "XRoadsLib",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "XRoadsTests"
        )
    ]
)
