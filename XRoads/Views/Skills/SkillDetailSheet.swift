//
//  SkillDetailSheet.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-017: Detailed view of a skill with templates per CLI and configuration
//

import SwiftUI

// MARK: - SkillDetailSheet

/// Sheet presenting detailed information about a skill
/// Shows name, description, version, CLI templates, required tools, and edit capabilities
struct SkillDetailSheet: View {
    let skill: Skill
    let isEnabled: Bool
    let isUserSkill: Bool
    let missingTools: [String]
    let onToggle: () -> Void
    let onEdit: (() -> Void)?
    let onDismiss: () -> Void

    @State private var selectedCLI: AgentType = .claude
    @State private var showPreview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            sheetHeader

            Divider()
                .background(Color.borderDefault)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Metadata section
                    metadataSection

                    Divider()
                        .background(Color.borderMuted)

                    // CLI Templates section (tabs)
                    templatesSection

                    Divider()
                        .background(Color.borderMuted)

                    // Required Tools section
                    requiredToolsSection

                    // MCP Dependencies section (if any)
                    if !mcpDependencies.isEmpty {
                        Divider()
                            .background(Color.borderMuted)
                        mcpDependenciesSection
                    }

                    Divider()
                        .background(Color.borderMuted)

                    // Actions section
                    actionsSection
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .frame(width: 600, height: 600)
        .background(Color.bgSurface)
        .sheet(isPresented: $showPreview) {
            SkillPreviewSheet(skill: skill, cli: selectedCLI, onDismiss: { showPreview = false })
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(alignment: .top) {
            // Category icon
            Image(systemName: (skill.category ?? .custom).iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(categoryColor)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(categoryColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(skill.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    // Version badge
                    Text("v\(skill.version)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.bgElevated)
                        .cornerRadius(4)

                    // User skill badge
                    if isUserSkill {
                        Text("Project Skill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentPrimary.opacity(0.15))
                            .cornerRadius(4)
                    }

                    // Warning badge for missing tools
                    if !missingTools.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("Missing Tools")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color.statusWarning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.statusWarning.opacity(0.15))
                        .cornerRadius(4)
                    }
                }

                // Author and category info
                HStack(spacing: Theme.Spacing.sm) {
                    if let category = skill.category {
                        Label(category.displayName, systemImage: category.iconName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondary)
                    }

                    if let author = skill.author {
                        Text("by \(author)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Spacer()

            // Close button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Description")

            Text(skill.description)
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
                .lineSpacing(4)

            // CLI Compatibility badges
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Compatible CLIs")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(AgentType.allCases, id: \.self) { cli in
                        CLICompatibilityBadge(
                            cli: cli,
                            isCompatible: skill.isCompatible(with: cli)
                        )
                    }
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
    }

    // MARK: - Templates Section

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                SectionHeader(title: "Prompt Templates")

                Spacer()

                // Preview button
                Button {
                    showPreview = true
                } label: {
                    Label("Preview", systemImage: "eye")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            // CLI Tabs
            SkillTemplateTabView(
                skill: skill,
                selectedCLI: $selectedCLI
            )
        }
    }

    // MARK: - Required Tools Section

    private var requiredToolsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Required Tools")

            if skill.requiredTools.isEmpty {
                Text("No specific tools required")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .italic()
            } else {
                DetailFlowLayout(spacing: 6) {
                    ForEach(skill.requiredTools, id: \.self) { tool in
                        ToolBadge(
                            name: tool,
                            isMissing: missingTools.contains(tool)
                        )
                    }
                }
            }
        }
    }

    // MARK: - MCP Dependencies Section

    private var mcpDependencies: [String] {
        // Extract MCP dependencies from prompt template (if mentioned)
        // This is a heuristic - in a real implementation, this would be a separate field
        let template = skill.promptTemplate.lowercased()
        var deps: [String] = []
        if template.contains("mcp") || template.contains("xroads-mcp") {
            deps.append("xroads-mcp")
        }
        if template.contains("filesystem") {
            deps.append("filesystem")
        }
        if template.contains("github") && !template.contains("github.com") {
            deps.append("github")
        }
        return deps
    }

    private var mcpDependenciesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "MCP Dependencies")

            DetailFlowLayout(spacing: 6) {
                ForEach(mcpDependencies, id: \.self) { mcp in
                    HStack(spacing: 4) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 10))
                        Text(mcp)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(Color.terminalCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.terminalCyan.opacity(0.1))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.terminalCyan.opacity(0.3), lineWidth: 0.5)
                    )
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Enable/Disable toggle
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            )) {
                Text(isEnabled ? "Enabled for this project" : "Disabled for this project")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
            }
            .toggleStyle(.switch)

            Spacer()

            // Edit button (only for user/project skills)
            if isUserSkill, let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Skill", systemImage: "pencil")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            // Enable/Disable button
            Button {
                onToggle()
            } label: {
                Text(isEnabled ? "Disable" : "Enable")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(isEnabled ? Color.statusError : Color.statusSuccess)
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgElevated)
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Helpers

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

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
    }
}

