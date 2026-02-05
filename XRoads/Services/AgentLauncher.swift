import Foundation

// MARK: - AgentSession

struct AgentSession: Identifiable, Sendable {
    let id: UUID
    let processId: UUID
    let agentType: AgentType
    let branchName: String
    let worktreePath: URL
    let stories: [String]
    let startedAt: Date
}

// MARK: - AgentLauncherError

enum AgentLauncherError: LocalizedError {
    case instructionsWriteFailed(URL)
    case notesDirectoryFailed(URL)
    case adapterUnavailable(AgentType)

    var errorDescription: String? {
        switch self {
        case .instructionsWriteFailed(let url):
            return "Failed to write AGENT.md at \(url.path)"
        case .notesDirectoryFailed(let url):
            return "Failed to prepare notes directory at \(url.path)"
        case .adapterUnavailable(let type):
            return "\(type.displayName) CLI is not available on this system."
        }
    }
}

// MARK: - AGENT.md Generator

struct AGENTFileGenerator {
    func generate(
        assignment: WorktreeAssignment,
        prd: PRDDocument,
        instructions: String
    ) -> String {
        let storyLookup = Dictionary(uniqueKeysWithValues: prd.userStories.map { ($0.id, $0) })
        let stories = assignment.taskGroup.storyIds.compactMap { storyLookup[$0] }

        let header = """
        # AGENT BRIEF – \(assignment.agentType.displayName)

        ## Session Overview
        - **Feature:** \(prd.featureName)
        - **Branch:** \(assignment.branchName)
        - **Worktree:** \(assignment.worktreePath.path)
        - **Stories Assigned:** \(assignment.taskGroup.storyIds.joined(separator: ", "))

        """

        let storiesSection = stories.map { story in
            """
            ### \(story.id) – \(story.title)
            - Priority: \(story.priority.rawValue.capitalized)
            - Depends on: \(story.dependsOn.isEmpty ? "None" : story.dependsOn.joined(separator: ", "))

            \(story.description)
            """
        }.joined(separator: "\n\n")

        let coordination = """
        ## Coordination
        - Communicate progress via MCP emit_log / update_status (level=info/warn/error).
        - When blocked, append details to `notes/blockers.md` and emit a warn log.
        - Respect files owned by other agents; coordinate via MCP before editing shared assets.

        ## Completion Criteria
        - Meet each story's acceptance criteria from the PRD.
        - Ensure `notes/` documents contain final learnings/decisions.
        - Push changes to \(assignment.branchName) and notify orchestrator via MCP.

        ## Launch Instructions (auto-generated)
        \(instructions)
        """

        return [header, "## Stories", storiesSection, coordination]
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AgentLauncher

actor AgentLauncher {

    private let ptyRunner: PTYProcessRunner
    private var adapterRegistry: CLIAdapterRegistry
    private let agentFileGenerator = AGENTFileGenerator()
    private let fileManager: FileManager = .default

    init(
        ptyRunner: PTYProcessRunner = PTYProcessRunner(),
        adapterRegistry: CLIAdapterRegistry = CLIAdapterRegistry()
    ) {
        self.ptyRunner = ptyRunner
        self.adapterRegistry = adapterRegistry
    }

    func setCustomPath(_ path: String?, for type: AgentType) {
        adapterRegistry.setCustomPath(path, for: type)
    }

    func launchAgent(
        assignment: WorktreeAssignment,
        prd: PRDDocument,
        sessionID: UUID,
        instructions: String,
        onOutput: @escaping PTYProcessRunner.OutputHandler
    ) async throws -> AgentSession {
        try prepareWorktreeArtifacts(assignment: assignment, prd: prd, instructions: instructions)

        let adapter = adapterRegistry.adapter(for: assignment.agentType)
        guard adapter.isAvailable() else {
            throw AgentLauncherError.adapterUnavailable(assignment.agentType)
        }

        var environment = Foundation.ProcessInfo.processInfo.environment
        environment["CROSSROADS_SESSION_ID"] = sessionID.uuidString
        environment["CROSSROADS_AGENT_TYPE"] = assignment.agentType.rawValue
        environment["CROSSROADS_BRANCH"] = assignment.branchName
        environment["CROSSROADS_ASSIGNED_STORIES"] = assignment.taskGroup.storyIds.joined(separator: ",")
        environment["CROSSROADS_ASSIGNMENT_ID"] = assignment.id.uuidString

        let processId = try await ptyRunner.launch(
            executable: adapter.executablePath,
            arguments: adapter.launchArguments(worktreePath: assignment.worktreePath.path),
            workingDirectory: assignment.worktreePath.path,
            environment: environment,
            onOutput: onOutput,
            onTermination: { exitCode in
                print("[AgentLauncher] Process terminated with exit code: \(exitCode)")
            }
        )

        // Wait a bit for PTY to initialize
        try await Task.sleep(nanoseconds: 500_000_000)  // 500ms

        try await ptyRunner.sendInput(
            id: processId,
            text: adapter.formatCommand(instructions)
        )

        return AgentSession(
            id: UUID(),
            processId: processId,
            agentType: assignment.agentType,
            branchName: assignment.branchName,
            worktreePath: assignment.worktreePath,
            stories: assignment.taskGroup.storyIds,
            startedAt: Date()
        )
    }

    // MARK: - Private

    private func prepareWorktreeArtifacts(
        assignment: WorktreeAssignment,
        prd: PRDDocument,
        instructions: String
    ) throws {
        let agentFile = assignment.worktreePath.appendingPathComponent("AGENT.md")
        let notesDirectory = assignment.worktreePath.appendingPathComponent("notes", isDirectory: true)

        try ensureDirectoryExists(at: assignment.worktreePath)
        try ensureNotesDirectory(at: notesDirectory)

        let content = agentFileGenerator.generate(
            assignment: assignment,
            prd: prd,
            instructions: instructions
        )

        do {
            try content.write(to: agentFile, atomically: true, encoding: .utf8)
        } catch {
            throw AgentLauncherError.instructionsWriteFailed(agentFile)
        }
    }

    private func ensureDirectoryExists(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func ensureNotesDirectory(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw AgentLauncherError.notesDirectoryFailed(url)
            }
        }

        let files = ["decisions.md", "learnings.md", "blockers.md"]
        for filename in files {
            let fileURL = url.appendingPathComponent(filename)
            if !fileManager.fileExists(atPath: fileURL.path) {
                try "# \(filename.replacingOccurrences(of: ".md", with: "").capitalized)\n\n"
                    .write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
