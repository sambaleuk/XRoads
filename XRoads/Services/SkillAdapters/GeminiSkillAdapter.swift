import Foundation

/// Skill adapter for Gemini CLI
/// Formats skill prompts according to Gemini CLI's expected conventions
struct GeminiSkillAdapter: SkillAdapter {
    let agentType: AgentType = .gemini

    // MARK: - Gemini-Specific Formatting

    /// Gemini CLI prompt conventions:
    /// - Uses GEMINI.md or instructions in project root
    /// - Supports structured prompts with clear sections
    /// - Prefers numbered steps for complex tasks
    /// - Has file operation capabilities via built-in tools
    /// - Uses {{placeholders}} for dynamic content

    func adaptSkill(_ skill: Skill, context: SkillContext) -> String {
        var prompt = skill.promptTemplate

        // Apply common placeholder replacements first
        prompt = replaceCommonPlaceholders(in: prompt, context: context)

        // Apply Gemini-specific replacements
        prompt = replaceGeminiPlaceholders(in: prompt, context: context)

        // Wrap in Gemini's preferred format
        return formatForGemini(skill: skill, prompt: prompt, context: context)
    }

    func replacePlaceholders(in template: String, context: SkillContext) -> String {
        var result = replaceCommonPlaceholders(in: template, context: context)
        result = replaceGeminiPlaceholders(in: result, context: context)
        return result
    }

    // MARK: - Private Helpers

    private func replaceGeminiPlaceholders(in template: String, context: SkillContext) -> String {
        var result = template

        // Gemini-specific placeholders
        result = result.replacingOccurrences(of: "{{gemini_tools}}", with: geminiToolsSection())
        result = result.replacingOccurrences(of: "{{gemini_style}}", with: geminiStyleGuidelines())
        result = result.replacingOccurrences(of: "{{execution_mode}}", with: geminiExecutionMode(context: context))

        // Gemini uses sandbox mode setting
        result = result.replacingOccurrences(of: "{{sandbox_mode}}", with: "disabled")

        return result
    }

    private func formatForGemini(skill: Skill, prompt: String, context: SkillContext) -> String {
        var sections: [String] = []

        // Skill header with Gemini-style formatting
        sections.append("""
            # \(skill.name)

            **Skill**: `\(skill.id)` (v\(skill.version))
            """)

        // Required capabilities notice
        if !skill.requiredTools.isEmpty {
            sections.append("""

                ## Required Capabilities

                \(skill.requiredTools.map { "- \($0)" }.joined(separator: "\n"))
                """)
        }

        // Main instructions with Gemini's preferred numbered format
        sections.append("""

            ## Task Instructions

            \(prompt)
            """)

        // Gemini-specific workflow hints
        sections.append(geminiWorkflowSection(context: context))

        return sections.joined(separator: "\n")
    }

    private func geminiToolsSection() -> String {
        """
        Available Gemini CLI capabilities:
        - File reading and writing
        - Directory navigation and listing
        - Shell command execution
        - Code search and analysis
        - Git operations
        - Web browsing (limited)
        """
    }

    private func geminiStyleGuidelines() -> String {
        """
        Style Guidelines for Gemini CLI:
        - Provide clear, step-by-step instructions
        - Use numbered lists for sequential operations
        - Include expected outcomes for verification
        - Handle errors gracefully with fallback approaches
        - Document changes in commit messages
        """
    }

    private func geminiExecutionMode(context: SkillContext) -> String {
        if context.assignedStories.count > 3 {
            return "batch"
        } else if context.assignedStories.count > 1 {
            return "sequential"
        }
        return "single"
    }

    private func geminiWorkflowSection(context: SkillContext) -> String {
        var workflow: [String] = []

        workflow.append("## Workflow")
        workflow.append("")
        workflow.append("Follow these steps to complete the task:")
        workflow.append("")

        var stepNum = 1

        workflow.append("\(stepNum). **Analyze** - Review the current state and requirements")
        stepNum += 1

        if !context.assignedStories.isEmpty {
            workflow.append("\(stepNum). **Plan** - Break down stories into implementation steps")
            stepNum += 1
        }

        workflow.append("\(stepNum). **Implement** - Make the necessary code changes")
        stepNum += 1

        workflow.append("\(stepNum). **Verify** - Run tests and ensure code compiles")
        stepNum += 1

        workflow.append("\(stepNum). **Commit** - Save changes with descriptive message")
        stepNum += 1

        if context.coordinationNotes != nil {
            workflow.append("\(stepNum). **Coordinate** - Update notes/ for other agents")
        }

        return workflow.joined(separator: "\n")
    }
}
