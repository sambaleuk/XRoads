//
//  SkillsViewModel.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  ViewModel for the Skills Browser view
//

import Foundation
import SwiftUI

/// ViewModel for browsing and managing skills
/// Provides filtering by category, CLI compatibility, and search functionality
@MainActor
@Observable
final class SkillsViewModel {

    // MARK: - State Properties

    /// All available skills from the registry
    private(set) var allSkills: [Skill] = []

    /// Currently selected category filter (nil = all)
    var selectedCategory: SkillCategory? = nil

    /// Currently selected CLI filter (nil = all)
    var selectedCLI: AgentType? = nil

    /// Search query for filtering by name/description
    var searchQuery: String = ""

    /// Whether the registry is loading
    private(set) var isLoading: Bool = false

    /// Error message if loading failed
    private(set) var loadError: String? = nil

    /// Set of installed/enabled skill IDs for the current project
    private(set) var enabledSkillIDs: Set<String> = []

    /// Set of available tools in the current environment
    private(set) var availableTools: Set<String> = []

    // MARK: - Computed Properties

    /// Filtered skills based on current filter criteria
    var filteredSkills: [Skill] {
        var result = allSkills

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by CLI compatibility
        if let cli = selectedCLI {
            result = result.filter { $0.isCompatible(with: cli) }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { skill in
                skill.name.lowercased().contains(query) ||
                skill.description.lowercased().contains(query) ||
                skill.id.lowercased().contains(query)
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    /// Skills grouped by category
    var skillsByCategory: [SkillCategory: [Skill]] {
        var grouped: [SkillCategory: [Skill]] = [:]

        for skill in filteredSkills {
            let category = skill.category ?? .custom
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(skill)
        }

        return grouped
    }

    /// Ordered categories that have skills
    var availableCategories: [SkillCategory] {
        let categories = Set(allSkills.compactMap { $0.category })
        return SkillCategory.allCases.filter { categories.contains($0) || $0 == .custom }
    }

    /// Count of skills per category
    var categoryCounts: [SkillCategory: Int] {
        var counts: [SkillCategory: Int] = [:]
        for category in SkillCategory.allCases {
            let count = allSkills.filter { ($0.category ?? .custom) == category }.count
            if count > 0 {
                counts[category] = count
            }
        }
        return counts
    }

    /// Total number of skills
    var totalSkillCount: Int {
        allSkills.count
    }

    /// Number of filtered skills
    var filteredSkillCount: Int {
        filteredSkills.count
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Loads skills from the registry
    func loadSkills() async {
        isLoading = true
        loadError = nil

        // Ensure registry is initialized
        await SkillRegistry.shared.initialize()

        // Load all skills
        allSkills = await SkillRegistry.shared.allSkills()

        // Check for load errors
        let errors = await SkillRegistry.shared.getLoadErrors()
        if !errors.isEmpty {
            loadError = "Some skills failed to load: \(errors.first?.localizedDescription ?? "Unknown error")"
        }

        isLoading = false
    }

    /// Reloads skills from the registry
    func reloadSkills() async {
        isLoading = true
        loadError = nil

        await SkillRegistry.shared.reload()
        allSkills = await SkillRegistry.shared.allSkills()

        isLoading = false
    }

    /// Checks if a skill is enabled for the current project
    func isSkillEnabled(_ skill: Skill) -> Bool {
        enabledSkillIDs.contains(skill.id)
    }

    /// Checks if a skill is a user-provided skill (not bundled)
    func isUserSkill(_ skill: Skill) async -> Bool {
        await SkillRegistry.shared.isUserSkill(skill.id)
    }

    /// Toggles skill enabled state for the current project
    func toggleSkill(_ skill: Skill) {
        if enabledSkillIDs.contains(skill.id) {
            enabledSkillIDs.remove(skill.id)
        } else {
            enabledSkillIDs.insert(skill.id)
        }
    }

    /// Enables a skill for the current project
    func enableSkill(_ skill: Skill) {
        enabledSkillIDs.insert(skill.id)
    }

    /// Disables a skill for the current project
    func disableSkill(_ skill: Skill) {
        enabledSkillIDs.remove(skill.id)
    }

    /// Sets the available tools in the environment
    func setAvailableTools(_ tools: Set<String>) {
        availableTools = tools
    }

    /// Checks if a skill has all required tools available
    func hasRequiredTools(_ skill: Skill) -> Bool {
        skill.hasRequiredTools(available: availableTools)
    }

    /// Gets missing tools for a skill
    func missingTools(for skill: Skill) -> [String] {
        skill.missingTools(from: availableTools)
    }

    /// Clears all filters
    func clearFilters() {
        selectedCategory = nil
        selectedCLI = nil
        searchQuery = ""
    }

    /// Gets skills compatible with a specific CLI
    func skills(for cli: AgentType) -> [Skill] {
        allSkills.filter { $0.isCompatible(with: cli) }
    }

    /// Gets skills in a specific category
    func skills(in category: SkillCategory) -> [Skill] {
        allSkills.filter { ($0.category ?? .custom) == category }
    }
}

// MARK: - SkillsViewModel Environment Key

private struct SkillsViewModelKey: EnvironmentKey {
    @MainActor static var defaultValue: SkillsViewModel = SkillsViewModel()
}

extension EnvironmentValues {
    var skillsViewModel: SkillsViewModel {
        get { self[SkillsViewModelKey.self] }
        set { self[SkillsViewModelKey.self] = newValue }
    }
}