// MARK: - Tool Badge

private struct ToolBadge: View {
    let name: String
    let isMissing: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isMissing ? "xmark.circle" : "checkmark.circle")
                .font(.system(size: 10))
            Text(name)
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundStyle(isMissing ? Color.statusError : Color.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isMissing ? Color.statusError.opacity(0.1) : Color.bgElevated)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isMissing ? Color.statusError.opacity(0.3) : Color.borderDefault, lineWidth: 0.5)
        )
    }
}

// MARK: - Detail Flow Layout

private struct DetailFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func calculateLayout(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return (CGSize(width: totalWidth, height: y + lineHeight), positions)
    }
}

// MARK: - Skill Preview Sheet

struct SkillPreviewSheet: View {
    let skill: Skill
    let cli: AgentType
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill Preview")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("How this skill appears to \(cli.displayName)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.md)

            Divider()

            // Preview content
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Simulated context injection
                    Text("# \(skill.name)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)

                    Text(generatePreviewContent())
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(4)
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.bgCanvas)
        }
        .frame(width: 500, height: 400)
        .background(Color.bgSurface)
    }

    private func generatePreviewContent() -> String {
        // Replace common placeholders with sample values
        var content = skill.promptTemplate
        content = content.replacingOccurrences(of: "{{context}}", with: "[Project context would be injected here]")
        content = content.replacingOccurrences(of: "{{worktree_path}}", with: "~/.xroads/worktrees/my-project/feat-new-feature")
        content = content.replacingOccurrences(of: "{{branch}}", with: "feat/new-feature")
        content = content.replacingOccurrences(of: "{{prd_path}}", with: "prd.json")
        content = content.replacingOccurrences(of: "{{assigned_stories}}", with: "US-001, US-002")
        return content
    }
}

// MARK: - Preview

#if DEBUG
struct SkillDetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        SkillDetailSheet(
            skill: Skill(
                id: "commit",
                name: "Git Commit",
                description: "Create git commits with conventional commit messages following project standards. Analyzes staged changes and generates appropriate commit messages based on the type of changes.",
                promptTemplate: "Analyze staged changes and create commit...\n\n## Context\n{{context}}\n\n## Worktree\n{{worktree_path}}",
                requiredTools: ["git", "file-read", "file-edit"],
                version: "1.2.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .git,
                author: "XRoads Team"
            ),
            isEnabled: true,
            isUserSkill: false,
            missingTools: [],
            onToggle: {},
            onEdit: nil,
            onDismiss: {}
        )
        .background(Color.bgApp)

        SkillDetailSheet(
            skill: Skill(
                id: "custom-lint",
                name: "Custom Linter",
                description: "User-defined linting rules for the project with custom configurations.",
                promptTemplate: "Run custom lint rules...",
                requiredTools: ["eslint", "prettier"],
                version: "0.1.0",
                compatibleCLIs: [.claude],
                category: .review,
                author: "User"
            ),
            isEnabled: false,
            isUserSkill: true,
            missingTools: ["eslint"],
            onToggle: {},
            onEdit: {},
            onDismiss: {}
        )
        .background(Color.bgApp)
    }
}
#endif
