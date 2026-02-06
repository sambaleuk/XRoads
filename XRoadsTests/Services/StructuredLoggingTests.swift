//
//  StructuredLoggingTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-06.
//  CR-101: Verify print() calls are replaced with structured os.Logger
//

import XCTest
import os
@testable import XRoadsLib

final class StructuredLoggingTests: XCTestCase {

    // MARK: - Test: Log enum exists with correct subsystem

    func test_logSubsystem_isComXroads() {
        XCTAssertEqual(Log.subsystem, "com.xroads")
    }

    // MARK: - Test: All expected logger categories exist

    func test_logCategories_serviceLoggersExist() {
        // Service loggers
        let mcp = Log.mcp
        let loop = Log.loop
        let status = Log.status
        let dispatcher = Log.dispatcher
        let action = Log.action
        let orchestrator = Log.orchestrator
        let agent = Log.agent

        // UI loggers
        let dashboard = Log.dashboard
        let input = Log.input
        let modal = Log.modal
        let app = Log.app

        // All loggers should be valid Logger instances (non-nil by construction)
        // Simply accessing them without crash proves they exist
        XCTAssertNotNil(mcp)
        XCTAssertNotNil(loop)
        XCTAssertNotNil(status)
        XCTAssertNotNil(dispatcher)
        XCTAssertNotNil(action)
        XCTAssertNotNil(orchestrator)
        XCTAssertNotNil(agent)
        XCTAssertNotNil(dashboard)
        XCTAssertNotNil(input)
        XCTAssertNotNil(modal)
        XCTAssertNotNil(app)
    }

    // MARK: - Test: No unconditional print() in production code

    /// Scans all Swift source files in XRoads/ (production code) to ensure
    /// no unconditional print() calls remain outside of #if DEBUG blocks.
    func test_noUnconditionalPrint_inProductionCode() throws {
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
            var inDebugBlock = false
            var debugBlockDepth = 0

            for (lineNumber, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Track #if DEBUG / #endif blocks
                if trimmed == "#if DEBUG" {
                    if !inDebugBlock {
                        inDebugBlock = true
                        debugBlockDepth = 1
                    } else {
                        debugBlockDepth += 1
                    }
                    continue
                }
                if trimmed.hasPrefix("#if ") && inDebugBlock {
                    debugBlockDepth += 1
                    continue
                }
                if trimmed == "#endif" && inDebugBlock {
                    debugBlockDepth -= 1
                    if debugBlockDepth == 0 {
                        inDebugBlock = false
                    }
                    continue
                }

                // Skip if inside #if DEBUG block
                if inDebugBlock { continue }

                // Skip comments
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                    continue
                }

                // Skip string literals that contain "print(" as part of code review detection
                if trimmed.contains("contains(\"print(") || trimmed.contains("\"print(") {
                    continue
                }

                // Check for bare print() calls in production code
                if trimmed.contains("print(") {
                    violations.append("\(relativePath):\(lineNumber + 1): \(trimmed)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Found \(violations.count) unconditional print() call(s) in production code (should use Log.xxx instead):\n\(violations.joined(separator: "\n"))"
        )
    }

    // MARK: - Test: XRoadsLogger file uses os.Logger

    func test_loggerFile_importsOs() throws {
        let fm = FileManager.default
        let projectRoot = findProjectRoot()
        XCTAssertNotNil(projectRoot)
        guard let root = projectRoot else { return }

        let loggerPath = (root as NSString).appendingPathComponent("XRoads/Services/XRoadsLogger.swift")
        XCTAssertTrue(fm.fileExists(atPath: loggerPath), "XRoadsLogger.swift should exist")

        guard let content = fm.contents(atPath: loggerPath),
              let text = String(data: content, encoding: .utf8) else {
            XCTFail("Could not read XRoadsLogger.swift")
            return
        }

        XCTAssertTrue(text.contains("import os"), "XRoadsLogger should import os framework")
        XCTAssertTrue(text.contains("Logger(subsystem:"), "XRoadsLogger should use os.Logger")
        XCTAssertTrue(text.contains("com.xroads"), "XRoadsLogger should use com.xroads subsystem")
    }

    // MARK: - Test: Key files use Log instead of print

    func test_mcpClient_usesStructuredLogger() throws {
        try assertFileUsesLogger("XRoads/Services/MCPClient.swift", logCategory: "Log.mcp")
    }

    func test_loopLauncher_usesStructuredLogger() throws {
        try assertFileUsesLogger("XRoads/Services/LoopLauncher.swift", logCategory: "Log.loop")
    }

    func test_layeredDispatcher_usesStructuredLogger() throws {
        try assertFileUsesLogger("XRoads/Services/LayeredDispatcher.swift", logCategory: "Log.dispatcher")
    }

    func test_statusMonitor_usesStructuredLogger() throws {
        try assertFileUsesLogger("XRoads/Services/StatusMonitor.swift", logCategory: "Log.status")
    }

    func test_actionRunner_usesStructuredLogger() throws {
        try assertFileUsesLogger("XRoads/Services/ActionRunner.swift", logCategory: "Log.action")
    }

    func test_orchestratorService_usesStructuredLogger() throws {
        try assertFileUsesLogger("XRoads/Services/OrchestratorService.swift", logCategory: "Log.orchestrator")
    }

    func test_dashboard_usesStructuredLogger() throws {
        try assertFileUsesLogger("XRoads/Views/Dashboard/XRoadsDashboardView.swift", logCategory: "Log.dashboard")
    }

    // MARK: - Helpers

    private func assertFileUsesLogger(_ relativePath: String, logCategory: String) throws {
        let fm = FileManager.default
        let projectRoot = findProjectRoot()
        XCTAssertNotNil(projectRoot)
        guard let root = projectRoot else { return }

        let fullPath = (root as NSString).appendingPathComponent(relativePath)
        XCTAssertTrue(fm.fileExists(atPath: fullPath), "\(relativePath) should exist")

        guard let content = fm.contents(atPath: fullPath),
              let text = String(data: content, encoding: .utf8) else {
            XCTFail("Could not read \(relativePath)")
            return
        }

        XCTAssertTrue(
            text.contains(logCategory),
            "\(relativePath) should use \(logCategory) for structured logging"
        )
    }

    private func findProjectRoot() -> String? {
        // Walk up from the test bundle to find Package.swift
        let fm = FileManager.default
        var dir = fm.currentDirectoryPath

        for _ in 0..<10 {
            let packagePath = (dir as NSString).appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: packagePath) {
                return dir
            }
            dir = (dir as NSString).deletingLastPathComponent
        }

        // Fallback: try common paths
        let candidates = [
            "/Users/birahimmbow/Projets/CrossRoads",
            NSHomeDirectory() + "/Projets/CrossRoads"
        ]
        for candidate in candidates {
            let packagePath = (candidate as NSString).appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: packagePath) {
                return candidate
            }
        }

        return nil
    }
}
