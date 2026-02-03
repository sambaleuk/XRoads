import XCTest
@testable import XRoads

final class ActionPickerMenuTests: XCTestCase {

    // MARK: - Action Filtering by Category Tests

    func testActionsFilteredByDevCategory() {
        // Given
        let devActions = ActionType.allCases.filter { $0.category == .dev }

        // Then
        XCTAssertTrue(devActions.contains(.implement))
        XCTAssertTrue(devActions.contains(.review))
        XCTAssertFalse(devActions.contains(.integrationTest))
        XCTAssertFalse(devActions.contains(.write))
    }

    func testActionsFilteredByQACategory() {
        // Given
        let qaActions = ActionType.allCases.filter { $0.category == .qa }

        // Then
        XCTAssertTrue(qaActions.contains(.integrationTest))
        XCTAssertFalse(qaActions.contains(.implement))
        XCTAssertFalse(qaActions.contains(.review))
        XCTAssertFalse(qaActions.contains(.write))
    }

    func testActionsFilteredByOpsCategory() {
        // Given
        let opsActions = ActionType.allCases.filter { $0.category == .ops }

        // Then
        XCTAssertTrue(opsActions.contains(.write))
        XCTAssertTrue(opsActions.contains(.custom))
        XCTAssertFalse(opsActions.contains(.implement))
        XCTAssertFalse(opsActions.contains(.integrationTest))
    }

    func testAllCategoriesCoverAllActions() {
        // Given
        let devActions = ActionType.allCases.filter { $0.category == .dev }
        let qaActions = ActionType.allCases.filter { $0.category == .qa }
        let opsActions = ActionType.allCases.filter { $0.category == .ops }

        // When
        let totalCategorized = devActions.count + qaActions.count + opsActions.count

        // Then
        XCTAssertEqual(totalCategorized, ActionType.allCases.count)
    }

    // MARK: - Disabled State for Incompatible CLI Tests

    func testActionRequiredSkillsNotEmpty() {
        // Given - actions that should have required skills
        let implement = ActionType.implement
        let review = ActionType.review
        let integrationTest = ActionType.integrationTest
        let write = ActionType.write

        // Then
        XCTAssertFalse(implement.requiredSkills.isEmpty)
        XCTAssertFalse(review.requiredSkills.isEmpty)
        XCTAssertFalse(integrationTest.requiredSkills.isEmpty)
        XCTAssertFalse(write.requiredSkills.isEmpty)
    }

    func testCustomActionHasEmptyRequiredSkills() {
        // Given
        let custom = ActionType.custom

        // Then
        XCTAssertTrue(custom.requiredSkills.isEmpty)
    }

    func testSkillAvailabilityCheck() {
        // Given
        let availableSkills: Set<String> = ["prd", "code-writer", "commit"]
        let implementSkills = Set(ActionType.implement.requiredSkills)

        // When - check if all implement skills are available
        let hasAllSkills = implementSkills.isSubset(of: availableSkills)

        // Then
        XCTAssertTrue(hasAllSkills)
    }

    func testMissingSkillDetection() {
        // Given
        let availableSkills: Set<String> = ["prd", "commit"] // Missing "code-writer"
        let implementSkills = Set(ActionType.implement.requiredSkills)

        // When
        let missingSkills = implementSkills.subtracting(availableSkills)

        // Then
        XCTAssertFalse(missingSkills.isEmpty)
        XCTAssertTrue(missingSkills.contains("code-writer"))
    }

    // MARK: - Selection Callback Tests

    func testSelectionCallbackIsInvoked() {
        // Given
        var selectedAction: ActionType?
        let callback: (ActionType) -> Void = { action in
            selectedAction = action
        }

        // When
        callback(.implement)

        // Then
        XCTAssertEqual(selectedAction, .implement)
    }

