# XRoads - Modèles d'Architecture

> Document de référence pour la cohérence architecturale du système XRoads

---

## 1. MCD - Modèle Conceptuel de Données

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           MCD - XRoads Data Model                                       │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│   PRDDocument    │          │   PRDUserStory   │          │  DependencyLayer │
├──────────────────┤          ├──────────────────┤          ├──────────────────┤
│ _id_: UUID       │          │ _id_: String     │          │ level: Int       │
│ featureName      │ 1,n      │ title            │   n,1    │ storyIds: [Str]  │
│ description      │◄────────►│ description      │◄────────►│                  │
│ author           │ contient │ priority         │ appartient                  │
│ templateType     │          │ status           │          └──────────────────┘
│ createdAt        │          │ dependsOn: [Str] │
│ updatedAt        │          │ estimatedComplx  │
└──────────────────┘          │ acceptanceCrit   │
                              └──────────────────┘
                                      │
                                      │ 0,1
                                      ▼ possède
                              ┌──────────────────┐
                              │   PRDUnitTest    │
                              ├──────────────────┤
                              │ file: String     │
                              │ status           │
                              └──────────────────┘

┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│  TerminalSlot    │          │    Worktree      │          │    AgentType     │
├──────────────────┤          ├──────────────────┤          ├──────────────────┤
│ _slotNumber_:Int │   0,1    │ _id_: UUID       │          │ _rawValue_: Str  │
│ status           │◄────────►│ path: String     │          │ (claude/gemini/  │
│ currentTask      │ utilise  │ branch: String   │   1,1    │  codex)          │
│ progress: Double │          │ createdAt        │◄────────►│                  │
│ processId: UUID? │          └──────────────────┘ héberge  │ cliPath          │
│ logs: [LogEntry] │                                        │ loopScriptName   │
└──────────────────┘                                        └──────────────────┘
        │                                                           │
        │ 0,1                                                       │ 0,1
        ▼ assigné_à                                                 ▼ exécute
┌──────────────────┐                                        ┌──────────────────┐
│    ActionType    │                                        │      Skill       │
├──────────────────┤                                        ├──────────────────┤
│ _rawValue_: Str  │                                        │ _id_: UUID       │
│ (implement/      │                                        │ name: String     │
│  review/test)    │                                        │ description      │
│ category         │                                        │ category         │
│ iconName         │                                        │ supportedAgents  │
└──────────────────┘                                        │ template         │
                                                            └──────────────────┘

┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│     Session      │          │      Agent       │          │    LogEntry      │
├──────────────────┤          ├──────────────────┤          ├──────────────────┤
│ _id_: UUID       │   1,n    │ _id_: UUID       │          │ _id_: UUID       │
│ name: String     │◄────────►│ type: AgentType  │   1,n    │ level: LogLevel  │
│ status           │ contient │ status           │◄────────►│ source: String   │
│ worktreePath     │          │ worktree         │ génère   │ message: String  │
│ startedAt        │          │ currentTask      │          │ timestamp        │
│ completedAt      │          │ processId        │          │ worktree?        │
└──────────────────┘          └──────────────────┘          └──────────────────┘

