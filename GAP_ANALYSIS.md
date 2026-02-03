# XRoads Gap Analysis — Vision vs Current State

## Ta Vision

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           XRoads Workflow Idéal                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    FRICTIONLESS INIT                                 │  │
│  │  - Auto-detect repo                                                  │  │
│  │  - No worktree sheet popup                                           │  │
│  │  - Quick action buttons visible                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      ACTION SELECTION                                │  │
│  │                                                                      │  │
│  │   [🔨 Implement]  [🔍 Review]  [🧪 Test]  [✍️ Write]  [⚙️ Custom]   │  │
│  │                                                                      │  │
│  │   Chaque action = Loop spécialisée avec skills définis              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      AGENT SELECTION                                 │  │
│  │                                                                      │  │
│  │   [Claude Code]     [Gemini CLI]     [Codex]                        │  │
│  │   ✓ All skills      ✓ Most skills    ✓ Basic skills                 │  │
│  │                                                                      │  │
│  │   Skills chargés selon action + compatibilité CLI                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    TERMINAL INTERACTIF                               │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │  > Agent: "Which authentication method?"                       │ │  │
│  │  │  > Agent: "1. JWT  2. Session  3. OAuth"                       │ │  │
│  │  │  │                                                              │ │  │
│  │  │  │ (User peut répondre directement dans le terminal)           │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │  [Type your response...                              ] [Send]  │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  WORKS IN BOTH:  [Single Mode]  AND  [Agentic Mode (6 slots)]             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## État Actuel vs Gaps

### GAP 1: No Action Selection ❌

**Current:**
```swift
// AgentLauncher.swift - Lance un CLI sans action spécifique
func launchAgent(assignment:, prd:, sessionID:, instructions:, onOutput:)
// → instructions = texte brut générique
```

**Target:**
```swift
// ActionRunner.swift - Lance une ACTION avec skills
func run(action: ActionType, agent: AgentType, worktree: Worktree, skills: [Skill])
// ActionType = .implement | .review | .test | .write | .custom
```

**Impact:** L'utilisateur ne peut pas choisir "Review mon code" ou "Écris des tests"

---

### GAP 2: No Interactive Terminal Input ❌

**Current:**
```swift
// TerminalSlotView.swift - Read-only
private var terminalContent: some View {
    ScrollView {
        ForEach(slot.recentLogs) { log in  // ← OUTPUT ONLY
            MiniLogLine(log: log)
        }
    }
}
// Pas d'InputBar, pas de stdin bridge
```

**Target:**
```swift
// TerminalSlotView.swift - Avec input
VStack {
    terminalOutput  // Logs

    if slot.needsInput {
        TerminalInputBar(onSubmit: { text in
            await processRunner.sendInput(id: slot.processId, text: text)
        })
    }
}
```

**Impact:** Impossible de répondre à AskClaudeCode

---

### GAP 3: No Skill Packaging ❌

**Current:**
```swift
// AGENTFileGenerator.swift - Texte brut
func generate(assignment:, prd:, instructions:) -> String {
    """
    # AGENT BRIEF
    ## Stories
    \(stories)
    ## Coordination
    Use MCP emit_log...
    """
}
// → Pas de skills, pas de prompt templates
```

**Target:**
```swift
// Skill.swift
struct Skill: Codable {
    let id: String           // "commit"
    let name: String         // "Git Commit"
    let promptTemplate: String
    let requiredTools: [String]
    let compatibility: [AgentType]
}

// SkillLoader.swift
func loadSkills(for action: ActionType, agent: AgentType) -> [Skill]
```

**Impact:** Pas de réutilisation, pas de standardisation

---

### GAP 4: No Cross-CLI Conformity ❌

**Current:**
```swift
// CLIAdapters.swift - Formatage basique
func formatCommand(_ command: String) -> String {
    command.hasSuffix("\n") ? command : command + "\n"
}
// → Même format pour tous les CLIs
```

**Target:**
```swift
// SkillAdapter.swift
protocol SkillAdapter {
    func adapt(skill: Skill, context: ActionContext) -> String
}

// ClaudeSkillAdapter.swift
struct ClaudeSkillAdapter: SkillAdapter {
    func adapt(skill: Skill, context: ActionContext) -> String {
        // Claude-specific: peut utiliser /skill syntax
        "/\(skill.id) \(context.args)"
    }
}

// GeminiSkillAdapter.swift
struct GeminiSkillAdapter: SkillAdapter {
    func adapt(skill: Skill, context: ActionContext) -> String {
        // Gemini: prompt direct avec instructions
        """
        [SKILL: \(skill.name)]
        \(skill.promptTemplate)
        Context: \(context)
        """
    }
}
```

**Impact:** Un skill Claude ne marche pas sur Gemini

---

### GAP 5: Friction in Worktree Init ❌

**Current:**
```
User opens app
    → Sees empty dashboard
    → Must click "New Worktree"
    → Modal appears with form
    → Fill branch name, base branch
    → Click Create
    → Then configure slot
    → Then select agent
    → Then start

    = 7+ interactions minimum
```

**Target:**
```
User opens app (in git repo)
    → App auto-detects repo
    → Shows QuickActionBar: [Implement] [Review] [Test]
    → User clicks action
    → Auto-creates worktree with convention name
    → Starts immediately

    = 1-2 interactions
```

---

### GAP 6: Actions not unified Single/Agentic ❌

**Current:**
```swift
// XRoadsDashboardView.swift - Flows différents
switch dashboardMode {
case .single:
    SingleTerminalLayout(...)  // Flow A
case .agentic:
    TerminalGridLayout(...)    // Flow B
}
// → Configuration et exécution différentes
```

