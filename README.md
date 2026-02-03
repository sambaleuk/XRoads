# XRoads

**XRoads** is a native macOS application that orchestrates multiple AI coding agents (Claude Code, Gemini CLI, Codex) working in parallel on isolated git worktrees.

## Features

- **Multi-Agent Orchestration**: Run Claude Code, Gemini CLI, and Codex simultaneously on separate worktrees
- **Git Worktree Management**: Create, manage, and monitor isolated git worktrees for parallel development
- **Real-time Log Streaming**: View agent output and logs in real-time via MCP (Model Context Protocol)
- **Dark Pro Theme**: Beautiful dark UI designed for long coding sessions
- **Full Agentic Mode**: Let Claude orchestrate task distribution across agents automatically
- **PRD-Driven Development**: Load PRD files to automatically assign tasks to agents

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+
- Node.js 18+ (for MCP server)
- Git

### Optional CLI Tools

- [Claude Code](https://claude.ai/code) - Anthropic's CLI coding assistant
- [Gemini CLI](https://github.com/google/gemini-cli) - Google's CLI assistant
- [Codex](https://openai.com/codex) - OpenAI's coding assistant

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/sambaleuk/XRoads.git
cd XRoads

# Build the MCP server
cd xroads-mcp
npm install
npm run build
cd ..

# Build and run the app
swift build
swift run XRoads
```

### Using Xcode

1. Open `Package.swift` in Xcode
2. Select the XRoads scheme
3. Build and run (⌘R)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          XRoads (SwiftUI)                           │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │ Worktree A  │  │ Worktree B  │  │ Worktree C  │                 │
│  │ Claude Code │  │ Gemini CLI  │  │   Codex     │                 │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │
│         └────────────────┼────────────────┘                         │
│                          ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   XRoads MCP Server                          │   │
│  │            emit_log • update_status • get_state              │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
XRoads/
├── XRoads/
│   ├── App/
│   │   └── XRoadsApp.swift          # App entry point
│   ├── Models/                       # Data models
│   ├── Views/                        # SwiftUI views
│   ├── ViewModels/                   # View models
│   ├── Services/                     # Core services (Git, MCP, Process)
│   └── Resources/                    # Theme and assets
├── xroads-mcp/                       # MCP server (TypeScript)
├── Package.swift                     # Swift Package Manager config
└── README.md
```

## Usage

1. **Launch XRoads**
2. **Create a Worktree**: Click the "+" button in the sidebar
3. **Select an Agent**: Choose Claude, Gemini, or Codex
4. **Start Working**: The agent begins working in its isolated worktree
5. **Monitor Progress**: View logs and status in real-time

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New Worktree |
| ⌘W | Close Worktree |
| ⌘. | Stop Agent |
| ⌘K | Command Palette |
| ⌘L | Clear Logs |
| ⌘Q | Quit |

## Development

### Building the MCP Server

```bash
cd xroads-mcp
npm install
npm run build
npm run dev  # for development with watch mode
```

### Running Tests

```bash
swift test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with SwiftUI for macOS
- Uses [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) for agent communication
- Dark Pro theme inspired by modern code editors
