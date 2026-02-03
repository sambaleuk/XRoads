import XCTest
@testable import XRoads

final class SkillTests: XCTestCase {

    // MARK: - Skill Initialization Tests

    func testSkillInitializationWithAllParameters() {
        let skill = Skill(
            id: "test-skill",
            name: "Test Skill",
            description: "A test skill",
            promptTemplate: "Test {{context}}",
            requiredTools: ["tool1", "tool2"],
            version: "2.0.0",
            compatibleCLIs: [.claude, .gemini],
            category: .code,
            author: "Test Author"
        )

        XCTAssertEqual(skill.id, "test-skill")
        XCTAssertEqual(skill.name, "Test Skill")
        XCTAssertEqual(skill.description, "A test skill")
        XCTAssertEqual(skill.promptTemplate, "Test {{context}}")
        XCTAssertEqual(skill.requiredTools, ["tool1", "tool2"])
        XCTAssertEqual(skill.version, "2.0.0")
        XCTAssertEqual(skill.compatibleCLIs, [.claude, .gemini])
        XCTAssertEqual(skill.category, .code)
        XCTAssertEqual(skill.author, "Test Author")
    }

    func testSkillInitializationWithDefaults() {
        let skill = Skill(
            id: "minimal-skill",
            name: "Minimal",
            description: "Minimal skill",
            promptTemplate: "Template"
        )

        XCTAssertEqual(skill.id, "minimal-skill")
        XCTAssertEqual(skill.requiredTools, [])
        XCTAssertEqual(skill.version, "1.0.0")
        XCTAssertEqual(skill.compatibleCLIs, Set(AgentType.allCases))
        XCTAssertNil(skill.category)
        XCTAssertNil(skill.author)
    }

    // MARK: - Codable Tests

