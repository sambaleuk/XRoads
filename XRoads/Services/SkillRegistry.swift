import Foundation

/// Registry for managing available skills
/// Loads skills from bundled resources and user's ~/.xroads/skills/ directory
actor SkillRegistry {
    /// Singleton instance for app-wide access
    static let shared = SkillRegistry()

    /// User skills directory path
    private static let userSkillsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".xroads/skills").path
    }()

    /// All loaded skills indexed by ID
    private var skills: [String: Skill] = [:]

    /// Track which skills are user-provided vs bundled
    private var userSkillIDs: Set<String> = []

    /// Track load errors for diagnostics
    private var loadErrors: [SkillLoadError] = []

    /// Whether the registry has been initialized
    private var isInitialized: Bool = false

    // MARK: - Initialization

    init() {}

    /// Initialize the registry by loading bundled and user skills
    /// Call this once at app startup
    func initialize() async {
        guard !isInitialized else { return }

        // Load bundled skills first (they can be overridden by user skills)
        loadBundledSkills()

        // Load user skills from ~/.xroads/skills/
        await loadUserSkills()

        isInitialized = true
    }

    /// Force reload all skills
    func reload() async {
        skills.removeAll()
        userSkillIDs.removeAll()
        loadErrors.removeAll()
        isInitialized = false
        await initialize()
    }

    // MARK: - Skill Queries

    /// Get a skill by ID
    /// - Parameter id: The skill identifier
    /// - Returns: The skill if found
    func skill(byID id: String) -> Skill? {
        skills[id]
    }

    /// Get all available skills
    /// - Returns: Array of all loaded skills
    func allSkills() -> [Skill] {
        Array(skills.values).sorted { $0.id < $1.id }
    }

    /// Get skills compatible with a specific CLI
    /// - Parameter cliType: The CLI agent type
    /// - Returns: Array of compatible skills
    func skills(for cliType: AgentType) -> [Skill] {
        skills.values.filter { $0.isCompatible(with: cliType) }
            .sorted { $0.id < $1.id }
    }

    /// Get skills in a specific category
    /// - Parameter category: The skill category
    /// - Returns: Array of skills in that category
    func skills(in category: SkillCategory) -> [Skill] {
        skills.values.filter { $0.category == category }
            .sorted { $0.id < $1.id }
    }

    /// Get skills by multiple IDs
    /// - Parameter ids: Array of skill IDs to fetch
    /// - Returns: Array of found skills (missing IDs are skipped)
    func skills(byIDs ids: [String]) -> [Skill] {
        ids.compactMap { skills[$0] }
    }

    /// Check if a skill exists
    /// - Parameter id: The skill identifier
    /// - Returns: True if the skill exists
    func hasSkill(_ id: String) -> Bool {
        skills[id] != nil
    }

    /// Get all skill IDs
    /// - Returns: Array of all loaded skill IDs
    func allSkillIDs() -> [String] {
        Array(skills.keys).sorted()
    }

    /// Check if a skill is user-provided (not bundled)
    /// - Parameter id: The skill identifier
    /// - Returns: True if user-provided
    func isUserSkill(_ id: String) -> Bool {
        userSkillIDs.contains(id)
    }

    /// Get any load errors that occurred during initialization
    /// - Returns: Array of load errors
    func getLoadErrors() -> [SkillLoadError] {
        loadErrors
    }

    // MARK: - Skill Registration

    /// Register a skill (used for user-defined or runtime skills)
    /// - Parameter skill: The skill to register
    /// - Returns: True if registered successfully, false if duplicate exists
    @discardableResult
    func registerSkill(_ skill: Skill) -> Bool {
        if skills[skill.id] != nil {
            loadErrors.append(.duplicateSkillID(id: skill.id))
            return false
        }
        skills[skill.id] = skill
        return true
    }

    /// Register a skill from user directory (can override bundled)
    /// - Parameter skill: The skill to register
    func registerUserSkill(_ skill: Skill) {
        skills[skill.id] = skill
        userSkillIDs.insert(skill.id)
    }

    /// Remove a user skill (bundled skills cannot be removed)
    /// - Parameter id: The skill ID to remove
    /// - Returns: True if removed
    @discardableResult
    func removeUserSkill(_ id: String) -> Bool {
        guard userSkillIDs.contains(id) else { return false }
        skills.removeValue(forKey: id)
        userSkillIDs.remove(id)
        return true
    }

    // MARK: - Private Loading Methods

    /// Load bundled skills from the app's resources
    private func loadBundledSkills() {
        // Define bundled skills inline (will be replaced by JSON resources in US-V3-008)
        let bundledSkills = createBundledSkills()
        for skill in bundledSkills {
            skills[skill.id] = skill
        }
    }

    /// Load user skills from ~/.xroads/skills/
    private func loadUserSkills() async {
        let fileManager = FileManager.default
        let skillsPath = Self.userSkillsPath

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: skillsPath) {
            do {
                try fileManager.createDirectory(
                    atPath: skillsPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                // Directory creation failed, but not critical
                return
            }
        }

        // Find all .skill.json files
        guard let contents = try? fileManager.contentsOfDirectory(atPath: skillsPath) else {
            return
        }

        let skillFiles = contents.filter { $0.hasSuffix(".skill.json") }

        for filename in skillFiles {
            let filePath = (skillsPath as NSString).appendingPathComponent(filename)
            do {
                let skill = try loadSkillFromFile(path: filePath)
                registerUserSkill(skill)
            } catch let error as SkillLoadError {
                loadErrors.append(error)
            } catch {
                loadErrors.append(.invalidJSON(path: filePath, underlyingError: error))
            }
        }
    }

    /// Load a skill from a JSON file
    /// - Parameter path: Path to the .skill.json file
    /// - Returns: The parsed Skill
    private func loadSkillFromFile(path: String) throws -> Skill {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            throw SkillLoadError.fileNotFound(path: path)
        }

        guard let data = fileManager.contents(atPath: path) else {
            throw SkillLoadError.fileNotFound(path: path)
        }

        do {
            let decoder = JSONDecoder()
            let skillFile = try decoder.decode(SkillFile.self, from: data)
            return skillFile.toSkill()
        } catch {
            throw SkillLoadError.invalidJSON(path: path, underlyingError: error)
        }
    }

    /// Create the set of bundled default skills
    /// These will be replaced by actual JSON resources in US-V3-008
    private func createBundledSkills() -> [Skill] {
        [
            Skill(
                id: "commit",
                name: "Commit",
                description: "Create git commits with conventional commit messages",
                promptTemplate: """
                    You are a git commit assistant. Follow these rules:
                    1. Use conventional commit format: type(scope): description
                    2. Keep the first line under 72 characters
                    3. Add detailed body if needed
                    4. Reference issues when applicable

                    {{context}}
                    """,
                requiredTools: ["git"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .git,
                author: "XRoads"
            ),
            Skill(
                id: "code-writer",
                name: "Code Writer",
                description: "Generate code following project conventions and best practices",
                promptTemplate: """
                    You are a code generation assistant. Follow these rules:
                    1. Match existing code style and patterns
                    2. Include appropriate error handling
                    3. Write self-documenting code
                    4. Add comments only where necessary

                    {{context}}
                    """,
                requiredTools: ["file-edit", "file-read"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .code,
                author: "XRoads"
            ),
            Skill(
                id: "code-reviewer",
                name: "Code Reviewer",
                description: "Review code for issues, bugs, and improvements",
                promptTemplate: """
                    You are a code review assistant. Analyze code for:
                    1. Bugs and potential issues
                    2. Security vulnerabilities
                    3. Performance problems
                    4. Code style violations
                    5. Best practice adherence

                    Provide actionable feedback with specific line references.

                    {{context}}
                    """,
                requiredTools: ["file-read", "git"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .review,
                author: "XRoads"
            ),
            Skill(
                id: "prd",
                name: "PRD Parser",
                description: "Parse and execute PRD user stories",
                promptTemplate: """
                    You are implementing features from a PRD. Follow these rules:
                    1. Read prd.json and find the first incomplete user story
                    2. Implement exactly ONE story per iteration
                    3. Include unit tests with the implementation
                    4. Update prd.json status when complete
                    5. Commit with format: feat(scope): US-XXX description

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit", "git"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .code,
                author: "XRoads"
            ),
            Skill(
                id: "doc-generator",
                name: "Documentation Generator",
                description: "Generate comprehensive documentation",
                promptTemplate: """
                    You are a documentation assistant. Create documentation that:
                    1. Is clear and concise
                    2. Includes code examples where appropriate
                    3. Covers API usage and parameters
                    4. Documents edge cases and error handling

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .docs,
                author: "XRoads"
            ),
            Skill(
                id: "lint",
                name: "Linter",
                description: "Check code for style and formatting issues",
                promptTemplate: """
                    You are a code linting assistant. Check for:
                    1. Formatting consistency
                    2. Naming conventions
                    3. Import organization
                    4. Trailing whitespace and line lengths

                    {{context}}
                    """,
                requiredTools: ["file-read"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .review,
                author: "XRoads"
            ),
            Skill(
                id: "integration-test",
                name: "Integration Test Writer",
                description: "Generate integration tests for service boundaries",
                promptTemplate: """
                    You are an integration test assistant. Create tests that:
                    1. Test service boundaries and interfaces
                    2. Mock external dependencies appropriately
                    3. Verify data flow between components
                    4. Cover error scenarios

                    Do NOT write unit tests - those belong with the implementation.

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .test,
                author: "XRoads"
            ),
            Skill(
                id: "e2e-test",
                name: "E2E Test Writer",
                description: "Generate end-to-end tests for user flows",
                promptTemplate: """
                    You are an E2E test assistant. Create tests that:
                    1. Simulate real user interactions
                    2. Cover critical user journeys
                    3. Verify full system behavior
                    4. Handle async operations properly

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .test,
                author: "XRoads"
            ),
            Skill(
                id: "perf-test",
                name: "Performance Test Writer",
                description: "Generate performance and load tests",
                promptTemplate: """
                    You are a performance test assistant. Create tests that:
                    1. Measure response times and throughput
                    2. Identify bottlenecks
                    3. Test under load conditions
                    4. Verify memory usage patterns

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .test,
                author: "XRoads"
            )
        ]
    }
}

// MARK: - SkillRegistry Path Access

extension SkillRegistry {
    /// Get the user skills directory path
    static var userSkillsDirectory: String {
        userSkillsPath
    }
}
