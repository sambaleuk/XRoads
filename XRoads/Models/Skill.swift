import Foundation

/// Represents a packaged skill/capability that can be loaded by actions
/// Skills define prompt templates and tool requirements for specific tasks
struct Skill: Codable, Hashable, Sendable, Identifiable {
    /// Unique identifier for the skill (e.g., "commit", "code-reviewer")
    let id: String

    /// Human-readable display name
    let name: String

    /// Description of what this skill does
    let description: String

    /// Prompt template with {{placeholders}} for dynamic content injection
    let promptTemplate: String

    /// Tools/capabilities required by this skill (e.g., ["git", "file-edit"])
    let requiredTools: [String]

    /// Version string for skill updates (semver format)
    let version: String

    /// CLI compatibility flags - which agents can use this skill
    let compatibleCLIs: Set<AgentType>

    /// Optional category for grouping skills
    let category: SkillCategory?

    /// Optional author/source information
    let author: String?

    /// Create a skill with all parameters
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Display name
    ///   - description: What this skill does
    ///   - promptTemplate: Template with {{placeholders}}
    ///   - requiredTools: Required tool capabilities
    ///   - version: Semantic version string
    ///   - compatibleCLIs: CLIs that support this skill (empty = all)
    ///   - category: Optional category
    ///   - author: Optional author/source
    init(
        id: String,
        name: String,
        description: String,
        promptTemplate: String,
        requiredTools: [String] = [],
        version: String = "1.0.0",
        compatibleCLIs: Set<AgentType> = Set(AgentType.allCases),
        category: SkillCategory? = nil,
        author: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.promptTemplate = promptTemplate
        self.requiredTools = requiredTools
        self.version = version
        self.compatibleCLIs = compatibleCLIs
        self.category = category
        self.author = author
    }

    /// Check if this skill is compatible with a specific CLI
    /// - Parameter cliType: The CLI agent type to check
    /// - Returns: True if compatible (empty compatibleCLIs means all CLIs)
    func isCompatible(with cliType: AgentType) -> Bool {
        compatibleCLIs.isEmpty || compatibleCLIs.contains(cliType)
    }

    /// Check if all required tools are available
    /// - Parameter availableTools: Set of available tool identifiers
    /// - Returns: True if all required tools are available
    func hasRequiredTools(available availableTools: Set<String>) -> Bool {
        requiredTools.allSatisfy { availableTools.contains($0) }
    }

    /// Get list of missing tools
    /// - Parameter availableTools: Set of available tool identifiers
    /// - Returns: Array of missing tool identifiers
    func missingTools(from availableTools: Set<String>) -> [String] {
        requiredTools.filter { !availableTools.contains($0) }
    }
}

// MARK: - SkillCategory

/// Categories for grouping skills in the UI
enum SkillCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case git
    case code
    case test
    case docs
    case review
    case custom

    var displayName: String {
        switch self {
        case .git: return "Git Operations"
        case .code: return "Code Generation"
        case .test: return "Testing"
        case .docs: return "Documentation"
        case .review: return "Code Review"
        case .custom: return "Custom"
        }
    }

    var iconName: String {
        switch self {
        case .git: return "arrow.triangle.branch"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .test: return "testtube.2"
        case .docs: return "doc.text"
        case .review: return "eye"
        case .custom: return "gearshape"
        }
    }
}

// MARK: - SkillFile

/// Represents a skill file loaded from disk (JSON format)
/// Used for parsing ~/.xroads/skills/*.skill.json files
struct SkillFile: Codable {
    let id: String
    let name: String
    let description: String
    let promptTemplate: String
    let requiredTools: [String]?
    let version: String?
    let compatibleCLIs: [String]?
    let category: String?
    let author: String?

    /// Convert to Skill model
    func toSkill() -> Skill {
        let cliSet: Set<AgentType>
        if let clis = compatibleCLIs {
            cliSet = Set(clis.compactMap { AgentType(rawValue: $0) })
        } else {
            cliSet = Set(AgentType.allCases)
        }

        let skillCategory: SkillCategory?
        if let cat = category {
            skillCategory = SkillCategory(rawValue: cat)
        } else {
            skillCategory = nil
        }

        return Skill(
            id: id,
            name: name,
            description: description,
            promptTemplate: promptTemplate,
            requiredTools: requiredTools ?? [],
            version: version ?? "1.0.0",
            compatibleCLIs: cliSet,
            category: skillCategory,
            author: author
        )
    }
}

// MARK: - SkillLoadError

/// Errors that can occur when loading skills
enum SkillLoadError: Error, LocalizedError {
    case fileNotFound(path: String)
    case invalidJSON(path: String, underlyingError: Error)
    case invalidSkillFormat(path: String, reason: String)
    case duplicateSkillID(id: String)
    case directoryNotFound(path: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Skill file not found: \(path)"
        case .invalidJSON(let path, let error):
            return "Invalid JSON in skill file \(path): \(error.localizedDescription)"
        case .invalidSkillFormat(let path, let reason):
            return "Invalid skill format in \(path): \(reason)"
        case .duplicateSkillID(let id):
            return "Duplicate skill ID: \(id)"
        case .directoryNotFound(let path):
            return "Skills directory not found: \(path)"
        }
    }
}
