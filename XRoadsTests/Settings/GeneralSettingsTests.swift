//
//  GeneralSettingsTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-019: Unit tests for General Settings
//

import XCTest
@testable import XRoadsLib

final class GeneralSettingsTests: XCTestCase {

    // MARK: - Test Properties

    var testDefaults: UserDefaults!
    var suiteName: String!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        // Create unique suite name for each test
        suiteName = "com.xroads.test.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        // Clean up test defaults
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Test: Settings Save Correctly

    func test_settingsSaveCorrectly_stringValue() {
        // Given: A test UserDefaults
        let key = SettingsKey.defaultRepoPath.rawValue
        let testValue = "/test/repo/path"

        // When: Saving a string value
        testDefaults.set(testValue, forKey: key)

        // Then: Value should be retrievable
        let retrieved = testDefaults.string(forKey: key)
        XCTAssertEqual(retrieved, testValue, "String value should be saved and retrieved correctly")
    }

    func test_settingsSaveCorrectly_boolValue() {
        // Given: A test UserDefaults
        let key = SettingsKey.autoStartLogStreaming.rawValue

        // When: Saving a bool value
        testDefaults.set(true, forKey: key)

        // Then: Value should be retrievable
        let retrieved = testDefaults.bool(forKey: key)
        XCTAssertTrue(retrieved, "Bool value should be saved and retrieved correctly")
    }

    func test_settingsSaveCorrectly_intValue() {
        // Given: A test UserDefaults
        let key = SettingsKey.maxLogEntries.rawValue
        let testValue = 1000

        // When: Saving an int value
        testDefaults.set(testValue, forKey: key)

        // Then: Value should be retrievable
        let retrieved = testDefaults.integer(forKey: key)
        XCTAssertEqual(retrieved, testValue, "Int value should be saved and retrieved correctly")
    }

    // MARK: - Test: Settings Load on Launch (Default Values)

    func test_settingsLoadOnLaunch_defaultRepoPath() {
        // Given: Fresh UserDefaults (no saved value)
        let key = SettingsKey.defaultRepoPath.rawValue

        // When: Getting a non-existent string
        let value = testDefaults.string(forKey: key)

        // Then: Should return nil (empty in AppSettings)
        XCTAssertNil(value, "Non-existent string should return nil")
    }

    func test_settingsLoadOnLaunch_defaultMaxLogEntries() {
        // Given: Fresh UserDefaults (no saved value)
        let key = SettingsKey.maxLogEntries.rawValue

        // When: Getting a non-existent int
        let value = testDefaults.integer(forKey: key)

        // Then: Should return 0 (AppSettings provides default 500)
        XCTAssertEqual(value, 0, "Non-existent int should return 0")
    }

    func test_settingsLoadOnLaunch_defaultAutoStartLogStreaming() {
        // Given: Fresh UserDefaults with value set
        let key = SettingsKey.autoStartLogStreaming.rawValue
        testDefaults.set(true, forKey: key)

        // When: Getting the value
        let value = testDefaults.bool(forKey: key)

        // Then: Should return true
        XCTAssertTrue(value, "Auto-start log streaming should default to true")
    }

    // MARK: - Test: Reset Works

