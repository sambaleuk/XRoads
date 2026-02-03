import Foundation

/// Skill adapter for OpenAI Codex CLI
/// Formats skill prompts according to Codex CLI's expected conventions
struct CodexSkillAdapter: SkillAdapter {
    let agentType: AgentType = .codex

    // MARK: - Codex-Specific Formatting

    /// Codex CLI prompt conventions:
    /// - Uses AGENTS.md in project root
    /// - Prefers concise, direct instructions
    /// - Supports full-auto approval mode for autonomous operation
    /// - Has built-in code generation and editing capabilities
    /// - Uses {{placeholders}} for dynamic content

    func adaptSkill(_ skill: Skill, context: SkillContext) -> String {
        var prompt = skill.promptTemplate

        // Apply common placeholder replacements first
        prompt = replaceCommonPlaceholders(in: prompt, context: context)

        // Apply Codex-specific replacements
        prompt = replaceCodexPlaceholders(in: prompt, context: context)

        // Wrap in Codex's preferred format
        return formatForCodex(skill: skill, prompt: prompt, context: context)
    }

    func replacePlaceholders(in template: String, context: SkillContext) -> String {
        var result = replaceCommonPlaceholders(in: template, context: context)
        result = replaceCodexPlaceholders(in: result, context: context)
        return result
    }

    // MARK: - Private Helpers

    private func replaceCodexPlaceholders(in template: String, context: SkillContext) -> String {
        var result = template

        // Codex-specific placeholders
        result = result.replacingOccurrences(of: "{{codex_tools}}", with: codexToolsSection())
        result = result.replacingOccurrences(of: "{{codex_style}}", with: codexStyleGuidelines())
        result = result.replacingOccurrences(of: "{{approval_mode}}", with: codexApprovalMode(context: context))

        // Codex uses approval mode setting
        result = result.replacingOccurrences(of: "{{auto_approve}}", with: "full-auto")

        return result
    }

    private func formatForCodex(skill: Skill, prompt: String, context: SkillContext) -> String {
        var sections: [String] = []

        // Skill header with Codex's concise style
        sections.append("""
            ## \(skill.name)
            `\(skill.id)` v\(skill.version)
            """)

        // Required tools as inline list
        if !skill.requiredTools.isEmpty {
            sections.append("""

                **Tools**: \(skill.requiredTools.joined(separator: " | "))
                """)
        }

        // Main instructions - Codex prefers more direct style
        sections.append("""

            ### Instructions

            \(prompt)
            """)

        // Codex-specific constraints
        sections.append(codexConstraintsSection(context: context))

        return sections.joined(separator: "\n")
    }

    private func codexToolsSection() -> String {
        """
        Codex CLI capabilities:
        - Code generation and modification
        - File system operations
        - Shell command execution
        - Git integration
        - Test execution
        """
    }

    private func codexStyleGuidelines() -> String {
        """
        Codex Style Guidelines:
        - Write clean, idiomatic code
        - Follow existing patterns in the codebase
        - Include inline comments for complex logic
        - Run tests before committing
        - Keep changes focused and atomic
        """
    }

    private func codexApprovalMode(context: SkillContext) -> String {
        // In XRoads orchestration, we typically use full-auto
        if context.coordinationNotes != nil {
            return "full-auto"
        }
        return "suggest"
    }

    private func codexConstraintsSection(context: SkillContext) -> String {
        var constraints: [String] = []

        constraints.append("### Constraints")
        constraints.append("")

        // Codex-specific constraints
        constraints.append("- Work within the assigned worktree only")
        constraints.append("- Do not modify files outside the project scope")
        constraints.append("- Verify changes compile before marking complete")

        if !context.assignedStories.isEmpty {
            constraints.append("- Focus only on assigned stories: \(context.assignedStories.joined(separator: ", "))")
        }

        if context.branch != nil {
            constraints.append("- Commit to branch: \(context.branch!)")
        }

        // Add output expectations
        constraints.append("")
        constraints.append("### Expected Output")
        constraints.append("")
        constraints.append("On completion, ensure:")
        constraints.append("- All changes are committed")
        constraints.append("- Build passes successfully")
        constraints.append("- Tests pass (if applicable)")

        return constraints.joined(separator: "\n")
    }
}