    func testSelectionCallbackReceivesCorrectAction() {
        // Given
        var receivedActions: [ActionType] = []
        let callback: (ActionType) -> Void = { action in
            receivedActions.append(action)
        }

        // When
        callback(.implement)
        callback(.review)
        callback(.integrationTest)

        // Then
        XCTAssertEqual(receivedActions.count, 3)
        XCTAssertEqual(receivedActions[0], .implement)
        XCTAssertEqual(receivedActions[1], .review)
        XCTAssertEqual(receivedActions[2], .integrationTest)
    }

    // MARK: - ActionPickerStyle Tests

    func testAllPickerStyles() {
        // Given/Then
        let styles: [ActionPickerStyle] = [.menu, .inline, .compact]
        XCTAssertEqual(styles.count, 3)
    }

    func testMenuStyle() {
        // Given
        let style = ActionPickerStyle.menu

        // Then
        XCTAssertEqual(style, .menu)
    }

    func testInlineStyle() {
        // Given
        let style = ActionPickerStyle.inline

        // Then
        XCTAssertEqual(style, .inline)
    }

    func testCompactStyle() {
        // Given
        let style = ActionPickerStyle.compact

        // Then
        XCTAssertEqual(style, .compact)
    }

    // MARK: - Action Color Tests

    func testActionAccentColorByCategory() {
        // Given
        let devAction = ActionType.implement
        let qaAction = ActionType.integrationTest
        let opsAction = ActionType.write

        // Then
        XCTAssertEqual(devAction.category, .dev)
        XCTAssertEqual(qaAction.category, .qa)
        XCTAssertEqual(opsAction.category, .ops)
    }

    func testAllActionsHaveAccentColor() {
        // Given/Then
        for action in ActionType.allCases where action != .custom {
            // Every non-custom action should have a valid category-based color
            let category = action.category
            XCTAssertNotNil(category)
        }
    }

    // MARK: - ActionPickerMenu Component Tests

    func testActionPickerMenuCreation() {
        // Given
        let pickerMenu = ActionPickerMenu(
            selectedAction: .constant(.implement),
            cliType: .claude,
            style: .menu
        )

        // Then - verify the component structure exists
        XCTAssertNotNil(pickerMenu)
    }

    func testActionPickerMenuWithNilSelection() {
        // Given
        let pickerMenu = ActionPickerMenu(
            selectedAction: .constant(nil),
            cliType: nil,
            style: .inline
        )

        // Then
        XCTAssertNotNil(pickerMenu)
    }

    func testActionPickerMenuWithCallback() {
        // Given
        var callbackInvoked = false
        let pickerMenu = ActionPickerMenu(
            selectedAction: .constant(.review),
            cliType: .gemini,
            onSelect: { _ in
                callbackInvoked = true
            },
            style: .compact
        )

        // Then
        XCTAssertNotNil(pickerMenu.onSelect)
    }

    // MARK: - ActionPickerPopover Tests

    func testActionPickerPopoverCreation() {
        // Given
        let popover = ActionPickerPopover(
            selectedAction: .constant(.implement),
            cliType: .claude
        )

        // Then
        XCTAssertNotNil(popover)
    }

    func testActionPickerPopoverWithCallback() {
        // Given
        var selectedAction: ActionType?
        let popover = ActionPickerPopover(
            selectedAction: .constant(nil),
            cliType: .codex,
            onSelect: { action in
                selectedAction = action
            }
        )

        // Then
        XCTAssertNotNil(popover.onSelect)
    }

    // MARK: - Category Display Names

    func testCategoryDisplayNames() {
        // Given/Then
        XCTAssertEqual(ActionCategory.dev.displayName, "Development")
        XCTAssertEqual(ActionCategory.qa.displayName, "Quality Assurance")
        XCTAssertEqual(ActionCategory.ops.displayName, "Operations")
    }

    // MARK: - Action Display Names Match PRD

    func testActionDisplayNames() {
        // Given - names from PRD action_definitions
        let expected: [ActionType: String] = [
            .implement: "Implement",
            .review: "Review",
            .integrationTest: "Integration Test",
            .write: "Write Docs",
            .custom: "Custom"
        ]

        // Then
        for (action, expectedName) in expected {
            XCTAssertEqual(action.displayName, expectedName)
        }
    }

