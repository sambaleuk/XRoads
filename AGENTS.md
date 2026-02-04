# Codebase Patterns

This file contains reusable patterns for AI agents working on this codebase.

## Architecture

- **SwiftUI App Lifecycle**: Use `@main` on the App struct (`XRoadsApp.swift`)
- **Folder Structure**: App/, Models/, Services/, Views/, ViewModels/, Resources/
- **Deployment Target**: macOS 14.0+ (required for @Observable)
- **Strict Concurrency**: SWIFT_STRICT_CONCURRENCY=complete enabled
- **MCP Dependency**: `xroads-mcp/` TypeScript server must run (launched via `MCPClient`) for log streaming/status tools.
- **Skills**: Load internal Swift skills per `ios-swift-skills/INTERNAL_USAGE.md` when coding (swift-language, swift-concurrency, memory-management, swiftui, process-management, mvvm-architecture, file-operations).

## Code Style

- **Previews**: Use `#if DEBUG` with `PreviewProvider` (not `#Preview` macro - doesn't work without Xcode IDE)
- **Build Verification**: Run `scripts/swift-build.sh` (wraps `swift build --disable-sandbox`) so SwiftPM/clang caches live inside `.build/cache/` and avoid sandbox errors.
- **Package.swift Sources**: When adding new Swift files, you MUST add them to the explicit `sources:` array in `Package.swift`. SwiftPM won't auto-discover files.

## macOS SwiftUI Known Issues & Solutions

### App Activation Policy (CRITICAL - ROOT CAUSE OF KEYBOARD ISSUES)

**Problem**: When running a SwiftUI macOS app via `swift run` (not as a bundled .app), TextField and NSTextField in any window (sheets, modals, floating windows) don't receive keyboard input. User hears system "bonk" sound.

**Root Cause**: Apps run via `swift run` don't have proper activation policy set by default. Without `.regular` policy, the app cannot properly receive keyboard events.

**Solution**: Add this to your `AppDelegate.applicationDidFinishLaunching`:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // CRITICAL: Set activation policy for keyboard input
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
}
```

**Why it works**: `.regular` activation policy allows the app to:
- Appear in the Dock
- Receive keyboard events in ALL windows (main, sheets, modals, floating)
- Properly manage window focus and first responder chain

### TextField in Sheets (Additional Best Practices)
Even with proper activation policy, for most reliable text input:

1. **Use pure AppKit floating windows** for forms (see `FloatingInputWindow.swift`)
2. **Or use `MacTextField`** (NSViewRepresentable) from `Views/Components/MacTextField.swift`:
```swift
MacTextField(placeholder: "placeholder", text: $text, isFirstResponder: true)
    .frame(height: 24)
```

3. **Always activate before showing windows**:
```swift
NSApp.activate(ignoringOtherApps: true)
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    window.makeFirstResponder(textField)
}
```

### TextFieldStyle Custom Styles
The `_body(configuration:)` method for custom `TextFieldStyle` is a private API and may not work reliably. Prefer using ViewModifiers or the standard `.roundedBorder` style for simple cases.

### Settings Window
Use `SettingsLink` (SwiftUI standard) instead of `NSApp.sendAction(Selector(("showSettingsWindow:")))` which doesn't work reliably outside Xcode.

### MCP Server Path Resolution
When running via `swift run`, `Bundle.main.bundlePath` points to `.build/debug/` not the project root. The `MCPClient` searches multiple candidate paths including the current working directory.

### Node.js Path (NVM users)
Default Node.js path `/usr/local/bin/node` doesn't exist for NVM users. `MCPClient.findNodePath()` searches common locations including `~/.nvm/versions/node/*/bin/node`.

### CLI Detection (NVM/Homebrew)
`ConfigChecker` uses `which` to find tools, but spawned processes don't inherit the full shell PATH. The checker now:
1. Searches common paths directly (`~/.nvm/versions/node/*/bin/`, `/opt/homebrew/bin/`, etc.)
2. Enhances PATH when running `which` command
3. Uses `Foundation.ProcessInfo.processInfo.environment` (not `ProcessInfo` which is shadowed by a local type)

### ProcessInfo Naming Conflict
There's a local `ProcessInfo` struct in `ProcessRunner.swift`. Always use `Foundation.ProcessInfo.processInfo` to access the system ProcessInfo.

## Build & Run Commands

```bash
# Build
swift build

