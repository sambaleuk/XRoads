//
//  DashboardLayoutTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-015: Unit tests for Dashboard Layout with Chat Panel
//

import XCTest
@testable import XRoadsLib

final class DashboardLayoutTests: XCTestCase {

    // MARK: - Test Properties

    var panelState: CollapsiblePanelState!
    let testPersistenceKey = "test_chatPanel"

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // Clear any existing test data
        UserDefaults.standard.removeObject(forKey: testPersistenceKey)
        UserDefaults.standard.removeObject(forKey: "\(testPersistenceKey).width")
        UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.chatPanelExpanded)
        UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.chatPanelWidth)

        panelState = CollapsiblePanelState(
            persistenceKey: testPersistenceKey,
            defaultExpanded: true,
            defaultWidth: 360
        )
    }

    override func tearDown() async throws {
        // Clean up test data
        UserDefaults.standard.removeObject(forKey: testPersistenceKey)
        UserDefaults.standard.removeObject(forKey: "\(testPersistenceKey).width")
        UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.chatPanelExpanded)
        UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.chatPanelWidth)
        panelState = nil
        try await super.tearDown()
    }

    // MARK: - Test: Panel Shows/Hides on Toggle

    @MainActor
    func test_chatPanel_toggleShowsAndHides() async {
        // Given: A panel state that starts expanded (default)
        XCTAssertTrue(panelState.isExpanded, "Panel should be expanded by default")

        // When: Toggling the panel
        panelState.toggle()

        // Then: Panel should be collapsed
        XCTAssertFalse(panelState.isExpanded, "Panel should be collapsed after toggle")

        // When: Toggling again
        panelState.toggle()

        // Then: Panel should be expanded again
        XCTAssertTrue(panelState.isExpanded, "Panel should be expanded after second toggle")
    }

    // MARK: - Test: State Persists

    @MainActor
    func test_chatPanel_statePersists() async {
        // Given: A panel state that we collapse
        panelState.collapse()
        XCTAssertFalse(panelState.isExpanded, "Panel should be collapsed")

        // When: Creating a new panel state with the same persistence key
        let newPanelState = CollapsiblePanelState(
            persistenceKey: testPersistenceKey,
            defaultExpanded: true,
            defaultWidth: 360
        )

        // Then: The new state should load the persisted value
        XCTAssertFalse(newPanelState.isExpanded, "New panel state should load persisted collapsed state")
    }

    @MainActor
    func test_chatPanel_widthPersists() async {
        // Given: A panel state with modified width
        let customWidth: CGFloat = 420
        panelState.width = customWidth

        // When: Creating a new panel state with the same persistence key
        let newPanelState = CollapsiblePanelState(
            persistenceKey: testPersistenceKey,
            defaultExpanded: true,
            defaultWidth: 360
        )

        // Then: The new state should load the persisted width
        XCTAssertEqual(newPanelState.width, customWidth, "New panel state should load persisted width")
    }

    // MARK: - Test: UserDefaults Keys Exist

    func test_userDefaultsKeys_chatPanelExpanded_exists() {
        // Then: The key should be defined
        XCTAssertEqual(UserDefaults.Keys.chatPanelExpanded, "chatPanelExpanded",
                       "chatPanelExpanded key should be defined correctly")
    }

    func test_userDefaultsKeys_chatPanelWidth_exists() {
        // Then: The key should be defined
        XCTAssertEqual(UserDefaults.Keys.chatPanelWidth, "chatPanelWidth",
                       "chatPanelWidth key should be defined correctly")
    }

    // MARK: - Test: Expand and Collapse Methods

    @MainActor
    func test_chatPanel_expandMethod_expandsPanel() async {
        // Given: A collapsed panel
        panelState.collapse()
        XCTAssertFalse(panelState.isExpanded)

        // When: Calling expand
        panelState.expand()

        // Then: Panel should be expanded
        XCTAssertTrue(panelState.isExpanded, "Panel should be expanded after calling expand()")
    }

    @MainActor
    func test_chatPanel_collapseMethod_collapsesPanel() async {
        // Given: An expanded panel
        panelState.expand()
        XCTAssertTrue(panelState.isExpanded)

        // When: Calling collapse
        panelState.collapse()

        // Then: Panel should be collapsed
        XCTAssertFalse(panelState.isExpanded, "Panel should be collapsed after calling collapse()")
    }

    // MARK: - Test: Width Reset

    @MainActor
    func test_chatPanel_resetWidth_restoresDefault() async {
        // Given: A panel with custom width
        let defaultWidth: CGFloat = 360
        panelState.width = 450

        // When: Resetting width
        panelState.resetWidth()

        // Then: Width should be restored to default
        XCTAssertEqual(panelState.width, defaultWidth, "Width should be reset to default value")
    }

    // MARK: - Test: Width Constraints

    @MainActor
    func test_chatPanel_widthWithinConstraints() async {
        // Given: Default width settings
        let minWidth: CGFloat = 280
        let maxWidth: CGFloat = 500

        // Then: Default width should be within constraints
        XCTAssertGreaterThanOrEqual(panelState.width, minWidth, "Default width should be >= minWidth")
        XCTAssertLessThanOrEqual(panelState.width, maxWidth, "Default width should be <= maxWidth")
    }

    // MARK: - Test: Default Expanded State

    @MainActor
    func test_chatPanel_defaultsToExpanded() async {
        // Given: A fresh panel state with default settings
        UserDefaults.standard.removeObject(forKey: "fresh_test_key")
        let freshState = CollapsiblePanelState(
            persistenceKey: "fresh_test_key",
            defaultExpanded: true,
            defaultWidth: 360
        )

        // Then: Panel should be expanded by default
        XCTAssertTrue(freshState.isExpanded, "Panel should default to expanded state")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "fresh_test_key")
        UserDefaults.standard.removeObject(forKey: "fresh_test_key.width")
    }

    // MARK: - Test: Default Collapsed State

    @MainActor
    func test_chatPanel_canDefaultToCollapsed() async {
        // Given: A fresh panel state with defaultExpanded = false
        UserDefaults.standard.removeObject(forKey: "collapsed_test_key")
        let collapsedState = CollapsiblePanelState(
            persistenceKey: "collapsed_test_key",
            defaultExpanded: false,
            defaultWidth: 360
        )

        // Then: Panel should be collapsed by default
        XCTAssertFalse(collapsedState.isExpanded, "Panel should default to collapsed state when configured")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "collapsed_test_key")
        UserDefaults.standard.removeObject(forKey: "collapsed_test_key.width")
    }

    // MARK: - Test: AppStorage Integration

    func test_appStorageKeys_areCorrectlyDefined() {
        // Then: Keys should be properly defined for @AppStorage use
        XCTAssertFalse(UserDefaults.Keys.chatPanelExpanded.isEmpty,
                       "chatPanelExpanded key should not be empty")
        XCTAssertFalse(UserDefaults.Keys.chatPanelWidth.isEmpty,
                       "chatPanelWidth key should not be empty")
    }

    // MARK: - Test: UserDefaults Direct Access

    func test_userDefaults_canStoreBoolForChatPanel() {
        // Given: A boolean value
        let key = UserDefaults.Keys.chatPanelExpanded
        let expectedValue = false

        // When: Storing in UserDefaults
        UserDefaults.standard.set(expectedValue, forKey: key)

        // Then: Should be retrievable
        let storedValue = UserDefaults.standard.bool(forKey: key)
        XCTAssertEqual(storedValue, expectedValue, "Bool should be stored and retrieved correctly")
    }

    func test_userDefaults_canStoreDoubleForChatPanelWidth() {
        // Given: A double value for width
        let key = UserDefaults.Keys.chatPanelWidth
        let expectedValue: Double = 400.0

        // When: Storing in UserDefaults
        UserDefaults.standard.set(expectedValue, forKey: key)

        // Then: Should be retrievable
        let storedValue = UserDefaults.standard.double(forKey: key)
        XCTAssertEqual(storedValue, expectedValue, accuracy: 0.001, "Double should be stored and retrieved correctly")
    }
}