┌──────────────────┐          ┌──────────────────┐
│  ChatMessage     │          │ OrchestrationRec │
├──────────────────┤          ├──────────────────┤
│ _id_: UUID       │          │ _id_: UUID       │
│ role: ChatRole   │          │ prdName          │
│ content          │          │ startedAt        │
│ timestamp        │          │ completedAt      │
│ status           │          │ status           │
│ actions?         │          │ agentMetrics     │
└──────────────────┘          └──────────────────┘
```

### Cardinalités Principales

| Relation | Cardinalité | Description |
|----------|-------------|-------------|
| PRDDocument → PRDUserStory | 1,n | Un PRD contient plusieurs stories |
| TerminalSlot → Worktree | 0,1 | Un slot peut avoir un worktree |
| TerminalSlot → AgentType | 0,1 | Un slot peut être assigné à un agent |
| TerminalSlot → ActionType | 0,1 | Un slot peut avoir une action assignée |
| ActionType → Skill | 1,n | Une action requiert plusieurs skills |
| Agent → LogEntry | 1,n | Un agent génère plusieurs logs |
| PRDUserStory → DependencyLayer | n,1 | Stories groupées par layer |

### Flux ActionType → Skills → AGENT.md

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ActionType → Skills Integration                               │
└─────────────────────────────────────────────────────────────────────────────────┘

┌────────────────┐        ┌────────────────┐        ┌────────────────┐
│   ActionType   │   1,n  │     Skill      │   n,1  │   AgentType    │
├────────────────┤◄──────►├────────────────┤◄──────►├────────────────┤
│ implement      │requiert│ prd            │ compatible │ claude       │
│ review         │        │ code-writer    │  avec      │ gemini       │
│ integrationTest│        │ commit         │            │ codex        │
│ write          │        │ code-reviewer  │            │              │
│ custom         │        │ lint           │            │              │
│                │        │ doc-generator  │            │              │
│ requiredSkills │        │ integration-test│           │              │
└────────────────┘        └────────────────┘            └────────────────┘
        │                         │
        │                         │
        └────────────┬────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │    SkillLoader         │
        ├────────────────────────┤
        │ loadSkillsForAction()  │
        │ generateAgentMD()      │
        │ processPromptTemplate()│
        └────────────┬───────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │      AGENT.md          │
        ├────────────────────────┤
        │ - Session Overview     │
        │ - Mission (ActionType) │
        │ - Loaded Skills        │
        │ - Skill Instructions   │
        │ - Assigned Stories     │
        │ - Dependencies         │
        │ - Workflow             │
        └────────────────────────┘
```

### ActionTypes et leurs Skills

| ActionType | Required Skills | Category | Description |
|------------|-----------------|----------|-------------|
| implement | prd, code-writer, commit | dev | PRD → User Stories → Code + Unit Tests |
| review | code-reviewer, lint | dev | Analyze code for issues, suggest fixes |
| integrationTest | integration-test, e2e-test, perf-test | qa | Generate integration, e2e, and performance tests |
| write | doc-generator | ops | Generate documentation, README, API docs |
| custom | (user-defined) | ops | Custom action with user-defined skills |

---

## 2. MCT - Modèle Conceptuel de Traitements

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                      MCT - XRoads Event-Result Model                                    │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │         POINT D'ENTRÉE 1            │
                    │        (PRD Loader Flow)            │
                    └─────────────────────────────────────┘

    ╭─────────────────╮
    │  E1: Fichier    │
    │  PRD sélectionné│
    ╰────────┬────────╯
             │
             ▼
    ┌────────────────────────────────────┐
    │ OP1: ParsePRD                      │
    │ ─────────────────────────          │
    │ - Valider JSON                     │
    │ - Extraire stories                 │
    │ - Calculer layers de dépendances   │
    │                                    │
    │ Règles d'émission:                 │
    │ (PRD_VALIDE) → R1                  │
    │ (PRD_INVALIDE) → R2                │
    └────────────────────────────────────┘
             │
      ┌──────┴──────┐
      ▼             ▼
╭──────────╮  ╭──────────────╮
│R1: PRD   │  │R2: Erreur    │
│ chargé   │  │ de parsing   │
╰────┬─────╯  ╰──────────────╯
     │
     ▼
    ╭─────────────────╮
    │  E2: PRD prêt   │
    │  pour config    │
    ╰────────┬────────╯
             │
             ▼
    ┌────────────────────────────────────┐
    │ OP2: ShowSlotAssignment            │
    │ ─────────────────────────          │
    │ - Afficher grille de slots         │
    │ - Proposer assignation auto        │
    │ - Permettre config manuelle        │
    │                                    │
    │ Synchronisation:                   │
    │ (SLOTS_CONFIGURÉS ET START_CLICK)  │
    │     → R3                           │
    └────────────────────────────────────┘
             │
             ▼
╭────────────────────╮     ╭─────────────────╮
│R3: Configuration   │ ET  │E3: User click   │
│    complète        │◄────│    "Start"      │
╰────────┬───────────╯     ╰─────────────────╯
         │
         ▼
    ┌────────────────────────────────────┐
    │ OP3: InitializeDispatch            │
    │ ─────────────────────────          │
    │ - Créer status.json                │
    │ - Créer worktrees git              │
    │ - Valider worktrees                │
    │                                    │
    │ Règles d'émission:                 │
    │ (WORKTREES_OK) → R4                │
    │ (WORKTREE_ERROR) → R5              │
    └────────────────────────────────────┘
             │
      ┌──────┴──────┐
      ▼             ▼