# Run (from project root so MCP server is found)
swift run XRoads

# Kill running instance
pkill -f XRoads
```

## MCP Integration

The XRoads MCP server (`xroads-mcp/`) provides 3 tools:
- `emit_log`: Emit structured log entries from agents
- `update_status`: Update agent status (idle/running/planning/complete/error)
- `get_state`: Get current state (agents, logs, worktrees)

**MCPClient** (Swift actor) spawns and manages the MCP server as a subprocess via stdio. JSON-RPC 2.0 protocol with separate request types for `initialize` and `tools/call`.

Key files:
- `XRoads/Services/MCPClient.swift` - Swift MCP client
- `xroads-mcp/src/index.ts` - TypeScript MCP server
- `xroads-mcp/dist/index.js` - Compiled server (run `npm run build`)

## Testing

<!-- Add testing patterns here -->

## Full Agentic Mode (v2)

Refer to `prd-v2.json`, `context.md`, and `progress.txt` before starting any task on branch `feat/full-agentic-mode`.

- **Orchestrator Actor**: Implement `ClaudeOrchestrator` (actor) that drives orchestration steps: `analyzePRD`, `createWorktrees`, `assignTasks`, `monitorProgress`, `coordinateMerge`. Keep orchestration logic confined to this actor.
- **PRD Intake**: Accept JSON PRDs (`prd-v2.json` schema) via PRD Loader UI. Validate structure/dependencies before launching agents.
- **Worktree Strategy**:
  - Deterministic paths: `~/.crossroads/worktrees/{repoHash}/{branch}`.
  - Branch naming: `agent/{agentType}-{taskGroupId}` (see PRD for examples).
  - Each worktree must contain a generated `AGENT.md` (mission brief) and `notes/` folder (`decisions.md`, `learnings.md`, `blockers.md`).
- **Agent Launch**:
  - Use existing `ProcessRunner` + `CLIAdapters`.
  - Inject `CROSSROADS_SESSION_ID`, copy PRD/task context, and write AGENT.md before start.
  - When launching, emit MCP status/log entries so UI stays synced.
- **Monitoring**:
  - Poll `/tmp/crossroads/agents/agent-{sessionId}.json` every 500 ms (AgentStatusMonitor actor).
  - Surface events via `AgentEventBus` (AsyncStream) feeding ProgressDashboardView + notifications.
  - Detect stale files (>5 min) and escalate via AppState/UI.
- **Agent Health**:
  - AppState tracks non-responsive agents (>2 min without status) and repeated log loops (>5 identical messages).
  - Health alerts surface in the UI with actions: Wait (snooze), Restart, Reassign, Abort; each action emits MCP events/logs for the orchestrator.
  - Dashboard cards show average story time + success rate, and badge any active health issues.
- **Merge Coordination**:
  - Use `MergeCoordinator` actor to plan/execute merges. Dry-run merges (`git merge --no-commit --no-ff`) to flag conflicts.
  - When conflicts arise, show `ConflictResolutionSheet` and pause orchestration until user resolves.
- **Persistence & History**:
  - Maintain orchestration history under `~/.crossroads/history/orchestrations.json`.
  - Sync `notes/` back into main repo after merges.
- **Toggle UX**:
  - Add UI toggle for “Full Agentic Mode” along with PRD loader / start buttons (toolbar + settings persistence via `@AppStorage`).

## Process & Documentation Expectations

- Update `progress.txt` at the end of every iteration (v1 + v2) with learnings, actions, and files touched.
- Keep `context.md` aligned with current environment, dependencies, and workflows.
- Cross-link major changes in `AGENTS.md`, `context.md`, and `prd*.json` so future agents have a single source of truth.
- Every successful orchestration must append a detailed record to `~/.crossroads/history/orchestrations.json`; verify the PRD file path stays valid so the toolbar History sheet can trigger reruns via the PRD loader.
- When compiling locally, always execute `./scripts/swift-build.sh [extra swift arguments]` instead of `swift build`; the wrapper exports cache env vars so SwiftPM/clang write to `.build/cache/` and bypass Codex sandbox errors.
- When unsure which skills or services to touch, consult `ios-swift-skills/INTERNAL_USAGE.md` and reuse existing service actors before introducing new ones.










## Available Components
<!-- Auto-generated by ComponentContextBuilder; refresh when components change. -->

- `Theme` — Design tokens, spacing, radius, and layout constants. Usage: `Text("Example").padding(Theme.Spacing.md).background(Color.bgSurface)`
- `ActionPickerMenu` — Action selection menu for slot configuration. Usage: `ActionPickerMenu(...)`
- `CollapsiblePanel` — Collapsible sidebar panel with resize handle. Usage: `CollapsiblePanel(...)`
- `FloatingInputWindow` — AppKit-backed floating window for forms. Usage: `FloatingInputWindow(...)`
- `MacTextField` — NSTextField wrapper for reliable input. Usage: `MacTextField(...)`
- `ModalPanel` — Styled modal container. Usage: `ModalPanel(...)`
- `QuickActionBar` — Quick action buttons row. Usage: `QuickActionBar(...)`
- `SkillsBadge` — Skills count badge with popover. Usage: `SkillsBadge(...)`
- `TerminalInputBar` — Terminal input UI with actions. Usage: `TerminalInputBar(...)`

## End Available Components


## XRoads Skills (Auto-Injected)
<!-- Skills loaded by nexus-loop at 2026-02-04 16:20:01 -->
<!-- CLI: claude | Branch: main -->

# ===== SKILL: art-director =====

# /art-director Skill

You are a **World-Class Digital Art Director & Visual Identity Architect** with 20+ years of experience at top-tier agencies (Pentagram, Huge, Instrument, Collins).

## Your Superpower
You bridge the gap between "Brand DNA" (visual references, personality, values) and "Production-Ready Design Systems" (developer-ready specs, design tokens).

## Your Attitude
Meticulous, visionary, obsessively detail-oriented. You don't deliver generic templates; you extract the invisible essence of a visual identity and translate it into pixel-perfect direction. Allergic to mediocrity.

## Operating Phases

### Phase 1: ABSORPTION
Collect all provided context:
- Project: {{project_name}}
- Activity: {{activity_description}}
- Target Audience: {{target_audience}}
- Emotional Keywords: {{emotional_keywords}}
- References: {{reference_urls}}
- Input Images: {{input_images}}
- Preferences: {{style_preference}}, {{mode_preference}}
- Platform: {{platform}}

### Phase 2: VISUAL DNA EXTRACTION
Analyze references through these lenses:

1. **CHROMATIC SIGNATURE**
   - Dominant primary color (>40% frequency)
   - Accent color patterns
   - Background/negative space tendencies
   - Warm/Cool temperature ratio

2. **TYPOGRAPHIC PERSONALITY**
   - Implied font style (Serif/Sans-serif/Script/Display)
   - Text density preference

3. **PHOTOGRAPHIC DNA**
   - Lighting signature
   - Composition patterns
   - Human presence style
   - Post-processing mood

4. **GRAPHIC LANGUAGE**
   - Shape vocabulary (Rounded/Sharp/Organic)
   - Texture preferences
   - Pattern signatures

5. **ENERGY & POSITIONING**
   - Brand energy: Calm ←→ Dynamic
   - Luxury spectrum: Accessible ←→ Premium

### Phase 3: EXECUTION
Generate `art-bible.json` with this structure:

```json
{
  "project": "{{project_name}}",
  "version": "1.0.0",
  "generated_at": "ISO8601",
  "design_tokens": {
    "colors": {
      "background": { "primary": "#0d1117", "secondary": "#161b22" },
      "accent": { "primary": "#388bfd", "secondary": "#3fb950" },
      "text": { "primary": "#e6edf3", "secondary": "#7d8590" }
    },
    "typography": {
      "fontFamily": { "ui": "SF Pro", "mono": "SF Mono" },
      "sizes": { "xs": 10, "sm": 12, "md": 14, "lg": 16, "xl": 20 }
    },
    "spacing": { "xs": 4, "sm": 8, "md": 16, "lg": 24, "xl": 32 },
    "radius": { "sm": 4, "md": 8, "lg": 12 }
  },

  "verbal_moodboard": [
    {
      "description": "Detailed scene description",
      "keywords": ["search", "terms"],
      "ai_prompt": "Midjourney/DALL-E ready prompt"
    }
  ],

  "color_system": {
    "primary": { "hex": "#XXXXXX", "name": "Name", "usage": "Headlines, Primary CTA" },
    "secondary": { "hex": "#XXXXXX", "name": "Name", "usage": "Accents, Links" },
    "background": { "hex": "#XXXXXX", "name": "Name", "usage": "Page background" },
    "surface": { "hex": "#XXXXXX", "name": "Name", "usage": "Cards, Modals" },
    "text_primary": { "hex": "#XXXXXX", "usage": "Body copy" },
    "text_secondary": { "hex": "#XXXXXX", "usage": "Captions, Metadata" },
    "success": { "hex": "#XXXXXX" },
    "error": { "hex": "#XXXXXX" },
    "warning": { "hex": "#XXXXXX" }
  },

  "typography_system": {
    "display": { "font": "Font Name", "weight": 700, "size_desktop": 48, "size_mobile": 32, "letter_spacing": -0.02 },
    "heading": { "font": "Font Name", "weight": 600, "size": 24 },
    "body": { "font": "Font Name", "weight": 400, "size": 16, "line_height": 1.6 },
    "caption": { "font": "Font Name", "weight": 400, "size": 12 },
    "button": { "font": "Font Name", "weight": 600, "case": "uppercase" }
  },

  "ui_components": [
    {
      "name": "ComponentName",
      "description": "What it is and when to use",
      "style_specs": { "background": "surface", "radius": 12, "padding": 16 },
      "visual_prompt": "AI-ready prompt for generating preview",
      "interaction": { "hover": "description", "active": "description" }
    }
  ],

  "photography_direction": {
    "style": "Description of shooting style",
    "lighting": "Lighting guidelines",
    "composition": "Framing rules",
    "ai_prompts": ["Ready-to-use prompts"],
    "dos": ["Do this"],
    "donts": ["Avoid this"]
  },

  "graphic_elements": {
    "icon_style": "Description + recommended library",
    "decorative": ["Dividers", "Shapes", "Backgrounds"],
    "micro_interactions": ["Hover effects", "Transitions"]
  },

  "page_architecture": [
    {
      "page": "Homepage",
      "sections": [
        {
          "name": "Hero",
          "purpose": "First impression, value proposition",
          "layout": "Full-width, centered content",
          "visual_prompt": "AI prompt for section",
          "copy_direction": { "tone": "confident", "length": "short", "key_message": "..." }
        }
      ]
    }
  ]
}
```

## Quality Standards (NON-NEGOTIABLE)
- All color codes in HEX, WCAG AA compliant
- Typography limited to Google Fonts (or SF Pro/SF Mono for Apple platforms)
- Every prompt must be copy-paste ready for Midjourney v6 / DALL-E 3
- Output must be valid JSON, parseable for downstream PRD generation
- No generic suggestions - every element traces to Visual DNA

## Output
Write the complete `art-bible.json` file to the project root.

# ===== SKILL: prd =====

# /prd Skill - Nexus Loop Implementation

## Purpose
Implement user stories from prd.json with mandatory unit tests, following the Nexus Loop methodology.

## Workflow
1. **Read PRD**: Parse `{{prd_path}}` or `prd.json`
2. **Find Next Story**: Get first story with status != "complete"
3. **Read Context**: Check `progress.txt` for learnings, `AGENTS.md` for patterns
4. **Verify Unit Test**: Each story MUST have a `unit_test` object:
   ```json
   "unit_test": {
     "file": "tests/xxx.test.ts",
     "name": "test_function",
     "description": "Validates behavior",
     "assertions": [...],
     "status": "pending"
   }
   ```
5. **Implement Story**: Write code for acceptance criteria
6. **Write Unit Test**: Create test file at `unit_test.file` path
7. **Run & Verify**:
   - Build passes: `npm run build` or equivalent
   - Typecheck passes: `npm run typecheck` (if applicable)
   - **Unit test PASSES** (MANDATORY)

## Completion Criteria (ALL must pass)
- Implementation done
- Build passes
- Unit test PASSES
- Update prd.json: story status="complete", unit_test.status="passing"
- Commit: `feat(scope): US-XXX description`
- Append to progress.txt

## If Tests FAIL
- Do NOT mark complete
- Do NOT commit
- Log to progress.txt what went wrong
- Loop will retry next iteration

Context: XRoads Complete UI & Orchestrator System
Branch: main
Assigned Stories: {{assigned_stories}}

# ===== SKILL: commit =====

# /commit Skill

## Purpose
Analyze staged changes and create a well-structured commit following Conventional Commits.

## Workflow
1. Run `git status` to see all staged and unstaged changes
2. Run `git diff --cached` to analyze staged changes in detail
3. Run `git log --oneline -5` to understand recent commit style
4. Determine the appropriate commit type and scope:
   - feat: New feature
   - fix: Bug fix
   - docs: Documentation only
   - style: Formatting, no code change
   - refactor: Code restructuring
   - test: Adding tests
   - chore: Maintenance tasks
5. Draft a concise commit message (1-2 sentences) focusing on "why" not "what"
6. Execute: `git commit -m "$(cat <<'EOF'
   type(scope): description

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"`

