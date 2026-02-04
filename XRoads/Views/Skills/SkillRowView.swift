//
//  SkillRowView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  Individual skill row component for the Skills Browser
//

import SwiftUI

// MARK: - SkillRowView

struct SkillRowView: View {
    let skill: Skill
    let isEnabled: Bool
    let isUserSkill: Bool
    let hasMissingTools: Bool
    let missingTools: [String]
    let onToggle: () -> Void
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Category icon
            categoryIcon

            // Skill info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textPrimary)

                    // Version badge
                    Text("v\(skill.version)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.bgElevated)
                        .cornerRadius(3)

                    // User skill badge
                    if isUserSkill {
                        Text("User")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.accentPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentPrimary.opacity(0.15))
                            .cornerRadius(3)
                    }

                    // Warning indicator for missing tools
                    if hasMissingTools {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.statusWarning)
                            .help("Missing tools: \(missingTools.joined(separator: ", "))")
                    }
                }

                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)

                // CLI compatibility badges
                HStack(spacing: 4) {
                    ForEach(AgentType.allCases, id: \.self) { cli in
                        CLICompatibilityBadge(
                            cli: cli,
                            isCompatible: skill.isCompatible(with: cli)
                        )
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            // Toggle button
            Button {
                onToggle()
            } label: {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isEnabled ? Color.statusSuccess : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help(isEnabled ? "Disable skill" : "Enable skill")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(isHovered ? Color.bgElevated : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect()
        }
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        let category = skill.category ?? .custom
        return Image(systemName: category.iconName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(categoryColor)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(categoryColor.opacity(0.15))
            )
    }

    private var categoryColor: Color {
        guard let category = skill.category else { return .textSecondary }
        switch category {
        case .git: return .statusInfo
        case .code: return .accentPrimary
        case .test: return .statusSuccess
        case .docs: return .statusWarning
        case .review: return Color(red: 0.8, green: 0.4, blue: 1.0)
        case .custom: return .textSecondary
        }
    }
}

// MARK: - CLI Compatibility Badge

struct CLICompatibilityBadge: View {
    let cli: AgentType
    let isCompatible: Bool

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: cli.iconName)
                .font(.system(size: 8))
            Text(cli.shortName)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundStyle(isCompatible ? cli.neonColor : Color.textTertiary.opacity(0.5))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isCompatible ? cli.neonColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isCompatible ? cli.neonColor.opacity(0.3) : Color.textTertiary.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Compact Skill Row (for lists)

struct CompactSkillRowView: View {
    let skill: Skill
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Category icon (small)
            Image(systemName: (skill.category ?? .custom).iconName)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 20)

            // Name
            Text(skill.name)
                .font(.system(size: 12))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.7)
            .frame(width: 40)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
struct SkillRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.sm) {
            SkillRowView(
                skill: Skill(
                    id: "commit",
                    name: "Git Commit",
                    description: "Create git commits with conventional commit messages following project standards",
                    promptTemplate: "...",
                    requiredTools: ["git", "file-read"],
                    version: "1.0.0",
                    compatibleCLIs: Set(AgentType.allCases),
                    category: .git,
                    author: "XRoads Team"
                ),
                isEnabled: true,
                isUserSkill: false,
                hasMissingTools: false,
                missingTools: [],
                onToggle: {},
                onSelect: {}
            )

            SkillRowView(
                skill: Skill(
                    id: "custom-lint",
                    name: "Custom Linter",
                    description: "User-defined linting rules for the project",
                    promptTemplate: "...",
                    requiredTools: ["eslint"],
                    version: "0.1.0",
                    compatibleCLIs: [.claude],
                    category: .review,
                    author: "User"
                ),
                isEnabled: false,
                isUserSkill: true,
                hasMissingTools: true,
                missingTools: ["eslint"],
                onToggle: {},
                onSelect: {}
            )

            Divider()

            CompactSkillRowView(
                skill: Skill(
                    id: "commit",
                    name: "Git Commit",
                    description: "...",
                    promptTemplate: "..."
                ),
                isEnabled: true,
                onToggle: {}
            )
        }
        .padding()
        .background(Color.bgSurface)
    }
}
#endif
