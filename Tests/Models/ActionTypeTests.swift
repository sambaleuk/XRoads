import XCTest
@testable import XRoads

final class ActionTypeTests: XCTestCase {

    // MARK: - Display Name Tests

    func testAllEnumCasesHaveValidDisplayName() {
        for actionType in ActionType.allCases {
            let displayName = actionType.displayName
            XCTAssertFalse(displayName.isEmpty, "\(actionType) should have a non-empty displayName")
            XCTAssertGreaterThan(displayName.count, 0, "\(actionType) displayName should have characters")
        }
    }

    func testDisplayNameValues() {
        XCTAssertEqual(ActionType.implement.displayName, "Implement")
        XCTAssertEqual(ActionType.review.displayName, "Review")
        XCTAssertEqual(ActionType.integrationTest.displayName, "Integration Test")
        XCTAssertEqual(ActionType.write.displayName, "Write Docs")
        XCTAssertEqual(ActionType.custom.displayName, "Custom")
    }

    // MARK: - Icon Name Tests

    func testAllEnumCasesHaveValidIconName() {
        for actionType in ActionType.allCases {
            let iconName = actionType.iconName
            XCTAssertFalse(iconName.isEmpty, "\(actionType) should have a non-empty iconName")
            // SF Symbols typically have a dot separator
            XCTAssertTrue(iconName.contains(".") || iconName.count > 2,
                          "\(actionType) iconName should be a valid SF Symbol format")
        }
    }

    func testIconNameValues() {
        XCTAssertEqual(ActionType.implement.iconName, "hammer.fill")
        XCTAssertEqual(ActionType.review.iconName, "eye.fill")
        XCTAssertEqual(ActionType.integrationTest.iconName, "testtube.2")
        XCTAssertEqual(ActionType.write.iconName, "doc.text.fill")
        XCTAssertEqual(ActionType.custom.iconName, "gearshape.fill")
    }

    // MARK: - Required Skills Tests

    func testRequiredSkillsReturnsNonEmptyForKnownActions() {
        // All known actions except custom should have required skills
        let knownActions: [ActionType] = [.implement, .review, .integrationTest, .write]

        for actionType in knownActions {
            let skills = actionType.requiredSkills
            XCTAssertFalse(skills.isEmpty,
                           "\(actionType) should have non-empty requiredSkills")
        }
    }

    func testCustomActionHasEmptyRequiredSkills() {
        XCTAssertTrue(ActionType.custom.requiredSkills.isEmpty,
                      "Custom action should have empty requiredSkills (user-defined)")
    }

    func testRequiredSkillsValues() {
        XCTAssertEqual(ActionType.implement.requiredSkills, ["prd", "code-writer", "commit"])
        XCTAssertEqual(ActionType.review.requiredSkills, ["code-reviewer", "lint"])
        XCTAssertEqual(ActionType.integrationTest.requiredSkills, ["integration-test", "e2e-test", "perf-test"])
        XCTAssertEqual(ActionType.write.requiredSkills, ["doc-generator"])
    }

    // MARK: - Description Tests

    func testAllEnumCasesHaveValidDescription() {
        for actionType in ActionType.allCases {
            let description = actionType.description
            XCTAssertFalse(description.isEmpty, "\(actionType) should have a non-empty description")
            XCTAssertGreaterThan(description.count, 10, "\(actionType) description should be meaningful")
        }
    }

    // MARK: - Category Tests

    func testCategoryAssignment() {
        XCTAssertEqual(ActionType.implement.category, .dev)
        XCTAssertEqual(ActionType.review.category, .dev)
        XCTAssertEqual(ActionType.integrationTest.category, .qa)
        XCTAssertEqual(ActionType.write.category, .ops)
        XCTAssertEqual(ActionType.custom.category, .ops)
    }

    func testAllCategoriesHaveAtLeastOneAction() {
        for category in ActionCategory.allCases {
            let actionsInCategory = ActionType.allCases.filter { $0.category == category }
            XCTAssertFalse(actionsInCategory.isEmpty,
                           "Category \(category) should have at least one action")
        }
    }

    // MARK: - Unit Tests Flag Tests

    func testIncludesUnitTestsFlag() {
        XCTAssertTrue(ActionType.implement.includesUnitTests,
                      "Implement action should include unit tests")
        XCTAssertFalse(ActionType.review.includesUnitTests,
                       "Review action should not include unit tests")
        XCTAssertFalse(ActionType.integrationTest.includesUnitTests,
                       "IntegrationTest action should not include unit tests (it's for integration/e2e)")
        XCTAssertFalse(ActionType.write.includesUnitTests,
                       "Write action should not include unit tests")
        XCTAssertFalse(ActionType.custom.includesUnitTests,
                       "Custom action should not include unit tests by default")
    }

    // MARK: - Codable Tests

    func testActionTypeEncodingDecoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for actionType in ActionType.allCases {
            let data = try encoder.encode(actionType)
            let decoded = try decoder.decode(ActionType.self, from: data)
            XCTAssertEqual(decoded, actionType, "\(actionType) should survive encode/decode cycle")
        }
    }

    func testActionTypeDecodesFromRawString() throws {
        let decoder = JSONDecoder()

        let testCases: [(String, ActionType)] = [
            ("\"implement\"", .implement),
            ("\"review\"", .review),
            ("\"integrationTest\"", .integrationTest),
            ("\"write\"", .write),
            ("\"custom\"", .custom)
        ]

        for (jsonString, expected) in testCases {
            let data = jsonString.data(using: .utf8)!
            let decoded = try decoder.decode(ActionType.self, from: data)
            XCTAssertEqual(decoded, expected)
        }
    }

    // MARK: - CaseIterable Tests

    func testAllCasesCount() {
        XCTAssertEqual(ActionType.allCases.count, 5,
                       "ActionType should have exactly 5 cases")
    }

    // MARK: - ActionCategory Tests

    func testActionCategoryDisplayNames() {
        XCTAssertEqual(ActionCategory.dev.displayName, "Development")
        XCTAssertEqual(ActionCategory.qa.displayName, "Quality Assurance")
        XCTAssertEqual(ActionCategory.ops.displayName, "Operations")
    }

    func testActionCategoryCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for category in ActionCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(ActionCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }
}