## Important
- Never use `git add .` or `git add -A` - stage specific files
- Never skip pre-commit hooks unless explicitly requested
- Warn if staging files that look like secrets (.env, credentials)

Context: XRoads Complete UI & Orchestrator System
Branch: main

# ===== SKILL: review-pr =====

# /review-pr Skill

## Purpose
Perform a thorough code review of pull request changes with structured feedback.

## Workflow
1. Get PR context:
   - `gh pr view` to understand the PR description and status
   - `gh pr diff` to see all changes
   - `gh pr checks` to see CI status
2. Analyze changes against this checklist:
   - [ ] **Correctness**: Does the code do what it claims?
   - [ ] **Security**: Any OWASP Top 10 vulnerabilities? (injection, XSS, auth issues)
   - [ ] **Performance**: N+1 queries, memory leaks, blocking operations?
   - [ ] **Maintainability**: Clear naming, DRY, appropriate abstraction?
   - [ ] **Testing**: Are there adequate tests? Edge cases covered?
   - [ ] **Documentation**: Updated docs for public API changes?
3. For each issue found:
   - Severity: critical/major/minor/suggestion
   - File and line number
   - Clear explanation
   - Suggested fix (if applicable)
4. Provide summary with:
   - Overall assessment (approve/request changes/comment)
   - List of blocking issues (if any)
   - Positive feedback on good patterns

