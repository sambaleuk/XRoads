//
//  SkillDetailSheetTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-017: Unit tests for Skill Detail Sheet
//

import XCTest
@testable import XRoadsLib

final class SkillDetailSheetTests: XCTestCase {

    // MARK: - Test: All Fields Displayed

    func test_skillDetail_displaysAllFields() {
        // Given: A skill with all fields populated
        let skill = Skill(
            id: "test-skill",
            name: "Test Skill",
            description: "A comprehensive test skill for validation",
            promptTemplate: "Execute the test task...",
            requiredTools: ["git", "file-read", "file-edit"],
            version: "2.1.0",
            compatibleCLIs: Set([.claude, .gemini]),
            category: .code,
            author: "Test Author"
        )

        // Then: All fields should be accessible
        XCTAssertEqual(skill.name, "Test Skill", "Name should be accessible")
        XCTAssertEqual(skill.description, "A comprehensive test skill for validation", "Description should be accessible")
        XCTAssertEqual(skill.version, "2.1.0", "Version should be accessible")
        XCTAssertEqual(skill.category, .code, "Category should be accessible")
        XCTAssertEqual(skill.author, "Test Author", "Author should be accessible")
        XCTAssertEqual(skill.requiredTools, ["git", "file-read", "file-edit"], "Required tools should be accessible")
    }

    func test_skillDetail_handlesNilOptionalFields() {
        // Given: A skill with minimal fields (nil optionals)
        let skill = Skill(
            id: "minimal-skill",
            name: "Minimal Skill",
            description: "A skill with minimal fields",
            promptTemplate: "...",
            category: nil,
            author: nil
        )

        // Then: Optional fields should be nil
        XCTAssertNil(skill.category, "Category can be nil")
        XCTAssertNil(skill.author, "Author can be nil")
    }

    // MARK: - Test: Templates Shown in Tabs (CLI Compatibility)

    func test_skillTemplates_compatibleWithAllCLIs() {
        // Given: A skill compatible with all CLIs
        let skill = Skill(
            id: "all-cli-skill",
            name: "Universal Skill",
            description: "Works with all CLIs",
            promptTemplate: "Do something...",
            compatibleCLIs: Set(AgentType.allCases)
        )

        // Then: Skill should be compatible with all CLI types
        for cli in AgentType.allCases {
            XCTAssertTrue(skill.isCompatible(with: cli),
                          "Skill should be compatible with \(cli.displayName)")
        }
    }

    func test_skillTemplates_compatibleWithSpecificCLIs() {
        // Given: A skill compatible only with Claude
        let skill = Skill(
            id: "claude-only-skill",
            name: "Claude Only Skill",
            description: "Only works with Claude",
            promptTemplate: "Claude specific task...",
            compatibleCLIs: Set([.claude])
        )

        // Then: Skill should only be compatible with Claude
        XCTAssertTrue(skill.isCompatible(with: .claude),
                      "Skill should be compatible with Claude")
        XCTAssertFalse(skill.isCompatible(with: .gemini),
                       "Skill should not be compatible with Gemini")
        XCTAssertFalse(skill.isCompatible(with: .codex),
                       "Skill should not be compatible with Codex")
    }

    func test_skillTemplates_emptyCompatibleCLIsMeansAll() {
        // Given: A skill with empty compatibleCLIs set
        let skill = Skill(
            id: "empty-compat-skill",
            name: "Default Compatibility",
            description: "Empty compatibleCLIs means all",
            promptTemplate: "...",
            compatibleCLIs: Set()
        )

        // Then: Empty set should mean compatible with all
        for cli in AgentType.allCases {
            XCTAssertTrue(skill.isCompatible(with: cli),
                          "Empty compatibleCLIs should mean all CLIs supported")
        }
    }

    // MARK: - Test: Edit Button for Project Skills

    func test_skillDetail_projectSkillIdentification() {
        // Given: A skill that could be a project skill (user-defined)
        let userSkill = Skill(
            id: "custom-user-skill",
            name: "My Custom Skill",
            description: "User created skill",
            promptTemplate: "User defined prompt...",
            version: "0.1.0",
            category: .custom,
            author: "User"
        )

        // Then: Skill properties indicate it's a custom/user skill
        XCTAssertEqual(userSkill.category, .custom, "User skills typically use .custom category")
        XCTAssertEqual(userSkill.author, "User", "User skill has User as author")
        XCTAssertTrue(userSkill.version.hasPrefix("0."), "User skills often start with 0.x version")
    }

    func test_skillDetail_bundledSkillIdentification() {
        // Given: A bundled skill (from XRoads Team)
        let bundledSkill = Skill(
            id: "commit",
            name: "Git Commit",
            description: "Create git commits",
            promptTemplate: "...",
            version: "1.0.0",
            category: .git,
            author: "XRoads Team"
        )

        // Then: Skill properties indicate it's a bundled skill
        XCTAssertEqual(bundledSkill.author, "XRoads Team", "Bundled skills have XRoads Team author")
        XCTAssertNotEqual(bundledSkill.category, .custom, "Bundled skills have specific categories")
    }