╭──────────────╮  ╭──────────────╮
│R4: Worktrees │  │R5: Erreur    │
│   prêts      │  │ création     │
╰──────┬───────╯  ╰──────────────╯
       │
       ▼
    ┌────────────────────────────────────┐
    │ OP4: LaunchLoopsByLayer            │
    │ ─────────────────────────          │
    │ - Lancer loops Layer 0             │
    │ - Monitorer status.json            │
    │ - Quand layer N complet → N+1      │
    │                                    │
    │ Règles d'émission:                 │
    │ (STORY_COMPLETE) → R6              │
    │ (LAYER_COMPLETE) → R7              │
    │ (ALL_COMPLETE) → R8                │
    │ (ERROR) → R9                       │
    └────────────────────────────────────┘
             │
    ┌────────┼────────┬────────┐
    ▼        ▼        ▼        ▼
╭────────╮ ╭────────╮ ╭────────╮ ╭────────╮
│R6:Story│ │R7:Layer│ │R8: All │ │R9:Error│
│complete│ │complete│ │complete│ │        │
╰────────╯ ╰────────╯ ╰────────╯ ╰────────╯


                    ┌─────────────────────────────────────┐
                    │         POINT D'ENTRÉE 2            │
                    │        (Manual Slot Config)         │
                    └─────────────────────────────────────┘

╭─────────────────╮     ╭─────────────────╮
│E10: User click  │     │E11: User select │
│  slot vide      │     │  agent & branch │
╰────────┬────────╯     ╰────────┬────────╯
         │                       │
         └───────────┬───────────┘
                     │ (E10 ET E11)
                     ▼
    ┌────────────────────────────────────┐
    │ OP5: ConfigureSlot                 │
    │ ─────────────────────────          │
    │ - Assigner agent au slot           │
    │ - Assigner worktree/branch         │
    │ - Mettre status = ready            │
    │                                    │
    │ Règles d'émission:                 │
    │ (CONFIG_COMPLETE) → R10            │
    └────────────────────────────────────┘
         │
         ▼
╭────────────────╮     ╭─────────────────╮
│R10: Slot       │     │E12: User click  │
│    ready       │ ET  │    "Play"       │
╰────────┬───────╯     ╰────────┬────────╯
         │                      │
         └──────────┬───────────┘
                    │ (R10 ET E12)
                    ▼
    ┌────────────────────────────────────┐
    │ OP6: ExecuteActionInSlot           │
    │ ─────────────────────────          │
    │ - Lancer loop script via PTY       │
    │ - Streamer output vers logs        │
    │ - Monitorer processus              │
    │                                    │
    │ Règles d'émission:                 │
    │ (PROCESS_RUNNING) → R11            │
    │ (PROCESS_COMPLETE) → R12           │
    │ (PROCESS_ERROR) → R13              │
    └────────────────────────────────────┘


                    ┌─────────────────────────────────────┐
                    │         POINT D'ENTRÉE 3            │
                    │           (Chat Flow)               │
                    └─────────────────────────────────────┘

╭─────────────────╮
│E20: User envoie │
│  message chat   │
╰────────┬────────╯
         │
         ▼
    ┌────────────────────────────────────┐
    │ OP7: ProcessChatMessage            │
    │ ─────────────────────────          │
    │ - Parser intention                 │
    │ - Détecter commandes               │
    │ - Identifier actions               │
    │                                    │
    │ Règles d'émission:                 │
    │ (COMMAND_DETECTED) → R20           │
    │ (QUESTION) → R21                   │
    │ (PRD_REQUEST) → R22                │
    └────────────────────────────────────┘
         │
    ┌────┼────────────┬────────────┐
    ▼    ▼            ▼            ▼
╭──────╮ ╭──────────╮ ╭──────────╮ ╭──────────╮
│R20:  │ │R21:      │ │R22: PRD  │ │R23: Skill│
│Command│ │Response │ │ Request  │ │ Invoke   │
╰──────╯ ╰──────────╯ ╰──────────╯ ╰──────────╯

         ??? QUESTION: Le chat peut-il lancer des slots ???
         >>> INCOHÉRENCE DÉTECTÉE - À RÉSOUDRE <<<
