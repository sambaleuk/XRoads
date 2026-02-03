import XCTest
@testable import XRoads

final class ActionRegistryTests: XCTestCase {

    var registry: ActionRegistry!

    override func setUp() async throws {
        registry = ActionRegistry()
    }

    override func tearDown() async throws {
        await registry.reset()
        registry = nil
    }

    // MARK: - Built-in Actions Tests

    func testBuiltInActionsExcludesCustom() async {
        let builtIn = await registry.builtInActions()

        XCTAssertFalse(builtIn.contains(.custom),
                       "Built-in actions should not include .custom")
        XCTAssertEqual(builtIn.count, 4,
                       "Should have 4 built-in actions (implement, review, integrationTest, write)")
    }

    func testBuiltInActionsContainsAllKnownTypes() async {
        let builtIn = await registry.builtInActions()

        XCTAssertTrue(builtIn.contains(.implement))
        XCTAssertTrue(builtIn.contains(.review))
        XCTAssertTrue(builtIn.contains(.integrationTest))
        XCTAssertTrue(builtIn.contains(.write))
    }

    // MARK: - Actions Per CLI Tests

    func testActionsFilteredByCLICompatibility() async {
        // By default, all CLIs support all built-in actions
        for cliType in AgentType.allCases {
            let actions = await registry.actions(for: cliType)

            XCTAssertFalse(actions.isEmpty,
                           "\(cliType) should have available actions")
            XCTAssertFalse(actions.contains(.custom),
                           "CLI actions should not include .custom by default")
        }
    }

    func testAllCLIsHaveSameDefaultActions() async {
        let claudeActions = await registry.actions(for: .claude)
        let geminiActions = await registry.actions(for: .gemini)
        let codexActions = await registry.actions(for: .codex)

        XCTAssertEqual(Set(claudeActions), Set(geminiActions),
                       "Claude and Gemini should have same default actions")
        XCTAssertEqual(Set(geminiActions), Set(codexActions),
                       "Gemini and Codex should have same default actions")
    }

    func testActionsFilteredByCategory() async {
        let devActions = await registry.actions(in: .dev)
        let qaActions = await registry.actions(in: .qa)
        let opsActions = await registry.actions(in: .ops)

        XCTAssertTrue(devActions.contains(.implement))
        XCTAssertTrue(devActions.contains(.review))

        XCTAssertTrue(qaActions.contains(.integrationTest))

        XCTAssertTrue(opsActions.contains(.write))
        XCTAssertTrue(opsActions.contains(.custom))
    }

    func testActionsForCLIInCategory() async {
        let claudeDevActions = await registry.actions(for: .claude, in: .dev)

        XCTAssertTrue(claudeDevActions.contains(.implement))
        XCTAssertTrue(claudeDevActions.contains(.review))
        XCTAssertFalse(claudeDevActions.contains(.integrationTest))
        XCTAssertFalse(claudeDevActions.contains(.write))
    }

    // MARK: - Action Availability Tests

    func testIsActionAvailableForBuiltInActions() async {
        for cliType in AgentType.allCases {
            let isImplementAvailable = await registry.isActionAvailable(.implement, for: cliType)
            XCTAssertTrue(isImplementAvailable,
                          "Implement should be available for \(cliType)")
        }
    }

    func testCustomActionNotAvailableByDefault() async {
        // No custom actions registered yet
        let isCustomAvailable = await registry.isActionAvailable(.custom, for: .claude)
        XCTAssertFalse(isCustomAvailable,
                       "Custom action should not be available when no custom actions registered")
    }

    // MARK: - Custom Action Registration Tests

    func testRegisterCustomAction() async {
        let customAction = CustomAction(
            id: "test-action",
            name: "Test Action",
            description: "A test custom action",
            requiredSkills: ["test-skill"]
        )

        await registry.registerCustomAction(customAction)

        let customActions = await registry.allCustomActions()
        XCTAssertEqual(customActions.count, 1)
        XCTAssertEqual(customActions.first?.id, "test-action")
    }

    func testRegisterDuplicateCustomActionIgnored() async {
        let customAction = CustomAction(
            id: "test-action",
            name: "Test Action",
            description: "A test custom action"
        )

        await registry.registerCustomAction(customAction)
        await registry.registerCustomAction(customAction) // Duplicate

        let customActions = await registry.allCustomActions()
        XCTAssertEqual(customActions.count, 1,
                       "Duplicate registration should be ignored")
    }

    func testRemoveCustomAction() async {
        let customAction = CustomAction(
            id: "test-action",
            name: "Test Action",
            description: "A test custom action"
        )

        await registry.registerCustomAction(customAction)
        await registry.removeCustomAction(id: "test-action")

        let customActions = await registry.allCustomActions()
        XCTAssertTrue(customActions.isEmpty)
    }

    func testCustomActionAvailableAfterRegistration() async {
        let customAction = CustomAction(
            id: "test-action",
            name: "Test Action",
            description: "A test custom action"
        )

        await registry.registerCustomAction(customAction)

        let isCustomAvailable = await registry.isActionAvailable(.custom, for: .claude)
        XCTAssertTrue(isCustomAvailable,
                      "Custom action should be available after registration")
    }

