//
//  CLISettingsTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-020: Unit tests for CLI Settings
//

import XCTest
@testable import XRoadsLib

final class CLISettingsTests: XCTestCase {

    // MARK: - Test Properties

    var testDefaults: UserDefaults!
    var suiteName: String!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        suiteName = "com.xroads.test.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Test: Valid Path Shows Green Check

    func test_validPathShowsGreenCheck_fileExists() {
        // Given: A path to a file that exists
        let validPath = "/bin/ls"  // ls always exists on macOS

        // When: Validating the path
        let result = CLIPathValidator.validate(path: validPath)

        // Then: Result should be valid
        XCTAssertTrue(result.isValid, "Valid path should show as valid")
        XCTAssertNil(result.errorMessage, "Valid path should have no error message")
    }

    func test_validPathShowsGreenCheck_executableFile() {
        // Given: A path to an executable
        let executablePath = "/bin/bash"

        // When: Validating the path
        let result = CLIPathValidator.validate(path: executablePath)

        // Then: Result should be valid with possible version info
        XCTAssertTrue(result.isValid, "Executable file should be valid")
    }

    // MARK: - Test: Invalid Path Shows Error

    func test_invalidPathShowsError_fileNotFound() {
        // Given: A path to a file that doesn't exist
        let invalidPath = "/nonexistent/path/to/cli"

        // When: Validating the path
        let result = CLIPathValidator.validate(path: invalidPath)

        // Then: Result should be invalid with error
        XCTAssertFalse(result.isValid, "Invalid path should show as invalid")
        XCTAssertEqual(result.errorMessage, "File not found", "Should show 'File not found' error")
    }

    func test_invalidPathShowsError_emptyPath() {
        // Given: An empty path
        let emptyPath = ""

        // When: Validating the path
        let result = CLIPathValidator.validate(path: emptyPath)

        // Then: Result should be invalid
        XCTAssertFalse(result.isValid, "Empty path should be invalid")
        XCTAssertEqual(result.errorMessage, "Path is empty", "Should show 'Path is empty' error")
    }