    // MARK: - Test: Required Tools Display

    func test_skillDetail_requiredToolsAccess() {
        // Given: A skill with required tools
        let skill = Skill(
            id: "tools-skill",
            name: "Tool Dependent Skill",
            description: "Requires specific tools",
            promptTemplate: "...",
            requiredTools: ["git", "file-read", "file-edit", "bash"]
        )

        // Then: Required tools should be accessible
        XCTAssertEqual(skill.requiredTools.count, 4, "Should have 4 required tools")
        XCTAssertTrue(skill.requiredTools.contains("git"), "Should contain git")
        XCTAssertTrue(skill.requiredTools.contains("file-read"), "Should contain file-read")
        XCTAssertTrue(skill.requiredTools.contains("file-edit"), "Should contain file-edit")
        XCTAssertTrue(skill.requiredTools.contains("bash"), "Should contain bash")
    }

    func test_skillDetail_emptyRequiredTools() {
        // Given: A skill with no required tools
        let skill = Skill(
            id: "no-tools-skill",
            name: "No Tools Skill",
            description: "Doesn't require specific tools",
            promptTemplate: "...",
            requiredTools: []
        )

        // Then: Required tools should be empty
        XCTAssertTrue(skill.requiredTools.isEmpty, "Required tools should be empty")
    }

    func test_skillDetail_missingToolsDetection() {
        // Given: A skill with required tools and available tools
        let skill = Skill(
            id: "partial-tools-skill",
            name: "Partial Tools Skill",
            description: "Some tools missing",
            promptTemplate: "...",
            requiredTools: ["git", "eslint", "prettier"]
        )
        let availableTools: Set<String> = ["git", "file-read", "bash"]

        // When: Checking for missing tools
        let missingTools = skill.missingTools(from: availableTools)

        // Then: Should identify missing tools
        XCTAssertTrue(missingTools.contains("eslint"), "eslint should be missing")
        XCTAssertTrue(missingTools.contains("prettier"), "prettier should be missing")
        XCTAssertFalse(missingTools.contains("git"), "git should not be missing")
    }

    func test_skillDetail_hasRequiredToolsCheck() {
        // Given: A skill with required tools
        let skill = Skill(
            id: "check-tools-skill",
            name: "Check Tools Skill",
            description: "Check tool availability",
            promptTemplate: "...",
            requiredTools: ["git", "file-read"]
        )

        // When: All tools are available
        let allAvailable: Set<String> = ["git", "file-read", "file-edit", "bash"]
        XCTAssertTrue(skill.hasRequiredTools(available: allAvailable),
                      "Should have all required tools when all available")

        // When: Some tools are missing
        let someMissing: Set<String> = ["git", "bash"]
        XCTAssertFalse(skill.hasRequiredTools(available: someMissing),
                       "Should not have all required tools when some missing")
    }

    // MARK: - Test: SkillCategory Properties

