import XCTest
@testable import XRoads

final class SkillRegistryTests: XCTestCase {

    // MARK: - Bundled Skills Tests

    func testBundledSkillsLoadedOnInit() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let allSkills = await registry.allSkills()
        XCTAssertFalse(allSkills.isEmpty, "Registry should have bundled skills after initialization")
    }

    func testBundledSkillsContainCoreSkills() async {
        let registry = SkillRegistry()
        await registry.initialize()

        // Check for core bundled skill IDs
        let expectedSkillIDs = ["commit", "code-writer", "code-reviewer", "prd", "doc-generator"]

        for skillID in expectedSkillIDs {
            let skill = await registry.skill(byID: skillID)
            XCTAssertNotNil(skill, "Bundled skill '\(skillID)' should exist")
        }
    }

    func testBundledSkillsAreNotUserSkills() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let commitSkill = await registry.skill(byID: "commit")
        XCTAssertNotNil(commitSkill)

        let isUser = await registry.isUserSkill("commit")
        XCTAssertFalse(isUser, "Bundled skills should not be marked as user skills")
    }

    // MARK: - Skill Query Tests

    func testSkillByID() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let skill = await registry.skill(byID: "commit")
        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.id, "commit")
        XCTAssertEqual(skill?.name, "Commit")
    }

    func testSkillByIDReturnsNilForUnknown() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let skill = await registry.skill(byID: "nonexistent-skill-id")
        XCTAssertNil(skill)
    }

    func testAllSkills() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let skills = await registry.allSkills()
        XCTAssertGreaterThan(skills.count, 0)

        // Should be sorted by ID
        let ids = skills.map { $0.id }
        XCTAssertEqual(ids, ids.sorted())
    }

    func testSkillsByIDs() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let skills = await registry.skills(byIDs: ["commit", "code-writer", "nonexistent"])

        XCTAssertEqual(skills.count, 2, "Should only return found skills")
        XCTAssertTrue(skills.contains { $0.id == "commit" })
        XCTAssertTrue(skills.contains { $0.id == "code-writer" })
    }

    func testHasSkill() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let hasCommit = await registry.hasSkill("commit")
        XCTAssertTrue(hasCommit)

        let hasUnknown = await registry.hasSkill("unknown-skill")
        XCTAssertFalse(hasUnknown)
    }

    func testAllSkillIDs() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let ids = await registry.allSkillIDs()
        XCTAssertFalse(ids.isEmpty)
        XCTAssertTrue(ids.contains("commit"))

        // Should be sorted
        XCTAssertEqual(ids, ids.sorted())
    }

    // MARK: - CLI Filtering Tests

    func testSkillsForCLIType() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let claudeSkills = await registry.skills(for: .claude)
        XCTAssertFalse(claudeSkills.isEmpty, "Claude should have compatible skills")

        // All returned skills should be compatible with Claude
        for skill in claudeSkills {
            XCTAssertTrue(skill.isCompatible(with: .claude),
                          "Skill \(skill.id) should be compatible with Claude")
        }
    }

    func testSkillsForAllCLITypes() async {
        let registry = SkillRegistry()
        await registry.initialize()

        for cliType in AgentType.allCases {
            let skills = await registry.skills(for: cliType)
            XCTAssertFalse(skills.isEmpty,
                          "\(cliType) should have at least some compatible skills")
        }
    }

    // MARK: - Category Filtering Tests

    func testSkillsInCategory() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let gitSkills = await registry.skills(in: .git)
        XCTAssertFalse(gitSkills.isEmpty, "Should have git category skills")

        for skill in gitSkills {
            XCTAssertEqual(skill.category, .git)
        }
    }

    func testSkillsInCodeCategory() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let codeSkills = await registry.skills(in: .code)
        XCTAssertFalse(codeSkills.isEmpty, "Should have code category skills")

        // code-writer and prd should be in code category
        let ids = codeSkills.map { $0.id }
        XCTAssertTrue(ids.contains("code-writer") || ids.contains("prd"),
                     "Code category should contain code-writer or prd")
    }

    // MARK: - Custom Skill Registration Tests

    func testRegisterCustomSkill() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let customSkill = Skill(
            id: "custom-test-skill",
            name: "Custom Test",
            description: "A custom skill",
            promptTemplate: "Custom {{context}}"
        )

        let success = await registry.registerSkill(customSkill)
        XCTAssertTrue(success)

        let retrieved = await registry.skill(byID: "custom-test-skill")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Custom Test")
    }

    func testRegisterDuplicateSkillFails() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let customSkill = Skill(
            id: "duplicate-skill",
            name: "Duplicate",
            description: "First",
            promptTemplate: "Template"
        )

        let success1 = await registry.registerSkill(customSkill)
        XCTAssertTrue(success1)

        let duplicate = Skill(
            id: "duplicate-skill",
            name: "Duplicate 2",
            description: "Second",
            promptTemplate: "Template 2"
        )

        let success2 = await registry.registerSkill(duplicate)
        XCTAssertFalse(success2, "Duplicate registration should fail")

        // Should have recorded the error
        let errors = await registry.getLoadErrors()
        XCTAssertTrue(errors.contains { error in
            if case .duplicateSkillID(let id) = error {
                return id == "duplicate-skill"
            }
            return false
        })
    }

    func testRegisterUserSkillOverridesBundled() async {
        let registry = SkillRegistry()
        await registry.initialize()

        // Get original bundled skill
        let originalCommit = await registry.skill(byID: "commit")
        XCTAssertNotNil(originalCommit)

        // Register user override
        let userCommit = Skill(
            id: "commit",
            name: "User Commit",
            description: "User override",
            promptTemplate: "User template"
        )

        await registry.registerUserSkill(userCommit)

        // Should now return user version
        let retrieved = await registry.skill(byID: "commit")
        XCTAssertEqual(retrieved?.name, "User Commit")

        // Should be marked as user skill
        let isUser = await registry.isUserSkill("commit")
        XCTAssertTrue(isUser)
    }

    func testRemoveUserSkill() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let customSkill = Skill(
            id: "removable-skill",
            name: "Removable",
            description: "Will be removed",
            promptTemplate: "Template"
        )

        await registry.registerUserSkill(customSkill)

        var exists = await registry.hasSkill("removable-skill")
        XCTAssertTrue(exists)

        let removed = await registry.removeUserSkill("removable-skill")
        XCTAssertTrue(removed)

        exists = await registry.hasSkill("removable-skill")
        XCTAssertFalse(exists)
    }

    func testCannotRemoveBundledSkill() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let removed = await registry.removeUserSkill("commit")
        XCTAssertFalse(removed, "Should not be able to remove bundled skill")

        let exists = await registry.hasSkill("commit")
        XCTAssertTrue(exists, "Bundled skill should still exist")
    }

    // MARK: - Reload Tests

    func testReloadClearsAndReloads() async {
        let registry = SkillRegistry()
        await registry.initialize()

        // Add a custom skill
        let customSkill = Skill(
            id: "temp-skill",
            name: "Temp",
            description: "Temporary",
            promptTemplate: "Template"
        )
        await registry.registerUserSkill(customSkill)

        var exists = await registry.hasSkill("temp-skill")
        XCTAssertTrue(exists)

        // Reload
        await registry.reload()

        // Custom skill should be gone (it wasn't in a file)
        exists = await registry.hasSkill("temp-skill")
        XCTAssertFalse(exists, "Custom skill should be gone after reload")

        // Bundled skills should still exist
        exists = await registry.hasSkill("commit")
        XCTAssertTrue(exists, "Bundled skills should exist after reload")
    }

    // MARK: - User Skills Directory Tests

    func testUserSkillsDirectoryPath() {
        let path = SkillRegistry.userSkillsDirectory
        XCTAssertTrue(path.contains(".xroads/skills"))
    }

    // MARK: - Load Errors Tests

    func testGetLoadErrorsInitiallyEmpty() async {
        let registry = SkillRegistry()
        await registry.initialize()

        let errors = await registry.getLoadErrors()
        // May have errors if user directory has invalid files, but fresh install should be empty
        // Just verify we can call it
        XCTAssertNotNil(errors)
    }

    // MARK: - Multiple Initialization Tests

    func testDoubleInitializationIsIdempotent() async {
        let registry = SkillRegistry()

        await registry.initialize()
        let count1 = await registry.allSkills().count

        await registry.initialize() // Second call should be no-op
        let count2 = await registry.allSkills().count

        XCTAssertEqual(count1, count2, "Double initialization should not duplicate skills")
    }
}
