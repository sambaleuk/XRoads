import XCTest
import Foundation

/// CR-302: Verifies that Package.swift uses SPM auto-discovery instead of manual source enumeration.
final class PackageAutoDiscoveryTests: XCTestCase {

    private var packageSwiftContent: String!
    private var projectRoot: String!

    override func setUp() {
        super.setUp()
        // Navigate up from the test file to find the project root
        // #filePath = .../XRoadsTests/Build/PackageAutoDiscoveryTests.swift
        // We need to go up 3 levels: file -> Build -> XRoadsTests -> project root
        let testFile = #filePath
        var path = testFile as NSString
        for _ in 0..<3 {
            path = path.deletingLastPathComponent as NSString
        }
        projectRoot = path as String
        let packagePath = (projectRoot as NSString).appendingPathComponent("Package.swift")
        packageSwiftContent = try? String(contentsOfFile: packagePath, encoding: .utf8)
    }

    // MARK: - Package.swift was loaded

    func test_packageSwift_exists() {
        XCTAssertNotNil(packageSwiftContent, "Package.swift should be readable from project root at \(projectRoot ?? "nil")")
    }

    // MARK: - XRoadsLib target has no explicit sources

    func test_xroadsLib_noExplicitSources() throws {
        let content = try XCTUnwrap(packageSwiftContent)
        let lines = content.components(separatedBy: "\n")

        // Find the line with .target( that defines XRoadsLib (has name: "XRoadsLib" nearby)
        var inXRoadsLibTarget = false
        var xroadsLibHasSources = false
        var depth = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains(".target(") && !trimmed.contains(".executableTarget(") && !trimmed.contains(".testTarget(") {
                inXRoadsLibTarget = true
                depth = 0
            }

            if inXRoadsLibTarget {
                depth += line.filter({ $0 == "(" }).count
                depth -= line.filter({ $0 == ")" }).count

                if trimmed.hasPrefix("sources:") {
                    xroadsLibHasSources = true
                }

                if depth <= 0 {
                    break
                }
            }
        }

        XCTAssertTrue(inXRoadsLibTarget, "Should find .target( for XRoadsLib")
        XCTAssertFalse(
            xroadsLibHasSources,
            "XRoadsLib target should NOT have an explicit sources: array — SPM auto-discovers .swift files"
        )
    }

    // MARK: - XRoadsTests target has no explicit sources

    func test_xroadsTests_noExplicitSources() throws {
        let content = try XCTUnwrap(packageSwiftContent)
        let lines = content.components(separatedBy: "\n")

        var inTestTarget = false
        var testTargetHasSources = false
        var depth = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains(".testTarget(") {
                inTestTarget = true
                depth = 0
            }

            if inTestTarget {
                depth += line.filter({ $0 == "(" }).count
                depth -= line.filter({ $0 == ")" }).count

                if trimmed.hasPrefix("sources:") {
                    testTargetHasSources = true
                }

                if depth <= 0 {
                    break
                }
            }
        }

        XCTAssertTrue(inTestTarget, "Should find .testTarget(")
        XCTAssertFalse(
            testTargetHasSources,
            "XRoadsTests target should NOT have an explicit sources: array — SPM auto-discovers .swift files"
        )
    }

    // MARK: - Package.swift retains exclude and resources

    func test_xroadsLib_retainsExcludeArray() throws {
        let content = try XCTUnwrap(packageSwiftContent)
        XCTAssertTrue(
            content.contains("\"XRoads.entitlements\""),
            "Package.swift should still exclude XRoads.entitlements"
        )
        XCTAssertTrue(
            content.contains("\"Resources/Assets.xcassets\""),
            "Package.swift should still exclude Assets.xcassets"
        )
    }

    func test_xroadsLib_retainsResourcesCopy() throws {
        let content = try XCTUnwrap(packageSwiftContent)
        XCTAssertTrue(
            content.contains(".copy(\"Resources/Skills\")"),
            "Package.swift should still copy Resources/Skills"
        )
    }

    // MARK: - Package.swift is concise (no bloated sources array)

    func test_packageSwift_isConcise() throws {
        let content = try XCTUnwrap(packageSwiftContent)
        let lineCount = content.components(separatedBy: "\n").count
        XCTAssertLessThan(
            lineCount, 80,
            "Package.swift should be under 80 lines without manual source enumeration (was ~252 lines before). Got \(lineCount) lines."
        )
    }

    // MARK: - All source directories exist

    func test_sourceDirectories_exist() throws {
        let xroadsPath = (projectRoot as NSString).appendingPathComponent("XRoads")
        let fm = FileManager.default

        let expectedDirs = ["App", "Models", "Views", "ViewModels", "Services", "Actions", "Resources"]
        for dir in expectedDirs {
            let fullPath = (xroadsPath as NSString).appendingPathComponent(dir)
            var isDir: ObjCBool = false
            XCTAssertTrue(
                fm.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue,
                "XRoads/\(dir)/ directory should exist for SPM auto-discovery"
            )
        }
    }

    // MARK: - Auto-discovered files match expected count

    func test_autoDiscovery_findsAllSwiftFiles() throws {
        let xroadsPath = (projectRoot as NSString).appendingPathComponent("XRoads")
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(atPath: xroadsPath) else {
            XCTFail("Could not enumerate XRoads/ directory")
            return
        }

        var swiftFiles = 0
        while let file = enumerator.nextObject() as? String {
            // Skip Resources/Skills (copied as resources, not compiled)
            if file.hasPrefix("Resources/Skills") { continue }
            if file.hasSuffix(".swift") {
                swiftFiles += 1
            }
        }

        // At the time of CR-302, there were 131 Swift source files.
        // Allow some margin for future additions.
        XCTAssertGreaterThanOrEqual(
            swiftFiles, 120,
            "SPM should auto-discover at least 120 .swift files in XRoads/ (found \(swiftFiles))"
        )
    }
}
