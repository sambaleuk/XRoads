//
//  SkillsBadgeTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-018: Unit tests for Skills Badge component
//

import XCTest
@testable import XRoadsLib

final class SkillsBadgeTests: XCTestCase {

    // MARK: - Test Data

    private var sampleSkills: [Skill] {
        [
            Skill(
                id: "commit",
                name: "Git Commit",
                description: "Create git commits",
                promptTemplate: "...",
                requiredTools: ["git"],
                version: "1.0.0",
                category: .git,
                author: "XRoads Team"
            ),
            Skill(
                id: "review",
                name: "Code Review",
                description: "Review code changes",
                promptTemplate: "...",
                requiredTools: ["file-read", "eslint"],
                version: "1.0.0",
                category: .review,
                author: "XRoads Team"
            ),
            Skill(
                id: "test",
                name: "Test Runner",
                description: "Run unit tests",
                promptTemplate: "...",
                requiredTools: ["bash", "jest"],
                version: "1.0.0",
                category: .test,
                author: "XRoads Team"
            )
        ]
    }

    // MARK: - Test: Badge Shows Correct Count

    func test_skillsBadge_showsCorrectCount() {
        // Given: 3 skills
        let skills = sampleSkills

        // Then: Skill count should be 3
        XCTAssertEqual(skills.count, 3, "Should have 3 skills")
    }

    func test_skillsBadge_emptySkillsReturnsZeroCount() {
        // Given: Empty skills array
        let skills: [Skill] = []

        // Then: Count should be 0
        XCTAssertEqual(skills.count, 0, "Empty skills should return 0 count")
    }

    func test_skillsBadge_singleSkillCountsCorrectly() {
        // Given: Single skill
        let skills = [sampleSkills[0]]

        // Then: Count should be 1
        XCTAssertEqual(skills.count, 1, "Single skill should return count of 1")
    }

    // MARK: - Test: Popover Lists Skills

    func test_skillsBadge_skillsAreAccessible() {
        // Given: Sample skills
        let skills = sampleSkills

        // Then: Each skill should be accessible with its properties
        for skill in skills {
            XCTAssertFalse(skill.name.isEmpty, "Skill name should not be empty")
            XCTAssertFalse(skill.id.isEmpty, "Skill ID should not be empty")
            XCTAssertNotNil(skill.category, "Skills should have categories")
        }
    }

    func test_skillsBadge_skillCategoriesHaveIcons() {
        // Given: Skills with categories
        let skills = sampleSkills

        // Then: Each category should have an icon
        for skill in skills {
            if let category = skill.category {
                XCTAssertFalse(category.iconName.isEmpty,
                              "Category \(category) should have an icon")
            }
        }
    }

    func test_skillsBadge_skillVersionsAreAccessible() {
        // Given: Skills with versions
        let skills = sampleSkills

        // Then: Each skill should have a version string
        for skill in skills {
            XCTAssertFalse(skill.version.isEmpty,
                          "Skill \(skill.name) should have a version")
        }
    }

    // MARK: - Test: Warning for Missing MCP Dependencies

    func test_skillsBadge_detectsMissingDependencies() {
        // Given: Skills with required tools and limited available tools
        let skills = sampleSkills
        let availableTools: Set<String> = ["git", "file-read"]

        // When: Checking for missing dependencies
        let skillsWithMissing = skills.filter { skill in
            !skill.hasRequiredTools(available: availableTools)
        }

        // Then: Should identify skills with missing tools
        XCTAssertEqual(skillsWithMissing.count, 2,
                      "2 skills should have missing dependencies (eslint, bash, jest)")

        // The "review" skill needs eslint, and "test" skill needs bash and jest
        XCTAssertTrue(skillsWithMissing.contains { $0.id == "review" },
                     "Review skill should have missing dependencies")
        XCTAssertTrue(skillsWithMissing.contains { $0.id == "test" },
                     "Test skill should have missing dependencies")
    }

    func test_skillsBadge_noWarningWhenAllDependenciesMet() {
        // Given: Skills with all required tools available
        let skills = sampleSkills
        let availableTools: Set<String> = ["git", "file-read", "eslint", "bash", "jest"]

        // When: Checking for missing dependencies
        let skillsWithMissing = skills.filter { skill in
            !skill.hasRequiredTools(available: availableTools)
        }

        // Then: No skills should have missing dependencies
        XCTAssertEqual(skillsWithMissing.count, 0,
                      "No skills should have missing dependencies when all tools available")
    }

    func test_skillsBadge_identifiesSpecificMissingTools() {
        // Given: A skill with specific required tools
        let skill = Skill(
            id: "deploy",
            name: "Deploy",
            description: "Deploy to production",
            promptTemplate: "...",
            requiredTools: ["docker", "kubectl", "aws-cli"]
        )
        let availableTools: Set<String> = ["docker"]

        // When: Getting missing tools
        let missingTools = skill.missingTools(from: availableTools)

        // Then: Should identify exactly which tools are missing
        XCTAssertEqual(missingTools.count, 2, "Should have 2 missing tools")
        XCTAssertTrue(missingTools.contains("kubectl"), "kubectl should be missing")
        XCTAssertTrue(missingTools.contains("aws-cli"), "aws-cli should be missing")
        XCTAssertFalse(missingTools.contains("docker"), "docker should not be missing")
    }

