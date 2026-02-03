import XCTest
@testable import XRoads

// MARK: - SkillAdapter Protocol Tests

final class SkillAdapterTests: XCTestCase {

    // MARK: - Test Helpers

    func createTestSkill(
        id: String = "test-skill",
        name: String = "Test Skill",
        template: String = "Test template with {{context}} and {{branch}}"
    ) -> Skill {
        Skill(
            id: id,
            name: name,
            description: "A test skill for adapters",
            promptTemplate: template,
            requiredTools: ["git", "file-edit"],
            version: "1.0.0",
            compatibleCLIs: Set(AgentType.allCases),
            category: .code,
            author: "XRoads Tests"
        )
    }

    func createTestContext(
        agentType: AgentType = .claude,
        branch: String = "test-branch"
    ) -> SkillContext {
        SkillContext(
            agentType: agentType,
            worktreePath: "/test/worktree",
            branch: branch,
            prdPath: "/test/prd.json",
            sessionID: "test-session-123",
            assignedStories: ["US-001", "US-002"],
            taskDescription: "Test task",
            coordinationNotes: "Coordinate with other agents",
            completionCriteria: ["Tests pass", "Build succeeds"],
            customContext: ["custom_key": "custom_value"]
        )
    }

    // MARK: - Placeholder Replacement Tests

    func testPlaceholderReplacementContextPlaceholder() {
        let adapter = ClaudeSkillAdapter()
        let context = createTestContext()

        let template = "Working in {{context}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("/test/worktree"), "Should contain worktree path")
        XCTAssertTrue(result.contains("test-branch"), "Should contain branch name")
    }

    func testPlaceholderReplacementBranchPlaceholder() {
        let adapter = ClaudeSkillAdapter()
        let context = createTestContext(branch: "feature/my-branch")

        let template = "Checkout to {{branch}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("feature/my-branch"))
    }