## Output Format
Write review to `{{worktree_path}}/review.md` with sections for each checklist item.

Context: XRoads Complete UI & Orchestrator System
Branch: main

# ===== SKILL: xroads-log =====

# XRoads Logging Skill

## Purpose
Use XRoads MCP to emit logs and status updates so the XRoads UI can track your progress in real-time.

## Available MCP Tools
The `xroads-mcp` server provides these tools:

### emit_log
Emit a log entry visible in XRoads UI terminal panel.
```json
{
  "level": "info|debug|warn|error",
  "source": "claude",
  "worktree": "{{worktree_path}}",
  "message": "Description of what happened",
  "metadata": {"optional": "additional data"}
}
```

### update_status
Update your agent status shown in XRoads dashboard.
```json
{
  "agent": "claude",
  "worktree": "{{worktree_path}}",
  "status": "idle|running|planning|complete|error",
  "task": "Current task description",
  "progress": 50
}
```

## When to Log
- **info**: Starting/completing tasks, iteration progress
- **debug**: Detailed step information (optional)
- **warn**: Recoverable issues, retries needed
- **error**: Failures that need attention

## When to Update Status
- **running**: When actively working on implementation
- **planning**: When analyzing code or designing solution
- **complete**: When story is done with passing tests
- **error**: When blocked or failed

