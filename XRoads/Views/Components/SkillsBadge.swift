//
//  SkillsBadge.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-018: Skills badge component for terminal slots
//

import SwiftUI

// MARK: - SkillsBadge

/// Badge displaying the number of skills loaded in a terminal slot
/// Shows a count badge with popover listing skills on hover
/// Displays a warning indicator if any skill has missing MCP dependencies
struct SkillsBadge: View {
    /// The skills to display
    let skills: [Skill]

    /// Available MCP tools for checking dependencies
    var availableMCPTools: Set<String> = []

    /// Action when clicking the badge (e.g., open Skills Browser filtered)
    var onTap: (() -> Void)?

    @State private var isHovered: Bool = false
    @State private var showPopover: Bool = false

    // MARK: - Computed Properties

    /// Number of skills loaded
    var skillCount: Int {
        skills.count
    }

    /// Check if any skill has missing MCP dependencies
    var hasMissingDependencies: Bool {
        skills.contains { skill in
            !skill.hasRequiredTools(available: availableMCPTools)
        }
    }

    /// Get skills with missing dependencies
    var skillsWithMissingDependencies: [Skill] {
        skills.filter { !$0.hasRequiredTools(available: availableMCPTools) }
    }

    // MARK: - Body

    var body: some View {
        if skillCount > 0 {
            Button {
                onTap?()
            } label: {
                HStack(spacing: 4) {
                    // Skills icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .medium))

                    // Count
                    Text("\(skillCount)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))

                    // Warning indicator for missing dependencies
                    if hasMissingDependencies {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.statusWarning)
                    }
                }
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.15))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(badgeColor.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    showPopover = true
                }
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                SkillsPopoverContent(
                    skills: skills,
                    availableMCPTools: availableMCPTools
                )
            }
        }
    }

    // MARK: - Private

    private var badgeColor: Color {
        hasMissingDependencies ? Color.statusWarning : Color.accentPrimary
    }
}

// MARK: - SkillsPopoverContent

/// Content view for the skills popover
private struct SkillsPopoverContent: View {
    let skills: [Skill]
    let availableMCPTools: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentPrimary)
                Text("Loaded Skills")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(skills.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
            }

            Divider()
                .background(Color.borderMuted)

            // Skills list
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(skills) { skill in
                        SkillPopoverRow(
                            skill: skill,
                            availableMCPTools: availableMCPTools
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(12)
        .frame(width: 240)
        .background(Color.bgSurface)
    }
}

// MARK: - SkillPopoverRow

/// Single skill row in the popover
private struct SkillPopoverRow: View {
    let skill: Skill
    let availableMCPTools: Set<String>

    var body: some View {
        HStack(spacing: 8) {
            // Category icon
            if let category = skill.category {
                Image(systemName: category.iconName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 16)
            } else {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 16)
            }

            // Skill info
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if !missingTools.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.statusWarning)
                        Text("Missing: \(missingTools.joined(separator: ", "))")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.statusWarning)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Version badge
            Text("v\(skill.version)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(hasMissingTools ? Color.statusWarning.opacity(0.1) : Color.clear)
        )
    }

    private var missingTools: [String] {
        skill.missingTools(from: availableMCPTools)
    }

    private var hasMissingTools: Bool {
        !missingTools.isEmpty
    }
}

// MARK: - Compact Skills Badge (for smaller spaces)

/// A more compact version of the skills badge for tight layouts
struct CompactSkillsBadge: View {
    let skillCount: Int
    let hasMissingDependencies: Bool
    var onTap: (() -> Void)?

    var body: some View {
        if skillCount > 0 {
            Button {
                onTap?()
            } label: {
                HStack(spacing: 2) {
                    Text("\(skillCount)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))

                    if hasMissingDependencies {
                        Circle()
                            .fill(Color.statusWarning)
                            .frame(width: 4, height: 4)
                    }
                }
                .foregroundStyle(hasMissingDependencies ? Color.statusWarning : Color.accentPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    (hasMissingDependencies ? Color.statusWarning : Color.accentPrimary)
                        .opacity(0.15)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SkillsBadge_Previews: PreviewProvider {
    static var sampleSkills: [Skill] = [
        Skill(
            id: "commit",
            name: "Git Commit",
            description: "Create git commits",
            promptTemplate: "...",
            requiredTools: ["git"],
            category: .git,
            author: "XRoads Team"
        ),
        Skill(
            id: "review",
            name: "Code Review",
            description: "Review code changes",
            promptTemplate: "...",
            requiredTools: ["file-read", "eslint"],
            category: .review,
            author: "XRoads Team"
        ),
        Skill(
            id: "test",
            name: "Test Runner",
            description: "Run unit tests",
            promptTemplate: "...",
            requiredTools: ["bash", "jest"],
            category: .test,
            author: "XRoads Team"
        )
    ]

    static var previews: some View {
        VStack(spacing: 20) {
            // Normal badge
            HStack(spacing: 16) {
                Text("Normal:")
                SkillsBadge(
                    skills: sampleSkills,
                    availableMCPTools: Set(["git", "file-read", "bash", "eslint", "jest"])
                )
            }

            // Badge with missing dependencies
            HStack(spacing: 16) {
                Text("Missing deps:")
                SkillsBadge(
                    skills: sampleSkills,
                    availableMCPTools: Set(["git", "file-read"])
                )
            }

            // Empty skills
            HStack(spacing: 16) {
                Text("Empty:")
                SkillsBadge(
                    skills: [],
                    availableMCPTools: Set()
                )
            }

            // Compact badge
            HStack(spacing: 16) {
                Text("Compact:")
                CompactSkillsBadge(skillCount: 3, hasMissingDependencies: false)
                CompactSkillsBadge(skillCount: 2, hasMissingDependencies: true)
            }
        }
        .padding()
        .background(Color.bgApp)
    }
}
#endif
