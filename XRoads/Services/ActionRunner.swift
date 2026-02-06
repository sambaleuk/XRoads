import Foundation

// MARK: - ActionRunnerError

/// Errors that can occur during action execution
enum ActionRunnerError: LocalizedError {
    case skillNotFound(id: String)
    case skillsLoadFailed(ids: [String])
    case agentMDGenerationFailed(path: String)
    case agentLaunchFailed(underlying: Error)
    case worktreePathInvalid(path: String)
    case noSkillsLoaded
    case missingRequiredTool(tool: String, skill: String)

    var errorDescription: String? {
        switch self {
        case .skillNotFound(let id):
            return "Required skill '\(id)' not found in registry."
        case .skillsLoadFailed(let ids):
            return "Failed to load skills: \(ids.joined(separator: ", "))"
        case .agentMDGenerationFailed(let path):
            return "Failed to generate AGENT.md at \(path)"
        case .agentLaunchFailed(let underlying):
            return "Agent launch failed: \(underlying.localizedDescription)"
        case .worktreePathInvalid(let path):
            return "Invalid worktree path: \(path)"
        case .noSkillsLoaded:
            return "No skills were loaded for the action."
        case .missingRequiredTool(let tool, let skill):
            return "Skill '\(skill)' requires tool '\(tool)' which is not available."
        }
    }
}

// MARK: - ActionRunRequest

/// Request to run an action
struct ActionRunRequest: Sendable {
    /// The action type to execute
    let actionType: ActionType

    /// The CLI agent that will execute the action
    let agentType: AgentType

    /// Path to the worktree where the action runs
    let worktreePath: String

    /// Optional additional skill IDs to load (beyond action's required skills)
    let additionalSkillIDs: [String]

    /// Session ID for tracking
    let sessionID: UUID

    /// Optional PRD path for implement/review actions
    let prdPath: String?

    /// Branch name for the worktree
    let branchName: String

    /// Assigned story IDs (for implement action)
    let assignedStories: [String]

    /// Custom task description (for custom actions)
    let taskDescription: String?

    /// Coordination notes for multi-agent scenarios
    let coordinationNotes: String?

    init(
        actionType: ActionType,
        agentType: AgentType,
        worktreePath: String,
        additionalSkillIDs: [String] = [],
        sessionID: UUID = UUID(),
        prdPath: String? = nil,
        branchName: String = "main",
        assignedStories: [String] = [],
        taskDescription: String? = nil,
        coordinationNotes: String? = nil
    ) {
        self.actionType = actionType
        self.agentType = agentType
        self.worktreePath = worktreePath
        self.additionalSkillIDs = additionalSkillIDs
        self.sessionID = sessionID
        self.prdPath = prdPath
        self.branchName = branchName
        self.assignedStories = assignedStories
        self.taskDescription = taskDescription
        self.coordinationNotes = coordinationNotes
    }
}

// MARK: - ActionRunResult

/// Result of running an action
struct ActionRunResult: Sendable {
    /// The process ID of the launched agent
    let processID: UUID

    /// Skills that were loaded for this action
    let loadedSkills: [Skill]

    /// Path to the generated AGENT.md
    let agentMDPath: String

    /// Session ID for tracking
    let sessionID: UUID

    /// Timestamp when the action started
    let startedAt: Date
}

// MARK: - ActionRunner