    func testSkillCodableEncodeDecode() throws {
        let skill = Skill(
            id: "codable-test",
            name: "Codable Test",
            description: "Testing Codable",
            promptTemplate: "Template {{context}}",
            requiredTools: ["git", "file-edit"],
            version: "1.2.3",
            compatibleCLIs: [.claude],
            category: .git,
            author: "XRoads"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(skill)
        let decoded = try decoder.decode(Skill.self, from: data)

        XCTAssertEqual(decoded.id, skill.id)
        XCTAssertEqual(decoded.name, skill.name)
        XCTAssertEqual(decoded.description, skill.description)
        XCTAssertEqual(decoded.promptTemplate, skill.promptTemplate)
        XCTAssertEqual(decoded.requiredTools, skill.requiredTools)
        XCTAssertEqual(decoded.version, skill.version)
        XCTAssertEqual(decoded.compatibleCLIs, skill.compatibleCLIs)
        XCTAssertEqual(decoded.category, skill.category)
        XCTAssertEqual(decoded.author, skill.author)
    }

    func testSkillCodableWithNilOptionals() throws {
        let skill = Skill(
            id: "nil-optionals",
            name: "Nil Optionals",
            description: "Test nil optionals",
            promptTemplate: "Template"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(skill)
        let decoded = try decoder.decode(Skill.self, from: data)

        XCTAssertNil(decoded.category)
        XCTAssertNil(decoded.author)
    }

    // MARK: - CLI Compatibility Tests

    func testIsCompatibleWithAllCLIs() {
        let skill = Skill(
            id: "all-cli",
            name: "All CLI",
            description: "Compatible with all",
            promptTemplate: "Template",
            compatibleCLIs: Set(AgentType.allCases)
        )

        for cliType in AgentType.allCases {
            XCTAssertTrue(skill.isCompatible(with: cliType),
                          "Skill should be compatible with \(cliType)")
        }
    }

    func testIsCompatibleWithEmptyCLIs() {
        // Empty compatibleCLIs means compatible with all
        let skill = Skill(
            id: "empty-cli",
            name: "Empty CLI",
            description: "Empty means all",
            promptTemplate: "Template",
            compatibleCLIs: []
        )

        for cliType in AgentType.allCases {
            XCTAssertTrue(skill.isCompatible(with: cliType),
                          "Skill with empty CLIs should be compatible with \(cliType)")
        }
    }

    func testIsCompatibleWithSpecificCLI() {
        let skill = Skill(
            id: "claude-only",
            name: "Claude Only",
            description: "Only Claude",
            promptTemplate: "Template",
            compatibleCLIs: [.claude]
        )

        XCTAssertTrue(skill.isCompatible(with: .claude))
        XCTAssertFalse(skill.isCompatible(with: .gemini))
        XCTAssertFalse(skill.isCompatible(with: .codex))
    }

    func testIsCompatibleWithMultipleCLIs() {
        let skill = Skill(
            id: "multi-cli",
            name: "Multi CLI",
            description: "Claude and Gemini",
            promptTemplate: "Template",
            compatibleCLIs: [.claude, .gemini]
        )

        XCTAssertTrue(skill.isCompatible(with: .claude))
        XCTAssertTrue(skill.isCompatible(with: .gemini))
        XCTAssertFalse(skill.isCompatible(with: .codex))
    }

    // MARK: - Required Tools Tests

    func testHasRequiredToolsWithAllAvailable() {
        let skill = Skill(
            id: "tools-test",
            name: "Tools Test",
            description: "Test tools",
            promptTemplate: "Template",
            requiredTools: ["git", "file-edit"]
        )

        let availableTools: Set<String> = ["git", "file-edit", "file-read"]
        XCTAssertTrue(skill.hasRequiredTools(available: availableTools))
    }

    func testHasRequiredToolsWithMissing() {
        let skill = Skill(
            id: "tools-test",
            name: "Tools Test",
            description: "Test tools",
            promptTemplate: "Template",
            requiredTools: ["git", "file-edit", "special-tool"]
        )

        let availableTools: Set<String> = ["git", "file-edit"]
        XCTAssertFalse(skill.hasRequiredTools(available: availableTools))
    }

    func testHasRequiredToolsWithEmptyRequired() {
        let skill = Skill(
            id: "no-tools",
            name: "No Tools",
            description: "No tools required",
            promptTemplate: "Template",
            requiredTools: []
        )

        XCTAssertTrue(skill.hasRequiredTools(available: []))
        XCTAssertTrue(skill.hasRequiredTools(available: ["git"]))
    }

    func testMissingToolsReturnsCorrectList() {
        let skill = Skill(
            id: "missing-test",
            name: "Missing Test",
            description: "Test missing",
            promptTemplate: "Template",
            requiredTools: ["git", "special-tool", "another-tool"]
        )

        let availableTools: Set<String> = ["git"]
        let missing = skill.missingTools(from: availableTools)

        XCTAssertEqual(missing.count, 2)
        XCTAssertTrue(missing.contains("special-tool"))
        XCTAssertTrue(missing.contains("another-tool"))
    }

    func testMissingToolsReturnsEmptyWhenAllAvailable() {
        let skill = Skill(
            id: "all-available",
            name: "All Available",
            description: "Test",
            promptTemplate: "Template",
            requiredTools: ["git", "file-edit"]
        )

        let availableTools: Set<String> = ["git", "file-edit", "extra"]
        let missing = skill.missingTools(from: availableTools)

        XCTAssertTrue(missing.isEmpty)
    }

    // MARK: - Hashable & Equatable Tests

    func testSkillHashable() {
        let skill1 = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            promptTemplate: "Template"
        )
        let skill2 = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            promptTemplate: "Template"
        )

        var skillSet: Set<Skill> = []
        skillSet.insert(skill1)
        skillSet.insert(skill2)

        XCTAssertEqual(skillSet.count, 1, "Identical skills should hash to same value")
    }

    func testSkillEquatable() {
        let skill1 = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            promptTemplate: "Template"
        )
        let skill2 = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            promptTemplate: "Template"
        )
        let skill3 = Skill(
            id: "different",
            name: "Test",
            description: "Test",
            promptTemplate: "Template"
        )

        XCTAssertEqual(skill1, skill2)
        XCTAssertNotEqual(skill1, skill3)
    }

    // MARK: - Identifiable Tests

    func testSkillIdentifiable() {
        let skill = Skill(
            id: "identifiable-test",
            name: "Test",
            description: "Test",
            promptTemplate: "Template"
        )

        XCTAssertEqual(skill.id, "identifiable-test")
    }
}

// MARK: - SkillCategory Tests

final class SkillCategoryTests: XCTestCase {

    func testAllCategoriesHaveDisplayName() {
        for category in SkillCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty,
                          "\(category) should have a non-empty displayName")
        }
    }

    func testAllCategoriesHaveIconName() {
        for category in SkillCategory.allCases {
            XCTAssertFalse(category.iconName.isEmpty,
                          "\(category) should have a non-empty iconName")
        }
    }

    func testCategoryDisplayNameValues() {
        XCTAssertEqual(SkillCategory.git.displayName, "Git Operations")
        XCTAssertEqual(SkillCategory.code.displayName, "Code Generation")
        XCTAssertEqual(SkillCategory.test.displayName, "Testing")
        XCTAssertEqual(SkillCategory.docs.displayName, "Documentation")
        XCTAssertEqual(SkillCategory.review.displayName, "Code Review")
        XCTAssertEqual(SkillCategory.custom.displayName, "Custom")
    }

    func testCategoryCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for category in SkillCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(SkillCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }
}

