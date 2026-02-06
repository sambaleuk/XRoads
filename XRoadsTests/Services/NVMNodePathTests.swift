//
//  NVMNodePathTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-06.
//  CR-202: Verify MCPClient node path resolution dynamically discovers NVM versions
//

import XCTest
@testable import XRoadsLib

final class NVMNodePathTests: XCTestCase {

    // MARK: - Source-Level Checks

    /// Verifies no hardcoded NVM version string remains in MCPClient.swift
    func test_noHardcodedNVMVersion_inSource() throws {
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

        // The hardcoded version "v20.19.4" should no longer appear in non-comment code
        let lines = content.components(separatedBy: .newlines)
        var violations: [String] = []
        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                continue
            }
            if line.contains("v20.19.4") {
                violations.append("Line \(lineNumber + 1): \(trimmed)")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "MCPClient.swift should not contain hardcoded NVM version 'v20.19.4':\n\(violations.joined(separator: "\n"))"
        )
    }

    /// Verifies source uses glob-based NVM resolution (findLatestNVMNode method exists)
    func test_source_usesGlobBasedNVMResolution() throws {
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

        XCTAssertTrue(content.contains("findLatestNVMNode"),
                       "MCPClient.swift should contain findLatestNVMNode method for dynamic NVM resolution")
        XCTAssertTrue(content.contains("contentsOfDirectory"),
                       "MCPClient.swift should glob NVM versions directory")
        XCTAssertTrue(content.contains("parseVersion"),
                       "MCPClient.swift should parse version strings for sorting")
    }

    // MARK: - parseVersion Tests

    func test_parseVersion_standardVersion() {
        let result = MCPClient.parseVersion("v20.19.4")
        XCTAssertEqual(result, [20, 19, 4])
    }

    func test_parseVersion_withoutPrefix() {
        let result = MCPClient.parseVersion("18.0.0")
        XCTAssertEqual(result, [18, 0, 0])
    }

    func test_parseVersion_singleComponent() {
        let result = MCPClient.parseVersion("v22")
        XCTAssertEqual(result, [22])
    }

    func test_parseVersion_invalidInput() {
        let result = MCPClient.parseVersion("notaversion")
        XCTAssertTrue(result.isEmpty, "Invalid version string should return empty array")
    }

    func test_parseVersion_emptyString() {
        let result = MCPClient.parseVersion("")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - findLatestNVMNode Tests

    /// When NVM directory doesn't exist, should return nil
    func test_findLatestNVMNode_noNVMDirectory_returnsNil() {
        let result = MCPClient.findLatestNVMNode(home: "/nonexistent/path")
        XCTAssertNil(result, "Should return nil when NVM directory doesn't exist")
    }

    /// When NVM directory exists on this machine, should return a path containing /bin/node
    func test_findLatestNVMNode_withRealNVM_returnsValidPath() {
        let home = NSHomeDirectory()
        let nvmDir = (home as NSString).appendingPathComponent(".nvm/versions/node")
        guard FileManager.default.fileExists(atPath: nvmDir) else {
            // NVM not installed - skip (not a failure)
            return
        }

        let result = MCPClient.findLatestNVMNode(home: home)
        XCTAssertNotNil(result, "Should find at least one NVM node version")
        if let path = result {
            XCTAssertTrue(path.hasSuffix("/bin/node"), "Path should end with /bin/node, got: \(path)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                          "Returned node path should exist: \(path)")
        }
    }

    /// Verifies the latest version is picked when multiple NVM versions exist
    func test_findLatestNVMNode_selectsLatestVersion() {
        let home = NSHomeDirectory()
        let nvmDir = (home as NSString).appendingPathComponent(".nvm/versions/node")
        guard FileManager.default.fileExists(atPath: nvmDir) else { return }

        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) else {
            return
        }

        let versions = entries
            .filter { $0.hasPrefix("v") }
            .compactMap { entry -> (name: String, parts: [Int])? in
                let parts = MCPClient.parseVersion(entry)
                guard !parts.isEmpty else { return nil }
                let nodeBin = (nvmDir as NSString)
                    .appendingPathComponent(entry)
                    .appending("/bin/node")
                guard FileManager.default.fileExists(atPath: nodeBin) else { return nil }
                return (entry, parts)
            }
            .sorted { lhs, rhs in
                for (l, r) in zip(lhs.parts, rhs.parts) {
                    if l != r { return l > r }
                }
                return lhs.parts.count > rhs.parts.count
            }

        guard let expectedLatest = versions.first else { return }
        guard let result = MCPClient.findLatestNVMNode(home: home) else {
            XCTFail("findLatestNVMNode should return a path when NVM versions exist")
            return
        }

        XCTAssertTrue(result.contains(expectedLatest.name),
                       "Should select latest version \(expectedLatest.name), got path: \(result)")
    }

    // MARK: - findNodePath Tests

    func test_findNodePath_returnsNonEmptyString() {
        let result = MCPClient.findNodePath()
        XCTAssertFalse(result.isEmpty, "findNodePath should return a non-empty path")
    }

    func test_findNodePath_returnsExistingExecutable() {
        let result = MCPClient.findNodePath()
        // On CI or machines without Node, the fallback is /usr/local/bin/node which may not exist,
        // but on a dev machine at least one candidate should resolve
        if FileManager.default.fileExists(atPath: result) {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: result),
                          "Resolved node path should be executable: \(result)")
        }
    }

    // MARK: - Fallback Chain Source Check

    /// Verifies the fallback chain includes expected paths
    func test_source_fallbackChainIncludesExpectedPaths() throws {
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

        XCTAssertTrue(content.contains("/opt/homebrew/bin/node"),
                       "Fallback chain should include Homebrew path")
        XCTAssertTrue(content.contains("/usr/local/bin/node"),
                       "Fallback chain should include /usr/local/bin/node")
        XCTAssertTrue(content.contains("/usr/bin/node"),
                       "Fallback chain should include /usr/bin/node")
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
