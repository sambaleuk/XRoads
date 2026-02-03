# Codebase Patterns

This file contains reusable patterns for AI agents working on this codebase.

## Architecture

- **SwiftUI App Lifecycle**: Use `@main` on the App struct (`CrossRoadsApp.swift`)
- **Folder Structure**: App/, Models/, Services/, Views/, ViewModels/, Resources/
- **Deployment Target**: macOS 14.0+ (required for @Observable)
- **Strict Concurrency**: SWIFT_STRICT_CONCURRENCY=complete enabled
- **MCP Dependency**: `crossroads-mcp/` TypeScript server must run (launched via `MCPClient`) for log streaming/status tools.
- **Skills**: Load internal Swift skills per `ios-swift-skills/INTERNAL_USAGE.md` when coding (swift-language, swift-concurrency, memory-management, swiftui, process-management, mvvm-architecture, file-operations).

## Code Style

- **Previews**: Use `#if DEBUG` with `PreviewProvider` (not `#Preview` macro - doesn't work without Xcode IDE)
- **Build Verification**: Run `scripts/swift-build.sh` (wraps `swift build --disable-sandbox`) so SwiftPM/clang caches live inside `.build/cache/` and avoid sandbox errors.
- **Package.swift Sources**: When adding new Swift files, you MUST add them to the explicit `sources:` array in `Package.swift`. SwiftPM won't auto-discover files.

## macOS SwiftUI Known Issues & Solutions

### TextField in Sheets (CRITICAL)
SwiftUI's `TextField` has a known bug on macOS where it doesn't receive keyboard input in sheets/modals. **Solution**: Use `MacTextField` (NSViewRepresentable wrapper) from `Views/Components/MacTextField.swift`:
```swift
// Instead of:
TextField("placeholder", text: $text)

// Use:
MacTextField(placeholder: "placeholder", text: $text, isFirstResponder: true)
    .frame(height: 24)
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
swift run CrossRoads

# Kill running instance
pkill -f CrossRoads
```

## MCP Integration

The CrossRoads MCP server (`crossroads-mcp/`) provides 3 tools:
- `emit_log`: Emit structured log entries from agents
- `update_status`: Update agent status (idle/running/planning/complete/error)
- `get_state`: Get current state (agents, logs, worktrees)

**MCPClient** (Swift actor) spawns and manages the MCP server as a subprocess via stdio. JSON-RPC 2.0 protocol with separate request types for `initialize` and `tools/call`.

Key files:
- `CrossRoads/Services/MCPClient.swift` - Swift MCP client
- `crossroads-mcp/src/index.ts` - TypeScript MCP server
- `crossroads-mcp/dist/index.js` - Compiled server (run `npm run build`)

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