// MARK: - SkillFile Tests

final class SkillFileTests: XCTestCase {

    func testSkillFileToSkillConversion() {
        let skillFile = SkillFile(
            id: "test-skill",
            name: "Test Skill",
            description: "A test skill",
            promptTemplate: "Test {{context}}",
            requiredTools: ["git"],
            version: "1.0.0",
            compatibleCLIs: ["claude", "gemini"],
            category: "git",
            author: "Test"
        )

        let skill = skillFile.toSkill()

        XCTAssertEqual(skill.id, "test-skill")
        XCTAssertEqual(skill.name, "Test Skill")
        XCTAssertEqual(skill.requiredTools, ["git"])
        XCTAssertEqual(skill.version, "1.0.0")
        XCTAssertEqual(skill.compatibleCLIs, [.claude, .gemini])
        XCTAssertEqual(skill.category, .git)
        XCTAssertEqual(skill.author, "Test")
    }

    func testSkillFileToSkillWithNilOptionals() {
        let skillFile = SkillFile(
            id: "minimal",
            name: "Minimal",
            description: "Minimal skill",
            promptTemplate: "Template",
            requiredTools: nil,
            version: nil,
            compatibleCLIs: nil,
            category: nil,
            author: nil
        )

        let skill = skillFile.toSkill()

        XCTAssertEqual(skill.id, "minimal")
        XCTAssertEqual(skill.requiredTools, [])
        XCTAssertEqual(skill.version, "1.0.0")
        XCTAssertEqual(skill.compatibleCLIs, Set(AgentType.allCases))
        XCTAssertNil(skill.category)
        XCTAssertNil(skill.author)
    }

    func testSkillFileIgnoresInvalidCLIs() {
        let skillFile = SkillFile(
            id: "invalid-cli",
            name: "Invalid CLI",
            description: "Test",
            promptTemplate: "Template",
            requiredTools: nil,
            version: nil,
            compatibleCLIs: ["claude", "invalid", "gemini"],
            category: nil,
            author: nil
        )

        let skill = skillFile.toSkill()

        // Should only contain valid CLIs
        XCTAssertEqual(skill.compatibleCLIs, [.claude, .gemini])
    }

    func testSkillFileIgnoresInvalidCategory() {
        let skillFile = SkillFile(
            id: "invalid-cat",
            name: "Invalid Category",
            description: "Test",
            promptTemplate: "Template",
            requiredTools: nil,
            version: nil,
            compatibleCLIs: nil,
            category: "invalid-category",
            author: nil
        )

        let skill = skillFile.toSkill()

        XCTAssertNil(skill.category)
    }

    func testSkillFileDecodableFromJSON() throws {
        let json = """
        {
            "id": "json-skill",
            "name": "JSON Skill",
            "description": "Loaded from JSON",
            "promptTemplate": "Template {{context}}",
            "requiredTools": ["git", "file-edit"],
            "version": "2.0.0",
            "compatibleCLIs": ["claude"],
            "category": "code",
            "author": "XRoads"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let skillFile = try decoder.decode(SkillFile.self, from: data)

        XCTAssertEqual(skillFile.id, "json-skill")
        XCTAssertEqual(skillFile.name, "JSON Skill")
        XCTAssertEqual(skillFile.requiredTools, ["git", "file-edit"])
        XCTAssertEqual(skillFile.compatibleCLIs, ["claude"])
    }
}

// MARK: - SkillLoadError Tests

final class SkillLoadErrorTests: XCTestCase {

    func testErrorDescriptions() {
        let fileNotFound = SkillLoadError.fileNotFound(path: "/test/path.json")
        XCTAssertTrue(fileNotFound.errorDescription?.contains("/test/path.json") ?? false)

        let invalidJSON = SkillLoadError.invalidJSON(
            path: "/test/skill.json",
            underlyingError: NSError(domain: "Test", code: 1)
        )
        XCTAssertTrue(invalidJSON.errorDescription?.contains("/test/skill.json") ?? false)

        let invalidFormat = SkillLoadError.invalidSkillFormat(
            path: "/test/bad.json",
            reason: "Missing id"
        )
        XCTAssertTrue(invalidFormat.errorDescription?.contains("Missing id") ?? false)

        let duplicate = SkillLoadError.duplicateSkillID(id: "test-id")
        XCTAssertTrue(duplicate.errorDescription?.contains("test-id") ?? false)

        let dirNotFound = SkillLoadError.directoryNotFound(path: "/test/dir")
        XCTAssertTrue(dirNotFound.errorDescription?.contains("/test/dir") ?? false)
    }
}
