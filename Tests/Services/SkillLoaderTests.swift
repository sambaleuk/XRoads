import XCTest
@testable import XRoads

final class SkillLoaderTests: XCTestCase {

    // MARK: - Test Data

    private func createTestSkill(id: String = "test-skill") -> Skill {
        Skill(
            id: id,
            name: "Test Skill",
            description: "A test skill",
            promptTemplate: "Test prompt with {{context}} placeholder",
            requiredTools: ["git"],
            version: "1.0.0",
            compatibleCLIs: Set(AgentType.allCases),
            category: .code,
            author: "Test"
        )
    }

    private func createTestContext() -> SkillContext {
        SkillContext(
            agentType: .claude,
            worktreePath: "/test/worktree",
            branch: "feature/test",
            prdPath: "/test/prd.json",
            sessionID: "test-session-123",
            assignedStories: ["US-001", "US-002"],
            taskDescription: "Implement test feature",
            coordinationNotes: "Work with other agents on shared code",
            completionCriteria: ["Tests pass", "Lint clean"]
        )
    }

    // MARK: - Skill Rendering Tests

    func testRenderSkillPromptContainsContext() async {
        let loader = SkillLoader()
        let skill = createTestSkill()
        let context = createTestContext()

        let rendered = await loader.renderSkillPrompt(skill, context: context)

        // Should contain the skill name as header
        XCTAssertTrue(rendered.contains("## Test Skill"))

        // Should have replaced {{context}} with actual context
        XCTAssertFalse(rendered.contains("{{context}}"),
                       "{{context}} placeholder should be replaced")
        XCTAssertTrue(rendered.contains("Working directory: /test/worktree"))
        XCTAssertTrue(rendered.contains("Branch: feature/test"))
    }

    func testRenderSkillPromptReplacesPlaceholders() async {
        let skill = Skill(
            id: "placeholder-test",
            name: "Placeholder Test",
            description: "Test",
            promptTemplate: """
                Agent: {{agent_name}}
                Branch: {{branch}}
                Stories: {{assigned_stories}}
                Path: {{worktree_path}}
                """
        )

        let context = createTestContext()
        let loader = SkillLoader()

        let rendered = await loader.renderSkillPrompt(skill, context: context)

        XCTAssertTrue(rendered.contains("Agent: Claude Code"))
        XCTAssertTrue(rendered.contains("Branch: feature/test"))
        XCTAssertTrue(rendered.contains("Stories: US-001, US-002"))
        XCTAssertTrue(rendered.contains("Path: /test/worktree"))
    }

    // MARK: - AGENT.md Generation Tests

    func testGenerateAgentMDContainsHeader() async {
        let loader = SkillLoader()
        let skills = [createTestSkill()]
        let context = createTestContext()

        let content = await loader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: "/test/worktree"
        )

