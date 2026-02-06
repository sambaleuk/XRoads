//
//  SendableAuditTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-06.
//  CR-102: Verify @unchecked Sendable usages are documented and justified
//

import XCTest
import Foundation
@testable import XRoadsLib

final class SendableAuditTests: XCTestCase {

    // MARK: - Helpers

    /// Read a source file relative to the project root
    private func readSource(_ relativePath: String) throws -> String {
        // Find the project root by walking up from the test bundle
        let projectRoot = findProjectRoot()
        let fileURL = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func findProjectRoot() -> URL {
        // The project root contains Package.swift
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services/
            .deletingLastPathComponent() // XRoadsTests/
            .deletingLastPathComponent() // CrossRoads/
        // Verify we found the right directory
        let packageSwift = dir.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: packageSwift.path) {
            return dir
        }
        // Fallback: try current working directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: - DefaultServiceContainer Tests

    func test_defaultServiceContainer_hasUncheckedSendableWithSafetyComment() throws {
        let source = try readSource("XRoads/Services/ServiceContainer.swift")
        XCTAssertTrue(
            source.contains("final class DefaultServiceContainer: ServiceContainer, @unchecked Sendable"),
            "DefaultServiceContainer should use @unchecked Sendable"
        )
        // Find the safety comment before the class declaration
        guard let range = source.range(of: "final class DefaultServiceContainer") else {
            XCTFail("DefaultServiceContainer class declaration not found")
            return
        }
        let preceding = String(source[source.startIndex..<range.lowerBound])
        XCTAssertTrue(
            preceding.contains("Safety:") || preceding.contains("Safety:"),
            "DefaultServiceContainer should have a Safety: comment explaining @unchecked Sendable"
        )
    }

    func test_defaultServiceContainer_propertiesAreAllLetBindings() throws {
        let source = try readSource("XRoads/Services/ServiceContainer.swift")

        // Extract the DefaultServiceContainer class body
        guard let classStart = source.range(of: "final class DefaultServiceContainer")?.lowerBound else {
            XCTFail("DefaultServiceContainer not found")
            return
        }
        let fromClass = String(source[classStart...])

        // Check that service properties are `let` not `var`
        let serviceNames = [
            "gitService", "processRunner", "ptyRunner", "mcpClient",
            "agentEventBus", "mergeCoordinator", "gitMaster", "notesSyncService",
            "historyService", "agentLauncher", "loopLauncher", "layeredDispatcher",
            "actionRunner", "unifiedDispatcher", "orchestrator"
        ]

        for name in serviceNames {
            XCTAssertTrue(
                fromClass.contains("let \(name):"),
                "DefaultServiceContainer.\(name) should be a let binding, not var"
            )
        }
    }

    // MARK: - MockServiceContainer Tests

    func test_mockServiceContainer_hasUncheckedSendableWithSafetyComment() throws {
        let source = try readSource("XRoads/Services/ServiceContainer.swift")
        XCTAssertTrue(
            source.contains("final class MockServiceContainer: ServiceContainer, @unchecked Sendable"),
            "MockServiceContainer should use @unchecked Sendable"
        )
        guard let range = source.range(of: "final class MockServiceContainer") else {
            XCTFail("MockServiceContainer class declaration not found")
            return
        }
        let preceding = String(source[source.startIndex..<range.lowerBound])
        // Count occurrences of "Safety:" - need at least 2 (one for Default, one for Mock)
        let safetyCount = preceding.components(separatedBy: "Safety:").count - 1
        XCTAssertGreaterThanOrEqual(
            safetyCount, 2,
            "MockServiceContainer should have its own Safety: comment (found \(safetyCount) total before it)"
        )
    }

    func test_mockServiceContainer_propertiesAreAllLetBindings() throws {
        let source = try readSource("XRoads/Services/ServiceContainer.swift")

        guard let classStart = source.range(of: "final class MockServiceContainer")?.lowerBound else {
            XCTFail("MockServiceContainer not found")
            return
        }
        let fromClass = String(source[classStart...])

        let serviceNames = [
            "gitService", "processRunner", "ptyRunner", "mcpClient",
            "agentEventBus", "mergeCoordinator", "gitMaster", "notesSyncService",
            "historyService", "agentLauncher", "loopLauncher", "layeredDispatcher",
            "actionRunner", "unifiedDispatcher", "orchestrator"
        ]

        for name in serviceNames {
            XCTAssertTrue(
                fromClass.contains("let \(name):"),
                "MockServiceContainer.\(name) should be a let binding, not var"
            )
        }
    }

    // MARK: - PTYProcess Tests

    func test_ptyProcess_hasUncheckedSendableWithSafetyComment() throws {
        let source = try readSource("XRoads/Services/PTYProcess.swift")
        XCTAssertTrue(
            source.contains("final class PTYProcess: @unchecked Sendable"),
            "PTYProcess should use @unchecked Sendable"
        )
        guard let range = source.range(of: "final class PTYProcess") else {
            XCTFail("PTYProcess class declaration not found")
            return
        }
        let preceding = String(source[source.startIndex..<range.lowerBound])
        XCTAssertTrue(
            preceding.contains("Safety:"),
            "PTYProcess should have a Safety: comment explaining @unchecked Sendable"
        )
    }

    func test_ptyProcess_usesNSLockForMutableState() throws {
        let source = try readSource("XRoads/Services/PTYProcess.swift")
        XCTAssertTrue(
            source.contains("private let lock = NSLock()"),
            "PTYProcess should use NSLock for thread safety"
        )
        // Verify lock is used in property accessors and methods
        XCTAssertTrue(
            source.contains("lock.lock()"),
            "PTYProcess should call lock.lock() to protect mutable state"
        )
        XCTAssertTrue(
            source.contains("lock.unlock()"),
            "PTYProcess should call lock.unlock() after accessing mutable state"
        )
    }

    // MARK: - WeakAppStateRef Tests

    func test_weakAppStateRef_hasUncheckedSendableWithSafetyComment() throws {
        let source = try readSource("XRoads/ViewModels/AppState.swift")
        XCTAssertTrue(
            source.contains("WeakAppStateRef: @unchecked Sendable"),
            "WeakAppStateRef should use @unchecked Sendable"
        )
        guard let range = source.range(of: "class WeakAppStateRef") else {
            XCTFail("WeakAppStateRef class declaration not found")
            return
        }
        let preceding = String(source[source.startIndex..<range.lowerBound])
        XCTAssertTrue(
            preceding.contains("Safety:"),
            "WeakAppStateRef should have a Safety: comment explaining @unchecked Sendable"
        )
        XCTAssertTrue(
            preceding.contains("MainActor"),
            "WeakAppStateRef safety comment should mention MainActor confinement"
        )
    }

    // MARK: - NotesSyncService Tests

    func test_notesSyncService_conformsToUncheckedSendable() throws {
        let source = try readSource("XRoads/Services/NotesSyncService.swift")
        XCTAssertTrue(
            source.contains("struct NotesSyncService: @unchecked Sendable"),
            "NotesSyncService should conform to @unchecked Sendable"
        )
        XCTAssertTrue(
            source.contains("Safety:"),
            "NotesSyncService should have a Safety: comment explaining @unchecked Sendable"
        )
    }

    // MARK: - Comprehensive: All @unchecked Sendable have Safety comments

    func test_allUncheckedSendable_haveSafetyComments() throws {
        let files: [(String, String)] = [
            ("XRoads/Services/ServiceContainer.swift", "DefaultServiceContainer"),
            ("XRoads/Services/ServiceContainer.swift", "MockServiceContainer"),
            ("XRoads/Services/PTYProcess.swift", "PTYProcess"),
            ("XRoads/ViewModels/AppState.swift", "WeakAppStateRef"),
            ("XRoads/Services/NotesSyncService.swift", "NotesSyncService")
        ]

        for (file, typeName) in files {
            let source = try readSource(file)
            // Find @unchecked Sendable usage
            guard let uncheckedRange = source.range(of: "\(typeName): @unchecked Sendable") ??
                  source.range(of: "\(typeName):.*@unchecked Sendable") else {
                // Try broader search for types with protocol conformance in between
                XCTAssertTrue(
                    source.contains("@unchecked Sendable"),
                    "\(typeName) in \(file) should have @unchecked Sendable"
                )
                continue
            }

            let preceding = String(source[source.startIndex..<uncheckedRange.lowerBound])
            // Look for Safety: within the last 500 chars before the declaration
            let lookback = String(preceding.suffix(500))
            XCTAssertTrue(
                lookback.contains("Safety:"),
                "\(typeName) in \(file) should have a 'Safety:' comment within 500 chars before @unchecked Sendable"
            )
        }
    }
}