```

### Synchronisations Critiques

| Sync ID | Événements requis | Opération déclenchée |
|---------|-------------------|----------------------|
| S1 | SLOTS_CONFIGURÉS ET START_CLICK | InitializeDispatch |
| S2 | CONFIG_COMPLETE ET PLAY_CLICK | ExecuteActionInSlot |
| S3 | LAYER_N_COMPLETE | LaunchLayer(N+1) |
| S4 | ALL_STORIES_COMPLETE | CompleteOrchestration |

---

## 3. BPMN - Business Process Model

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                      BPMN 2.0 - XRoads Orchestration Process                            │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ POOL: XRoads Application                                                                ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                                                         ┃
┃ ┌─────────────────────────────────────────────────────────────────────────────────────┐ ┃
┃ │ LANE: User Interface                                                                │ ┃
┃ ├─────────────────────────────────────────────────────────────────────────────────────┤ ┃
┃ │                                                                                     │ ┃
┃ │   ○──►[Load PRD]──►[Assign Slots]──►[Click Start]                                  │ ┃
┃ │   │                                       │                                         │ ┃
┃ │   │   ○──►[Config Slot]──►[Click Play]────┼───────────────────────►◉               │ ┃
┃ │   │   │                                   │                                         │ ┃
┃ │   │   │   ○──►[Send Chat]─────────────────┼───────────────────────►◉               │ ┃
┃ │   │   │                                   │                                         │ ┃
┃ │   │   │   ○──►[Quick Action]──────────────┘                                        │ ┃
┃ │   │                                                                                 │ ┃
┃ └───┼───────────────────────────────────────┬─────────────────────────────────────────┘ ┃
┃     │                                       │                                           ┃
┃     │                                       ▼                                           ┃
┃ ┌───┼───────────────────────────────────────────────────────────────────────────────────┐ ┃
┃ │ LANE: Orchestrator Service                                                          │ ┃
┃ ├───────────────────────────────────────────────────────────────────────────────────────┤ ┃
┃ │                                       │                                               │ ┃
┃ │                                       ▼                                               │ ┃
┃ │                              ◇──────────────────◇                                     │ ┃
┃ │                             ╱ Source?           ╲                                     │ ┃
┃ │                            ╱                     ╲                                    │ ┃
┃ │                   ┌───────╱─────────┬─────────────╲───────┐                           │ ┃
┃ │                   │                 │                     │                           │ ┃
┃ │                   ▼                 ▼                     ▼                           │ ┃
┃ │            [PRD Dispatch]    [Single Slot]         [Chat Action]                      │ ┃
┃ │                   │                 │                     │                           │ ┃
┃ │                   ▼                 │                     │                           │ ┃
┃ │            [Create Status]          │                     │                           │ ┃
┃ │                   │                 │                     │                           │ ┃
┃ │                   ▼                 │                     │                           │ ┃
┃ │            ◇ Parallel ◇             │                     │                           │ ┃
┃ │           ╱           ╲             │                     │                           │ ┃
┃ │          ╱             ╲            │                     │                           │ ┃
┃ │         ▼               ▼           │                     │                           │ ┃
┃ │  [Create WT 1]   [Create WT N]      │                     │                           │ ┃
┃ │         │               │           │                     │                           │ ┃
┃ │         └───────┬───────┘           │                     │                           │ ┃
┃ │                 │                   │                     │                           │ ┃
┃ │                 ▼                   │                     │                           │ ┃
┃ │            ◇ Join ◇                 │                     │                           │ ┃
┃ │                 │                   │                     │                           │ ┃
┃ │                 └───────────────────┼─────────────────────┘                           │ ┃
┃ │                                     │                                                 │ ┃
┃ │                                     ▼                                                 │ ┃
┃ └─────────────────────────────────────┬─────────────────────────────────────────────────┘ ┃
┃                                       │                                                   ┃
┃                                       ▼                                                   ┃
┃ ┌─────────────────────────────────────────────────────────────────────────────────────────┐ ┃
┃ │ LANE: Loop Launcher (PTY)                                                             │ ┃
┃ ├─────────────────────────────────────────────────────────────────────────────────────────┤ ┃
┃ │                                     │                                                   │ ┃
┃ │                                     ▼                                                   │ ┃
┃ │                          [Launch Loop Script]                                           │ ┃
┃ │                                     │                                                   │ ┃
┃ │                                     ▼                                                   │ ┃
┃ │                              ⊙ Timer 5s ⊙                                               │ ┃
┃ │                              (Poll Status)                                              │ ┃
┃ │                                     │                                                   │ ┃
┃ │                                     ▼                                                   │ ┃
┃ │                              ◇ Story Done? ◇                                            │ ┃
┃ │                             ╱               ╲                                           │ ┃
┃ │                     YES    ╱                 ╲   NO                                     │ ┃
┃ │                           ▼                   ▼                                         │ ┃
┃ │                    [Update Progress]   [Continue Loop]                                  │ ┃
┃ │                           │                   │                                         │ ┃
┃ │                           ▼                   │                                         │ ┃
┃ │                    ◇ All Done? ◇              │                                         │ ┃
┃ │                   ╱            ╲              │                                         │ ┃
┃ │           YES    ╱              ╲   NO        │                                         │ ┃
┃ │                 ▼                ▼            │                                         │ ┃
┃ │              ◉ End          [Next Layer]──────┘                                         │ ┃
┃ │                                                                                         │ ┃
┃ └─────────────────────────────────────────────────────────────────────────────────────────┘ ┃
┃                                                                                             ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

LÉGENDE BPMN:
  ○     Start Event (cercle fin)
  ◉     End Event (cercle épais)
  ⊙     Timer Event (cercle double avec horloge)
  [ ]   Task (rectangle arrondi)
  ◇     Gateway (losange) - XOR par défaut
  ◇◇    Parallel Gateway (AND)
  ───►  Sequence Flow
  - - ► Message Flow
```

