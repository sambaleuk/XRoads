---
title: CrossRoads Swift Skills Usage
audience: CrossRoads macOS 14+ developers
last_updated: 2026-02-02
---

# CrossRoads Swift Skill Usage Guide

This guide explains how the CrossRoads team should install, refresh, and use the Swift-focused skills that live in `ios-swift-skills/`. All direction assumes macOS 14.0+ targets and `SWIFT_STRICT_CONCURRENCY=complete`, matching the requirements in `AGENTS.md`.

## Skill Inventory Snapshot

Packaged skills are committed as `.skill` archives alongside their source folders. Each archive mirrors its matching directory (e.g., `swift-language.skill` contains the `swift-language/` tree).

- `swift-language.skill` (`swift-language/`)
  - Fundamentals of Swift 5.x + macOS-specific patterns.
  - Includes `scripts/generate_model.py` and `assets/macos-app-template.swift`.
  - References: `fundamentals.md`, `macos-specifics.md`.
- `swift-concurrency.skill` (`swift-concurrency/`)
  - async/await, actors, TaskGroups, MainActor enforcement.
  - Includes `scripts/generate_async_code.py` and `assets/async-networking-template.swift`.
  - References: `async-await.md`, `actors.md`, `structured-concurrency.md`.
- `memory-management.skill` (`memory-management/`)
  - ARC, retain-cycle prevention, Instruments workflows.
  - References: `arc-basics.md`, `debugging-leaks.md` (no scripts/assets yet).
- `swiftui.skill` (`swiftui/`)
  - Declarative UI guidance, state management, navigation patterns.
  - Reference: `swiftui-essentials.md` (scripts/assets folders are placeholders).
- `process-management.skill` (`process-management/`)
  - Launching CLI tools, capturing output, async Process actors.
  - Reference: `process-essentials.md` (empty scripts/assets for future tooling).
- `mvvm-architecture.skill` (`mvvm-architecture/`)
  - ViewModel patterns, dependency injection, multi-session flows.
  - Reference: `mvvm-essentials.md` (scripts/assets slots reserved).
- `file-operations.skill` (`file-operations/`)
  - FileManager operations, URL vs path handling, session folders.
  - Reference: `file-essentials.md` (scripts/assets pending).

Additional directories:
- `README.md`, `START_HERE.md`, `QUICK_START.md`, `SUMMARY.md`, `INDEX.md`, `STRUCTURE.txt` describe the repository at different depths.
- Root-level `docs/` and `scripts/` are currently empty placeholders for future shared material.

## Installation & Update Workflow

1. **Sync the repository**
   - Ensure `ios-swift-skills/` is up to date in your CrossRoads checkout (`git pull` or `git submodule update`, depending on how it is wired in your workspace).
2. **Install or refresh skills locally**
   - Copy the desired archives into Claude/Codex’s skill directory:
     ```bash
     cd /Users/birahimmbow/Projets/CrossRoads/ios-swift-skills
     cp swift-language.skill ~/.anthropic/skills/
     cp swift-concurrency.skill ~/.anthropic/skills/
     # repeat for others as needed
     ```
   - Optional: symlink instead of copying to avoid manual refreshes:
     ```bash
     ln -sf $(pwd)/swift-language.skill ~/.anthropic/skills/swift-language.skill
     ```
3. **Verify installation**
   - `ls ~/.anthropic/skills | grep swift` should list the archives you expect.
4. **Adopt a refresh cadence**
   - At minimum, pull latest changes and re-copy (or rely on symlinks) once per week or whenever a skill update lands.
5. **Respect build constraints**
   - Any code or template produced through these skills must compile under macOS 14+ and pass `swift build` locally before being merged, honoring the strict concurrency flag noted in `AGENTS.md`.

## Using Skills in Codex/Claude

- **Invoke explicitly**: Begin prompts with a short line such as “Using `swift-concurrency` skill:” so the agent loads the correct instructions. Mention multiple skills only when each is directly relevant.
- **Sample prompts**
  - Swift language: “Using `swift-language` skill, generate a data model for onboarding flows.”
  - Concurrency: “With `swift-concurrency`, refactor this callback-based service to async/await.”
  - Memory: “Using `memory-management`, explain why this view model leaks and fix it.”
  - SwiftUI/MVVM: “Apply `swiftui` + `mvvm-architecture` skills to scaffold a detail screen with @Observable ViewModel.”
  - Process/File tooling: “Leverage `process-management` and `file-operations` skills to add a log rotation helper.”