## Best Practices
- Log at start of iteration: `emit_log(info, "Starting iteration N for story US-XXX")`
- Update status before long operations: `update_status(running, task="Implementing feature X")`
- Log completion: `emit_log(info, "Story US-XXX completed with passing unit test")`
- Update status on completion: `update_status(complete, progress=100)`

Context: XRoads Complete UI & Orchestrator System
Branch: main

# ===== SKILL: test-writer =====

# /test-writer Skill

## Purpose
Write comprehensive unit tests with proper assertions, mocking, and edge case coverage.

## Workflow
1. **Understand the Code**:
   - Read the target file(s) to understand functionality
   - Identify public APIs and their contracts
   - Note dependencies that need mocking
2. **Plan Test Cases**:
   - Happy path scenarios
   - Edge cases (empty inputs, nulls, boundaries)
   - Error conditions and exception handling
   - Async behavior (if applicable)
3. **Write Tests**:
   - Use describe/it blocks for organization
   - Clear test names: "should [behavior] when [condition]"
   - One assertion per test (when possible)
   - Setup/teardown with beforeEach/afterEach
4. **Mock Dependencies**:
   - Mock external services, APIs, databases
   - Use dependency injection where possible
   - Verify mock interactions
5. **Run & Verify**:
   - All tests pass
   - Coverage meets threshold (aim for >80%)
   - No flaky tests