---

## 4. Points d'Entrée Identifiés

### 4.1 Entrées Existantes

| # | Point d'Entrée | Fichier | Peut lancer un slot? | Peut lancer dispatch? |
|---|----------------|---------|----------------------|-----------------------|
| 1 | PRD Loader | `PRDLoaderSheet.swift` | ❌ Non | ✅ Via SlotAssignment |
| 2 | Slot Assignment | `SlotAssignmentSheet.swift` | ✅ Dispatch | ✅ LayeredDispatcher |
| 3 | Manual Slot Config | `TerminalSlotView.swift` | ✅ Single | ❌ Non |
| 4 | Chat | `OrchestratorChatView.swift` | ❓ UNCLEAR | ❓ UNCLEAR |
| 5 | Quick Actions | `GitInfoPanel.swift` | ❓ UNCLEAR | ❌ Non |
| 6 | Start All Button | `XRoadsDashboardView.swift` | ✅ All configured | ❌ Uses ActionRunner |

### 4.2 Incohérences Détectées

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      INCOHÉRENCES À RÉSOUDRE                                │
└─────────────────────────────────────────────────────────────────────────────┘

1. DUAL LAUNCH SYSTEM
   ├── SlotAssignmentSheet → LayeredDispatcher → LoopLauncher
   └── XRoadsDashboardView → AppState.executeActionInSlot → ActionRunner

   PROBLÈME: Deux chemins différents pour lancer des agents
   SOLUTION: Unifier vers un seul point d'entrée

2. CHAT CAPABILITIES UNDEFINED
   └── Le chat peut recevoir des messages mais:
       - Peut-il lancer des slots?
       - Peut-il charger un PRD?
       - Peut-il invoquer des skills?

   PROBLÈME: Fonctionnalités chat non connectées au reste
   SOLUTION: Définir et implémenter les capabilities

3. QUICK ACTIONS SCOPE
   └── GitInfoPanel propose des actions mais:
       - Quelles actions sont disponibles?
       - Comment se connectent-elles aux slots?

   PROBLÈME: Quick actions isolées
   SOLUTION: Mapper vers les mêmes workflows

4. PROGRESS TRACKING INCONSISTENT
   ├── SlotAssignment → DispatchProgress (stories count)
   └── Dashboard → globalProgress (slot progress average)

   PROBLÈME: Deux systèmes de tracking
   SOLUTION: Source unique de vérité (status.json)

