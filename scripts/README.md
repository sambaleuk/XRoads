# XRoads Loop Scripts

Autonomous AI agent loops for PRD-driven development.

## Scripts

| Script | Agent | Description |
|--------|-------|-------------|
| `nexus-loop` | Claude Code | Main development loop |
| `gemini-loop` | Gemini CLI | Google's Gemini agent |
| `codex-loop` | Codex | OpenAI's Codex agent |

## Usage

### Option A: Run from repo (bundled)

```bash
# From any project with a prd.json
/path/to/CrossRoads/scripts/nexus-loop [max_iterations] [sleep_seconds]
/path/to/CrossRoads/scripts/gemini-loop [max_iterations] [sleep_seconds]
/path/to/CrossRoads/scripts/codex-loop [max_iterations] [sleep_seconds]
```

### Option B: Install globally

```bash
# Run the installer
./scripts/install.sh

# Then use from anywhere
nexus-loop
gemini-loop
codex-loop
```

## Prerequisites

### CLI Tools

Install the required CLI tools:

```bash
# Claude Code
npm install -g @anthropic-ai/claude-code

# Gemini CLI
npm install -g @google/gemini-cli

# Codex (OpenAI)
# Follow OpenAI instructions for Codex CLI
```

### Other Dependencies

```bash
# jq (JSON processor)
brew install jq  # macOS
apt install jq   # Linux
```

## How It Works

1. **Read PRD**: Each loop reads `prd.json` to find pending user stories
2. **Implement Story**: The agent implements one story per iteration
3. **Run Tests**: Unit tests are mandatory for completion
4. **Update Status**: Story marked "complete" if tests pass
5. **Repeat**: Loop continues until all stories complete or max iterations

## PRD Format

Create a `prd.json` in your project:

```json
{
  "feature_name": "My Feature",
  "user_stories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "What needs to be done",
      "status": "pending",
      "unit_test": {
        "file": "tests/unit/story.test.ts",
        "description": "Test description"
      }
    }
  ]
}
```

## Output Files

| File | Purpose |
|------|---------|
| `progress.txt` | Session log with learnings |
| `AGENTS.md` | Codebase patterns for agents |
| `logs/` | Iteration logs (gemini/codex) |

## Banner

All loops display a unified NEXUS LOOP banner:

```
╔═══════════════════════════════════════════════════════════════╗
║     ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗              ║
║     ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝              ║
║     ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗              ║
║     ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║              ║
║     ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║              ║
║     ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝              ║
║                     L O O P                                   ║
║                 ─── Claude Code ───                           ║
╚═══════════════════════════════════════════════════════════════╝
```

## Troubleshooting

### CLI not found
Ensure the CLI is in your PATH or set custom paths in XRoads Settings.

### common.sh not found
Run `./scripts/install.sh` to install the library globally.

### Gemini can't write files
Add the filesystem MCP to `~/.gemini/settings.json`:
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/projects"]
    }
  }
}
```
