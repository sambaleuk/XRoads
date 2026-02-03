import Foundation

/// Protocol for adapting skill prompts to different CLI formats
/// Each CLI (Claude, Gemini, Codex) has its own prompt conventions and expectations
protocol SkillAdapter: Sendable {
    /// The agent type this adapter handles
    var agentType: AgentType { get }

    /// Adapt a skill for the target CLI format
    /// - Parameters:
    ///   - skill: The skill to adapt
    ///   - context: Context for placeholder replacement
    /// - Returns: Adapted skill prompt string
    func adaptSkill(_ skill: Skill, context: SkillContext) -> String

    /// Adapt multiple skills for the target CLI format
    /// - Parameters:
    ///   - skills: Array of skills to adapt
    ///   - context: Context for placeholder replacement
    /// - Returns: Combined adapted prompts
    func adaptSkills(_ skills: [Skill], context: SkillContext) -> String

    /// Replace CLI-specific placeholders in a template
    /// - Parameters:
    ///   - template: The template string with {{placeholders}}
    ///   - context: Context for replacement values
    /// - Returns: Template with placeholders replaced
    func replacePlaceholders(in template: String, context: SkillContext) -> String
}

// MARK: - Default Implementation

extension SkillAdapter {
    /// Default implementation for adapting multiple skills
    func adaptSkills(_ skills: [Skill], context: SkillContext) -> String {
        skills.map { adaptSkill($0, context: context) }
            .joined(separator: "\n\n---\n\n")
    }

    /// Common placeholders shared across all CLIs
    func replaceCommonPlaceholders(in template: String, context: SkillContext) -> String {
        var result = template

        // Context placeholder
        result = result.replacingOccurrences(of: "{{context}}", with: context.toContextString())

        // Agent placeholders
        result = result.replacingOccurrences(of: "{{agent_type}}", with: context.agentType.rawValue)
        result = result.replacingOccurrences(of: "{{agent_name}}", with: context.agentType.displayName)

        // Path placeholders
        result = result.replacingOccurrences(of: "{{branch}}", with: context.branch ?? "main")
        result = result.replacingOccurrences(of: "{{worktree_path}}", with: context.worktreePath ?? "")

        if let prd = context.prdPath {
            result = result.replacingOccurrences(of: "{{prd_path}}", with: prd)
        }

        if let session = context.sessionID {
            result = result.replacingOccurrences(of: "{{session_id}}", with: session)
        }

        // Stories placeholder
        let storiesList = context.assignedStories.joined(separator: ", ")
        result = result.replacingOccurrences(of: "{{assigned_stories}}", with: storiesList)

        // Task placeholder
        if let task = context.taskDescription {
            result = result.replacingOccurrences(of: "{{task}}", with: task)
        }

        // Custom context placeholders
        for (key, value) in context.customContext {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return result
    }
}

// MARK: - SkillAdapterError

/// Errors that can occur during skill adaptation
enum SkillAdapterError: Error, LocalizedError {
    case unsupportedCLI(AgentType)
    case invalidTemplate(reason: String)
    case missingRequiredPlaceholder(placeholder: String)
    case adaptationFailed(skillID: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCLI(let cliType):
            return "Unsupported CLI type for skill adaptation: \(cliType.displayName)"
        case .invalidTemplate(let reason):
            return "Invalid skill template: \(reason)"
        case .missingRequiredPlaceholder(let placeholder):
            return "Missing required placeholder: {{\(placeholder)}}"
        case .adaptationFailed(let skillID, let reason):
            return "Failed to adapt skill '\(skillID)': \(reason)"
        }
    }
}

// MARK: - SkillAdapterFactory

/// Factory for creating appropriate skill adapters
struct SkillAdapterFactory {
    /// Get the appropriate adapter for an agent type
    /// - Parameter agentType: The CLI agent type
    /// - Returns: The corresponding skill adapter
    static func adapter(for agentType: AgentType) -> SkillAdapter {
        switch agentType {
        case .claude:
            return ClaudeSkillAdapter()
        case .gemini:
            return GeminiSkillAdapter()
        case .codex:
            return CodexSkillAdapter()
        }
    }

    /// Adapt a skill for a specific CLI
    /// - Parameters:
    ///   - skill: The skill to adapt
    ///   - agentType: Target CLI type
    ///   - context: Context for rendering
    /// - Returns: Adapted skill prompt
    static func adaptSkill(_ skill: Skill, for agentType: AgentType, context: SkillContext) -> String {
        let adapter = self.adapter(for: agentType)
        return adapter.adaptSkill(skill, context: context)
    }

    /// Adapt multiple skills for a specific CLI
    /// - Parameters:
    ///   - skills: Skills to adapt
    ///   - agentType: Target CLI type
    ///   - context: Context for rendering
    /// - Returns: Combined adapted prompts
    static func adaptSkills(_ skills: [Skill], for agentType: AgentType, context: SkillContext) -> String {
        let adapter = self.adapter(for: agentType)
        return adapter.adaptSkills(skills, context: context)
    }
}

// MARK: - AdaptedSkill

/// Wrapper for a skill that has been adapted for a specific CLI
struct AdaptedSkill: Sendable {
    /// The original skill
    let skill: Skill

    /// The target CLI type
    let targetCLI: AgentType

    /// The adapted prompt content
    let adaptedPrompt: String

    /// Timestamp when adaptation occurred
    let adaptedAt: Date

    init(skill: Skill, targetCLI: AgentType, adaptedPrompt: String) {
        self.skill = skill
        self.targetCLI = targetCLI
        self.adaptedPrompt = adaptedPrompt
        self.adaptedAt = Date()
    }
}