- **Best practices**
  - Reference each skill’s `SKILL.md` quick-start before issuing complex requests.
  - Cite sections (e.g., `swift-concurrency/references/actors.md`) in prompts when you need a specific pattern enforced.
  - Keep prompts scoped: enable only the skills needed for the task to keep the agent reasoning focused.

## Integrating with CrossRoads Development

Map skill resources to the project’s folder conventions (`App/`, `Models/`, `Services/`, `Views/`, `ViewModels/`, `Resources/`). Recommended usage:

- **Project scaffolding**
  - Copy `swift-language/assets/macos-app-template.swift` into `App/` when starting a new module; adapt window groups, sidebars, and menu commands to match CrossRoads features.
- **Model generation**
  - Run `python3 swift-language/scripts/generate_model.py --name Feature --properties "id:UUID,title:String,isEnabled:Bool" --identifiable --example` and drop the output into `Models/`.
- **Async networking boilerplate**
  - Start from `swift-concurrency/assets/async-networking-template.swift` for any `Services/Network/` additions; ensure actors and clients stay `@MainActor` aware where necessary.
- **ViewModel + SwiftUI patterns**
  - Pair the `mvvm-architecture` references with the `swiftui` guide when adding state containers under `ViewModels/` and views under `Views/`, respecting the `@Observable` availability on macOS 14+.
- **Process + File utilities**
  - Use `process-management` and `file-operations` references when wiring automation helpers (e.g., log trimming in `Services/Automation/`). The guides include FileManager recipes for sandbox-safe file IO and Process actor samples for invoking CLI tools.

## Contribution & Maintenance Guidelines

1. **Update source first**
   - Modify the relevant `SKILL.md`, references, scripts, or assets under the source folder.
2. **Regenerate the `.skill` archive**
   - Skills are plain zip archives rooted at the skill directory:
     ```bash
     cd /Users/birahimmbow/Projets/CrossRoads/ios-swift-skills
     zip -r swift-language.skill swift-language
     ```
   - Repeat for any other skill you changed. Confirm contents with `unzip -l swift-language.skill | head`.
3. **Validate scripts/templates**
   - Run `python3 -m compileall swift-language/scripts` (or the specific script) to catch syntax errors.
   - Spot-check generators with a dry run (e.g., `python3 swift-concurrency/scripts/generate_async_code.py --type actor --name CacheStore`).
   - If templates are updated, compile affected modules via `swift build` from the repo root to ensure the instructions remain macOS 14 compliant.
4. **Document additions**
   - Update this `INTERNAL_USAGE.md` inventory when new skills or automation helpers appear.
   - Note any new dependencies or external tools introduced by a skill in `README.md` or skill-specific docs.

## Troubleshooting / FAQ

- **Skill not loading in Codex/Claude**
  - Confirm the `.skill` file exists in `~/.anthropic/skills/` and matches the latest commit timestamp.
  - Make sure the prompt explicitly references the skill name (per AGENTS instructions).
- **Generated code fails strict concurrency**
  - Re-run `swift build` with `SWIFT_STRICT_CONCURRENCY=complete` and apply fixes from `swift-concurrency` and `mvvm-architecture` references (e.g., mark ViewModels `@MainActor`, wrap mutable state in actors).
- **Scripts missing dependencies**
  - Both bundled generators run on Python 3 without extra packages. If you hit import errors, verify your shell is running the system Python 3.11+ and rerun `python3 --version`.
- **Stale archives**
  - If updates are made to a skill directory but agents still respond with old content, regenerate the `.skill` archive and recopy it locally.
- **Where to report issues**
  - File a ticket in the CrossRoads repository issue tracker (or the internal ticket queue your team uses) with the skill name, reproduction steps, and whether the `.skill` file or source directory needs correction.

## Verification Checklist

- [ ] README/INDEX references align with the inventory in this guide.
- [ ] `.skill` archives regenerated after any source change (run `zip -r ...`).
- [ ] Scripts run without errors using `python3 --version` from macOS 14+.
- [ ] `swift build` succeeds after integrating generated templates or code.
