//
//  LoopLauncher.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Service for launching loop scripts with worktree isolation and dependency tracking
//

import Foundation

// MARK: - LoopLauncherError

enum LoopLauncherError: LocalizedError {
    case loopScriptNotFound(AgentType)
    case worktreeNotConfigured
    case worktreeCreationFailed(String)
    case prdWriteFailed(URL)
    case slotNotReady(Int)
    case processLaunchFailed(String)
    case gitError(String)

    var errorDescription: String? {
        switch self {
        case .loopScriptNotFound(let type):
            return "Loop script for \(type.displayName) not found"
        case .worktreeNotConfigured:
            return "Slot has no worktree configured"
        case .worktreeCreationFailed(let reason):
            return "Failed to create worktree: \(reason)"
        case .prdWriteFailed(let url):
            return "Failed to write PRD to \(url.path)"
        case .slotNotReady(let slotNumber):
            return "Slot \(slotNumber) is not ready to start"
        case .processLaunchFailed(let reason):
            return "Failed to launch loop: \(reason)"
        case .gitError(let reason):
            return "Git error: \(reason)"
        }
    }
}

// MARK: - LoopConfiguration

/// Configuration for launching a loop on a slot
struct LoopConfiguration: Sendable {
    let slotNumber: Int
    let agentType: AgentType
    let actionType: ActionType  // Action/role for this slot (implement, review, test, etc.)
    let repoPath: URL           // Main repository path
    let branchName: String      // Branch name for this slot's worktree
    let stories: [PRDUserStory] // Stories assigned to this slot
    let fullPRD: PRDDocument    // Full PRD for context
    let maxIterations: Int
    let sleepSeconds: Int
    let statusFilePath: URL?    // Shared status file for dependency tracking
    let additionalSkillIds: [String] // Optional additional skills to load
    let worktreePathOverride: URL?   // When set, reuse this path instead of computing a new one (failover)

    /// Worktree path - uses override if set (failover), otherwise computes from slot/agent/stories
    var worktreePath: URL {
        if let override = worktreePathOverride { return override }
        let storyIds = stories.map { $0.id }
        return WorktreePathResolver.resolve(
            repoPath: repoPath,
            slotNumber: slotNumber,
            agentType: agentType,
            storyIds: storyIds
        )
    }

    init(
        slotNumber: Int,
        agentType: AgentType,
        repoPath: URL,
        branchName: String,
        stories: [PRDUserStory],
        fullPRD: PRDDocument,
        actionType: ActionType = .implement,
        maxIterations: Int = 15,
        sleepSeconds: Int = 5,
        statusFilePath: URL? = nil,
        additionalSkillIds: [String] = [],
        worktreePathOverride: URL? = nil
    ) {
        self.slotNumber = slotNumber
        self.agentType = agentType
        self.actionType = actionType
        self.repoPath = repoPath
        self.branchName = branchName
        self.stories = stories
        self.fullPRD = fullPRD
        self.maxIterations = maxIterations
        self.sleepSeconds = sleepSeconds
        self.statusFilePath = statusFilePath
        self.additionalSkillIds = additionalSkillIds
        self.worktreePathOverride = worktreePathOverride
    }
}

// MARK: - LoopLauncher