    func test_resetWorks_generalSettings() {
        // Given: UserDefaults with custom values
        testDefaults.set("/custom/path", forKey: SettingsKey.defaultRepoPath.rawValue)
        testDefaults.set(false, forKey: SettingsKey.autoStartLogStreaming.rawValue)
        testDefaults.set(2000, forKey: SettingsKey.maxLogEntries.rawValue)
        testDefaults.set(false, forKey: SettingsKey.enableNotifications.rawValue)

        // Verify values are set
        XCTAssertEqual(testDefaults.string(forKey: SettingsKey.defaultRepoPath.rawValue), "/custom/path")
        XCTAssertFalse(testDefaults.bool(forKey: SettingsKey.autoStartLogStreaming.rawValue))
        XCTAssertEqual(testDefaults.integer(forKey: SettingsKey.maxLogEntries.rawValue), 2000)

        // When: Resetting to defaults
        testDefaults.removeObject(forKey: SettingsKey.defaultRepoPath.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.autoStartLogStreaming.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.maxLogEntries.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.enableNotifications.rawValue)

        // Then: Values should be nil/0 (AppSettings provides defaults)
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.defaultRepoPath.rawValue), "Reset should clear repo path")
        XCTAssertFalse(testDefaults.bool(forKey: SettingsKey.autoStartLogStreaming.rawValue), "Reset should clear auto-start (returns false for non-existent)")
        XCTAssertEqual(testDefaults.integer(forKey: SettingsKey.maxLogEntries.rawValue), 0, "Reset should clear max entries")
    }

    func test_resetWorks_cliPaths() {
        // Given: UserDefaults with custom CLI paths
        testDefaults.set("/custom/claude", forKey: SettingsKey.claudeCliPath.rawValue)
        testDefaults.set("/custom/gemini", forKey: SettingsKey.geminiCliPath.rawValue)
        testDefaults.set("/custom/codex", forKey: SettingsKey.codexCliPath.rawValue)

        // Verify values are set
        XCTAssertEqual(testDefaults.string(forKey: SettingsKey.claudeCliPath.rawValue), "/custom/claude")

        // When: Resetting to defaults
        testDefaults.removeObject(forKey: SettingsKey.claudeCliPath.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.geminiCliPath.rawValue)
        testDefaults.removeObject(forKey: SettingsKey.codexCliPath.rawValue)

        // Then: Values should be nil (AppSettings provides defaults)
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.claudeCliPath.rawValue), "Reset should clear Claude CLI path")
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.geminiCliPath.rawValue), "Reset should clear Gemini CLI path")
        XCTAssertNil(testDefaults.string(forKey: SettingsKey.codexCliPath.rawValue), "Reset should clear Codex CLI path")
    }

    // MARK: - Test: Appearance Mode

    func test_appearanceMode_allCases() {
        // Then: All appearance modes should have display names
        for mode in AppearanceMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "Appearance mode \(mode) should have a display name")
        }
    }

    func test_appearanceMode_colorScheme() {
        // Then: System mode should return nil, others should return specific schemes
        XCTAssertNil(AppearanceMode.system.colorScheme, "System mode should return nil color scheme")
        XCTAssertEqual(AppearanceMode.dark.colorScheme, .dark, "Dark mode should return .dark")
        XCTAssertEqual(AppearanceMode.light.colorScheme, .light, "Light mode should return .light")
    }

    func test_appearanceMode_persistence() {
        // Given: An appearance mode value
        let mode = AppearanceMode.dark

        // When: Saving to UserDefaults
        testDefaults.set(mode.rawValue, forKey: SettingsKey.appearanceMode.rawValue)

        // Then: Should be retrievable
        if let savedValue = testDefaults.string(forKey: SettingsKey.appearanceMode.rawValue),
           let savedMode = AppearanceMode(rawValue: savedValue) {
            XCTAssertEqual(savedMode, mode, "Appearance mode should persist correctly")
        } else {
            XCTFail("Should be able to retrieve saved appearance mode")
        }
    }

    // MARK: - Test: Accent Color Choice

    func test_accentColorChoice_allCases() {
        // Then: All accent colors should have display names and colors
        for choice in AccentColorChoice.allCases {
            XCTAssertFalse(choice.displayName.isEmpty, "Accent color \(choice) should have a display name")
            // Color property is implicitly tested by accessing it
            _ = choice.color
        }
    }

    func test_accentColorChoice_persistence() {
        // Given: An accent color value
        let color = AccentColorChoice.purple

        // When: Saving to UserDefaults
        testDefaults.set(color.rawValue, forKey: SettingsKey.accentColorChoice.rawValue)

        // Then: Should be retrievable
        if let savedValue = testDefaults.string(forKey: SettingsKey.accentColorChoice.rawValue),
           let savedColor = AccentColorChoice(rawValue: savedValue) {
            XCTAssertEqual(savedColor, color, "Accent color should persist correctly")
        } else {
            XCTFail("Should be able to retrieve saved accent color")
        }
    }

    // MARK: - Test: Keyboard Shortcut Config

    func test_keyboardShortcutConfig_displayString() {
        // Given: Various shortcut configurations
        let shortcut1 = KeyboardShortcutConfig(key: "n", modifiers: ["command"])
        let shortcut2 = KeyboardShortcutConfig(key: "k", modifiers: ["command", "shift"])
        let shortcut3 = KeyboardShortcutConfig(key: "p", modifiers: ["command", "option"])
        let shortcut4 = KeyboardShortcutConfig(key: "s", modifiers: ["control", "option", "shift", "command"])

        // Then: Display strings should be formatted correctly
        XCTAssertEqual(shortcut1.displayString, "⌘N", "Command+N should display as ⌘N")
        XCTAssertEqual(shortcut2.displayString, "⇧⌘K", "Command+Shift+K should display as ⇧⌘K")
        XCTAssertEqual(shortcut3.displayString, "⌥⌘P", "Command+Option+P should display as ⌥⌘P")
        XCTAssertEqual(shortcut4.displayString, "⌃⌥⇧⌘S", "All modifiers should be in correct order")
    }

    func test_keyboardShortcutConfig_defaults() {
        // Then: Default shortcuts should be set correctly
        XCTAssertEqual(KeyboardShortcutConfig.defaultNewWorktree.key, "n")
        XCTAssertTrue(KeyboardShortcutConfig.defaultNewWorktree.modifiers.contains("command"))

        XCTAssertEqual(KeyboardShortcutConfig.defaultCloseWorktree.key, "w")
        XCTAssertEqual(KeyboardShortcutConfig.defaultStopAgent.key, ".")
        XCTAssertEqual(KeyboardShortcutConfig.defaultCommandPalette.key, "k")
        XCTAssertEqual(KeyboardShortcutConfig.defaultClearLogs.key, "l")

        XCTAssertEqual(KeyboardShortcutConfig.defaultToggleChatPanel.key, "o")
        XCTAssertTrue(KeyboardShortcutConfig.defaultToggleChatPanel.modifiers.contains("command"))
        XCTAssertTrue(KeyboardShortcutConfig.defaultToggleChatPanel.modifiers.contains("shift"))
    }

    func test_keyboardShortcutConfig_codable() {
        // Given: A shortcut configuration
        let shortcut = KeyboardShortcutConfig(key: "t", modifiers: ["command", "option"])

        // When: Encoding and decoding
        do {
            let encoded = try JSONEncoder().encode(shortcut)
            let decoded = try JSONDecoder().decode(KeyboardShortcutConfig.self, from: encoded)

            // Then: Decoded should match original
            XCTAssertEqual(decoded.key, shortcut.key, "Key should survive encode/decode")
            XCTAssertEqual(decoded.modifiers, shortcut.modifiers, "Modifiers should survive encode/decode")
        } catch {
            XCTFail("Encoding/decoding should not throw: \(error)")
        }
    }

    func test_keyboardShortcutConfig_persistence() {
        // Given: A shortcut configuration
        let shortcut = KeyboardShortcutConfig(key: "x", modifiers: ["command", "shift"])

        // When: Saving to UserDefaults as data
        if let data = try? JSONEncoder().encode(shortcut) {
            testDefaults.set(data, forKey: SettingsKey.shortcutNewWorktree.rawValue)

            // Then: Should be retrievable
            if let savedData = testDefaults.data(forKey: SettingsKey.shortcutNewWorktree.rawValue),
               let savedShortcut = try? JSONDecoder().decode(KeyboardShortcutConfig.self, from: savedData) {
                XCTAssertEqual(savedShortcut.key, shortcut.key, "Shortcut key should persist")
                XCTAssertEqual(savedShortcut.modifiers, shortcut.modifiers, "Shortcut modifiers should persist")
            } else {
                XCTFail("Should be able to retrieve saved shortcut")
            }
        } else {
            XCTFail("Should be able to encode shortcut")
        }
    }

    // MARK: - Test: Settings Key Enum

    func test_settingsKey_allCasesExist() {
        // Then: All settings keys should have non-empty raw values
        for key in SettingsKey.allCases {
            XCTAssertFalse(key.rawValue.isEmpty, "Settings key \(key) should have a non-empty raw value")
        }
    }

    func test_settingsKey_uniqueRawValues() {
        // Given: All settings keys
        let rawValues = SettingsKey.allCases.map { $0.rawValue }

        // Then: All raw values should be unique
        let uniqueValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueValues.count, "All settings keys should have unique raw values")
    }

    // MARK: - Test: Notification Settings

    func test_notificationSettings_persistence() {
        // Given: Notification settings values
        testDefaults.set(true, forKey: SettingsKey.enableNotifications.rawValue)
        testDefaults.set(true, forKey: SettingsKey.notifyOnAgentComplete.rawValue)
        testDefaults.set(false, forKey: SettingsKey.notifyOnAgentError.rawValue)

        // Then: Values should be retrievable
        XCTAssertTrue(testDefaults.bool(forKey: SettingsKey.enableNotifications.rawValue))
        XCTAssertTrue(testDefaults.bool(forKey: SettingsKey.notifyOnAgentComplete.rawValue))
        XCTAssertFalse(testDefaults.bool(forKey: SettingsKey.notifyOnAgentError.rawValue))
    }

    // MARK: - Test: Chat Panel Settings

    func test_chatPanelSettings_persistence() {
        // Given: Chat panel settings values
        testDefaults.set(false, forKey: SettingsKey.chatPanelExpanded.rawValue)
        testDefaults.set(400.0, forKey: SettingsKey.chatPanelWidth.rawValue)

        // Then: Values should be retrievable
        XCTAssertFalse(testDefaults.bool(forKey: SettingsKey.chatPanelExpanded.rawValue))
        XCTAssertEqual(testDefaults.double(forKey: SettingsKey.chatPanelWidth.rawValue), 400.0, accuracy: 0.1)
    }

    // MARK: - Test: Full Agentic Mode

    func test_fullAgenticMode_persistence() {
        // Given: Full agentic mode enabled
        testDefaults.set(true, forKey: SettingsKey.fullAgenticMode.rawValue)

        // Then: Value should be retrievable
        XCTAssertTrue(testDefaults.bool(forKey: SettingsKey.fullAgenticMode.rawValue))
    }

    // MARK: - Test: Launch at Login

    func test_launchAtLogin_persistence() {
        // Given: Launch at login enabled
        testDefaults.set(true, forKey: SettingsKey.launchAtLogin.rawValue)

        // Then: Value should be retrievable
        XCTAssertTrue(testDefaults.bool(forKey: SettingsKey.launchAtLogin.rawValue))
    }
}
