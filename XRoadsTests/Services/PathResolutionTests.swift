//
//  PathResolutionTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-06.
//  CR-201: Verify no hardcoded user paths remain in production code
//

import XCTest
@testable import XRoadsLib

final class PathResolutionTests: XCTestCase {

    // MARK: - Test: No hardcoded user paths in source files

    /// Scans all Swift source files in XRoads/ to ensure no hardcoded /Users/birahimmbow paths remain.
    /// This is the core regression test for CR-201: paths must use dynamic resolution
    /// (NSHomeDirectory, FileManager.homeDirectoryForCurrentUser, env vars, etc.)
    func test_noHardcodedBirahimmbowPaths_inSourceFiles() throws {
        let fm = FileManager.default
        let projectRoot = findProjectRoot()
        XCTAssertNotNil(projectRoot, "Should find project root containing Package.swift")
        guard let root = projectRoot else { return }

        let xroadsDir = (root as NSString).appendingPathComponent("XRoads")
        XCTAssertTrue(fm.fileExists(atPath: xroadsDir), "XRoads source directory should exist")

        let enumerator = fm.enumerator(atPath: xroadsDir)
        var violations: [String] = []

        while let relativePath = enumerator?.nextObject() as? String {
            guard relativePath.hasSuffix(".swift") else { continue }
            let fullPath = (xroadsDir as NSString).appendingPathComponent(relativePath)
            guard let content = fm.contents(atPath: fullPath),
                  let text = String(data: content, encoding: .utf8) else { continue }

            let lines = text.components(separatedBy: .newlines)
            for (lineNumber, line) in lines.enumerated() {
                // Skip comment-only lines
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                    continue
                }
                // Check for the specific hardcoded username that was the portability issue
                if line.contains("/Users/birahimmbow") {
                    violations.append("\(relativePath):\(lineNumber + 1): \(trimmed)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Found hardcoded /Users/birahimmbow paths in source code (should use dynamic resolution):\n\(violations.joined(separator: "\n"))"
        )
    }

    // MARK: - Test: LoopScriptLocator uses dynamic paths

    func test_loopScriptLocator_checkAvailability_returnsAllLoopTypes() {
        let availability = LoopScriptLocator.checkAvailability()
        XCTAssertEqual(availability.count, LoopScriptLocator.LoopType.allCases.count,
                       "Should check all loop types")
        for loopType in LoopScriptLocator.LoopType.allCases {
            XCTAssertNotNil(availability[loopType],
                            "Should have availability status for \(loopType.rawValue)")
        }
    }

    func test_loopScriptLocator_diagnostics_containsAllLoopTypes() {
        let diagnostics = LoopScriptLocator.diagnostics()
        XCTAssertTrue(diagnostics.contains("nexus-loop"), "Should reference nexus-loop")
        XCTAssertTrue(diagnostics.contains("gemini-loop"), "Should reference gemini-loop")
        XCTAssertTrue(diagnostics.contains("codex-loop"), "Should reference codex-loop")
        XCTAssertTrue(diagnostics.contains("common.sh"), "Should reference common.sh")
    }

    func test_loopScriptLocator_scriptStatuses_returnsAllScripts() {
        let statuses = LoopScriptLocator.getScriptStatuses()
        XCTAssertEqual(statuses.count, LoopScriptLocator.ScriptType.allCases.count,
                       "Should return status for every script type")
        for status in statuses {
            if status.isInstalled {
                XCTAssertNotNil(status.path, "Installed script should have a path")
                XCTAssertTrue(["bundled", "user"].contains(status.source),
                              "Installed script source should be 'bundled' or 'user', got: \(status.source)")
            } else {
                XCTAssertEqual(status.source, "not found",
                               "Uninstalled script source should be 'not found'")
            }
        }
    }

    func test_loopScriptLocator_findLoop_returnsExecutablePathOrNil() {
        for loopType in LoopScriptLocator.LoopType.allCases {
            let result = LoopScriptLocator.findLoop(loopType)
            if let path = result {
                XCTAssertTrue(
                    FileManager.default.isExecutableFile(atPath: path),
                    "Found path for \(loopType.rawValue) should be executable: \(path)"
                )
            }
            // nil is acceptable (script not installed on this machine)
        }
    }

    func test_loopScriptLocator_findScript_returnsExecutablePathOrNil() {
        for scriptType in LoopScriptLocator.ScriptType.allCases {
            let result = LoopScriptLocator.findScript(scriptType)
            if let path = result {
                XCTAssertTrue(
                    FileManager.default.isExecutableFile(atPath: path),
                    "Found path for \(scriptType.rawValue) should be executable: \(path)"
                )
            }
        }
    }

    // MARK: - Test: MCPClient path resolution uses dynamic lookup

    /// Verifies MCPClient.findMCPServerPath doesn't hardcode user paths in source.
    /// This is a source-level check since findMCPServerPath is private.
    func test_mcpClient_sourceHasNoBirahimmbowPaths() throws {
        let fm = FileManager.default
        guard let root = findProjectRoot() else {
            XCTFail("Could not find project root")
            return
        }

        let mcpClientPath = (root as NSString).appendingPathComponent("XRoads/Services/MCPClient.swift")
        guard let data = fm.contents(atPath: mcpClientPath),
              let content = String(data: data, encoding: .utf8) else {
            XCTFail("Could not read MCPClient.swift")
            return
        }

        XCTAssertFalse(
            content.contains("/Users/birahimmbow"),
            "MCPClient.swift should not contain hardcoded /Users/birahimmbow paths"
        )
    }

    /// Verifies AppState.swift doesn't hardcode user paths in source.
    func test_appState_sourceHasNoBirahimmbowPaths() throws {
        let fm = FileManager.default
        guard let root = findProjectRoot() else {
            XCTFail("Could not find project root")
            return
        }

        let appStatePath = (root as NSString).appendingPathComponent("XRoads/ViewModels/AppState.swift")
        guard let data = fm.contents(atPath: appStatePath),
              let content = String(data: data, encoding: .utf8) else {
            XCTFail("Could not read AppState.swift")
            return
        }

        XCTAssertFalse(
            content.contains("/Users/birahimmbow"),
            "AppState.swift should not contain hardcoded /Users/birahimmbow paths"
        )
    }

    /// Verifies LoopLauncher.swift doesn't hardcode user paths in source.
    func test_loopLauncher_sourceHasNoBirahimmbowPaths() throws {
        let fm = FileManager.default
        guard let root = findProjectRoot() else {
            XCTFail("Could not find project root")
            return
        }

        let loopLauncherPath = (root as NSString).appendingPathComponent("XRoads/Services/LoopLauncher.swift")
        guard let data = fm.contents(atPath: loopLauncherPath),
              let content = String(data: data, encoding: .utf8) else {
            XCTFail("Could not read LoopLauncher.swift")
            return
        }

        XCTAssertFalse(
            content.contains("/Users/birahimmbow"),
            "LoopLauncher.swift should not contain hardcoded /Users/birahimmbow paths"
        )
    }

    // MARK: - Helpers

    private func findProjectRoot() -> String? {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        let candidates = [
            cwd,
            (cwd as NSString).deletingLastPathComponent,
        ]

        for candidate in candidates {
            let resolved = (candidate as NSString).standardizingPath
            let packageSwift = (resolved as NSString).appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: packageSwift) {
                return resolved
            }
        }

        return nil
    }
}