/// Central service for executing actions with skill loading
/// Coordinates between SkillRegistry, SkillLoader, and AgentLauncher
actor ActionRunner {

    // MARK: - Dependencies

    private let skillRegistry: SkillRegistry
    private let skillLoader: SkillLoader
    private let agentLauncher: AgentLauncher
    private let ptyRunner: PTYProcessRunner
    private let fileManager: FileManager

    // MARK: - State

    /// Track active action runs by session ID
    private var activeRuns: [UUID: ActionRunResult] = [:]

    // MARK: - Initialization

    init(
        skillRegistry: SkillRegistry = .shared,
        skillLoader: SkillLoader = .shared,
        agentLauncher: AgentLauncher = AgentLauncher(),
        ptyRunner: PTYProcessRunner = PTYProcessRunner()
    ) {
        self.skillRegistry = skillRegistry
        self.skillLoader = skillLoader
        self.agentLauncher = agentLauncher
        self.ptyRunner = ptyRunner
        self.fileManager = .default
    }

    // MARK: - Public API

    /// Run an action with the specified configuration
    /// - Parameters:
    ///   - request: The action run request
    ///   - onOutput: Callback for process output
    /// - Returns: The result of the action run
    func run(
        request: ActionRunRequest,
        onOutput: @escaping PTYProcessRunner.OutputHandler
    ) async throws -> ActionRunResult {
        // Validate worktree path
        guard fileManager.fileExists(atPath: request.worktreePath) else {
            throw ActionRunnerError.worktreePathInvalid(path: request.worktreePath)
        }

        // 1. Load required skills for the action
        let skills = try await loadSkills(for: request)

        // 2. Generate AGENT.md with skills
        let agentMDPath = try await generateAgentMD(
            skills: skills,
            request: request
        )

        // 3. Generate launch instructions from skills
        let instructions = generateLaunchInstructions(
            for: request.actionType,
            skills: skills,
            request: request
        )

        // 4. Launch the CLI agent
        let processID = try await launchAgent(
            request: request,
            skills: skills,
            instructions: instructions,
            onOutput: onOutput
        )

        // 5. Create and store the result
        let result = ActionRunResult(
            processID: processID,
            loadedSkills: skills,
            agentMDPath: agentMDPath,
            sessionID: request.sessionID,
            startedAt: Date()
        )

        activeRuns[request.sessionID] = result

        return result
    }

    /// Get the result of an active or completed run
    /// - Parameter sessionID: The session ID
    /// - Returns: The run result if found
    func getRunResult(sessionID: UUID) -> ActionRunResult? {
        activeRuns[sessionID]
    }

    /// Remove a completed run from tracking
    /// - Parameter sessionID: The session ID to remove
    func removeRun(sessionID: UUID) {
        activeRuns.removeValue(forKey: sessionID)
    }

    /// Get all active run session IDs
    func activeSessionIDs() -> [UUID] {
        Array(activeRuns.keys)
    }

    /// Load skills for an action type
    /// - Parameters:
    ///   - actionType: The action type
    ///   - agentType: The CLI agent type (for compatibility filtering)
    /// - Returns: Array of loaded skills
    func loadSkillsForAction(
        _ actionType: ActionType,
        agent agentType: AgentType
    ) async throws -> [Skill] {
        let skillIDs = actionType.requiredSkills
        return try await loadSkillsByIDs(skillIDs, for: agentType)
    }

    /// Check if all required skills are available for an action
    /// - Parameters:
    ///   - actionType: The action type
    ///   - agentType: The CLI agent type
    /// - Returns: Tuple of (available, missing skill IDs)
    func checkSkillsAvailability(
        for actionType: ActionType,
        agent agentType: AgentType
    ) async -> (available: Bool, missing: [String]) {
        let requiredIDs = actionType.requiredSkills
        let loadedSkills = await skillRegistry.skills(byIDs: requiredIDs)
            .filter { $0.isCompatible(with: agentType) }

        let loadedIDs = Set(loadedSkills.map { $0.id })
        let missingIDs = requiredIDs.filter { !loadedIDs.contains($0) }

        return (missingIDs.isEmpty, missingIDs)
    }

    // MARK: - Private Methods

    /// Load skills for the request
    private func loadSkills(for request: ActionRunRequest) async throws -> [Skill] {
        // Get required skills from action type
        var skillIDs = request.actionType.requiredSkills

        // Add any additional skills
        skillIDs.append(contentsOf: request.additionalSkillIDs)

        // Remove duplicates while preserving order
        skillIDs = Array(NSOrderedSet(array: skillIDs)) as? [String] ?? skillIDs

        // Load skills from registry
        let skills = try await loadSkillsByIDs(skillIDs, for: request.agentType)

        // For custom actions, we allow empty skills but warn
        if skills.isEmpty && request.actionType != .custom {
            throw ActionRunnerError.noSkillsLoaded
        }

        return skills
    }

    /// Load skills by their IDs
    private func loadSkillsByIDs(
        _ ids: [String],
        for agentType: AgentType
    ) async throws -> [Skill] {
        // Ensure registry is initialized
        await skillRegistry.initialize()

        // Get skills from registry
        let allSkills = await skillRegistry.skills(byIDs: ids)

        // Filter by CLI compatibility
        let compatibleSkills = allSkills.filter { $0.isCompatible(with: agentType) }

        // Check for missing skills
        let loadedIDs = Set(allSkills.map { $0.id })
        let missingIDs = ids.filter { !loadedIDs.contains($0) }

        if !missingIDs.isEmpty {
            // Log missing skills but don't fail - some skills are optional
            Log.action.warning("Skills not found: \(missingIDs.joined(separator: ", "))")
        }

        return compatibleSkills
    }

    /// Generate AGENT.md with skills
    private func generateAgentMD(
        skills: [Skill],
        request: ActionRunRequest
    ) async throws -> String {
        // Build skill context
        let context = SkillContext(
            agentType: request.agentType,
            worktreePath: request.worktreePath,
            branch: request.branchName,
            prdPath: request.prdPath,
            sessionID: request.sessionID.uuidString,
            assignedStories: request.assignedStories,
            taskDescription: request.taskDescription ?? request.actionType.description,
            coordinationNotes: request.coordinationNotes,
            completionCriteria: completionCriteria(for: request.actionType)
        )

        // Generate AGENT.md content
        let content = await skillLoader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: request.worktreePath
        )

        // Write to worktree
        let agentMDPath = (request.worktreePath as NSString).appendingPathComponent("AGENT.md")

        do {
            try content.write(toFile: agentMDPath, atomically: true, encoding: .utf8)
        } catch {
            throw ActionRunnerError.agentMDGenerationFailed(path: agentMDPath)
        }

        return agentMDPath
    }

    /// Generate launch instructions for the agent
    private func generateLaunchInstructions(
        for actionType: ActionType,
        skills: [Skill],
        request: ActionRunRequest
    ) -> String {
        var instructions: [String] = []

        // Add action-specific instructions
        switch actionType {
        case .implement:
            instructions.append("Read AGENT.md for your mission brief.")
            if let prdPath = request.prdPath {
                instructions.append("Load PRD from: \(prdPath)")
            }
            instructions.append("Implement assigned stories with unit tests.")
            instructions.append("Commit each completed story with format: feat(scope): US-XXX description")

        case .review:
            instructions.append("Read AGENT.md for your mission brief.")
            instructions.append("Analyze staged and committed changes for issues.")
            instructions.append("Generate review.md with findings and suggestions.")

        case .integrationTest:
            instructions.append("Read AGENT.md for your mission brief.")
            instructions.append("Generate integration tests for service boundaries.")
            instructions.append("Do NOT duplicate unit tests.")
            instructions.append("Focus on: integration tests, e2e tests, performance tests.")

        case .write:
            instructions.append("Read AGENT.md for your mission brief.")
            instructions.append("Generate documentation based on codebase analysis.")
            instructions.append("Create README, API docs, or other requested documentation.")

        case .custom:
            instructions.append("Read AGENT.md for your mission brief.")
            if let task = request.taskDescription {
                instructions.append("Task: \(task)")
            }
        }

        // Add skill references
        if !skills.isEmpty {
            instructions.append("")
            instructions.append("Loaded skills: \(skills.map { $0.name }.joined(separator: ", "))")
        }

        return instructions.joined(separator: "\n")
    }

    /// Get completion criteria for an action type
    private func completionCriteria(for actionType: ActionType) -> [String] {
        switch actionType {
        case .implement:
            return [
                "All assigned stories implemented",
                "Unit tests written and passing",
                "Code builds without errors",
                "Changes committed with proper message format"
            ]

        case .review:
            return [
                "All changed files reviewed",
                "Issues documented in review.md",
                "Suggestions provided with line references"
            ]

        case .integrationTest:
            return [
                "Integration tests cover service boundaries",
                "E2E tests cover critical user flows",
                "Tests are separate from unit tests",
                "All new tests pass"
            ]

        case .write:
            return [
                "Documentation is complete and accurate",
                "Code examples are working",
                "API documentation covers all public interfaces"
            ]

        case .custom:
            return [
                "Task completed as specified in AGENT.md"
            ]
        }
    }

    /// Launch the CLI agent with prepared configuration using PTY for proper terminal emulation
    private func launchAgent(
        request: ActionRunRequest,
        skills: [Skill],
        instructions: String,
        onOutput: @escaping PTYProcessRunner.OutputHandler
    ) async throws -> UUID {
        // Build environment variables
        var environment = Foundation.ProcessInfo.processInfo.environment
        environment["CROSSROADS_SESSION_ID"] = request.sessionID.uuidString
        environment["CROSSROADS_AGENT_TYPE"] = request.agentType.rawValue
        environment["CROSSROADS_BRANCH"] = request.branchName
        environment["CROSSROADS_ACTION_TYPE"] = request.actionType.rawValue
        environment["CROSSROADS_ASSIGNED_STORIES"] = request.assignedStories.joined(separator: ",")
        environment["CROSSROADS_LOADED_SKILLS"] = skills.map { $0.id }.joined(separator: ",")

        // Get CLI adapter
        let adapterRegistry = CLIAdapterRegistry()
        let adapter = adapterRegistry.adapter(for: request.agentType)

        guard adapter.isAvailable() else {
            throw ActionRunnerError.agentLaunchFailed(
                underlying: AgentLauncherError.adapterUnavailable(request.agentType)
            )
        }

        // Launch via PTYProcessRunner for proper terminal emulation
        // This is required for interactive CLIs like Claude Code, Gemini CLI, and Codex
        do {
            let processID = try await ptyRunner.launch(
                executable: adapter.executablePath,
                arguments: adapter.launchArguments(worktreePath: request.worktreePath),
                workingDirectory: request.worktreePath,
                environment: environment,
                onOutput: onOutput,
                onTermination: { exitCode in
                    Log.action.info("Process terminated with exit code: \(exitCode)")
                }
            )

            // Wait a bit for the process to initialize before sending input
            try await Task.sleep(nanoseconds: 800_000_000)  // 800ms for PTY initialization

            // Check if process is still running before sending input
            guard await ptyRunner.isRunning(id: processID) else {
                // Process exited immediately, likely due to an error
                // The output handler should have captured the error message
                return processID
            }

            // Send launch instructions
            try await ptyRunner.sendInput(
                id: processID,
                text: adapter.formatCommand(instructions)
            )

            return processID
        } catch {
            throw ActionRunnerError.agentLaunchFailed(underlying: error)
        }
    }
}

