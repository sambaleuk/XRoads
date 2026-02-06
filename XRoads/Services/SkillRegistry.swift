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

    // MARK: - Bundled Skills

    /// List of bundled skill IDs that come with the app
    static let bundledSkillIDs: [String] = [
        "commit",
        "review-pr",
        "prd",
        "art-director",
        "integration-test",
        "code-reviewer",
        "context-handoff"
    ]

    // MARK: - Private Loading Methods

    /// Load bundled skills from the app's resources
    private func loadBundledSkills() {
        // First try to load from bundled JSON resources
        let loadedFromJSON = loadBundledSkillsFromJSON()

        // If no JSON skills loaded (resources not available), fall back to inline definitions
        if loadedFromJSON.isEmpty {
            let fallbackSkills = createBundledSkills()
            for skill in fallbackSkills {
                skills[skill.id] = skill
            }
        } else {
            for skill in loadedFromJSON {
                skills[skill.id] = skill
            }
        }
    }

    /// Load bundled skills from JSON resource files
    /// Searches multiple locations: Bundle resources, executable directory, and working directory
    /// - Returns: Array of loaded skills (empty if resources not available)
    private func loadBundledSkillsFromJSON() -> [Skill] {
        var loadedSkills: [Skill] = []

        // Try to find the bundled Skills directory in multiple locations
        let resourceURL = findBundledSkillsDirectory()
        guard let skillsDir = resourceURL else {
            // Resources not available - will use fallback inline definitions
            return []
        }

        let fileManager = FileManager.default

        for skillID in Self.bundledSkillIDs {
            let skillFileURL = skillsDir.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: skillFileURL)
                let decoder = JSONDecoder()
                let skillFile = try decoder.decode(SkillFile.self, from: data)
                let skill = skillFile.toSkill()
                loadedSkills.append(skill)
            } catch {
                loadErrors.append(.invalidJSON(path: skillFileURL.path, underlyingError: error))
            }
        }

        return loadedSkills
    }

    /// Find the bundled Skills directory by searching multiple candidate locations
    /// - Returns: URL to Skills directory if found, nil otherwise
    private func findBundledSkillsDirectory() -> URL? {
        let fileManager = FileManager.default

        // Candidate paths to search for Skills directory
        var candidates: [URL] = []

        // 1. Main bundle resources (for .app bundle)
        if let bundleResourcePath = Bundle.main.resourcePath {
            candidates.append(URL(fileURLWithPath: bundleResourcePath).appendingPathComponent("Skills"))
        }

        // 2. Bundle URL for SwiftPM resources (XRoads_XRoads.bundle)
        if let bundleURL = Bundle.main.url(forResource: "XRoads_XRoads", withExtension: "bundle"),
           let resourceBundle = Bundle(url: bundleURL),
           let resourcePath = resourceBundle.resourcePath {
            candidates.append(URL(fileURLWithPath: resourcePath).appendingPathComponent("Skills"))
        }

        // 3. Executable directory (for swift run - .build/debug/XRoads_XRoads.resources/)
        let executableURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        candidates.append(executableURL.appendingPathComponent("XRoads_XRoads.resources/Skills"))

        // 4. Current working directory (project root)/XRoads/Resources/Skills
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        candidates.append(cwd.appendingPathComponent("XRoads/Resources/Skills"))

        // 5. Relative to executable parent directory
        let executableParent = executableURL.deletingLastPathComponent()
        candidates.append(executableParent.appendingPathComponent("XRoads_XRoads.resources/Skills"))

        // Search candidates and return the first one that exists
        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
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

    /// Create the set of bundled default skills (fallback when JSON resources not available)
    /// These mirror the JSON files in XRoads/Resources/Skills/
    private func createBundledSkills() -> [Skill] {
        [
            Skill(
                id: "commit",
                name: "Git Commit",
                description: "Create git commits with conventional commit messages following project standards",
                promptTemplate: """
                    You are a git commit assistant. Follow these rules strictly:

                    ## Commit Message Format
                    1. Use conventional commit format: type(scope): description
                    2. Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore
                    3. Keep the first line under 72 characters
                    4. Add detailed body if changes are complex
                    5. Reference issues when applicable (#123)

                    ## Before Committing
                    1. Review staged changes with `git diff --staged`
                    2. Ensure all tests pass
                    3. Verify no debug code or console.log statements
                    4. Check for sensitive data (API keys, passwords)

                    ## Commit Process
                    1. Stage relevant files: `git add <files>`
                    2. Create commit with descriptive message
                    3. Include Co-Authored-By if pair programming

                    {{context}}
                    """,
                requiredTools: ["git", "file-read"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .git,
                author: "XRoads Team"
            ),
            Skill(
                id: "review-pr",
                name: "Pull Request Review",
                description: "Review pull requests for code quality, bugs, security issues, and best practices",
                promptTemplate: """
                    You are a pull request reviewer. Conduct thorough code reviews following these guidelines:

                    ## Review Checklist
                    1. **Code Quality** - Is the code readable and well-structured?
                    2. **Functionality** - Does the code do what it claims?
                    3. **Security** - Input validation, no hardcoded secrets, proper auth?
                    4. **Performance** - Efficient algorithms, no N+1 queries?
                    5. **Testing** - Are tests included and adequate?
                    6. **Documentation** - Are complex sections documented?

                    ## Review Output Format
                    - **MUST FIX**: Critical issues that block merge
                    - **SHOULD FIX**: Important improvements
                    - **CONSIDER**: Optional suggestions
                    - **PRAISE**: Highlight good practices

                    Include file:line references for all comments.

                    {{context}}
                    """,
                requiredTools: ["git", "file-read"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .review,
                author: "XRoads Team"
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
                author: "XRoads Team"
            ),
            Skill(
                id: "code-reviewer",
                name: "Code Reviewer",
                description: "Comprehensive code review for quality, security, performance, and best practices",
                promptTemplate: """
                    You are a senior code reviewer. Analyze code systematically and provide actionable feedback.

                    ## Review Categories
                    1. **Correctness** - Logic errors, null handling, race conditions
                    2. **Security (OWASP Top 10)** - Injection, auth, data exposure
                    3. **Performance** - Algorithm complexity, query efficiency
                    4. **Maintainability** - Readability, DRY, SOLID principles
                    5. **Testing** - Coverage gaps, edge cases

                    ## Output Format
                    [SEVERITY] file:line - Description
                    Severities: CRITICAL, HIGH, MEDIUM, LOW

                    {{context}}
                    """,
                requiredTools: ["file-read", "git"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .review,
                author: "XRoads Team"
            ),
            Skill(
                id: "prd",
                name: "PRD Implementation",
                description: "Parse and implement features from PRD user stories with mandatory unit tests",
                promptTemplate: """
                    You are implementing features from a PRD (Product Requirements Document). Follow the Nexus Loop methodology:

                    ## Workflow
                    1. **Read prd.json** - Find the first user story that is NOT complete
                    2. **Read progress.txt** - Check the Learnings section for patterns
                    3. **Read AGENTS.md** - Understand codebase patterns if it exists
                    4. **Implement ONE story** - Only work on that single story
                    5. **Run quality checks** - Build, typecheck, run tests

                    ## Critical Rules
                    ### If Checks PASS:
                    - Update prd.json: set story status to "complete", add "completed_at" timestamp
                    - Commit changes with message: `feat(scope): US-XXX description`
                    - Append what worked to progress.txt

                    ### If Checks FAIL:
                    - Do NOT mark the story complete
                    - Do NOT commit broken code
                    - Append what went wrong to progress.txt

                    ## Unit Tests are MANDATORY
                    Every story implementation MUST include its unit tests.

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit", "git"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .code,
                author: "XRoads Team"
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
                description: "Generate integration tests for service boundaries and component interactions (NOT unit tests)",
                promptTemplate: """
                    You are an integration test specialist. Create tests that verify how components work together.

                    ## Important Distinction
                    Integration tests are DIFFERENT from unit tests:
                    - **Unit Tests**: Test individual functions/classes in isolation (written with implementations)
                    - **Integration Tests**: Test how multiple components interact (this skill)

                    ## Integration Test Focus Areas
                    1. **Service Boundaries** - API endpoints, database operations, external services
                    2. **Component Interactions** - Data flow, state management, event propagation
                    3. **Error Scenarios** - Network failures, timeouts, partial failures

                    ## Naming Convention
                    - File: `{Feature}IntegrationTests.swift`
                    - Location: `Tests/Integration/`

                    ## Do NOT
                    - Write unit tests (those belong with the implementation)
                    - Mock everything (defeats the purpose)
                    - Skip cleanup (tests must be idempotent)

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .test,
                author: "XRoads Team"
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
            ),
            Skill(
                id: "art-director",
                name: "Art Director",
                description: "Extract visual DNA and generate art-bible.json with design tokens",
                promptTemplate: """
                    You are a world-class digital art director. Use the provided context to generate art-bible.json.

                    ## Context
                    Project: {{project_name}}
                    Activity: {{activity_description}}
                    Target Audience: {{target_audience}}
                    Emotional Keywords: {{emotional_keywords}}
                    References: {{reference_urls}}
                    Input Images: {{input_images}}
                    Style: {{style_preference}}
                    Mode: {{mode_preference}}
                    Platform: {{platform}}

                    ## Output Requirements
                    1. Output valid JSON only.
                    2. Include design_tokens (colors, typography, spacing, radius).
                    3. Include color_system and typography_system summaries.
                    4. Include UI components with token references.
                    5. Ensure all colors are HEX and WCAG AA compliant.

                    Write art-bible.json to the project root.

                    {{context}}
                    """,
                requiredTools: ["file-read", "file-edit"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .custom,
                author: "XRoads"
            ),
            Skill(
                id: "context-handoff",
                name: "Context Handoff",
                description: "Generate a compact context handoff when session context is getting large or before ending a session. Captures key decisions, current state, and next steps for seamless continuation.",
                promptTemplate: """
                    You are a context handoff specialist. Your job is to create a compact summary that allows \
                    a new session to continue exactly where this one left off.

                    ## When to Trigger
                    - Context window is approaching capacity
                    - User requests a session handoff
                    - Major milestone completed, good point for a checkpoint

                    ## What to Capture
                    1. **Current State** - What was being worked on, what's done, what's pending
                    2. **Key Decisions** - Architectural choices, trade-offs made, reasons why
                    3. **Problems Solved** - Issues encountered and how they were resolved
                    4. **Next Steps** - Clear action items for the next session

                    ## Process
                    1. Call the `generate_handoff` MCP tool with the current session ID
                    2. Review the generated handoff for completeness
                    3. Store it via the MCP session persistence

                    ## Output Format
                    The handoff should be a concise markdown document (under 500 tokens by default) \
                    that can be injected into the next session's AGENT.md.

                    {{context}}
                    """,
                requiredTools: ["file-read"],
                version: "1.0.0",
                compatibleCLIs: Set(AgentType.allCases),
                category: .custom,
                author: "XRoads Team"
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