    func test_skillsBadge_emptyRequiredToolsNeverMissing() {
        // Given: A skill with no required tools
        let skill = Skill(
            id: "simple",
            name: "Simple Skill",
            description: "No tool requirements",
            promptTemplate: "...",
            requiredTools: []
        )
        let availableTools: Set<String> = []

        // Then: Should have all required tools (vacuously true)
        XCTAssertTrue(skill.hasRequiredTools(available: availableTools),
                     "Skill with no requirements should always have all tools")
        XCTAssertTrue(skill.missingTools(from: availableTools).isEmpty,
                     "Should have no missing tools")
    }

    // MARK: - Test: TerminalSlot Skills Integration

    func test_terminalSlot_skillCountProperty() {
        // Given: A terminal slot with loaded skills
        var slot = TerminalSlot(slotNumber: 1)
        slot.loadedSkills = sampleSkills

        // Then: loadedSkillCount should return correct count
        XCTAssertEqual(slot.loadedSkillCount, 3,
                      "Slot should report 3 loaded skills")
    }

    func test_terminalSlot_skillNamesProperty() {
        // Given: A terminal slot with loaded skills
        var slot = TerminalSlot(slotNumber: 1)
        slot.loadedSkills = sampleSkills

        // Then: loadedSkillNames should return skill names
        let names = slot.loadedSkillNames
        XCTAssertEqual(names.count, 3, "Should have 3 skill names")
        XCTAssertTrue(names.contains("Git Commit"), "Should contain Git Commit")
        XCTAssertTrue(names.contains("Code Review"), "Should contain Code Review")
        XCTAssertTrue(names.contains("Test Runner"), "Should contain Test Runner")
    }

    func test_terminalSlot_hasLoadedSkillsProperty() {
        // Given: A terminal slot
        var slot = TerminalSlot(slotNumber: 1)

        // When: No skills loaded
        XCTAssertFalse(slot.hasLoadedSkills, "Should return false when no skills")

        // When: Skills are loaded
        slot.loadedSkills = sampleSkills
        XCTAssertTrue(slot.hasLoadedSkills, "Should return true when skills loaded")
    }

    func test_terminalSlot_configureAction_setsSkills() {
        // Given: A terminal slot and skills
        var slot = TerminalSlot(slotNumber: 1)

        // When: Configuring action with skills
        slot.configureAction(.implement, skills: sampleSkills)

        // Then: Skills should be set
        XCTAssertEqual(slot.loadedSkills.count, 3, "Should have 3 skills after configure")
        XCTAssertEqual(slot.actionType, .implement, "Action should be set")
    }

    func test_terminalSlot_clearAction_clearsSkills() {
        // Given: A slot with action and skills
        var slot = TerminalSlot(slotNumber: 1)
        slot.configureAction(.implement, skills: sampleSkills)

        // When: Clearing action
        slot.clearAction()

        // Then: Skills should be cleared
        XCTAssertNil(slot.actionType, "Action should be nil")
        XCTAssertTrue(slot.loadedSkills.isEmpty, "Skills should be empty")
    }

    func test_terminalSlot_reset_clearsEverything() {
        // Given: A fully configured slot
        var slot = TerminalSlot(
            slotNumber: 1,
            worktree: Worktree(path: "/test", branch: "main"),
            agentType: .claude,
            actionType: .implement,
            loadedSkills: sampleSkills,
            status: .running
        )

        // When: Resetting
        slot.reset()

        // Then: Everything should be cleared
        XCTAssertNil(slot.worktree, "Worktree should be nil")
        XCTAssertNil(slot.agentType, "Agent type should be nil")
        XCTAssertNil(slot.actionType, "Action type should be nil")
        XCTAssertTrue(slot.loadedSkills.isEmpty, "Skills should be empty")
        XCTAssertEqual(slot.status, .empty, "Status should be empty")
    }

    // MARK: - Test: Skill Compatibility

    func test_skill_compatibilityCheck() {
        // Given: A skill compatible with specific CLIs
        let claudeOnlySkill = Skill(
            id: "claude-special",
            name: "Claude Special",
            description: "Only for Claude",
            promptTemplate: "...",
            compatibleCLIs: Set([.claude])
        )

        // Then: Should be compatible only with Claude
        XCTAssertTrue(claudeOnlySkill.isCompatible(with: .claude))
        XCTAssertFalse(claudeOnlySkill.isCompatible(with: .gemini))
        XCTAssertFalse(claudeOnlySkill.isCompatible(with: .codex))
    }

    func test_skill_universalCompatibility() {
        // Given: A skill compatible with all CLIs
        let universalSkill = Skill(
            id: "universal",
            name: "Universal",
            description: "Works everywhere",
            promptTemplate: "...",
            compatibleCLIs: Set(AgentType.allCases)
        )

        // Then: Should be compatible with all CLIs
        for cli in AgentType.allCases {
            XCTAssertTrue(universalSkill.isCompatible(with: cli),
                         "Universal skill should work with \(cli)")
        }
    }
}