    func testCustomActionsFilteredByCLI() async {
        let claudeOnlyAction = CustomAction(
            id: "claude-only",
            name: "Claude Only",
            description: "Only for Claude",
            compatibleCLIs: [.claude]
        )

        let allCLIsAction = CustomAction(
            id: "all-clis",
            name: "All CLIs",
            description: "For all CLIs",
            compatibleCLIs: Set(AgentType.allCases)
        )

        await registry.registerCustomAction(claudeOnlyAction)
        await registry.registerCustomAction(allCLIsAction)

        let claudeCustom = await registry.customActions(for: .claude)
        let geminiCustom = await registry.customActions(for: .gemini)

        XCTAssertEqual(claudeCustom.count, 2)
        XCTAssertEqual(geminiCustom.count, 1)
        XCTAssertEqual(geminiCustom.first?.id, "all-clis")
    }

    // MARK: - CLI Override Tests

    func testSetAvailableActionsOverride() async {
        let limitedActions: Set<ActionType> = [.implement, .review]
        await registry.setAvailableActions(limitedActions, for: .codex)

        let codexActions = await registry.actions(for: .codex)
        XCTAssertEqual(Set(codexActions), limitedActions)

        // Other CLIs should be unaffected
        let claudeActions = await registry.actions(for: .claude)
        XCTAssertGreaterThan(claudeActions.count, 2)
    }

    func testClearOverrides() async {
        let limitedActions: Set<ActionType> = [.implement]
        await registry.setAvailableActions(limitedActions, for: .codex)
        await registry.clearOverrides(for: .codex)

        let codexActions = await registry.actions(for: .codex)
        XCTAssertGreaterThan(codexActions.count, 1,
                             "Codex should have default actions after clearing overrides")
    }

    // MARK: - Reset Tests

    func testResetClearsEverything() async {
        // Setup
        let customAction = CustomAction(
            id: "test",
            name: "Test",
            description: "Test"
        )
        await registry.registerCustomAction(customAction)
        await registry.setAvailableActions([.implement], for: .claude)

        // Reset
        await registry.reset()

        // Verify
        let customActions = await registry.allCustomActions()
        let claudeActions = await registry.actions(for: .claude)

        XCTAssertTrue(customActions.isEmpty)
        XCTAssertGreaterThan(claudeActions.count, 1)
    }
}

// MARK: - CustomAction Tests

final class CustomActionTests: XCTestCase {

    func testCustomActionInitialization() {
        let action = CustomAction(
            id: "my-action",
            name: "My Action",
            description: "Does something cool",
            iconName: "star.fill",
            requiredSkills: ["skill1", "skill2"],
            compatibleCLIs: [.claude, .gemini]
        )

        XCTAssertEqual(action.id, "my-action")
        XCTAssertEqual(action.name, "My Action")
        XCTAssertEqual(action.description, "Does something cool")
        XCTAssertEqual(action.iconName, "star.fill")
        XCTAssertEqual(action.requiredSkills, ["skill1", "skill2"])
        XCTAssertEqual(action.compatibleCLIs, [.claude, .gemini])
    }

    func testCustomActionDefaultValues() {
        let action = CustomAction(
            id: "minimal",
            name: "Minimal",
            description: "Just the basics"
        )

        XCTAssertEqual(action.iconName, "gearshape.fill")
        XCTAssertTrue(action.requiredSkills.isEmpty)
        XCTAssertEqual(action.compatibleCLIs, Set(AgentType.allCases))
    }

    func testCustomActionCompatibilityWithAllCLIs() {
        let action = CustomAction(
            id: "universal",
            name: "Universal",
            description: "Works everywhere",
            compatibleCLIs: Set(AgentType.allCases)
        )

        for cliType in AgentType.allCases {
            XCTAssertTrue(action.isCompatible(with: cliType))
        }
    }

    func testCustomActionCompatibilityWithSpecificCLI() {
        let action = CustomAction(
            id: "claude-only",
            name: "Claude Only",
            description: "Only for Claude",
            compatibleCLIs: [.claude]
        )

        XCTAssertTrue(action.isCompatible(with: .claude))
        XCTAssertFalse(action.isCompatible(with: .gemini))
        XCTAssertFalse(action.isCompatible(with: .codex))
    }

    func testCustomActionCompatibilityWithEmptyCLIs() {
        // Empty compatible CLIs means compatible with all
        let action = CustomAction(
            id: "empty-compat",
            name: "Empty Compat",
            description: "Empty means all",
            compatibleCLIs: []
        )

        for cliType in AgentType.allCases {
            XCTAssertTrue(action.isCompatible(with: cliType),
                          "Empty compatibleCLIs should mean compatible with all")
        }
    }

    func testCustomActionCodable() throws {
        let action = CustomAction(
            id: "codable-test",
            name: "Codable Test",
            description: "Testing encode/decode",
            iconName: "gear",
            requiredSkills: ["a", "b"],
            compatibleCLIs: [.claude]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(action)
        let decoded = try decoder.decode(CustomAction.self, from: data)

        XCTAssertEqual(decoded.id, action.id)
        XCTAssertEqual(decoded.name, action.name)
        XCTAssertEqual(decoded.description, action.description)
        XCTAssertEqual(decoded.iconName, action.iconName)
        XCTAssertEqual(decoded.requiredSkills, action.requiredSkills)
        XCTAssertEqual(decoded.compatibleCLIs, action.compatibleCLIs)
    }

    func testCustomActionHashable() {
        let action1 = CustomAction(id: "a", name: "A", description: "A")
        let action2 = CustomAction(id: "a", name: "A", description: "A")
        let action3 = CustomAction(id: "b", name: "B", description: "B")

        XCTAssertEqual(action1, action2)
        XCTAssertNotEqual(action1, action3)

        var set: Set<CustomAction> = []
        set.insert(action1)
        set.insert(action2)
        XCTAssertEqual(set.count, 1)
    }
}
