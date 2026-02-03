import Foundation

/// Skill adapter for Claude Code CLI
/// Formats skill prompts according to Claude Code's expected conventions
struct ClaudeSkillAdapter: SkillAdapter {
    let agentType: AgentType = .claude

    // MARK: - Claude-Specific Formatting

    /// Claude Code prompt conventions:
    /// - Uses CLAUDE.md format with markdown sections
    /// - Supports XML-like tags for structured instructions: <command-name>, <example>, etc.
    /// - Prefers clear, structured prompts with bullet points
    /// - Supports tool use via MCP protocol
    /// - Uses {{placeholders}} for dynamic content

    func adaptSkill(_ skill: Skill, context: SkillContext) -> String {
        var prompt = skill.promptTemplate

        // Apply common placeholder replacements first
        prompt = replaceCommonPlaceholders(in: prompt, context: context)

        // Apply Claude-specific replacements
        prompt = replaceClaudePlaceholders(in: prompt, context: context)

        // Wrap in Claude's preferred format
        return formatForClaude(skill: skill, prompt: prompt, context: context)
    }

    func replacePlaceholders(in template: String, context: SkillContext) -> String {
        var result = replaceCommonPlaceholders(in: template, context: context)
        result = replaceClaudePlaceholders(in: result, context: context)
        return result
    }

    // MARK: - Private Helpers

    private func replaceClaudePlaceholders(in template: String, context: SkillContext) -> String {
        var result = template

        // Claude-specific placeholders
        result = result.replacingOccurrences(of: "{{claude_tools}}", with: claudeToolsSection())
        result = result.replacingOccurrences(of: "{{claude_style}}", with: claudeStyleGuidelines())
        result = result.replacingOccurrences(of: "{{thinking_mode}}", with: claudeThinkingMode(context: context))

        // Replace {{mcp_endpoint}} if present
        result = result.replacingOccurrences(of: "{{mcp_endpoint}}", with: "stdio")

        return result
    }

    private func formatForClaude(skill: Skill, prompt: String, context: SkillContext) -> String {
        var sections: [String] = []

        // Skill header with metadata
        sections.append("""
            ## \(skill.name)

            > **Skill ID**: `\(skill.id)` | **Version**: \(skill.version)
            """)

        // Required tools notice if applicable
        if !skill.requiredTools.isEmpty {
            sections.append("""

                **Required Tools**: \(skill.requiredTools.joined(separator: ", "))
                """)
        }

        // Main prompt content
        sections.append("""

            ### Instructions

            \(prompt)
            """)

        // Claude-specific execution hints
        sections.append(claudeExecutionHints(context: context))

        return sections.joined(separator: "\n")
    }

    private func claudeToolsSection() -> String {
        """
        Available Claude Code tools:
        - Read: Read files from the filesystem
        - Write: Create or overwrite files
        - Edit: Make targeted edits to files
        - Bash: Execute shell commands
        - Glob: Find files by pattern
        - Grep: Search file contents
        - Task: Launch sub-agents for complex tasks
        - WebFetch: Fetch web content
        - WebSearch: Search the web
        """
    }

    private func claudeStyleGuidelines() -> String {
        """
        Style Guidelines for Claude Code:
        - Keep responses concise and actionable
        - Use markdown formatting for readability
        - Prefer editing existing files over creating new ones
        - Run builds/tests after making changes
        - Commit changes with descriptive messages
        """
    }

    private func claudeThinkingMode(context: SkillContext) -> String {
        if context.assignedStories.count > 1 {
            return "Use extended thinking for multi-story tasks"
        }
        return "Standard execution mode"
    }

    private func claudeExecutionHints(context: SkillContext) -> String {
        var hints: [String] = []

        hints.append("### Execution Notes")
        hints.append("")
        hints.append("- Use TodoWrite to track progress on multi-step tasks")
        hints.append("- Read files before editing to understand existing code")
        hints.append("- Run `swift build` (or project's build command) to verify changes")

        if !context.assignedStories.isEmpty {
            hints.append("- Mark stories complete in prd.json as you finish them")
        }

        if context.coordinationNotes != nil {
            hints.append("- Coordinate with other agents via notes/ directory")
        }

        return hints.joined(separator: "\n")
    }
}