    func testPlaceholderReplacementAgentTypePlaceholder() {
        let adapter = GeminiSkillAdapter()
        let context = createTestContext(agentType: .gemini)

        let template = "Agent: {{agent_type}} ({{agent_name}})"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("gemini"))
        XCTAssertTrue(result.contains("Gemini CLI"))
    }

    func testPlaceholderReplacementAssignedStoriesPlaceholder() {
        let adapter = CodexSkillAdapter()
        let context = createTestContext()

        let template = "Work on: {{assigned_stories}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("US-001"))
        XCTAssertTrue(result.contains("US-002"))
    }

    func testPlaceholderReplacementCustomPlaceholders() {
        let adapter = ClaudeSkillAdapter()
        let context = createTestContext()

        let template = "Custom: {{custom_key}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("custom_value"))
    }

    // MARK: - Same Skill Produces Valid Output for All CLIs Tests

    func testSameSkillValidForAllCLIs() {
        let skill = createTestSkill()
        let baseContext = createTestContext()

        for cliType in AgentType.allCases {
            let context = SkillContext(
                agentType: cliType,
                worktreePath: baseContext.worktreePath,
                branch: baseContext.branch,
                prdPath: baseContext.prdPath,
                sessionID: baseContext.sessionID,
                assignedStories: baseContext.assignedStories
            )

            let adapter = SkillAdapterFactory.adapter(for: cliType)
            let result = adapter.adaptSkill(skill, context: context)

            // All outputs should:
            XCTAssertFalse(result.isEmpty, "Output should not be empty for \(cliType)")
            XCTAssertTrue(result.contains(skill.name), "Output should contain skill name for \(cliType)")
            XCTAssertTrue(result.contains(skill.id), "Output should contain skill ID for \(cliType)")
        }
    }

    func testSkillAdapterFactoryReturnsCorrectAdapterType() {
        let claudeAdapter = SkillAdapterFactory.adapter(for: .claude)
        XCTAssertEqual(claudeAdapter.agentType, .claude)

        let geminiAdapter = SkillAdapterFactory.adapter(for: .gemini)
        XCTAssertEqual(geminiAdapter.agentType, .gemini)

        let codexAdapter = SkillAdapterFactory.adapter(for: .codex)
        XCTAssertEqual(codexAdapter.agentType, .codex)
    }

    func testSkillAdapterFactoryConvenienceMethods() {
        let skill = createTestSkill()
        let context = createTestContext()

        let singleResult = SkillAdapterFactory.adaptSkill(skill, for: .claude, context: context)
        XCTAssertFalse(singleResult.isEmpty)

        let skills = [createTestSkill(id: "skill-1"), createTestSkill(id: "skill-2")]
        let multiResult = SkillAdapterFactory.adaptSkills(skills, for: .gemini, context: context)
        XCTAssertTrue(multiResult.contains("skill-1"))
        XCTAssertTrue(multiResult.contains("skill-2"))
    }

    // MARK: - Adapt Multiple Skills Tests

    func testAdaptMultipleSkillsJoinedWithSeparator() {
        let adapter = ClaudeSkillAdapter()
        let context = createTestContext()
        let skills = [
            createTestSkill(id: "skill-1", name: "First Skill"),
            createTestSkill(id: "skill-2", name: "Second Skill"),
            createTestSkill(id: "skill-3", name: "Third Skill")
        ]

        let result = adapter.adaptSkills(skills, context: context)

        XCTAssertTrue(result.contains("First Skill"))
        XCTAssertTrue(result.contains("Second Skill"))
        XCTAssertTrue(result.contains("Third Skill"))
        // Default separator is "---"
        XCTAssertTrue(result.contains("---"))
    }

    func testAdaptEmptySkillsReturnsEmpty() {
        let adapter = GeminiSkillAdapter()
        let context = createTestContext()

        let result = adapter.adaptSkills([], context: context)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - AdaptedSkill Wrapper Tests

    func testAdaptedSkillProperties() {
        let skill = createTestSkill()
        let adaptedSkill = AdaptedSkill(
            skill: skill,
            targetCLI: .claude,
            adaptedPrompt: "Adapted prompt content"
        )

        XCTAssertEqual(adaptedSkill.skill.id, skill.id)
        XCTAssertEqual(adaptedSkill.targetCLI, .claude)
        XCTAssertEqual(adaptedSkill.adaptedPrompt, "Adapted prompt content")
        XCTAssertNotNil(adaptedSkill.adaptedAt)
    }

    // MARK: - SkillAdapterError Tests

    func testSkillAdapterErrorDescriptions() {
        let unsupported = SkillAdapterError.unsupportedCLI(.claude)
        XCTAssertTrue(unsupported.errorDescription?.contains("Claude Code") ?? false)

        let invalidTemplate = SkillAdapterError.invalidTemplate(reason: "Empty template")
        XCTAssertTrue(invalidTemplate.errorDescription?.contains("Empty template") ?? false)

        let missingPlaceholder = SkillAdapterError.missingRequiredPlaceholder(placeholder: "context")
        XCTAssertTrue(missingPlaceholder.errorDescription?.contains("context") ?? false)

        let adaptationFailed = SkillAdapterError.adaptationFailed(skillID: "test-skill", reason: "Failed")
        XCTAssertTrue(adaptationFailed.errorDescription?.contains("test-skill") ?? false)
        XCTAssertTrue(adaptationFailed.errorDescription?.contains("Failed") ?? false)
    }
}

// MARK: - Claude Skill Adapter Tests

final class ClaudeSkillAdapterTests: XCTestCase {

    func createTestSkill() -> Skill {
        Skill(
            id: "claude-test",
            name: "Claude Test Skill",
            description: "Test skill for Claude",
            promptTemplate: "Execute this task: {{task}}",
            requiredTools: ["git", "Read", "Write"],
            version: "1.0.0"
        )
    }

    func createTestContext() -> SkillContext {
        SkillContext(
            agentType: .claude,
            worktreePath: "/test/worktree",
            branch: "main",
            assignedStories: ["US-001"],
            taskDescription: "Implement feature"
        )
    }

    func testClaudeAdapterAgentType() {
        let adapter = ClaudeSkillAdapter()
        XCTAssertEqual(adapter.agentType, .claude)
    }

