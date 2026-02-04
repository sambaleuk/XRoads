//
//  MCPSettingsTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-021: Unit tests for MCP Settings and credential storage
//

import XCTest
@testable import XRoadsLib

final class MCPSettingsTests: XCTestCase {

    // MARK: - MCPConfiguration Tests

    func test_mcpConfiguration_creation() {
        let config = MCPConfiguration(
            id: "test-mcp",
            name: "Test MCP",
            path: "/usr/local/bin/test-mcp",
            arguments: ["--arg1", "--arg2"],
            isEnabled: true,
            hasCredentials: false,
            environmentVariables: ["KEY": "VALUE"]
        )

        XCTAssertEqual(config.id, "test-mcp")
        XCTAssertEqual(config.name, "Test MCP")
        XCTAssertEqual(config.path, "/usr/local/bin/test-mcp")
        XCTAssertEqual(config.arguments, ["--arg1", "--arg2"])
        XCTAssertTrue(config.isEnabled)
        XCTAssertFalse(config.hasCredentials)
        XCTAssertEqual(config.environmentVariables["KEY"], "VALUE")
    }

    func test_mcpConfiguration_codable() throws {
        let config = MCPConfiguration(
            id: "test-mcp",
            name: "Test MCP",
            path: "/usr/local/bin/test-mcp",
            arguments: ["--arg1"],
            isEnabled: true,
            hasCredentials: true,
            environmentVariables: ["KEY": "VALUE"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPConfiguration.self, from: data)

        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.name, config.name)
        XCTAssertEqual(decoded.path, config.path)
        XCTAssertEqual(decoded.arguments, config.arguments)
        XCTAssertEqual(decoded.isEnabled, config.isEnabled)
        XCTAssertEqual(decoded.hasCredentials, config.hasCredentials)
        XCTAssertEqual(decoded.environmentVariables, config.environmentVariables)
    }

    func test_mcpConfiguration_equality() {
        let config1 = MCPConfiguration(
            id: "test-mcp",
            name: "Test MCP",
            path: "/usr/local/bin/test-mcp"
        )

        let config2 = MCPConfiguration(
            id: "test-mcp",
            name: "Test MCP",
            path: "/usr/local/bin/test-mcp"
        )

        // Note: They have different IDs since id defaults to UUID().uuidString
        // So we compare by creating with same id
        let config3 = MCPConfiguration(
            id: "same-id",
            name: "Test MCP",
            path: "/path"
        )
        let config4 = MCPConfiguration(
            id: "same-id",
            name: "Test MCP",
            path: "/path"
        )

        XCTAssertEqual(config3, config4)
    }