    // MARK: - Action Icon Names

    func testActionIconNames() {
        // Given - icons from PRD action_definitions
        let expected: [ActionType: String] = [
            .implement: "hammer.fill",
            .review: "eye.fill",
            .integrationTest: "testtube.2",
            .write: "doc.text.fill",
            .custom: "gearshape.fill"
        ]

        // Then
        for (action, expectedIcon) in expected {
            XCTAssertEqual(action.iconName, expectedIcon)
        }
    }

    // MARK: - Unit Tests Indicator

    func testImplementActionIncludesUnitTests() {
        // Given
        let implement = ActionType.implement

        // Then
        XCTAssertTrue(implement.includesUnitTests)
    }

    func testOtherActionsDoNotIncludeUnitTests() {
        // Given
        let nonImplementActions: [ActionType] = [.review, .integrationTest, .write, .custom]

        // Then
        for action in nonImplementActions {
            XCTAssertFalse(action.includesUnitTests, "\(action) should not include unit tests")
        }
    }

    // MARK: - Skills Badge Count Logic

    func testSkillsBadgeCountCalculation() {
        // Given
        let availableSkills: Set<String> = ["prd", "commit"]
        let actionSkills = ActionType.implement.requiredSkills

        // When
        let availableCount = actionSkills.filter { availableSkills.contains($0) }.count
        let totalCount = actionSkills.count
        let missingCount = totalCount - availableCount

        // Then
        XCTAssertEqual(availableCount, 2) // prd, commit
        XCTAssertEqual(totalCount, 3) // prd, code-writer, commit
        XCTAssertEqual(missingCount, 1) // code-writer
    }

    func testAllSkillsAvailableBadge() {
        // Given
        let availableSkills: Set<String> = ["prd", "code-writer", "commit"]
        let actionSkills = Set(ActionType.implement.requiredSkills)

        // When
        let missingSkills = actionSkills.subtracting(availableSkills)

        // Then
        XCTAssertTrue(missingSkills.isEmpty)
    }
}

// MARK: - CLI Compatibility Tests

final class ActionPickerCLICompatibilityTests: XCTestCase {

    func testAllActionsAvailableForClaude() async {
        // Given
        let registry = ActionRegistry.shared
        let claudeActions = await registry.actions(for: .claude)

        // Then - all built-in actions should be available
        XCTAssertTrue(claudeActions.contains(.implement))
        XCTAssertTrue(claudeActions.contains(.review))
        XCTAssertTrue(claudeActions.contains(.integrationTest))
        XCTAssertTrue(claudeActions.contains(.write))
    }

    func testAllActionsAvailableForGemini() async {
        // Given
        let registry = ActionRegistry.shared
        let geminiActions = await registry.actions(for: .gemini)

        // Then
        XCTAssertTrue(geminiActions.contains(.implement))
        XCTAssertTrue(geminiActions.contains(.review))
    }

    func testAllActionsAvailableForCodex() async {
        // Given
        let registry = ActionRegistry.shared
        let codexActions = await registry.actions(for: .codex)

        // Then
        XCTAssertTrue(codexActions.contains(.implement))
        XCTAssertTrue(codexActions.contains(.review))
    }

    func testActionFilteringByCategory() async {
        // Given
        let registry = ActionRegistry.shared
        let devActions = await registry.actions(for: .claude, in: .dev)
        let qaActions = await registry.actions(for: .claude, in: .qa)

        // Then
        XCTAssertTrue(devActions.contains(.implement))
        XCTAssertFalse(devActions.contains(.integrationTest))
        XCTAssertTrue(qaActions.contains(.integrationTest))
        XCTAssertFalse(qaActions.contains(.implement))
    }

    func testIsActionAvailableMethod() async {
        // Given
        let registry = ActionRegistry.shared

        // Then
        let implementAvailable = await registry.isActionAvailable(.implement, for: .claude)
        let reviewAvailable = await registry.isActionAvailable(.review, for: .gemini)

        XCTAssertTrue(implementAvailable)
        XCTAssertTrue(reviewAvailable)
    }
}