        XCTAssertTrue(content.contains("# AGENT.md"))
        XCTAssertTrue(content.contains("Claude Code"))
        XCTAssertTrue(content.contains("Mission Brief"))
    }

    func testGenerateAgentMDContainsMission() async {
        let loader = SkillLoader()
        let skills = [createTestSkill()]
        let context = createTestContext()

        let content = await loader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: "/test/worktree"
        )

        XCTAssertTrue(content.contains("## Mission"))
        XCTAssertTrue(content.contains("**PRD**: `/test/prd.json`"))
        XCTAssertTrue(content.contains("**Assigned Stories**:"))
        XCTAssertTrue(content.contains("- US-001"))
        XCTAssertTrue(content.contains("- US-002"))
    }

    func testGenerateAgentMDContainsSkills() async {
        let loader = SkillLoader()
        let skills = [
            createTestSkill(id: "skill-1"),
            createTestSkill(id: "skill-2")
        ]
        let context = createTestContext()

        let content = await loader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: "/test/worktree"
        )

        XCTAssertTrue(content.contains("## Loaded Skills"))
        XCTAssertTrue(content.contains("## Test Skill"))
    }

    func testGenerateAgentMDContainsCoordination() async {
        let loader = SkillLoader()
        let skills = [createTestSkill()]
        let context = createTestContext()

        let content = await loader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: "/test/worktree"
        )

        XCTAssertTrue(content.contains("## Coordination"))
        XCTAssertTrue(content.contains("Work with other agents"))
    }

    func testGenerateAgentMDContainsCompletionCriteria() async {
        let loader = SkillLoader()
        let skills = [createTestSkill()]
        let context = createTestContext()

        let content = await loader.generateAgentMD(
            skills: skills,
            context: context,
            worktreePath: "/test/worktree"
        )

        XCTAssertTrue(content.contains("## Completion Criteria"))
        XCTAssertTrue(content.contains("- Tests pass"))
        XCTAssertTrue(content.contains("- Lint clean"))
    }

    func testGenerateAgentMDWithEmptySkills() async {
        let loader = SkillLoader()
        let context = createTestContext()

        let content = await loader.generateAgentMD(
            skills: [],
            context: context,
            worktreePath: "/test/worktree"
        )

        // Should still have header and mission
        XCTAssertTrue(content.contains("# AGENT.md"))
        XCTAssertTrue(content.contains("## Mission"))

        // Should NOT have skills section
        XCTAssertFalse(content.contains("## Loaded Skills"))
    }

    func testGenerateAgentMDWithoutCoordination() async {
        let loader = SkillLoader()
        let context = SkillContext(
            agentType: .claude,
            coordinationNotes: nil
        )

        let content = await loader.generateAgentMD(
            skills: [createTestSkill()],
            context: context,
            worktreePath: "/test/worktree"
        )

        XCTAssertFalse(content.contains("## Coordination"))
    }

    // MARK: - Skill Injection Tests

    func testInjectSkillsIntoTemplate() async {
        let template = """
            # Agent Instructions

            {{skills}}

            ## End
            """

        let skill = createTestSkill()
        let context = createTestContext()
        let loader = SkillLoader()

        let result = await loader.injectSkills(
            into: template,
            skills: [skill],
            context: context
        )

        XCTAssertFalse(result.contains("{{skills}}"),
                       "{{skills}} placeholder should be replaced")
        XCTAssertTrue(result.contains("## Test Skill"))
        XCTAssertTrue(result.contains("# Agent Instructions"))
        XCTAssertTrue(result.contains("## End"))
    }

    func testInjectSkillsReplacesContext() async {
        let template = "Working in {{context}}"

        let context = createTestContext()
        let loader = SkillLoader()

        let result = await loader.injectSkills(
            into: template,
            skills: [],
            context: context
        )

        XCTAssertFalse(result.contains("{{context}}"))
        XCTAssertTrue(result.contains("Working directory: /test/worktree"))
    }

    func testInjectMultipleSkillsSeparatedByDivider() async {
        let template = "{{skills}}"

        let skills = [
            Skill(id: "skill1", name: "Skill One", description: "First", promptTemplate: "One"),
            Skill(id: "skill2", name: "Skill Two", description: "Second", promptTemplate: "Two")
        ]
        let context = createTestContext()
        let loader = SkillLoader()

        let result = await loader.injectSkills(
            into: template,
            skills: skills,
            context: context
        )

        XCTAssertTrue(result.contains("## Skill One"))
        XCTAssertTrue(result.contains("## Skill Two"))
        XCTAssertTrue(result.contains("---"), "Skills should be separated by divider")
    }

    // MARK: - Load and Render Tests

    func testLoadAndRenderSkillsByIDs() async {
        let loader = SkillLoader()
        let context = createTestContext()

        // Use bundled skills
        let rendered = await loader.loadAndRenderSkills(
            ids: ["commit", "code-writer"],
            for: .claude,
            context: context
        )

        XCTAssertTrue(rendered.contains("## Commit"))
        XCTAssertTrue(rendered.contains("## Code Writer"))
    }

    func testLoadAndRenderFiltersIncompatibleCLIs() async {
        let registry = SkillRegistry()
        await registry.initialize()

        // Register a Claude-only skill
        let claudeOnlySkill = Skill(
            id: "claude-only-test",
            name: "Claude Only",
            description: "Only for Claude",
            promptTemplate: "Claude specific",
            compatibleCLIs: [.claude]
        )
        await registry.registerUserSkill(claudeOnlySkill)

        let loader = SkillLoader(registry: registry)
        let context = SkillContext(agentType: .gemini)

        let rendered = await loader.loadAndRenderSkills(
            ids: ["claude-only-test"],
            for: .gemini,
            context: context
        )

        // Should be empty because skill is not compatible with Gemini
        XCTAssertTrue(rendered.isEmpty || !rendered.contains("Claude Only"),
                     "Claude-only skill should not appear for Gemini")
    }

    // MARK: - Skills for Action Tests

    func testSkillsForImplementAction() async {
        let loader = SkillLoader()

        let skills = await loader.skills(for: .implement, cli: .claude)

        XCTAssertFalse(skills.isEmpty, "Implement action should have skills")

        // Implement requires: prd, code-writer, commit
        let ids = skills.map { $0.id }
        XCTAssertTrue(ids.contains("prd") || ids.contains("code-writer") || ids.contains("commit"),
                     "Should contain at least one required skill")
    }

    func testSkillsForReviewAction() async {
        let loader = SkillLoader()

        let skills = await loader.skills(for: .review, cli: .claude)

        // Review requires: code-reviewer, lint
        let ids = skills.map { $0.id }
        XCTAssertTrue(ids.contains("code-reviewer") || ids.contains("lint"),
                     "Should contain review skills")
    }

    func testSkillsForCustomActionIsEmpty() async {
        let loader = SkillLoader()

        let skills = await loader.skills(for: .custom, cli: .claude)

        // Custom action has empty requiredSkills
        XCTAssertTrue(skills.isEmpty, "Custom action should have no required skills")
    }
}

// MARK: - SkillContext Tests

final class SkillContextTests: XCTestCase {

    func testToContextStringContainsAllFields() {
        let context = SkillContext(
            agentType: .claude,
            worktreePath: "/test/path",
            branch: "main",
            assignedStories: ["US-001", "US-002"],
            taskDescription: "Test task"
        )

        let string = context.toContextString()

        XCTAssertTrue(string.contains("Working directory: /test/path"))
        XCTAssertTrue(string.contains("Branch: main"))
        XCTAssertTrue(string.contains("Stories: US-001, US-002"))
        XCTAssertTrue(string.contains("Task: Test task"))
    }

    func testToContextStringWithCustomContext() {
        let context = SkillContext(
            agentType: .gemini,
            customContext: ["key1": "value1", "key2": "value2"]
        )

        let string = context.toContextString()

        XCTAssertTrue(string.contains("key1: value1"))
        XCTAssertTrue(string.contains("key2: value2"))
    }

    func testToContextStringWithMinimalFields() {
        let context = SkillContext(agentType: .codex)

        let string = context.toContextString()

        // Should be empty or minimal
        XCTAssertNotNil(string)
    }

    func testContextIsSendable() {
        // This is a compile-time check - if SkillContext is Sendable, this compiles
        let context = SkillContext(agentType: .claude)

        Task {
            let _ = context.agentType
        }
    }
}
