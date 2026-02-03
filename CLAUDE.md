# CLAUDE.md - XRoads Development Guide

This file provides guidance for AI agents (Claude, etc.) working on the XRoads codebase.

## Project Overview

**XRoads** is a native macOS SwiftUI application that orchestrates multiple AI coding agents (Claude Code, Gemini CLI, Codex) working in parallel on isolated git worktrees.

## Quick Start

```bash
# Build
swift build

# Run
swift run XRoads

# Build with Xcode (creates proper app bundle)
xcodebuild -scheme XRoads -destination 'platform=macOS' build
```

## Architecture

```
XRoads/
├── App/
│   └── XRoadsApp.swift          # @main entry point, AppDelegate
├── Models/                       # Data models (Codable, Sendable)
├── Views/                        # SwiftUI views
│   └── Components/              # Reusable UI components
├── ViewModels/                   # @Observable view models
├── Services/                     # Actor-based services
└── Resources/                    # Theme, assets
```

## Key Patterns

### 1. Actor-Based Concurrency
All services use Swift actors for thread safety:
```swift
actor GitService {
    func createWorktree(...) async throws -> Worktree
}
```

### 2. Environment-Based Dependency Injection
```swift
@Environment(\.appState) private var appState
```

### 3. MCP Integration
The app communicates with agents via Model Context Protocol (MCP):
- Server: `xroads-mcp/` (TypeScript)
- Client: `Services/MCPClient.swift` (Swift actor)

## Critical Bug Fixes

### TextField Keyboard Input in macOS Apps (IMPORTANT!)

**Problem**: When running a SwiftUI macOS app via `swift run`, TextField/NSTextField in sheets or secondary windows don't receive keyboard input. User hears system "bonk" sound.

**Root Cause**: Apps run via `swift run` don't have proper activation policy set by default.

**Solution**: Add this to your AppDelegate:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // CRITICAL: Set activation policy for keyboard input
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
}
```

**Why it works**: `.regular` activation policy allows the app to:
- Appear in the Dock
- Receive keyboard events in all windows
- Properly manage window focus

### NSTextField in Sheets Best Practices

Even with proper activation policy, for reliable text input in sheets:

1. **Use pure AppKit windows** for forms requiring text input (see `FloatingInputWindow.swift`)
2. **Activate app before showing window**:
   ```swift
   NSApp.activate(ignoringOtherApps: true)
   window.makeKeyAndOrderFront(nil)
   ```
3. **Focus text field after window appears**:
   ```swift
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
       window.makeFirstResponder(textField)
   }
   ```

## File Naming Conventions

- Views: `*View.swift`, `*Sheet.swift`, `*Card.swift`
- ViewModels: `*ViewModel.swift`
- Services: `*Service.swift`, `*Client.swift`
- Models: Singular nouns (`Agent.swift`, `Worktree.swift`)

## Testing

```bash
# Run tests
swift test

# Test TextField bug reproduction
swift Tests/test_textfield_bug.swift
```

## Common Tasks

### Adding a New View
1. Create `Views/MyNewView.swift`
2. Add to `Package.swift` sources array
3. Use `@Environment(\.appState)` for state access

### Adding a New Service
1. Create `Services/MyService.swift` as an actor
2. Add to `ServiceContainer.swift`
3. Add to `Package.swift` sources array

### Adding a New Model
1. Create `Models/MyModel.swift`
2. Conform to `Codable`, `Sendable`, `Hashable` as needed
3. Add to `Package.swift` sources array

## Dependencies

- **macOS 14.0+** (Sonoma)
- **Swift 5.9+**
- **Node.js 18+** (for MCP server)

## MCP Server

```bash
cd xroads-mcp
npm install
npm run build
npm start  # or npm run dev
```

## Git Workflow

- Main branch: `main`
- Feature branches: `feat/<feature-name>`
- Bug fixes: `fix/<bug-name>`

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New Worktree |
| ⌘W | Close Worktree |
| ⌘. | Stop Agent |
| ⌘K | Command Palette |
| ⌘L | Clear Logs |

## Troubleshooting

### App doesn't receive keyboard input
- Ensure `NSApp.setActivationPolicy(.regular)` is called in AppDelegate
- Check that windows are made key with `makeKeyAndOrderFront`

### MCP server not found
- Build the MCP server: `cd xroads-mcp && npm run build`
- Check path in `MCPClient.swift` `findMCPServerPath()`

### CLI tools not detected
- Check `ConfigChecker.swift` for search paths
- Ensure tools are in PATH or standard locations

## Code Style

- Use Swift's native async/await
- Prefer actors over classes for shared state
- Use `@MainActor` for UI-related code
- Keep views small, extract to components
- Document public APIs with `///` comments
