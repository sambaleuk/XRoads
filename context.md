# CrossRoads Project Context

_Last updated: 2026-02-03_

## Current State

- **CrossRoads v1 – Multi-CLI Orchestrator** is feature complete (see `prd.json` and `progress.txt`). All 19 user stories shipped on branch `feat/crossroads-v1`; the app builds via `swift build` and exposes the Dark Pro UI, Git/MCP services, keyboard shortcuts, and settings.
- **CrossRoads v2 – Full Agentic Mode** is in discovery/architecture on branch `feat/full-agentic-mode`. Requirements live in `prd-v2.json` and build upon the v1 codebase, reusing existing services (GitService, ProcessRunner, MCPClient, CLIAdapters, ConfigChecker).
- **MCP Server (`crossroads-mcp/`)** is available and must be running for log streaming/status updates. The Swift app launches it via `MCPClient`.
- **Orchestration History** persists every successful merge (per-agent metrics, conflicts, rerun metadata) under `~/.crossroads/history/orchestrations.json` and is surfaced via the toolbar “History” sheet with a one-click PRD rerun shortcut.
- **Agent Health Monitoring** automatically detects non-responsive agents (no status >2 min) and repeated status loops (>5 identical messages), raises UI alerts (Wait/Restart/Reassign/Abort), and displays average story time + success rate per agent on the dashboard.

## Environment & Tooling

- macOS 14.0+ with Swift 5.9 toolchain (Command Line Tools only). Use `scripts/swift-build.sh` (wraps `swift build --disable-sandbox`) so SwiftPM/clang caches stay inside `.build/cache/`; no `xcodebuild`.
- `SWIFT_STRICT_CONCURRENCY=complete` is enforced through Package.swift; keep all view models `@MainActor` and models `Sendable`.
- Agents (Claude/Gemini/Codex) must be installed locally (`/usr/local/bin/*`). ConfigChecker caches availability for 5 minutes.
- Worktrees live under the main repo unless v2 orchestrator decides to use `~/.crossroads/worktrees/{repoHash}/{branch}`.

## Active Branches & Files

| Purpose | Branch | Key Files |
| --- | --- | --- |
| v1 implementation | `feat/crossroads-v1` | `CrossRoads/`, `Package.swift`, `prd.json`, `progress.txt` |
| v2 design | `feat/full-agentic-mode` | `prd-v2.json`, `context.md`, updated `AGENTS.md` |
| MCP server | `main` | `crossroads-mcp/` (Node/TypeScript project) |

## Workflows

1. **Manual Mode (v1)** – Use WorktreeCreateSheet to add worktrees, start agents via SessionViewModel, monitor logs with TerminalView. User drives all orchestration.
2. **Full Agentic Mode (v2)** – Claude Orchestrator (actor) will:
   - Parse a PRD JSON (`prd-v2.json` format) and split stories into task groups per agent.
   - Create dedicated Git worktrees/branches automatically (deterministic paths).
   - Launch Gemini/Codex/Claude CLI instances with contextual `AGENT.md` + `notes/`.
   - Monitor agent status files under `/tmp/crossroads/agents/` and feed UI dashboards.
   - Coordinate merges (auto for conflict-free paths, manual ConflictResolutionSheet otherwise).
   - Persist orchestration history with per-agent metrics and enable reruns directly from the History sheet / PRD loader hand-off.

## Key References

- `NEXUS_ART_DIRECTION.md` – canonical palette/typography for Dark Pro theme.
- `ios-swift-skills/INTERNAL_USAGE.md` – how to install internal Swift skills for this repo.
- `progress.txt` – chronological log for v1 + v2 work; update for every iteration.
- `AGENTS.md` – operational rules for AI agents (see “Full Agentic Mode” section).

## Next Steps (v2)

1. Implement Orchestrator protocol + ClaudeOrchestrator actor (US-V2-001).
2. Build PRDParser + TaskSplitter (US-V2-002) using the new `.json` format.
3. Automate worktree creation paths (US-V2-003) and agent launching (US-V2-004).
4. Stand up monitoring layers (AgentStatusMonitor, AgentEventBus) feeding ProgressDashboardView.

Keep `context.md`, `AGENTS.md`, and `progress.txt` aligned whenever process or architecture changes occur.