5. LOG ROUTING INCOMPLETE
   ├── PTY Output → terminalSlots[n].addLog ✅
   ├── PTY Output → appState.logs ✅ (fixed)
   └── MCP Events → ???

   PROBLÈME: MCP events pas routés
   SOLUTION: Ajouter routing MCP → logs
```

---

## 5. Architecture Cible

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ARCHITECTURE CIBLE UNIFIÉE                             │
└─────────────────────────────────────────────────────────────────────────────┘

                          ┌─────────────────┐
                          │   USER ACTIONS  │
                          └────────┬────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           │                       │                       │
           ▼                       ▼                       ▼
    ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
    │  PRD Load   │        │    Chat     │        │ Quick Action│
    │   (File)    │        │  (Natural)  │        │  (Button)   │
    └──────┬──────┘        └──────┬──────┘        └──────┬──────┘
           │                      │                      │
           └──────────────────────┼──────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │    UNIFIED DISPATCHER   │
                    │  ────────────────────── │
                    │  - parseIntent()        │
                    │  - validateConfig()     │
                    │  - routeToExecutor()    │
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
    │  PRD DISPATCH   │  │  SINGLE SLOT    │  │  SKILL INVOKE   │
    │  (Multi-layer)  │  │  (Direct)       │  │  (Template)     │
    └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
             │                    │                    │
             └────────────────────┼────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │     LOOP LAUNCHER       │
                    │  (PTY Process Runner)   │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │     STATUS MONITOR      │
                    │  (status.json polling)  │
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
    │  SLOT LOGS      │  │  MCP LOGS       │  │  PROGRESS       │
    │  (Per-slot)     │  │  (Global)       │  │  (Dashboard)    │
    └─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## 6. Actions Requises

### Phase 1: Unification du Dispatch ✅ COMPLETE
- [x] Créer `UnifiedDispatcher` qui route toutes les sources ✅ (2026-02-06)
- [x] Migrer `SlotAssignmentSheet` vers UnifiedDispatcher ✅ (2026-02-06)
- [x] Ajouter support `DispatchCallbacks` avec `onLog` pour routing unifié ✅
- [ ] Migrer `AppState.executeActionInSlot` vers UnifiedDispatcher (optional - works with ActionRunner)

### Phase 1.5: ActionType & Skills Integration ✅ COMPLETE
- [x] Ajouter `ActionType` à `LoopConfiguration` ✅ (2026-02-06)
- [x] Ajouter `ActionType` à `SlotLaunchInfo` ✅ (2026-02-06)
- [x] Ajouter `ActionType` à `SlotStoryAssignment` ✅ (2026-02-06)
- [x] Intégrer `SkillLoader` dans `LoopLauncher` ✅ (2026-02-06)
- [x] Générer AGENT.md avec skills basés sur ActionType ✅ (2026-02-06)
- [x] UI: Ajouter picker d'ActionType dans SlotAssignmentSheet ✅ (2026-02-06)
- [x] Propager ActionType à travers UnifiedDispatcher → LayeredDispatcher → LoopLauncher ✅

### Phase 2: Chat Integration
- [ ] Définir les commandes chat supportées
- [ ] Connecter chat → UnifiedDispatcher
- [ ] Implémenter parsing d'intentions

### Phase 3: Progress Unification
- [x] Source unique: `status.json` pour PRD dispatch ✅ (via StatusMonitor)
- [ ] Fallback: slot.progress pour mode single
- [ ] Dashboard lit une seule source

### Phase 4: Log Routing ✅ COMPLETE
- [x] Tous les logs → `appState.logs` (MCP panel) ✅ (via DispatchCallbacks.onLog)
- [x] Logs filtrés par slot → `terminalSlots[n].logs` ✅ (via onSlotOutput)
- [ ] MCP events → routing vers les deux (requires MCP server update)

---

## Sources

- [MCD Merise](https://web.maths.unsw.edu.au/~lafaye/CCM/merise/mcd.htm)
- [MCT Merise](https://web.maths.unsw.edu.au/~lafaye/CCM/merise/mct.htm)
- [BPMN 2.0 Reference](https://camunda.com/bpmn/reference/)
- [BPMN Symbols Guide](https://www.lucidchart.com/pages/tutorial/bpmn-symbols-explained)