    func testClaudeSpecificFormatting() {
        let adapter = ClaudeSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        // Claude format includes markdown headers
        XCTAssertTrue(result.contains("## Claude Test Skill"))
        // Includes skill metadata
        XCTAssertTrue(result.contains("Skill ID"))
        XCTAssertTrue(result.contains(skill.id))
        XCTAssertTrue(result.contains("Version"))
    }

    func testClaudeIncludesRequiredTools() {
        let adapter = ClaudeSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("Required Tools"))
        XCTAssertTrue(result.contains("git"))
    }

    func testClaudeIncludesInstructionsSection() {
        let adapter = ClaudeSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("### Instructions"))
    }

    func testClaudeIncludesExecutionNotes() {
        let adapter = ClaudeSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("Execution Notes"))
        XCTAssertTrue(result.contains("TodoWrite"))
    }

    func testClaudeToolsPlaceholder() {
        let adapter = ClaudeSkillAdapter()
        let context = createTestContext()
        let skill = Skill(
            id: "tools-test",
            name: "Tools Test",
            description: "Test",
            promptTemplate: "Available: {{claude_tools}}"
        )

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("Read"))
        XCTAssertTrue(result.contains("Write"))
        XCTAssertTrue(result.contains("Bash"))
    }

    func testClaudeStylePlaceholder() {
        let adapter = ClaudeSkillAdapter()
        let context = createTestContext()
        let skill = Skill(
            id: "style-test",
            name: "Style Test",
            description: "Test",
            promptTemplate: "Style: {{claude_style}}"
        )

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("concise"))
    }

    func testClaudeCoordinationNotesIncluded() {
        let adapter = ClaudeSkillAdapter()
        let skill = createTestSkill()
        let context = SkillContext(
            agentType: .claude,
            coordinationNotes: "Work with Gemini agent"
        )

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("Coordinate"))
    }
}

// MARK: - Gemini Skill Adapter Tests

final class GeminiSkillAdapterTests: XCTestCase {

    func createTestSkill() -> Skill {
        Skill(
            id: "gemini-test",
            name: "Gemini Test Skill",
            description: "Test skill for Gemini",
            promptTemplate: "Execute this task: {{task}}",
            requiredTools: ["git", "file-read"],
            version: "1.0.0"
        )
    }

    func createTestContext() -> SkillContext {
        SkillContext(
            agentType: .gemini,
            worktreePath: "/test/worktree",
            branch: "main",
            assignedStories: ["US-001", "US-002", "US-003", "US-004"],
            taskDescription: "Implement feature"
        )
    }

    func testGeminiAdapterAgentType() {
        let adapter = GeminiSkillAdapter()
        XCTAssertEqual(adapter.agentType, .gemini)
    }

    func testGeminiSpecificFormatting() {
        let adapter = GeminiSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        // Gemini uses # for main header
        XCTAssertTrue(result.contains("# Gemini Test Skill"))
        // Includes skill version in different format
        XCTAssertTrue(result.contains("v1.0.0"))
    }

    func testGeminiIncludesRequiredCapabilities() {
        let adapter = GeminiSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("Required Capabilities"))
        XCTAssertTrue(result.contains("- git"))
        XCTAssertTrue(result.contains("- file-read"))
    }

    func testGeminiIncludesTaskInstructions() {
        let adapter = GeminiSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("## Task Instructions"))
    }

    func testGeminiIncludesWorkflowSection() {
        let adapter = GeminiSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("## Workflow"))
        XCTAssertTrue(result.contains("1."))
        XCTAssertTrue(result.contains("Analyze"))
        XCTAssertTrue(result.contains("Verify"))
    }

    func testGeminiToolsPlaceholder() {
        let adapter = GeminiSkillAdapter()
        let context = createTestContext()
        let skill = Skill(
            id: "tools-test",
            name: "Tools Test",
            description: "Test",
            promptTemplate: "{{gemini_tools}}"
        )

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("File reading"))
        XCTAssertTrue(result.contains("Shell command"))
    }

    func testGeminiExecutionModeBatch() {
        let adapter = GeminiSkillAdapter()
        let skill = createTestSkill()
        // Context with many stories triggers batch mode
        let context = SkillContext(
            agentType: .gemini,
            assignedStories: ["US-001", "US-002", "US-003", "US-004"]
        )

        let template = "Mode: {{execution_mode}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("batch"))
    }

    func testGeminiExecutionModeSingle() {
        let adapter = GeminiSkillAdapter()
        let context = SkillContext(
            agentType: .gemini,
            assignedStories: ["US-001"]
        )

        let template = "Mode: {{execution_mode}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("single"))
    }
}