**Target:**
```swift
// ActionRunner unifié
actor ActionRunner {
    func run(action: ActionType, slots: [TerminalSlot]) async {
        // Même logique, slots.count = 1 (single) ou N (agentic)
        for slot in slots where slot.isConfigured {
            await executeAction(action, in: slot)
        }
    }
}
```

---

## Mapping: Nexus-Scripts → XRoads Actions

| Nexus Script | XRoads Action | Skills Required |
|--------------|---------------|-----------------|
| `nexus-loop` | `.implement` | prd, code-writer, commit |
| `codex-loop` | `.implement` | prd, code-writer (codex-adapted) |
| `test-writer-loop` | `.test` | test-writer, coverage |
| `test-runner-loop` | `.test` | test-runner |
| N/A (new) | `.review` | code-reviewer, lint |
| N/A (new) | `.write` | doc-generator |

---

## Architecture Cible

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              XRoads v3                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────────────────┐  │
│  │ ActionType  │     │ SkillRegistry│     │     SkillAdapters          │  │
│  │ .implement  │────▶│ commit       │────▶│ ClaudeSkillAdapter         │  │
│  │ .review     │     │ review-pr    │     │ GeminiSkillAdapter         │  │
│  │ .test       │     │ prd          │     │ CodexSkillAdapter          │  │
│  │ .write      │     │ test-writer  │     └─────────────────────────────┘  │
│  └─────────────┘     │ code-reviewer│                   │                  │
│         │            └──────────────┘                   │                  │
│         │                   │                           ▼                  │
│         │                   │            ┌─────────────────────────────┐  │
│         └───────────────────┴───────────▶│       ActionRunner         │  │
│                                          │  - Loads skills for action │  │
│                                          │  - Adapts for CLI          │  │
│                                          │  - Generates AGENT.md      │  │
│                                          │  - Launches process        │  │
│                                          └─────────────────────────────┘  │
│                                                        │                   │
│                    ┌───────────────────────────────────┼───────────────┐  │
│                    │                                   │               │  │
│                    ▼                                   ▼               ▼  │
│           ┌──────────────┐                  ┌──────────────┐  ┌────────┐ │
│           │ ProcessRunner│◀─────────────────│TerminalSlot │  │  stdin │ │
│           │   (stdout)   │                  │  (display)   │──│ bridge │ │
│           └──────────────┘                  └──────────────┘  └────────┘ │
│                                                     ▲                     │
│                                                     │                     │
│                                          ┌──────────────────┐            │
│                                          │ TerminalInputBar │            │
│                                          │ (user response)  │            │
│                                          └──────────────────┘            │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Priorités d'Implémentation

### Phase 1: CRITICAL (Semaine 1)
1. **US-V3-004** - Interactive Terminal Input
2. **US-V3-013** - ProcessRunner stdin bridge
3. **US-V3-001** - ActionType model

→ **Goal:** User peut répondre aux questions agent

### Phase 2: HIGH (Semaine 2)
4. **US-V3-002** - Skill model & registry
5. **US-V3-003** - ActionRunner service
6. **US-V3-005** - Action picker UI

→ **Goal:** User peut sélectionner une action

### Phase 3: HIGH (Semaine 3)
7. **US-V3-006** - Cross-CLI skill adapters
8. **US-V3-008** - Built-in skills
9. **US-V3-009** - TerminalSlot extension

→ **Goal:** Skills fonctionnent sur Claude/Gemini/Codex

### Phase 4: MEDIUM (Semaine 4)
10. **US-V3-010** - Implement action
11. **US-V3-011** - Review action
12. **US-V3-012** - Test action

→ **Goal:** Loops complètes disponibles

### Phase 5: POLISH
13. **US-V3-007** - Frictionless UX
14. **US-V3-014** - Unified flow

→ **Goal:** Experience fluide < 3 clicks

---

## Fichiers à Créer

```
XRoads/
├── Models/
│   ├── ActionType.swift          # NEW
│   └── Skill.swift               # NEW
├── Services/
│   ├── ActionRegistry.swift      # NEW
│   ├── ActionRunner.swift        # NEW
│   ├── SkillRegistry.swift       # NEW
│   ├── SkillLoader.swift         # NEW
│   └── SkillAdapters/
│       ├── SkillAdapter.swift    # NEW
│       ├── ClaudeSkillAdapter.swift
│       ├── GeminiSkillAdapter.swift
│       └── CodexSkillAdapter.swift
├── Actions/
│   ├── ImplementAction.swift     # NEW
│   ├── ReviewAction.swift        # NEW
│   └── TestAction.swift          # NEW
├── Views/
│   └── Components/
│       ├── TerminalInputBar.swift    # NEW
│       ├── ActionPickerMenu.swift    # NEW
│       └── QuickActionBar.swift      # NEW
└── Resources/
    └── Skills/
        ├── commit.skill.json     # NEW
        ├── review-pr.skill.json
        ├── prd.skill.json
        ├── test-writer.skill.json
        └── code-reviewer.skill.json
```

---

## Conclusion

**6 gaps majeurs identifiés:**
1. ❌ No Action Selection → ActionType + ActionRunner
2. ❌ No Interactive Input → TerminalInputBar + stdin bridge
3. ❌ No Skill Packaging → Skill model + SkillRegistry
4. ❌ No CLI Conformity → SkillAdapters (x3)
5. ❌ Worktree Friction → QuickActionBar + auto-detect
6. ❌ Split Single/Agentic → Unified ActionRunner

**Estimation:** 14 user stories, ~67 points de complexité