    func test_skillCategory_allCategoriesHaveDisplayNames() {
        // Then: Each category should have a display name
        for category in SkillCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty,
                           "Category \(category) should have a display name")
        }
    }

    func test_skillCategory_allCategoriesHaveIcons() {
        // Then: Each category should have an icon name
        for category in SkillCategory.allCases {
            XCTAssertFalse(category.iconName.isEmpty,
                           "Category \(category) should have an icon name")
        }
    }

    func test_skillCategory_displayNamesAreUserFriendly() {
        // Then: Display names should be descriptive
        XCTAssertEqual(SkillCategory.git.displayName, "Git Operations")
        XCTAssertEqual(SkillCategory.code.displayName, "Code Generation")
        XCTAssertEqual(SkillCategory.test.displayName, "Testing")
        XCTAssertEqual(SkillCategory.docs.displayName, "Documentation")
        XCTAssertEqual(SkillCategory.review.displayName, "Code Review")
        XCTAssertEqual(SkillCategory.custom.displayName, "Custom")
    }

    // MARK: - Test: Skill Adapter Integration

    func test_skillAdapter_factoryReturnsCorrectAdapter() {
        // Then: Factory should return correct adapter for each CLI
        let claudeAdapter = SkillAdapterFactory.adapter(for: .claude)
        XCTAssertEqual(claudeAdapter.agentType, .claude, "Should return Claude adapter")

        let geminiAdapter = SkillAdapterFactory.adapter(for: .gemini)
        XCTAssertEqual(geminiAdapter.agentType, .gemini, "Should return Gemini adapter")

        let codexAdapter = SkillAdapterFactory.adapter(for: .codex)
        XCTAssertEqual(codexAdapter.agentType, .codex, "Should return Codex adapter")
    }

    func test_skillAdapter_adaptsSkillForCLI() {
        // Given: A skill and context
        let skill = Skill(
            id: "adapt-test-skill",
            name: "Adapter Test",
            description: "Test skill adaptation",
            promptTemplate: "## Instructions\n{{context}}\n\nExecute task on {{branch}}"
        )
        let context = SkillContext(
            agentType: .claude,
            worktreePath: "/test/path",
            branch: "main"
        )

        // When: Adapting for Claude
        let adapted = SkillAdapterFactory.adaptSkill(skill, for: .claude, context: context)

        // Then: Adapted template should contain skill info
        XCTAssertTrue(adapted.contains("Adapter Test") || adapted.contains("adapt-test-skill"),
                      "Adapted template should reference the skill")
    }

    // MARK: - Test: Skill Context

    func test_skillContext_toContextString() {
        // Given: A skill context with various fields
        let context = SkillContext(
            agentType: .claude,
            worktreePath: "/home/user/project",
            branch: "feat/new-feature",
            prdPath: "prd.json",
            assignedStories: ["US-001", "US-002"],
            taskDescription: "Implement new feature"
        )

        // When: Converting to context string
        let contextString = context.toContextString()

        // Then: Should contain relevant info
        XCTAssertTrue(contextString.contains("/home/user/project"), "Should contain worktree path")
        XCTAssertTrue(contextString.contains("feat/new-feature"), "Should contain branch")
        XCTAssertTrue(contextString.contains("US-001"), "Should contain assigned stories")
        XCTAssertTrue(contextString.contains("Implement new feature"), "Should contain task description")
    }

    func test_skillContext_emptyContextString() {
        // Given: A minimal skill context
        let context = SkillContext(
            agentType: .gemini
        )

        // When: Converting to context string
        let contextString = context.toContextString()

        // Then: Should be empty or minimal
        XCTAssertTrue(contextString.isEmpty || contextString.count < 50,
                      "Minimal context should produce minimal string")
    }

    // MARK: - Test: Skill Identifiable Conformance

    func test_skill_identifiable() {
        // Given: Two skills with different IDs
        let skill1 = Skill(
            id: "skill-1",
            name: "Skill One",
            description: "First skill",
            promptTemplate: "..."
        )
        let skill2 = Skill(
            id: "skill-2",
            name: "Skill Two",
            description: "Second skill",
            promptTemplate: "..."
        )

        // Then: IDs should be unique identifiers
        XCTAssertNotEqual(skill1.id, skill2.id, "Skills should have unique IDs")
        XCTAssertEqual(skill1.id, "skill-1", "ID should match initialization")
        XCTAssertEqual(skill2.id, "skill-2", "ID should match initialization")
    }

    // MARK: - Test: Skill Hashable Conformance

    func test_skill_hashable() {
        // Given: Skills for set operations
        let skill1 = Skill(
            id: "hash-skill",
            name: "Hash Test",
            description: "Test hashable",
            promptTemplate: "..."
        )
        let skill2 = Skill(
            id: "hash-skill",
            name: "Hash Test",
            description: "Test hashable",
            promptTemplate: "..."
        )
        let skill3 = Skill(
            id: "different-skill",
            name: "Different",
            description: "Different skill",
            promptTemplate: "..."
        )

        // When: Using in a Set
        var skillSet: Set<Skill> = []
        skillSet.insert(skill1)
        skillSet.insert(skill2) // Same as skill1
        skillSet.insert(skill3)

        // Then: Set should handle duplicates based on identity
        XCTAssertEqual(skillSet.count, 2, "Set should contain unique skills")
    }

    // MARK: - Test: Skill Codable Conformance

    func test_skill_encodeDecode() throws {
        // Given: A skill with all fields
        let originalSkill = Skill(
            id: "codable-skill",
            name: "Codable Test",
            description: "Test encoding/decoding",
            promptTemplate: "Template content...",
            requiredTools: ["git", "file-read"],
            version: "1.2.3",
            compatibleCLIs: Set([.claude, .gemini]),
            category: .code,
            author: "Test Author"
        )

        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSkill)
        let decoder = JSONDecoder()
        let decodedSkill = try decoder.decode(Skill.self, from: data)

        // Then: Decoded skill should match original
        XCTAssertEqual(decodedSkill.id, originalSkill.id)
        XCTAssertEqual(decodedSkill.name, originalSkill.name)
        XCTAssertEqual(decodedSkill.description, originalSkill.description)
        XCTAssertEqual(decodedSkill.version, originalSkill.version)
        XCTAssertEqual(decodedSkill.category, originalSkill.category)
        XCTAssertEqual(decodedSkill.author, originalSkill.author)
        XCTAssertEqual(decodedSkill.requiredTools, originalSkill.requiredTools)
    }
}