// MARK: - Codex Skill Adapter Tests

final class CodexSkillAdapterTests: XCTestCase {

    func createTestSkill() -> Skill {
        Skill(
            id: "codex-test",
            name: "Codex Test Skill",
            description: "Test skill for Codex",
            promptTemplate: "Execute this task: {{task}}",
            requiredTools: ["git", "code-edit"],
            version: "1.0.0"
        )
    }

    func createTestContext() -> SkillContext {
        SkillContext(
            agentType: .codex,
            worktreePath: "/test/worktree",
            branch: "feature/test",
            assignedStories: ["US-001"],
            taskDescription: "Implement feature"
        )
    }

    func testCodexAdapterAgentType() {
        let adapter = CodexSkillAdapter()
        XCTAssertEqual(adapter.agentType, .codex)
    }

    func testCodexSpecificFormatting() {
        let adapter = CodexSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        // Codex uses ## for skill header (concise style)
        XCTAssertTrue(result.contains("## Codex Test Skill"))
        // Compact version format
        XCTAssertTrue(result.contains("v1.0.0"))
    }

    func testCodexIncludesToolsInline() {
        let adapter = CodexSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        // Codex uses inline tool format with pipes
        XCTAssertTrue(result.contains("**Tools**"))
        XCTAssertTrue(result.contains("git"))
        XCTAssertTrue(result.contains("code-edit"))
    }

    func testCodexIncludesInstructionsSection() {
        let adapter = CodexSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("### Instructions"))
    }

    func testCodexIncludesConstraintsSection() {
        let adapter = CodexSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("### Constraints"))
        XCTAssertTrue(result.contains("Work within the assigned worktree"))
    }

    func testCodexIncludesExpectedOutput() {
        let adapter = CodexSkillAdapter()
        let skill = createTestSkill()
        let context = createTestContext()

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("### Expected Output"))
        XCTAssertTrue(result.contains("committed"))
        XCTAssertTrue(result.contains("Build passes"))
    }

    func testCodexToolsPlaceholder() {
        let adapter = CodexSkillAdapter()
        let context = createTestContext()
        let skill = Skill(
            id: "tools-test",
            name: "Tools Test",
            description: "Test",
            promptTemplate: "{{codex_tools}}"
        )

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("Code generation"))
        XCTAssertTrue(result.contains("File system"))
    }

    func testCodexApprovalModePlaceholder() {
        let adapter = CodexSkillAdapter()
        let context = createTestContext()

        let template = "Approval: {{approval_mode}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        // Without coordination notes, should suggest mode
        XCTAssertTrue(result.contains("suggest"))
    }

    func testCodexApprovalModeWithCoordination() {
        let adapter = CodexSkillAdapter()
        let context = SkillContext(
            agentType: .codex,
            coordinationNotes: "Coordinate with Claude"
        )

        let template = "Approval: {{approval_mode}}"
        let result = adapter.replacePlaceholders(in: template, context: context)

        XCTAssertTrue(result.contains("full-auto"))
    }

    func testCodexBranchConstraint() {
        let adapter = CodexSkillAdapter()
        let skill = createTestSkill()
        let context = SkillContext(
            agentType: .codex,
            branch: "feature/specific-branch",
            assignedStories: ["US-001"]
        )

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("feature/specific-branch"))
    }

    func testCodexAssignedStoriesConstraint() {
        let adapter = CodexSkillAdapter()
        let skill = createTestSkill()
        let context = SkillContext(
            agentType: .codex,
            assignedStories: ["US-001", "US-002"]
        )

        let result = adapter.adaptSkill(skill, context: context)

        XCTAssertTrue(result.contains("US-001"))
        XCTAssertTrue(result.contains("US-002"))
    }
}