// MARK: - ActionRunner Convenience Methods

extension ActionRunner {
    /// Run an action in Single mode (simple worktree, no orchestration)
    /// - Parameters:
    ///   - actionType: The action to run
    ///   - agentType: The CLI agent to use
    ///   - worktreePath: Path to the worktree
    ///   - onOutput: Output callback
    /// - Returns: The action run result
    func runSingle(
        action actionType: ActionType,
        agent agentType: AgentType,
        worktreePath: String,
        prdPath: String? = nil,
        taskDescription: String? = nil,
        onOutput: @escaping PTYProcessRunner.OutputHandler
    ) async throws -> ActionRunResult {
        let request = ActionRunRequest(
            actionType: actionType,
            agentType: agentType,
            worktreePath: worktreePath,
            prdPath: prdPath,
            branchName: "main",
            taskDescription: taskDescription
        )

        return try await run(request: request, onOutput: onOutput)
    }

    /// Run an action in Agentic mode (with orchestration context)
    /// - Parameters:
    ///   - actionType: The action to run
    ///   - agentType: The CLI agent to use
    ///   - worktreePath: Path to the worktree
    ///   - sessionID: Orchestration session ID
    ///   - branchName: Branch for this worktree
    ///   - prdPath: Path to the PRD
    ///   - assignedStories: Story IDs assigned to this agent
    ///   - coordinationNotes: Notes for multi-agent coordination
    ///   - onOutput: Output callback
    /// - Returns: The action run result
    func runAgentic(
        action actionType: ActionType,
        agent agentType: AgentType,
        worktreePath: String,
        sessionID: UUID,
        branchName: String,
        prdPath: String? = nil,
        assignedStories: [String] = [],
        coordinationNotes: String? = nil,
        onOutput: @escaping PTYProcessRunner.OutputHandler
    ) async throws -> ActionRunResult {
        let request = ActionRunRequest(
            actionType: actionType,
            agentType: agentType,
            worktreePath: worktreePath,
            sessionID: sessionID,
            prdPath: prdPath,
            branchName: branchName,
            assignedStories: assignedStories,
            coordinationNotes: coordinationNotes
        )

        return try await run(request: request, onOutput: onOutput)
    }
}