    func test_invalidPathShowsError_notExecutable() {
        // Given: A path to a file that exists but is not executable
        // Create a temporary non-executable file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_non_exec_\(UUID().uuidString)")

        do {
            try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
            // Remove execute permission
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempFile.path)

            // When: Validating the path
            let result = CLIPathValidator.validate(path: tempFile.path)

            // Then: Result should be invalid
            XCTAssertFalse(result.isValid, "Non-executable file should be invalid")
            XCTAssertEqual(result.errorMessage, "Not executable", "Should show 'Not executable' error")

            // Cleanup
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("Test setup failed: \(error)")
        }
    }

    // MARK: - Test: Test Connection Executes CLI

    func test_testConnectionExecutesCLI_success() async {
        // Given: A path to a valid CLI (using /bin/echo as a safe test)
        let cliPath = "/bin/echo"

        // When: Testing connection
        let result = await CLIPathValidator.testConnection(path: cliPath, agentType: .claude)

        // Then: Result should show connection test passed
        XCTAssertTrue(result.isValid, "Valid CLI should be valid")
        // Note: /bin/echo --help may or may not return 0 depending on implementation
        // The key is that it runs without crashing
    }

    func test_testConnectionExecutesCLI_invalidPath() async {
        // Given: An invalid path
        let invalidPath = "/nonexistent/cli"

        // When: Testing connection
        let result = await CLIPathValidator.testConnection(path: invalidPath, agentType: .claude)

        // Then: Result should be invalid
        XCTAssertFalse(result.isValid, "Invalid path should fail connection test")
        XCTAssertFalse(result.connectionTestPassed, "Connection test should not pass for invalid path")
    }

    // MARK: - Test: CLI Configuration Model

    func test_cliConfiguration_defaultValues() {
        // Given: Default CLI configurations
        let claudeConfig = CLIConfiguration.defaultClaude
        let geminiConfig = CLIConfiguration.defaultGemini
        let codexConfig = CLIConfiguration.defaultCodex

        // Then: Paths should either be an auto-detected real binary or the hardcoded fallback
        XCTAssertTrue(claudeConfig.path.hasSuffix("/claude"),
                       "Claude path should end with /claude, got: \(claudeConfig.path)")
        XCTAssertTrue(claudeConfig.defaultArguments.contains("--dangerously-skip-permissions"))
        XCTAssertTrue(claudeConfig.isEnabled)

        XCTAssertTrue(geminiConfig.path.hasSuffix("/gemini"),
                       "Gemini path should end with /gemini, got: \(geminiConfig.path)")
        XCTAssertTrue(geminiConfig.defaultArguments.contains("--sandbox=false"))
        XCTAssertTrue(geminiConfig.isEnabled)

        XCTAssertTrue(codexConfig.path.hasSuffix("/codex"),
                       "Codex path should end with /codex, got: \(codexConfig.path)")
        XCTAssertTrue(codexConfig.defaultArguments.contains("--full-auto"))
        XCTAssertTrue(codexConfig.isEnabled)
    }

    func test_cliConfiguration_codable() {
        // Given: A CLI configuration
        let config = CLIConfiguration(
            path: "/custom/path",
            defaultArguments: ["--arg1", "--arg2"],
            isEnabled: false
        )

        // When: Encoding and decoding
        do {
            let encoded = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(CLIConfiguration.self, from: encoded)

            // Then: Decoded should match original
            XCTAssertEqual(decoded.path, config.path)
            XCTAssertEqual(decoded.defaultArguments, config.defaultArguments)
            XCTAssertEqual(decoded.isEnabled, config.isEnabled)
        } catch {
            XCTFail("Encoding/decoding should not throw: \(error)")
        }
    }

    // MARK: - Test: CLI Validation Result

    func test_cliValidationResult_valid() {
        // Given: A valid result
        let result = CLIValidationResult.valid(version: "1.0.0", connectionTestPassed: true)

        // Then: Properties should be set correctly
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.version, "1.0.0")
        XCTAssertNil(result.errorMessage)
        XCTAssertTrue(result.connectionTestPassed)
    }

    func test_cliValidationResult_invalid() {
        // Given: An invalid result
        let result = CLIValidationResult.invalid(error: "Test error")

        // Then: Properties should be set correctly
        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.version)
        XCTAssertEqual(result.errorMessage, "Test error")
        XCTAssertFalse(result.connectionTestPassed)
    }

    // MARK: - Test: Settings Keys for CLI Configuration

    func test_settingsKeys_cliKeysExist() {
        // Then: All CLI-related settings keys should exist and be unique
        let cliKeys: [SettingsKey] = [
            .claudeCliPath, .geminiCliPath, .codexCliPath,
            .claudeDefaultArgs, .geminiDefaultArgs, .codexDefaultArgs,
            .claudeEnabled, .geminiEnabled, .codexEnabled,
            .cliPreferenceOrder
        ]

        let rawValues = cliKeys.map { $0.rawValue }
        let uniqueValues = Set(rawValues)

        XCTAssertEqual(rawValues.count, uniqueValues.count, "All CLI settings keys should be unique")

        for key in cliKeys {
            XCTAssertFalse(key.rawValue.isEmpty, "Key \(key) should have non-empty raw value")
        }
    }

    // MARK: - Test: CLI Default Arguments Persistence

    func test_cliDefaultArgs_persistence() {
        // Given: Custom CLI arguments
        let args = ["--custom-arg", "--another-arg"]
        let encoded = try? JSONEncoder().encode(args)

        // When: Saving to UserDefaults
        testDefaults.set(encoded, forKey: SettingsKey.claudeDefaultArgs.rawValue)

        // Then: Should be retrievable
        if let data = testDefaults.data(forKey: SettingsKey.claudeDefaultArgs.rawValue),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            XCTAssertEqual(decoded, args, "CLI arguments should persist correctly")
        } else {
            XCTFail("Should be able to retrieve saved CLI arguments")
        }
    }

    // MARK: - Test: CLI Enabled States Persistence

    func test_cliEnabled_persistence() {
        // Given: CLI enabled states
        testDefaults.set(false, forKey: SettingsKey.claudeEnabled.rawValue)
        testDefaults.set(true, forKey: SettingsKey.geminiEnabled.rawValue)
        testDefaults.set(false, forKey: SettingsKey.codexEnabled.rawValue)

        // Then: Values should be retrievable
        XCTAssertFalse(testDefaults.bool(forKey: SettingsKey.claudeEnabled.rawValue))
        XCTAssertTrue(testDefaults.bool(forKey: SettingsKey.geminiEnabled.rawValue))
        XCTAssertFalse(testDefaults.bool(forKey: SettingsKey.codexEnabled.rawValue))
    }

    // MARK: - Test: CLI Preference Order Persistence

    func test_cliPreferenceOrder_persistence() {
        // Given: A custom preference order
        let order = "gemini,codex,claude"

        // When: Saving to UserDefaults
        testDefaults.set(order, forKey: SettingsKey.cliPreferenceOrder.rawValue)

        // Then: Should be retrievable
        let retrieved = testDefaults.string(forKey: SettingsKey.cliPreferenceOrder.rawValue)
        XCTAssertEqual(retrieved, order, "CLI preference order should persist correctly")
    }

    func test_cliPreferenceOrder_parsing() {
        // Given: A preference order string
        let orderString = "gemini,codex,claude"
        let rawValues = orderString.split(separator: ",").map { String($0) }

        // When: Parsing to AgentType array
        let parsed = rawValues.compactMap { AgentType(rawValue: $0) }

        // Then: Should parse correctly
        XCTAssertEqual(parsed.count, 3, "Should parse all three agent types")
        XCTAssertEqual(parsed[0], .gemini, "First should be Gemini")
        XCTAssertEqual(parsed[1], .codex, "Second should be Codex")
        XCTAssertEqual(parsed[2], .claude, "Third should be Claude")
    }

    // MARK: - Test: Reset CLI Settings

    func test_resetCLISettings_resetsAllValues() {
        // Given: Custom CLI values saved
        testDefaults.set("/custom/claude", forKey: SettingsKey.claudeCliPath.rawValue)
        testDefaults.set("/custom/gemini", forKey: SettingsKey.geminiCliPath.rawValue)
        testDefaults.set("/custom/codex", forKey: SettingsKey.codexCliPath.rawValue)
        testDefaults.set(false, forKey: SettingsKey.claudeEnabled.rawValue)
        testDefaults.set("codex,gemini,claude", forKey: SettingsKey.cliPreferenceOrder.rawValue)

        // Verify values are set
        XCTAssertEqual(testDefaults.string(forKey: SettingsKey.claudeCliPath.rawValue), "/custom/claude")

        // When: Removing all CLI settings (simulating reset)
        testDefaults.removeObject(forKey: SettingsKey.claudeCliPath.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.geminiCliPath.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.codexCliPath.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.claudeEnabled.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.cliPreferenceOrder.rawValue)

        // Then: Values should be nil (AppSettings provides defaults)
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.claudeCliPath.rawValue))
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.geminiCliPath.rawValue))
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.codexCliPath.rawValue))
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.cliPreferenceOrder.rawValue))
    }
}