    func test_mcpConfiguration_hashable() {
        let config1 = MCPConfiguration(
            id: "test-1",
            name: "Test MCP 1",
            path: "/path1"
        )
        let config2 = MCPConfiguration(
            id: "test-2",
            name: "Test MCP 2",
            path: "/path2"
        )

        var set = Set<MCPConfiguration>()
        set.insert(config1)
        set.insert(config2)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(config1))
        XCTAssertTrue(set.contains(config2))
    }

    func test_mcpConfiguration_presets() {
        // XRoads MCP preset
        let xroads = MCPConfiguration.xroadsMCP
        XCTAssertEqual(xroads.id, "xroads-mcp")
        XCTAssertEqual(xroads.name, "XRoads MCP")
        XCTAssertTrue(xroads.isEnabled)

        // Filesystem MCP preset
        let filesystem = MCPConfiguration.fileSystemMCP
        XCTAssertEqual(filesystem.id, "filesystem-mcp")
        XCTAssertFalse(filesystem.isEnabled) // Disabled by default

        // Git MCP preset
        let git = MCPConfiguration.gitMCP
        XCTAssertEqual(git.id, "git-mcp")
        XCTAssertFalse(git.isEnabled) // Disabled by default
    }

    // MARK: - AutoLoadCondition Tests

    func test_autoLoadCondition_displayName() {
        XCTAssertEqual(AutoLoadCondition.always.displayName, "Always")
        XCTAssertEqual(AutoLoadCondition.hasPackageJson.displayName, "Has package.json")
        XCTAssertEqual(AutoLoadCondition.hasCargoToml.displayName, "Has Cargo.toml")
        XCTAssertEqual(AutoLoadCondition.hasPackageSwift.displayName, "Has Package.swift")
        XCTAssertEqual(AutoLoadCondition.hasGitRepo.displayName, "Is Git repository")
        XCTAssertEqual(AutoLoadCondition.custom.displayName, "Custom")
    }

    func test_autoLoadCondition_description() {
        XCTAssertFalse(AutoLoadCondition.always.description.isEmpty)
        XCTAssertFalse(AutoLoadCondition.hasPackageJson.description.isEmpty)
        XCTAssertFalse(AutoLoadCondition.hasCargoToml.description.isEmpty)
    }

    func test_autoLoadCondition_codable() throws {
        let condition = AutoLoadCondition.hasPackageJson

        let encoder = JSONEncoder()
        let data = try encoder.encode(condition)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AutoLoadCondition.self, from: data)

        XCTAssertEqual(decoded, condition)
    }

    // MARK: - MCPAutoLoadRule Tests

    func test_mcpAutoLoadRule_creation() {
        let rule = MCPAutoLoadRule(
            id: "rule-1",
            mcpId: "test-mcp",
            condition: .hasPackageJson,
            isEnabled: true
        )

        XCTAssertEqual(rule.id, "rule-1")
        XCTAssertEqual(rule.mcpId, "test-mcp")
        XCTAssertEqual(rule.condition, .hasPackageJson)
        XCTAssertTrue(rule.isEnabled)
    }

    func test_mcpAutoLoadRule_codable() throws {
        let rule = MCPAutoLoadRule(
            id: "rule-1",
            mcpId: "test-mcp",
            condition: .hasGitRepo,
            isEnabled: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPAutoLoadRule.self, from: data)

        XCTAssertEqual(decoded.id, rule.id)
        XCTAssertEqual(decoded.mcpId, rule.mcpId)
        XCTAssertEqual(decoded.condition, rule.condition)
        XCTAssertEqual(decoded.isEnabled, rule.isEnabled)
    }

    // MARK: - MCPValidationResult Tests

    func test_mcpValidationResult_valid() {
        let result = MCPValidationResult.valid(version: "1.0.0", connectionTestPassed: true)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.version, "1.0.0")
        XCTAssertNil(result.errorMessage)
        XCTAssertTrue(result.connectionTestPassed)
    }

    func test_mcpValidationResult_invalid() {
        let result = MCPValidationResult.invalid(error: "File not found")

        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.version)
        XCTAssertEqual(result.errorMessage, "File not found")
        XCTAssertFalse(result.connectionTestPassed)
    }

    // MARK: - KeychainError Tests

    func test_keychainError_descriptions() {
        XCTAssertNotNil(KeychainError.itemNotFound.errorDescription)
        XCTAssertNotNil(KeychainError.duplicateItem.errorDescription)
        XCTAssertNotNil(KeychainError.invalidData.errorDescription)
        XCTAssertNotNil(KeychainError.unexpectedStatus(0).errorDescription)
        XCTAssertNotNil(KeychainError.encodingFailed.errorDescription)
        XCTAssertNotNil(KeychainError.decodingFailed.errorDescription)

        // Check specific messages
        XCTAssertEqual(KeychainError.itemNotFound.errorDescription, "Item not found in Keychain")
        XCTAssertEqual(KeychainError.encodingFailed.errorDescription, "Failed to encode data for storage")
    }

    func test_keychainError_equality() {
        XCTAssertEqual(KeychainError.itemNotFound, KeychainError.itemNotFound)
        XCTAssertNotEqual(KeychainError.itemNotFound, KeychainError.duplicateItem)
        XCTAssertEqual(KeychainError.unexpectedStatus(42), KeychainError.unexpectedStatus(42))
        XCTAssertNotEqual(KeychainError.unexpectedStatus(42), KeychainError.unexpectedStatus(0))
    }

    // MARK: - String Masking Extension Tests

    func test_string_masked_short() {
        let short = "abc"
        XCTAssertEqual(short.masked, "•••")
    }

    func test_string_masked_long() {
        let apiKey = "sk-1234567890abcdef"
        let masked = apiKey.masked
        XCTAssertTrue(masked.hasPrefix("sk-1"))
        XCTAssertTrue(masked.hasSuffix("cdef"))
        XCTAssertTrue(masked.contains("••••"))
    }

    func test_string_fullyMasked() {
        let secret = "supersecretvalue"
        let masked = secret.fullyMasked
        XCTAssertFalse(masked.contains("s"))
        XCTAssertTrue(masked.allSatisfy { $0 == "•" })
    }

    // MARK: - MCPPathValidator Tests

    func test_mcpPathValidator_emptyPath() {
        let result = MCPPathValidator.validate(path: "")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Path is empty")
    }

    func test_mcpPathValidator_npmPackage() {
        let result = MCPPathValidator.validate(path: "@modelcontextprotocol/server-filesystem")
        XCTAssertTrue(result.isValid)
        // npm packages are considered valid (installed separately)
    }

    func test_mcpPathValidator_nonExistentPath() {
        let result = MCPPathValidator.validate(path: "/nonexistent/path/to/mcp")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "File not found")
    }

    // MARK: - KeychainService Async Tests

    func test_keychainService_credentialOperations() async {
        let service = KeychainService.shared
        let testMCPId = "test-mcp-\(UUID().uuidString)"
        let testCredential = "test-credential-value"

        // Initially no credential
        let hasInitial = await service.hasMCPCredential(mcpId: testMCPId)
        XCTAssertFalse(hasInitial)

        // Save credential
        do {
            try await service.saveMCPCredential(mcpId: testMCPId, credential: testCredential)
        } catch {
            XCTFail("Failed to save credential: \(error)")
            return
        }

        // Check it exists
        let hasAfterSave = await service.hasMCPCredential(mcpId: testMCPId)
        XCTAssertTrue(hasAfterSave)

        // Retrieve credential
        let retrieved = await service.getMCPCredential(mcpId: testMCPId)
        XCTAssertEqual(retrieved, testCredential)

        // Delete credential
        do {
            try await service.deleteMCPCredential(mcpId: testMCPId)
        } catch {
            XCTFail("Failed to delete credential: \(error)")
            return
        }

        // Check it's gone
        let hasAfterDelete = await service.hasMCPCredential(mcpId: testMCPId)
        XCTAssertFalse(hasAfterDelete)
    }

    func test_keychainService_retrieveNonExistent() async {
        let service = KeychainService.shared
        let nonExistentId = "non-existent-\(UUID().uuidString)"

        let result = await service.getMCPCredential(mcpId: nonExistentId)
        XCTAssertNil(result)
    }

    func test_keychainService_updateExisting() async {
        let service = KeychainService.shared
        let testMCPId = "update-test-\(UUID().uuidString)"
        let firstValue = "first-value"
        let secondValue = "second-value"

        // Save first value
        do {
            try await service.saveMCPCredential(mcpId: testMCPId, credential: firstValue)
            let first = await service.getMCPCredential(mcpId: testMCPId)
            XCTAssertEqual(first, firstValue)

            // Update with second value
            try await service.saveMCPCredential(mcpId: testMCPId, credential: secondValue)
            let second = await service.getMCPCredential(mcpId: testMCPId)
            XCTAssertEqual(second, secondValue)

            // Cleanup
            try await service.deleteMCPCredential(mcpId: testMCPId)
        } catch {
            XCTFail("Failed: \(error)")
        }
    }

    // MARK: - KeychainService API Key Tests

    func test_keychainService_apiKeyOperations() async {
        let service = KeychainService.shared
        let testProvider = "test-provider-\(UUID().uuidString)"
        let testApiKey = "sk-test1234567890abcdef"

        // Initially no API key
        let hasInitial = await service.hasAPIKey(provider: testProvider)
        XCTAssertFalse(hasInitial)

        // Save API key
        do {
            try await service.saveAPIKey(provider: testProvider, key: testApiKey)
        } catch {
            XCTFail("Failed to save API key: \(error)")
            return
        }

        // Check it exists
        let hasAfterSave = await service.hasAPIKey(provider: testProvider)
        XCTAssertTrue(hasAfterSave)

        // Retrieve API key
        let retrieved = await service.getAPIKey(provider: testProvider)
        XCTAssertEqual(retrieved, testApiKey)

        // Delete API key
        do {
            try await service.deleteAPIKey(provider: testProvider)
        } catch {
            XCTFail("Failed to delete API key: \(error)")
            return
        }

        // Check it's gone
        let hasAfterDelete = await service.hasAPIKey(provider: testProvider)
        XCTAssertFalse(hasAfterDelete)
    }
}
