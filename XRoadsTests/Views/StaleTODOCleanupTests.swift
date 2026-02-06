//
//  StaleTODOCleanupTests.swift
//  XRoadsTests
//
//  CR-303: Verify stale TODO/FIXME markers are cleaned up
//

import XCTest
import Foundation

final class StaleTODOCleanupTests: XCTestCase {

    // MARK: - Helpers

    private func sourceRoot() -> URL {
        // Navigate from the test file to the project root
        // XRoadsTests/Views/StaleTODOCleanupTests.swift -> project root
        var url = URL(fileURLWithPath: #filePath)
        // Go up: StaleTODOCleanupTests.swift -> Views -> XRoadsTests -> project root
        for _ in 0..<3 { url = url.deletingLastPathComponent() }
        return url
    }

    private func readFile(_ relativePath: String) throws -> String {
        let url = sourceRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func productionSwiftFiles() throws -> [URL] {
        let xroadsDir = sourceRoot().appendingPathComponent("XRoads")
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: xroadsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(url)
        }
        return files
    }

    // MARK: - MainWindowView.swift TODO cleanup

    func testMainWindowViewHasNoTODOComments() throws {
        let content = try readFile("XRoads/Views/MainWindowView.swift")
        let lines = content.components(separatedBy: .newlines)

        let todoLines = lines.enumerated().filter { (_, line) in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("// TODO:")
        }

        XCTAssertTrue(todoLines.isEmpty, "MainWindowView.swift should have no // TODO: comments, found: \(todoLines.map { "line \($0.offset + 1): \($0.element)" })")
    }

    func testMainWindowViewHasNoForcedAgenticMode() throws {
        let content = try readFile("XRoads/Views/MainWindowView.swift")
        XCTAssertFalse(content.contains("forcedAgenticMode"), "MainWindowView.swift should not contain forcedAgenticMode variable")
    }

    func testMainWindowViewHasNoIsFullAgenticModeAppStorage() throws {
        let content = try readFile("XRoads/Views/MainWindowView.swift")
        XCTAssertFalse(content.contains("@AppStorage") && content.contains("isFullAgenticMode"),
            "MainWindowView.swift should not contain isFullAgenticMode @AppStorage")
    }

    func testMainWindowViewHasNoLegacyNavigationLayout() throws {
        let content = try readFile("XRoads/Views/MainWindowView.swift")
        XCTAssertFalse(content.contains("legacyNavigationLayout"), "MainWindowView.swift should not contain legacyNavigationLayout")
    }

    func testMainWindowViewHasNoContentColumnStruct() throws {
        let content = try readFile("XRoads/Views/MainWindowView.swift")
        XCTAssertFalse(content.contains("struct ContentColumn"), "MainWindowView.swift should not contain ContentColumn struct")
    }

    func testLifecycleModifierHasNoIsFullAgenticMode() throws {
        let content = try readFile("XRoads/Views/MainWindowView.swift")
        // Check within the LifecycleModifier struct
        guard let range = content.range(of: "struct LifecycleModifier") else {
            XCTFail("LifecycleModifier struct not found")
            return
        }
        let afterModifier = String(content[range.lowerBound...])
        // Take roughly the modifier body (next 30 lines or so)
        let lines = afterModifier.components(separatedBy: .newlines).prefix(30)
        let modifierContent = lines.joined(separator: "\n")
        XCTAssertFalse(modifierContent.contains("isFullAgenticMode"), "LifecycleModifier should not reference isFullAgenticMode")
    }

    // MARK: - UnifiedDispatcher.swift TODO cleanup

    func testUnifiedDispatcherHasNoTODOComments() throws {
        let content = try readFile("XRoads/Services/UnifiedDispatcher.swift")
        let lines = content.components(separatedBy: .newlines)

        let todoLines = lines.enumerated().filter { (_, line) in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("// TODO:")
        }

        XCTAssertTrue(todoLines.isEmpty, "UnifiedDispatcher.swift should have no // TODO: comments, found: \(todoLines.map { "line \($0.offset + 1): \($0.element)" })")
    }

    // MARK: - No orphaned TODO/FIXME in production code

    func testNoOrphanedTODOsInProductionCode() throws {
        let files = try productionSwiftFiles()
        var violations: [String] = []

        for fileURL in files {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let relativePath = fileURL.path.replacingOccurrences(of: sourceRoot().path + "/", with: "")

            // Skip ReviewAction.swift which legitimately references TODO as part of code review logic
            if relativePath.contains("ReviewAction.swift") { continue }

            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("// TODO:") || trimmed.hasPrefix("// FIXME:") || trimmed.hasPrefix("// HACK:") {
                    violations.append("\(relativePath):\(i + 1): \(trimmed)")
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, "Production code should have no stale TODO/FIXME/HACK comments:\n\(violations.joined(separator: "\n"))")
    }
}
