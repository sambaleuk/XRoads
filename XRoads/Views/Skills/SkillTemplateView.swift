//
//  SkillTemplateView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-017: Template view component showing CLI-specific skill templates
//

import SwiftUI

// MARK: - SkillTemplateTabView

/// Tab view showing skill templates adapted for different CLIs
/// Each tab displays how the skill prompt would appear for that CLI
struct SkillTemplateTabView: View {
    let skill: Skill
    @Binding var selectedCLI: AgentType

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // CLI Tabs
            HStack(spacing: 0) {
                ForEach(AgentType.allCases, id: \.self) { cli in
                    CLITabButton(
                        cli: cli,
                        isSelected: selectedCLI == cli,
                        isCompatible: skill.isCompatible(with: cli),
                        action: { selectedCLI = cli }
                    )
                }

                Spacer()
            }

            // Template content
            SkillTemplateContent(
                skill: skill,
                cli: selectedCLI
            )
        }
    }
}

// MARK: - CLI Tab Button

private struct CLITabButton: View {
    let cli: AgentType
    let isSelected: Bool
    let isCompatible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: cli.iconName)
                    .font(.system(size: 11))
                Text(cli.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))

                if !isCompatible {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.statusWarning)
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    if isSelected {
                        Rectangle()
                            .fill(cli.neonColor)
                            .frame(height: 2)
                    }
                }
            )
            .background(isSelected ? cli.neonColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(!isCompatible)
        .opacity(isCompatible ? 1.0 : 0.5)
    }

    private var foregroundColor: Color {
        if isSelected {
            return cli.neonColor
        } else if isCompatible {
            return Color.textSecondary
        } else {
            return Color.textTertiary
        }
    }
}

// MARK: - Skill Template Content

/// Displays the adapted template content for a specific CLI
struct SkillTemplateContent: View {
    let skill: Skill
    let cli: AgentType

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Compatibility notice
            if !skill.isCompatible(with: cli) {
                incompatibilityNotice
            }

            // Template preview
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Adapted Template")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)

                    Spacer()

                    // Copy button
                    Button {
                        copyToClipboard(adaptedTemplate)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)

                    // Expand/collapse
                    Button {
                        withAnimation(.easeInOut(duration: Theme.Animation.normal)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Color.bgElevated)

                // Code content
                ScrollView(.vertical, showsIndicators: true) {
                    Text(adaptedTemplate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.sm)
                }
                .frame(height: isExpanded ? 300 : 150)
                .background(Color.bgCanvas)
            }
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Color.borderMuted, lineWidth: 1)
            )

            // CLI-specific notes
            cliSpecificNotes
        }
    }

    // MARK: - Computed Properties

    private var adaptedTemplate: String {
        // Use the skill adapter to generate CLI-specific template
        let adapter = SkillAdapterFactory.adapter(for: cli)
        let context = SkillContext(
            agentType: cli,
            worktreePath: "{{worktree_path}}",
            branch: "{{branch}}",
            prdPath: "prd.json",
            sessionID: nil,
            assignedStories: [],
            taskDescription: nil,
            coordinationNotes: nil,
            completionCriteria: nil,
            customContext: ["project_name": "{{project_name}}"]
        )

        return adapter.adaptSkill(skill, context: context)
    }

    // MARK: - Subviews

    private var incompatibilityNotice: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text("This skill is not compatible with \(cli.displayName). The template shown is a best-effort adaptation.")
                .font(.system(size: 11))
        }
        .foregroundStyle(Color.statusWarning)
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.statusWarning.opacity(0.1))
        .cornerRadius(Theme.Radius.sm)
    }

    private var cliSpecificNotes: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("\(cli.displayName) Notes")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.textTertiary)

            Text(notesForCLI)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgElevated)
        .cornerRadius(Theme.Radius.sm)
    }

    private var notesForCLI: String {
        switch cli {
        case .claude:
            return "Claude uses TodoWrite for task tracking and prefers structured markdown sections. It has access to Read, Edit, Write, and Bash tools."
        case .gemini:
            return "Gemini CLI uses numbered workflow steps and execution modes (single/sequential/batch). It processes tasks with Analyze/Plan/Implement/Verify/Commit phases."
        case .codex:
            return "Codex prefers concise instructions with inline tool specifications. It operates with suggest/full-auto approval modes and respects worktree boundaries."
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Preview

#if DEBUG
struct SkillTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SkillTemplateTabView(
                skill: Skill(
                    id: "prd",
                    name: "PRD Implementation",
                    description: "Implement user stories from a PRD file",
                    promptTemplate: """
                    ## Purpose
                    Implement user stories from prd.json with mandatory unit tests.

                    ## Workflow
                    1. Read PRD: Parse `{{prd_path}}` or `prd.json`
                    2. Find Next Story: Get first story with status != "complete"
                    3. Implement Story
                    4. Write Unit Test
                    5. Run & Verify

                    ## Context
                    {{context}}

                    ## Worktree
                    {{worktree_path}}
                    """,
                    requiredTools: ["git", "file-read", "file-edit"],
                    version: "1.0.0",
                    compatibleCLIs: Set(AgentType.allCases),
                    category: .code,
                    author: "XRoads Team"
                ),
                selectedCLI: .constant(.claude)
            )
            .padding()
        }
        .frame(width: 550)
        .background(Color.bgSurface)
    }
}
#endif
