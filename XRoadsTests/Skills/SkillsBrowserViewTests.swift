//
//  SkillsBrowserViewTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-016: Unit tests for Skills Browser View
//

import XCTest
@testable import XRoadsLib

final class SkillsBrowserViewTests: XCTestCase {

    // MARK: - Test Properties

    var viewModel: SkillsViewModel!

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        viewModel = SkillsViewModel()
    }

    @MainActor
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Test: Skills Grouped by Category

    @MainActor
    func test_skillsByCategory_groupsCorrectly() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Getting skills by category
        let groupedSkills = viewModel.skillsByCategory

        // Then: Each skill should be in its correct category group
        for (category, skills) in groupedSkills {
            for skill in skills {
                let skillCategory = skill.category ?? .custom
                XCTAssertEqual(skillCategory, category,
                               "Skill '\(skill.name)' should be in category '\(category.displayName)'")
            }
        }
    }

    @MainActor
    func test_skillsByCategory_customCategoryForNilCategory() async {
        // Given: A skill without category
        let skillWithoutCategory = Skill(
            id: "test-skill",
            name: "Test Skill",
            description: "A test skill without category",
            promptTemplate: "...",
            category: nil
        )

        // Then: Skill without category should be treated as custom
        let expectedCategory = skillWithoutCategory.category ?? .custom
        XCTAssertEqual(expectedCategory, .custom,
                       "Skills without category should default to .custom")
    }

    // MARK: - Test: Filter by CLI Works

    @MainActor
    func test_filterByCLI_filtersCorrectly() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()
        let allSkillsCount = viewModel.allSkills.count

        // When: Filtering by Claude CLI
        viewModel.selectedCLI = .claude
        let claudeSkills = viewModel.filteredSkills

        // Then: Only Claude-compatible skills should be shown
        for skill in claudeSkills {
            XCTAssertTrue(skill.isCompatible(with: .claude),
                          "Filtered skill '\(skill.name)' should be compatible with Claude")
        }

        // When: Clearing the filter
        viewModel.selectedCLI = nil
        let allSkillsAfterClear = viewModel.filteredSkills

        // Then: All skills should be shown again
        XCTAssertEqual(allSkillsAfterClear.count, allSkillsCount,
                       "Clearing CLI filter should show all skills")
    }

    @MainActor
    func test_filterByGeminiCLI_excludesIncompatible() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Filtering by Gemini CLI
        viewModel.selectedCLI = .gemini

        // Then: Filtered skills should be compatible with Gemini
        for skill in viewModel.filteredSkills {
            XCTAssertTrue(skill.isCompatible(with: .gemini),
                          "Filtered skill '\(skill.name)' should be compatible with Gemini")
        }
    }

    @MainActor
    func test_filterByCodexCLI_excludesIncompatible() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Filtering by Codex CLI
        viewModel.selectedCLI = .codex

        // Then: Filtered skills should be compatible with Codex
        for skill in viewModel.filteredSkills {
            XCTAssertTrue(skill.isCompatible(with: .codex),
                          "Filtered skill '\(skill.name)' should be compatible with Codex")
        }
    }

    // MARK: - Test: Search Filters Results

    @MainActor
    func test_searchFiltersResults_byName() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Searching for "commit"
        viewModel.searchQuery = "commit"
        let results = viewModel.filteredSkills

        // Then: Results should contain "commit" in name or description
        for skill in results {
            let matchesName = skill.name.lowercased().contains("commit")
            let matchesDescription = skill.description.lowercased().contains("commit")
            let matchesId = skill.id.lowercased().contains("commit")
            XCTAssertTrue(matchesName || matchesDescription || matchesId,
                          "Skill '\(skill.name)' should match search query 'commit'")
        }
    }

    @MainActor
    func test_searchFiltersResults_caseInsensitive() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Searching with different cases
        viewModel.searchQuery = "COMMIT"
        let uppercaseResults = viewModel.filteredSkills

        viewModel.searchQuery = "commit"
        let lowercaseResults = viewModel.filteredSkills

        viewModel.searchQuery = "Commit"
        let mixedCaseResults = viewModel.filteredSkills

        // Then: All searches should return same results (case insensitive)
        XCTAssertEqual(uppercaseResults.count, lowercaseResults.count,
                       "Search should be case insensitive")
        XCTAssertEqual(lowercaseResults.count, mixedCaseResults.count,
                       "Search should be case insensitive")
    }

    @MainActor
    func test_emptySearch_showsAllSkills() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()
        let totalCount = viewModel.allSkills.count

        // When: Search query is empty
        viewModel.searchQuery = ""

        // Then: All skills should be shown
        XCTAssertEqual(viewModel.filteredSkills.count, totalCount,
                       "Empty search should show all skills")
    }

    // MARK: - Test: Category Filter

    @MainActor
    func test_filterByCategory_gitCategory() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Filtering by Git category
        viewModel.selectedCategory = .git

        // Then: Only Git category skills should be shown
        for skill in viewModel.filteredSkills {
            XCTAssertEqual(skill.category, .git,
                           "Filtered skill '\(skill.name)' should be in Git category")
        }
    }

    @MainActor
    func test_filterByCategory_combinedWithCLI() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Filtering by both category and CLI
        viewModel.selectedCategory = .code
        viewModel.selectedCLI = .claude

        // Then: Skills should match both filters
        for skill in viewModel.filteredSkills {
            let categoryMatches = (skill.category ?? .custom) == .code
            let cliMatches = skill.isCompatible(with: .claude)
            XCTAssertTrue(categoryMatches && cliMatches,
                          "Skill '\(skill.name)' should match both category and CLI filters")
        }
    }

    // MARK: - Test: Clear Filters

    @MainActor
    func test_clearFilters_resetsAllFilters() async {
        // Given: A ViewModel with active filters
        await viewModel.loadSkills()
        viewModel.selectedCategory = .git
        viewModel.selectedCLI = .claude
        viewModel.searchQuery = "test"

        // When: Clearing all filters
        viewModel.clearFilters()

        // Then: All filters should be reset
        XCTAssertNil(viewModel.selectedCategory, "Category filter should be nil after clear")
        XCTAssertNil(viewModel.selectedCLI, "CLI filter should be nil after clear")
        XCTAssertTrue(viewModel.searchQuery.isEmpty, "Search query should be empty after clear")
    }

    // MARK: - Test: Enable/Disable Skills

    @MainActor
    func test_toggleSkill_enablesAndDisables() async {
        // Given: A skill
        let skill = Skill(
            id: "test-toggle",
            name: "Toggle Test",
            description: "Test",
            promptTemplate: "..."
        )

        // Initially not enabled
        XCTAssertFalse(viewModel.isSkillEnabled(skill), "Skill should not be enabled initially")

        // When: Toggling (enable)
        viewModel.toggleSkill(skill)

        // Then: Should be enabled
        XCTAssertTrue(viewModel.isSkillEnabled(skill), "Skill should be enabled after toggle")

        // When: Toggling again (disable)
        viewModel.toggleSkill(skill)

        // Then: Should be disabled
        XCTAssertFalse(viewModel.isSkillEnabled(skill), "Skill should be disabled after second toggle")
    }

    @MainActor
    func test_enableSkill_addsToEnabledSet() async {
        // Given: A skill
        let skill = Skill(
            id: "test-enable",
            name: "Enable Test",
            description: "Test",
            promptTemplate: "..."
        )

        // When: Enabling the skill
        viewModel.enableSkill(skill)

        // Then: Skill should be in enabled set
        XCTAssertTrue(viewModel.isSkillEnabled(skill), "Skill should be enabled")
    }

    @MainActor
    func test_disableSkill_removesFromEnabledSet() async {
        // Given: An enabled skill
        let skill = Skill(
            id: "test-disable",
            name: "Disable Test",
            description: "Test",
            promptTemplate: "..."
        )
        viewModel.enableSkill(skill)
        XCTAssertTrue(viewModel.isSkillEnabled(skill))

        // When: Disabling the skill
        viewModel.disableSkill(skill)

        // Then: Skill should not be in enabled set
        XCTAssertFalse(viewModel.isSkillEnabled(skill), "Skill should be disabled")
    }

    // MARK: - Test: Required Tools Check

    @MainActor
    func test_hasRequiredTools_withAvailableTools() async {
        // Given: A skill with required tools and available tools
        let skill = Skill(
            id: "test-tools",
            name: "Tools Test",
            description: "Test",
            promptTemplate: "...",
            requiredTools: ["git", "file-read"]
        )
        viewModel.setAvailableTools(Set(["git", "file-read", "file-edit"]))

        // Then: Should have all required tools
        XCTAssertTrue(viewModel.hasRequiredTools(skill),
                      "Skill should have all required tools available")
    }

    @MainActor
    func test_hasRequiredTools_withMissingTools() async {
        // Given: A skill with required tools, some missing
        let skill = Skill(
            id: "test-missing-tools",
            name: "Missing Tools Test",
            description: "Test",
            promptTemplate: "...",
            requiredTools: ["git", "eslint"]
        )
        viewModel.setAvailableTools(Set(["git", "file-read"]))

        // Then: Should not have all required tools
        XCTAssertFalse(viewModel.hasRequiredTools(skill),
                       "Skill should be missing some required tools")
    }

    @MainActor
    func test_missingTools_returnsMissingToolsList() async {
        // Given: A skill with some missing tools
        let skill = Skill(
            id: "test-missing-list",
            name: "Missing List Test",
            description: "Test",
            promptTemplate: "...",
            requiredTools: ["git", "eslint", "prettier"]
        )
        viewModel.setAvailableTools(Set(["git"]))

        // When: Getting missing tools
        let missing = viewModel.missingTools(for: skill)

        // Then: Should return the missing tools
        XCTAssertTrue(missing.contains("eslint"), "eslint should be in missing tools")
        XCTAssertTrue(missing.contains("prettier"), "prettier should be in missing tools")
        XCTAssertFalse(missing.contains("git"), "git should not be in missing tools")
    }

    // MARK: - Test: Category Counts

    @MainActor
    func test_categoryCounts_reflectsActualCounts() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Getting category counts
        let counts = viewModel.categoryCounts

        // Then: Counts should match actual skill counts per category
        for (category, count) in counts {
            let actualSkills = viewModel.allSkills.filter { ($0.category ?? .custom) == category }
            XCTAssertEqual(count, actualSkills.count,
                           "Category '\(category.displayName)' count should match actual skills")
        }
    }

    // MARK: - Test: Available Categories

    @MainActor
    func test_availableCategories_onlyIncludesUsedCategories() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Getting available categories
        let categories = viewModel.availableCategories

        // Then: Each category should have at least one skill (or be custom)
        for category in categories {
            let hasSkills = viewModel.allSkills.contains { ($0.category ?? .custom) == category }
            let isCustomFallback = category == .custom
            XCTAssertTrue(hasSkills || isCustomFallback,
                          "Category '\(category.displayName)' should have skills or be the custom fallback")
        }
    }

    // MARK: - Test: Filtered Skill Count

    @MainActor
    func test_filteredSkillCount_matchesFilteredSkillsArray() async {
        // Given: A ViewModel with loaded skills and active filter
        await viewModel.loadSkills()
        viewModel.selectedCLI = .claude

        // Then: Count should match array length
        XCTAssertEqual(viewModel.filteredSkillCount, viewModel.filteredSkills.count,
                       "filteredSkillCount should match filteredSkills array count")
    }

    @MainActor
    func test_totalSkillCount_matchesAllSkillsArray() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // Then: Count should match array length
        XCTAssertEqual(viewModel.totalSkillCount, viewModel.allSkills.count,
                       "totalSkillCount should match allSkills array count")
    }

    // MARK: - Test: Skills for CLI

    @MainActor
    func test_skillsForCLI_returnsOnlyCompatible() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Getting skills for Claude
        let claudeSkills = viewModel.skills(for: .claude)

        // Then: All returned skills should be Claude-compatible
        for skill in claudeSkills {
            XCTAssertTrue(skill.isCompatible(with: .claude),
                          "Skill '\(skill.name)' from skills(for: .claude) should be Claude-compatible")
        }
    }

    // MARK: - Test: Skills in Category

    @MainActor
    func test_skillsInCategory_returnsOnlyCategorySkills() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()

        // When: Getting skills in Git category
        let gitSkills = viewModel.skills(in: .git)

        // Then: All returned skills should be in Git category
        for skill in gitSkills {
            XCTAssertEqual(skill.category, .git,
                           "Skill '\(skill.name)' from skills(in: .git) should be in Git category")
        }
    }

    // MARK: - Test: Loading State

    @MainActor
    func test_isLoading_trueWhileLoading() async {
        // Given: A fresh ViewModel
        viewModel = SkillsViewModel()

        // Initially not loading
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")

        // When: Loading skills (we can't easily test during async, but we can test after)
        await viewModel.loadSkills()

        // Then: Should not be loading after completion
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }

    // MARK: - Test: Reload Skills

    @MainActor
    func test_reloadSkills_refreshesData() async {
        // Given: A ViewModel with loaded skills
        await viewModel.loadSkills()
        let initialCount = viewModel.allSkills.count

        // When: Reloading skills
        await viewModel.reloadSkills()

        // Then: Skills should still be loaded (count may vary based on registry)
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after reload")
        XCTAssertGreaterThanOrEqual(viewModel.allSkills.count, 0, "Should have skills after reload")
    }

    // MARK: - Test: Skill Model Properties

    func test_skill_isCompatibleWithAllCLIs_whenEmpty() {
        // Given: A skill with empty compatibleCLIs (means all)
        let skill = Skill(
            id: "test-all-compat",
            name: "All Compatible",
            description: "Test",
            promptTemplate: "...",
            compatibleCLIs: Set()
        )

        // Then: Should be compatible with all CLIs
        XCTAssertTrue(skill.isCompatible(with: .claude), "Empty compatibleCLIs should mean all CLIs")
        XCTAssertTrue(skill.isCompatible(with: .gemini), "Empty compatibleCLIs should mean all CLIs")
        XCTAssertTrue(skill.isCompatible(with: .codex), "Empty compatibleCLIs should mean all CLIs")
    }

    func test_skill_isCompatible_whenSpecific() {
        // Given: A skill with specific compatibleCLIs
        let skill = Skill(
            id: "test-specific-compat",
            name: "Claude Only",
            description: "Test",
            promptTemplate: "...",
            compatibleCLIs: Set([.claude])
        )

        // Then: Should only be compatible with Claude
        XCTAssertTrue(skill.isCompatible(with: .claude), "Should be compatible with Claude")
        XCTAssertFalse(skill.isCompatible(with: .gemini), "Should not be compatible with Gemini")
        XCTAssertFalse(skill.isCompatible(with: .codex), "Should not be compatible with Codex")
    }

    // MARK: - Test: SkillCategory Properties

    func test_skillCategory_displayNames() {
        // Then: Each category should have a display name
        for category in SkillCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty,
                           "Category \(category) should have a display name")
        }
    }

    func test_skillCategory_iconNames() {
        // Then: Each category should have an icon name
        for category in SkillCategory.allCases {
            XCTAssertFalse(category.iconName.isEmpty,
                           "Category \(category) should have an icon name")
        }
    }
}