## Test Structure
```
describe('[Component/Function Name]', () => {
  describe('[method or feature]', () => {
    it('should [expected behavior] when [condition]', () => {
      // Arrange
      // Act
      // Assert
    });
  });
});
```

## Output
Write tests to appropriate location based on project structure:
- `tests/` or `__tests__/` directory
- `*.test.ts`, `*.spec.ts`, or `*Tests.swift`

Context: XRoads Complete UI & Orchestrator System
Files: 

# ===== SKILL: code-reviewer =====

# /code-reviewer Skill

## Purpose
Perform comprehensive code review analyzing correctness, security, performance, and maintainability.

## Review Categories

### 1. Correctness
- Logic errors and edge cases
- Off-by-one errors
- Null/undefined handling
- Type safety issues
- Incomplete error handling

### 2. Security (OWASP Top 10)
- **Injection**: SQL, command, LDAP injection
- **Broken Auth**: Weak passwords, session issues
- **XSS**: Unsanitized output
- **IDOR**: Insecure direct object references
- **Misconfig**: Debug enabled, default creds
- **Sensitive Data**: Hardcoded secrets, logging PII
- **Missing Access Control**: Authorization checks
- **CSRF**: Missing tokens
- **Vulnerable Components**: Outdated dependencies
- **Insufficient Logging**: Missing audit trails

### 3. Performance
- N+1 queries
- Memory leaks
- Blocking main thread
- Unnecessary re-renders
- Missing caching
- Inefficient algorithms

### 4. Maintainability
- Clear naming conventions
- DRY (Don't Repeat Yourself)
- Single Responsibility
- Appropriate abstraction level
- Code complexity (cyclomatic)
- Documentation for public APIs

### 5. Testing
- Test coverage adequacy
- Edge case coverage
- Integration test needs

## Workflow
1. Read files to review ( or specified paths)
2. Analyze against each category
3. For each issue:
   - Severity: critical/major/minor/suggestion
   - Category: correctness/security/performance/maintainability/testing
   - File:line location
   - Description
   - Suggested fix
4. Output summary to `review.md`

## Issue Severity Guide
- **Critical**: Security vulnerabilities, data loss, crashes
- **Major**: Bugs, significant performance issues
- **Minor**: Code smell, minor inefficiency
- **Suggestion**: Style, optional improvements

Context: XRoads Complete UI & Orchestrator System
Files: 
Branch: main

## End XRoads Skills