/// Actor for launching loop scripts on terminal slots with worktree isolation
actor LoopLauncher {

    private let ptyRunner: PTYProcessRunner
    private let gitService: GitService
    private let dependencyTracker: DependencyTracker
    private let skillRegistry: SkillRegistry
    private let skillLoader: SkillLoader
    private let sessionPersistence: SessionPersistenceService
    private let fileManager: FileManager = .default
    private let scriptsDirectory: URL

    init(
        ptyRunner: PTYProcessRunner = PTYProcessRunner(),
        gitService: GitService = GitService(),
        dependencyTracker: DependencyTracker = DependencyTracker(),
        skillRegistry: SkillRegistry = .shared,
        skillLoader: SkillLoader = .shared,
        sessionPersistence: SessionPersistenceService = SessionPersistenceService()
    ) {
        self.ptyRunner = ptyRunner
        self.gitService = gitService
        self.dependencyTracker = dependencyTracker
        self.skillRegistry = skillRegistry
        self.skillLoader = skillLoader
        self.sessionPersistence = sessionPersistence

        // Find scripts directory
        let bundleScripts = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/scripts")
        let projectScripts = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts")
        let userScripts = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nexus/bin")

        if FileManager.default.fileExists(atPath: bundleScripts.path) {
            self.scriptsDirectory = bundleScripts
        } else if FileManager.default.fileExists(atPath: projectScripts.path) {
            self.scriptsDirectory = projectScripts
        } else {
            self.scriptsDirectory = userScripts
        }
    }

    // MARK: - Public Methods

    /// Initialize status file for orchestration session
    func initializeSession(
        repoPath: URL,
        sessionId: UUID,
        prd: PRDDocument
    ) async throws -> URL {
        return try await dependencyTracker.initializeStatusFile(
            repoPath: repoPath,
            sessionId: sessionId,
            prd: prd
        )
    }

    /// Calculate dependency layers for story assignment suggestions
    func calculateDependencyLayers(stories: [PRDUserStory]) async -> [DependencyLayer] {
        return await dependencyTracker.calculateLayers(stories: stories)
    }

    /// Termination handler type for loop completion
    typealias TerminationHandler = @Sendable (Int, Int32) -> Void  // (slotNumber, exitCode)

    /// Launch a loop script on a slot with worktree creation
    func launchLoop(
        config: LoopConfiguration,
        onOutput: @escaping PTYProcessRunner.OutputHandler,
        onTermination: TerminationHandler? = nil
    ) async throws -> UUID {
        // 1. Find the loop script
        let loopScript = try findLoopScript(for: config.agentType)

        // 2. Create or prepare the worktree
        let worktreePath = try await createWorktreeIfNeeded(config: config)

        // 3. Prepare the worktree with PRD and context files
        try await prepareWorktree(config: config, worktreePath: worktreePath)

        // 4. Build environment
        var environment = ProcessInfo.processInfo.environment
        environment["CROSSROADS_SLOT"] = String(config.slotNumber)
        environment["CROSSROADS_AGENT"] = config.agentType.rawValue
        environment["CROSSROADS_WORKTREE"] = worktreePath.path
        environment["CROSSROADS_REPO"] = config.repoPath.path
        environment["CROSSROADS_BRANCH"] = config.branchName
        if let statusPath = config.statusFilePath {
            environment["CROSSROADS_STATUS_FILE"] = statusPath.path
        }

        // Capture slot number and repoPath for termination callback
        let slotNumber = config.slotNumber
        let repoPath = config.repoPath.path

        // 5. Launch the loop via PTY
        let processId = try await ptyRunner.launch(
            executable: loopScript.path,
            arguments: [String(config.maxIterations), String(config.sleepSeconds)],
            workingDirectory: worktreePath.path,
            environment: environment,
            onOutput: onOutput,
            onTermination: { [sessionPersistence] exitCode in
                Log.loop.info("Slot \(slotNumber) loop terminated with code: \(exitCode)")

                // Auto-persist session state on loop completion
                Task {
                    if let lastSession = try? await sessionPersistence.lastSession(for: repoPath) {
                        var updated = lastSession
                        updated.updatedAt = Date()
                        if exitCode == 0 {
                            updated.status = .completed
                        }
                        try? await sessionPersistence.saveSession(updated)
                    }
                }

                // Notify caller about termination
                onTermination?(slotNumber, exitCode)
            }
        )

        return processId
    }

    /// Stop a running loop
    func stopLoop(processId: UUID) async throws {
        try await ptyRunner.terminate(id: processId)
    }

    /// Check if a loop is running
    func isLoopRunning(processId: UUID) async -> Bool {
        return await ptyRunner.isRunning(id: processId)
    }

    /// Send input to a running loop
    func sendInput(processId: UUID, text: String) async throws {
        try await ptyRunner.sendInput(id: processId, text: text)
    }

    /// Get the actual worktree path for a config
    func getWorktreePath(config: LoopConfiguration) -> URL {
        return config.worktreePath
    }

    // MARK: - Private Methods

    /// Create a git worktree for the slot if it doesn't exist
    private func createWorktreeIfNeeded(config: LoopConfiguration) async throws -> URL {
        let worktreePath = config.worktreePath

        // Check if worktree already exists
        if fileManager.fileExists(atPath: worktreePath.path) {
            // Verify it's a valid worktree
            let gitDir = worktreePath.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitDir.path) {
                Log.loop.debug("Worktree exists at \(worktreePath.path)")
                return worktreePath
            } else {
                // Directory exists but is not a worktree, remove it
                try? fileManager.removeItem(at: worktreePath)
            }
        }

        // Create parent directory
        let parentDir = worktreePath.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Create the worktree using git
        do {
            try await gitService.createWorktree(
                repoPath: config.repoPath.path,
                branch: config.branchName,
                worktreePath: worktreePath.path
            )
            Log.loop.info("Created worktree: \(worktreePath.path)")
            return worktreePath
        } catch {
            throw LoopLauncherError.worktreeCreationFailed(error.localizedDescription)
        }
    }

    /// Find the loop script for an agent type
    private func findLoopScript(for agentType: AgentType) throws -> URL {
        let scriptName = agentType.loopScriptName
        let scriptPath = scriptsDirectory.appendingPathComponent(scriptName)

        if fileManager.isExecutableFile(atPath: scriptPath.path) {
            return scriptPath
        }

        if let resolved = LoopScriptLocator.findLoopScript(for: agentType) {
            return URL(fileURLWithPath: resolved)
        }

        throw LoopLauncherError.loopScriptNotFound(agentType)

    }

    /// Prepare the worktree with PRD and context files
    private func prepareWorktree(config: LoopConfiguration, worktreePath: URL) async throws {
        // 1. Create filtered PRD with only assigned stories (but keep dependencies info)
        let filteredPRD = createFilteredPRD(config: config)
        let prdPath = worktreePath.appendingPathComponent("prd.json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(filteredPRD)
            try data.write(to: prdPath, options: .atomic)
        } catch {
            throw LoopLauncherError.prdWriteFailed(prdPath)
        }

        // 2. Create AGENT.md with dependency awareness
        let agentMd = await createAgentMd(config: config, worktreePath: worktreePath)
        let agentPath = worktreePath.appendingPathComponent("AGENT.md")
        try? agentMd.write(to: agentPath, atomically: true, encoding: .utf8)

        // 3. Add loop files to .gitignore and untrack them so they don't create merge conflicts
        let gitignorePath = worktreePath.appendingPathComponent(".gitignore")
        let loopIgnoreEntries = ["prd.json", "progress.txt", "AGENT.md", ".xroads-backup/", "logs/"]
        appendToGitignore(at: gitignorePath, entries: loopIgnoreEntries)

        // Untrack loop files (they may be tracked from the base branch) and commit .gitignore
        await untrackLoopFiles(worktreePath: worktreePath, files: ["prd.json", "progress.txt", "AGENT.md"])

        // 4. Create progress.txt
        let progressPath = worktreePath.appendingPathComponent("progress.txt")
        if !fileManager.fileExists(atPath: progressPath.path) {
            let progressContent = """
            # Progress Tracker

            ## Feature: \(config.fullPRD.featureName)
            ## Agent: \(config.agentType.displayName)
            ## Slot: \(config.slotNumber)
            ## Branch: \(config.branchName)

            ---

            ## Assigned Stories

            \(config.stories.map { "- [ ] \($0.id): \($0.title)" }.joined(separator: "\n"))

            ## Learnings

            (This section is updated automatically by the loop)

            ## Blockers

            (List any blockers encountered)

            """
            try? progressContent.write(to: progressPath, atomically: true, encoding: .utf8)
        }
    }

    /// Untracks loop files from git so they don't cause merge conflicts, then commits .gitignore.
    private func untrackLoopFiles(worktreePath: URL, files: [String]) async {
        let worktreeDir = worktreePath.path
        for file in files {
            // Remove from index if tracked (keeps file on disk)
            let tracked = await gitService.isTracked(file: file, repoPath: worktreeDir)
            if tracked {
                try? await gitService.removeFromIndex(file: file, repoPath: worktreeDir)
            }
        }
        // Commit .gitignore + untracked changes in a single commit
        do {
            try await gitService.stageFile(repoPath: worktreeDir, file: ".gitignore")
            try await gitService.commit(message: "chore: gitignore loop files", repoPath: worktreeDir, allowEmpty: true)
        } catch {
            Log.loop.warning("Could not commit .gitignore in worktree: \(error.localizedDescription)")
        }
    }

    /// Appends entries to a .gitignore file, creating it if necessary, skipping entries already present.
    private func appendToGitignore(at path: URL, entries: [String]) {
        var existing = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
        let existingLines = Set(existing.components(separatedBy: .newlines))
        var added = false
        for entry in entries where !existingLines.contains(entry) {
            if !existing.hasSuffix("\n") && !existing.isEmpty { existing += "\n" }
            existing += entry + "\n"
            added = true
        }
        if added {
            try? existing.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    /// Create a filtered PRD with only the assigned stories
    private func createFilteredPRD(config: LoopConfiguration) -> PRDDocument {
        return PRDDocument(
            featureName: config.fullPRD.featureName,
            description: config.fullPRD.description,
            author: config.fullPRD.author,
            templateType: config.fullPRD.templateType,
            userStories: config.stories,
            vision: config.fullPRD.vision
        )
    }

    /// Create AGENT.md content with dependency awareness, skill injection, and handoff context
    private func createAgentMd(config: LoopConfiguration, worktreePath: URL) async -> String {
        // Load previous session handoff for this repo
        let handoffSection = await loadHandoffSection(repoPath: config.repoPath.path)

        // Load skills for the action type
        let skills = await loadSkillsForAction(config: config)
        let skillsSection = generateSkillsSection(skills: skills, config: config)

        let storyList = config.stories.map { story in
            let deps = story.dependsOn.isEmpty ? "None" : story.dependsOn.joined(separator: ", ")
            return """
            ### \(story.id): \(story.title)
            - **Priority:** \(story.priority.rawValue)
            - **Depends on:** \(deps)
            - **Description:** \(story.description)
            """
        }.joined(separator: "\n\n")

        let otherStories = config.fullPRD.userStories
            .filter { story in !config.stories.contains(where: { $0.id == story.id }) }

        let otherStoriesList = otherStories.isEmpty ? "None - you have all stories" :
            otherStories.map { "- \($0.id): \($0.title) (assigned elsewhere)" }.joined(separator: "\n")

        // Build dependency check and status file instructions
        let statusFilePath = config.statusFilePath?.path ?? "\(config.repoPath.path)/.crossroads/status.json"
        let hasDependencies = config.stories.contains { !$0.dependsOn.isEmpty }

        let statusFileInstructions = """

        ## CRITICAL: Status File Coordination

        **CENTRAL STATUS FILE:** `\(statusFilePath)`

        This file tracks ALL stories across ALL agents. You MUST:

        1. **READ** this file before starting ANY story to check if dependencies are complete
        2. **UPDATE** this file when you COMPLETE a story

        ### Checking Dependencies
        ```bash
        cat "\(statusFilePath)" | jq '.stories["US-XXX"].status'
        ```
        If status is NOT "complete", the dependency is not ready.

        ### Updating Status on Completion
        After completing a story (e.g., US-001), update the central status file using jq:
        ```bash
        STORY_ID="US-001"
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        TMPFILE=$(mktemp /tmp/status_update.XXXXXX)
        jq --arg id "$STORY_ID" --arg ts "$TIMESTAMP" \\
          '.stories[$id].status = "complete" | .stories[$id].completedAt = $ts | .updatedAt = $ts' \\
          "\(statusFilePath)" > "$TMPFILE" && \\
          mv "$TMPFILE" "\(statusFilePath)"
        ```

        **THIS IS MANDATORY** - other agents are polling this file!

        """

        let dependencyInstructions = hasDependencies ? """

        ## Dependency Workflow

        Your stories have dependencies. Before implementing:

        1. Read `\(statusFilePath)` to check dependency status
        2. If ALL dependencies have `"status": "complete"`, proceed
        3. If ANY dependency is NOT complete:
           - Log: "⏳ Waiting for dependencies..."
           - Sleep 30 seconds and re-check
           - Do NOT proceed until dependencies are satisfied
        4. Only implement stories whose dependencies are ALL complete

        """ : ""

        // Design Direction section (from art-bible.json if present)
        let designSection = loadDesignContext(repoPath: config.repoPath.path)

        return """
        # AGENT BRIEF – \(config.agentType.displayName)
        \(handoffSection)
        ## Session Overview
        - **Feature:** \(config.fullPRD.featureName)
        - **Slot:** \(config.slotNumber)
        - **Branch:** \(config.branchName)
        - **Worktree:** \(worktreePath.path)
        - **Main Repo:** \(config.repoPath.path)
        - **Action:** \(config.actionType.displayName)
        - **Category:** \(config.actionType.category.displayName)
        \(designSection.map { "\n\($0)\n" } ?? "")
        ## Mission: \(config.actionType.displayName)

        **\(config.actionType.description)**

        \(skillsSection)

        ## CRITICAL: Working Directory

        **YOU MUST WORK AT THE ROOT OF THIS WORKTREE.**

        - Your current directory is: `\(worktreePath.path)`
        - DO NOT create subdirectories for the project (no `myproject/`, `app/`, etc.)
        - All source files go directly here: `src/`, `package.json`, etc.
        - The `prd.json` and `AGENT.md` are already at this root

        Example correct structure:
        ```
        \(worktreePath.lastPathComponent)/
        ├── src/
        ├── package.json
        ├── prd.json (already here)
        ├── AGENT.md (already here)
        └── progress.txt (already here)
        ```
        ## CRITICAL: No Blocking Commands

        You run in a **non-interactive loop** (no stdin, no display). Commands that block
        indefinitely will freeze the entire loop. To validate your code, use build and test
        commands that exit on their own:

        | Instead of (blocks forever) | Use (exits on its own) |
        |---|---|
        | `flutter run` | `flutter build` + `flutter test` |
        | `npm start` / `npm run dev` | `npm run build` + `npm test` |
        | `python manage.py runserver` | `python -m pytest` |
        | `rails server` | `rails test` |
        | `cargo run` (for servers) | `cargo build` + `cargo test` |

        \(statusFileInstructions)
        ## IMPORTANT: Reading Files Outside Your Worktree

        Your MCP filesystem tools are sandboxed to your worktree directory.
        To read or write files OUTSIDE this worktree (e.g., the central status.json),
        you MUST use **shell commands** (`cat`, `jq`), NOT the MCP `read_file` tool.

        Example:
        ```bash
        cat "\(statusFilePath)" | jq '.stories'
        ```

        ## Your Assigned Stories

        \(storyList)
        \(dependencyInstructions)

        ## Full Feature Context

        \(config.fullPRD.description)

        ## Other Stories (Context Only - DO NOT Implement)

        \(otherStoriesList)

        ## Workflow

        1. Read `\(statusFilePath)` to check dependency status
        2. Read local prd.json to find the next incomplete story
        3. If story has dependencies, verify they're "complete" in status.json
        4. Implement the story with unit tests AT THE WORKTREE ROOT
        5. Run tests and ensure they pass
        6. Update local prd.json status to "complete"
        7. **UPDATE CENTRAL STATUS FILE** (see above command)
        8. Commit changes with proper message
        9. Move to the next story

        ## Coordination

        - **ALWAYS update status.json** when completing stories
        - Append decisions, blockers, and learnings to `progress.txt`

        ---
        *Generated by XRoads Orchestrator with Dependency Tracking*
        """
    }

    // MARK: - Session Handoff

    /// Load the handoff section from the last session for this repo
    private func loadHandoffSection(repoPath: String) async -> String {
        guard let lastSession = try? await sessionPersistence.lastSession(for: repoPath),
              let handoff = lastSession.handoffPayload, !handoff.isEmpty else {
            return ""
        }

        return """

        ## Previous Session Context

        \(handoff)

        """
    }

    // MARK: - Skills Integration

    /// Load skills for the action type
    private func loadSkillsForAction(config: LoopConfiguration) async -> [Skill] {
        // Ensure registry is initialized
        await skillRegistry.initialize()

        // Get required skills from action type
        var skillIds = config.actionType.requiredSkills

        // Add any additional skills
        skillIds.append(contentsOf: config.additionalSkillIds)

        // Remove duplicates while preserving order
        skillIds = Array(NSOrderedSet(array: skillIds)) as? [String] ?? skillIds

        // Get skills from registry
        let allSkills = await skillRegistry.skills(byIDs: skillIds)

        // Filter by CLI compatibility
        let compatibleSkills = allSkills.filter { $0.isCompatible(with: config.agentType) }

        return compatibleSkills
    }

    /// Generate the skills section for AGENT.md
    private func generateSkillsSection(skills: [Skill], config: LoopConfiguration) -> String {
        guard !skills.isEmpty else {
            return """
            ## Loaded Skills
            No specific skills loaded for this action.
            """
        }

        var sections: [String] = []

        sections.append("## Loaded Skills")
        sections.append("")
        sections.append("The following skills have been loaded for this \(config.actionType.displayName) action:")
        sections.append("")

        for skill in skills {
            sections.append("### \(skill.name)")
            sections.append("")
            sections.append("**\(skill.description)**")
            sections.append("")

            // Process the prompt template with context
            let processedPrompt = processPromptTemplate(
                skill.promptTemplate,
                config: config
            )

            sections.append("**Instructions:**")
            sections.append("")
            sections.append(processedPrompt)
            sections.append("")

            if !skill.requiredTools.isEmpty {
                sections.append("**Required Tools:** \(skill.requiredTools.joined(separator: ", "))")
                sections.append("")
            }
        }

        return sections.joined(separator: "\n")
    }

    /// Load design context markdown from art-bible.json in the repo
    private func loadDesignContext(repoPath: String) -> String? {
        guard let dc = DesignContext.load(from: repoPath) else { return nil }
        return dc.agentMarkdown
    }

    /// Process a prompt template, replacing placeholders with actual values
    private func processPromptTemplate(_ template: String, config: LoopConfiguration) -> String {
        var processed = template

        // Replace common placeholders
        processed = processed.replacingOccurrences(of: "{{feature_name}}", with: config.fullPRD.featureName)
        processed = processed.replacingOccurrences(of: "{{branch_name}}", with: config.branchName)
        processed = processed.replacingOccurrences(of: "{{worktree_path}}", with: config.worktreePath.path)
        processed = processed.replacingOccurrences(of: "{{repo_path}}", with: config.repoPath.path)
        processed = processed.replacingOccurrences(of: "{{agent_type}}", with: config.agentType.displayName)
        processed = processed.replacingOccurrences(of: "{{action_type}}", with: config.actionType.displayName)
        processed = processed.replacingOccurrences(of: "{{slot_number}}", with: String(config.slotNumber))

        // Story-related placeholders
        let storyIds = config.stories.map { $0.id }.joined(separator: ", ")
        let storyTitles = config.stories.map { $0.title }.joined(separator: "\n- ")
        processed = processed.replacingOccurrences(of: "{{story_ids}}", with: storyIds)
        processed = processed.replacingOccurrences(of: "{{story_titles}}", with: storyTitles)
        processed = processed.replacingOccurrences(of: "{{story_count}}", with: String(config.stories.count))

        // PRD-related placeholders
        processed = processed.replacingOccurrences(of: "{{prd_description}}", with: config.fullPRD.description)

        // Status file placeholder
        if let statusPath = config.statusFilePath {
            processed = processed.replacingOccurrences(of: "{{status_file}}", with: statusPath.path)
        }

        return processed
    }
}
