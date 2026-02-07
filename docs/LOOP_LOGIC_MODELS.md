# XRoads - Loop Logic Models

> Modeles logiques complets du systeme de boucles autonomes : du lancement orchestrateur jusqu'a l'iteration agent.

---

## Table des matieres

1. [Vue d'ensemble](#1-vue-densemble)
2. [Modele de fichiers worktree](#2-modele-de-fichiers-worktree)
3. [Pipeline de lancement](#3-pipeline-de-lancement)
4. [Logique de la boucle agent](#4-logique-de-la-boucle-agent)
5. [Coordination inter-agents](#5-coordination-inter-agents)
6. [Variantes par agent](#6-variantes-par-agent)
7. [Cycle de vie complet](#7-cycle-de-vie-complet)
8. [Diagrammes d'etats](#8-diagrammes-detats)

---

## 1. Vue d'ensemble

Le systeme de boucles XRoads orchestre N agents IA travaillant en parallele sur des branches git isolees. Chaque agent execute un script de boucle (`nexus-loop`, `gemini-loop`, `codex-loop`) qui itere sur un PRD filtre jusqu'a completion de toutes les stories assignees.

```
                          ┌──────────────────────┐
                          │     USER ACTION      │
                          │  (Load PRD + Start)  │
                          └──────────┬───────────┘
                                     │
                                     ▼
                          ┌──────────────────────┐
                          │  LayeredDispatcher   │
                          │  (Orchestration)     │
                          └──────────┬───────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
     ┌────────────────┐    ┌────────────────┐    ┌────────────────┐
     │  LoopLauncher  │    │  LoopLauncher  │    │  LoopLauncher  │
     │  (Slot 1)      │    │  (Slot 2)      │    │  (Slot 3)      │
     └───────┬────────┘    └───────┬────────┘    └───────┬────────┘
             │                     │                     │
             ▼                     ▼                     ▼
     ┌────────────────┐    ┌────────────────┐    ┌────────────────┐
     │  PTY Process   │    │  PTY Process   │    │  PTY Process   │
     │  nexus-loop    │    │  gemini-loop   │    │  codex-loop    │
     └───────┬────────┘    └───────┬────────┘    └───────┬────────┘
             │                     │                     │
             ▼                     ▼                     ▼
     ┌────────────────┐    ┌────────────────┐    ┌────────────────┐
     │  Worktree 1    │    │  Worktree 2    │    │  Worktree 3    │
     │  (Claude)      │    │  (Gemini)      │    │  (Codex)       │
     └────────────────┘    └────────────────┘    └────────────────┘
             │                     │                     │
             └─────────────────────┼─────────────────────┘
                                   │
                                   ▼
                          ┌──────────────────────┐
                          │     status.json      │
                          │  (Source de verite)   │
                          └──────────┬───────────┘
                                     │
                                     ▼
                          ┌──────────────────────┐
                          │   StatusMonitor      │
                          │   (Poll 5s)          │
                          └──────────────────────┘
```

---

## 2. Modele de fichiers worktree

Chaque worktree cree par `LoopLauncher` contient un ensemble standardise de fichiers. La coherence des noms entre le code Swift et les scripts shell est critique.

### 2.1 Arborescence standard

```
<repo>/worktrees/slot-<N>-<agent>-<stories>/
├── .git                # Fichier worktree git (pas un dossier)
├── prd.json            # PRD filtre : uniquement les stories assignees
│                       #   Ecrit par : LoopLauncher.prepareWorktree()
│                       #   Lu par    : loop script (build_prompt)
│                       #   Modifie par : agent (status → "complete")
│
├── AGENT.md            # Brief contextuel riche injecte dans le prompt
│                       #   Ecrit par : LoopLauncher.createAgentMd()
│                       #   Lu par    : loop script ($AGENTS_FILE)
│                       #   Contient  : session info, mission, skills,
│                       #               stories, dependencies, workflow,
│                       #               handoff contexte precedent
│
├── progress.txt        # Log de progression iteration par iteration
│                       #   Cree par  : loop script (init) si absent
│                       #   OU par    : LoopLauncher.prepareWorktree()
│                       #   Modifie par : agent (append learnings/blockers)
│                       #   Variable  : $PROGRESS_FILE dans common.sh
│
├── logs/               # Logs bruts par iteration
│   ├── <agent>_loop_iter_1_20260207_120000.log
│   ├── <agent>_loop_iter_2_20260207_121500.log
│   └── ...
│
├── src/                # Code source du projet (cree par l'agent)
├── package.json        # Config projet (cree par l'agent)
└── .crossroads/        # Metadonnees session XRoads (optionnel)
    └── sessions.json   #   Ecrit par : SessionPersistenceService
```

### 2.2 Correspondance noms Swift ↔ Shell

| Fichier | Variable `common.sh` | Constante `LoopLauncher.swift` | Valeur |
|---------|---------------------|-------------------------------|--------|
| PRD | `$PRD_FILE` | `"prd.json"` (l.304) | `prd.json` |
| Context brief | `$AGENTS_FILE` | `"AGENT.md"` (l.319) | `AGENT.md` |
| Progress log | `$PROGRESS_FILE` | `"progress.txt"` (l.325) | `progress.txt` |
| Logs dir | `$LOG_DIR` | — (cree par le script) | `logs/` |

### 2.3 Responsabilites d'ecriture

```
┌────────────────────┬──────────────────┬──────────────────┬──────────────────┐
│                    │  LoopLauncher    │  Loop Script     │  Agent IA        │
│                    │  (Swift)         │  (Bash)          │  (Claude/etc)    │
├────────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ prd.json           │ CREATE (filtre)  │ READ (prompt)    │ READ + UPDATE    │
│                    │                  │                  │ (status→complete)│
├────────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ AGENT.md           │ CREATE (riche)   │ READ (prompt)    │ READ             │
│                    │                  │ fallback CREATE  │                  │
├────────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ progress.txt       │ CREATE (initial) │ CREATE si absent │ APPEND           │
│                    │                  │                  │ (learnings)      │
├────────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ logs/              │ —                │ CREATE (mkdir)   │ —                │
│ logs/*.log         │ —                │ CREATE (tee)     │ — (output route) │
├────────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ status.json        │ CREATE (init)    │ —                │ UPDATE           │
│ (.crossroads/)     │                  │                  │ (via jq)         │
└────────────────────┴──────────────────┴──────────────────┴──────────────────┘
```

---

## 3. Pipeline de lancement

Le lancement d'une boucle traverse 5 couches, de l'orchestrateur jusqu'au processus PTY.

### 3.1 Sequence complete

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PIPELINE DE LANCEMENT D'UN SLOT                        │
└─────────────────────────────────────────────────────────────────────────────┘

 LayeredDispatcher          LoopLauncher              PTYProcessRunner
 ════════════════           ════════════              ════════════════
        │                        │                          │
   startDispatch()               │                          │
        │                        │                          │
        ├─ calculateDependencyLayers()                      │
        │        │               │                          │
        │        └──────────────►│                          │
        │          [DependencyLayer]                        │
        │                        │                          │
        ├─ initializeSession()   │                          │
        │        │               │                          │
        │        └──────────────►│                          │
        │          statusFilePath │                          │
        │                        │                          │
        ├─ createAllWorktrees()  │                          │
        │   │ pour chaque slot:  │                          │
        │   ├─ git worktree add ─┤                          │
        │   │                    │                          │
        │   └─ validateWorktrees()                          │
        │                        │                          │
        ├─ startStatusMonitor()  │                          │
        │                        │                          │
        ├─ launchCurrentLayer()  │                          │
        │   │ pour chaque slot   │                          │
        │   │ du layer courant:  │                          │
        │   │                    │                          │
        │   └─ launchSlot(N) ───►│                          │
        │                        │                          │
        │                   launchLoop(config)              │
        │                        │                          │
        │                        ├─ findLoopScript()        │
        │                        │  (LoopScriptLocator)     │
        │                        │                          │
        │                        ├─ createWorktreeIfNeeded() │
        │                        │  (idempotent)            │
        │                        │                          │
        │                        ├─ prepareWorktree()       │
        │                        │  ├─ write prd.json       │
        │                        │  ├─ write AGENT.md       │
        │                        │  └─ write progress.txt   │
        │                        │                          │
        │                        ├─ build environment       │
        │                        │  CROSSROADS_SLOT=N       │
        │                        │  CROSSROADS_AGENT=type   │
        │                        │  CROSSROADS_WORKTREE=... │
        │                        │  CROSSROADS_STATUS_FILE=.│
        │                        │                          │
        │                        └─ ptyRunner.launch() ────►│
        │                                                   │
        │                                         PTYProcess.launch()
        │                                            │
        │                                            ├─ /usr/bin/script
        │                                            │  -q -F /dev/null
        │                                            │  /bin/bash -c
        │                                            │  "<loop-script> <args>"
        │                                            │
        │                                            ├─ env: TERM=xterm-256color
        │                                            │
        │                                            └─ callbacks:
        │                                               onOutput → UI stream
        │                                               onTermination → cleanup
        │                                                   │
        │◄──────────────────── processId (UUID) ────────────┘
        │
   [monitoring phase]
```

### 3.2 Resolution du script de boucle

```
findLoopScript(agentType) :

   AgentType.loopScriptName  →  "nexus-loop" | "gemini-loop" | "codex-loop"
                                         │
              ┌──────────────────────────┤
              │                          │
              ▼                          ▼
   1. Bundle:                    2. Project:
   Contents/Resources/          ./scripts/<name>
   scripts/<name>                        │
              │                          │
              │         pas trouve       ▼
              │              3. LoopScriptLocator.findLoopScript()
              │                 → cherche dans $PATH, ~/.nexus/bin/
              │                          │
              └──────────────────────────┘
                         │
                    URL du script executable
```

### 3.3 Construction de AGENT.md

```
createAgentMd(config, worktreePath) :

   ┌──────────────────────────────────────────────────────────────────┐
   │                        AGENT.md                                  │
   ├──────────────────────────────────────────────────────────────────┤
   │                                                                  │
   │  # AGENT BRIEF – <AgentType>                                     │
   │                                                                  │
   │  ┌───────────────────────────────────────┐                       │
   │  │ ## Previous Session Context           │ ← loadHandoffSection()│
   │  │ (handoff du dernier session)          │   SessionPersistence  │
   │  └───────────────────────────────────────┘                       │
   │                                                                  │
   │  ## Session Overview                                             │
   │  - Feature, Slot, Branch, Worktree, Repo                        │
   │  - Action: implement | review | test                             │
   │                                                                  │
   │  ## Mission: <ActionType.displayName>                            │
   │                                                                  │
   │  ┌───────────────────────────────────────┐                       │
   │  │ ## Loaded Skills                      │ ← loadSkillsForAction│
   │  │ Filtrees par compatibilite agent      │   SkillRegistry      │
   │  │ Templates processees avec variables   │   processPromptTmpl()│
   │  └───────────────────────────────────────┘                       │
   │                                                                  │
   │  ## CRITICAL: Working Directory                                  │
   │  (instructions pour travailler a la racine)                      │
   │                                                                  │
   │  ## CRITICAL: Status File Coordination                           │
   │  (instructions jq pour lire/ecrire status.json)                  │
   │                                                                  │
   │  ## Your Assigned Stories                                        │
   │  - US-001: titre (priority, deps, description)                   │
   │  - US-002: ...                                                   │
   │                                                                  │
   │  ## Dependency Workflow  (si deps existent)                      │
   │  (instructions polling 30s sur status.json)                      │
   │                                                                  │
   │  ## Other Stories (Context Only)                                 │
   │  (stories assignees a d'autres agents)                           │
   │                                                                  │
   │  ## Workflow (1-9 etapes)                                        │
   │  ## Coordination (instructions progress.txt)                     │
   │                                                                  │
   └──────────────────────────────────────────────────────────────────┘
```

---

## 4. Logique de la boucle agent

Tous les scripts de boucle (`nexus-loop`, `gemini-loop`, `codex-loop`) partagent la meme structure logique via `common.sh`. Seul `run_agent()` differe.

### 4.1 Machine a etats de la boucle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MACHINE A ETATS : LOOP SCRIPT                           │
└─────────────────────────────────────────────────────────────────────────────┘

                        ┌─────────┐
                        │  START  │
                        └────┬────┘
                             │
                             ▼
                    ┌────────────────┐     echec deps
                    │     INIT       │────────────────────► EXIT(1)
                    │                │
                    │ check_deps()   │
                    │ check PRD      │
                    │ create files   │
                    └───────┬────────┘
                            │ succes
                            ▼
                    ┌────────────────┐     pending == 0
                    │  CHECK_PRD     │────────────────────► EXIT(0)
                    │                │                      "Already complete"
                    │ count pending  │
                    │ count total    │
                    └───────┬────────┘
                            │ pending > 0
                            ▼
              ┌─────► ┌────────────────┐
              │       │  ITER_START    │     i > MAX_ITERATIONS
              │       │                │────────────────────► EXIT(1)
              │       │ i = 1..MAX     │                      "Timeout"
              │       │ recount PRD    │
              │       └───────┬────────┘
              │               │
              │               ▼
              │       ┌────────────────┐
              │       │  BUILD_PROMPT  │
              │       │                │
              │       │ read AGENT.md  │
              │       │ read status env│
              │       │ inject context │
              │       └───────┬────────┘
              │               │
              │               ▼
              │       ┌────────────────┐
              │       │  RUN_AGENT     │
              │       │                │
              │       │ <CLI> prompt   │
              │       │ tee → log file │
              │       │ tee → stderr   │
              │       └───────┬────────┘
              │               │
              │         ┌─────┴─────┐
              │         │           │
              │    exit != 0    exit == 0
              │         │           │
              │         ▼           │
              │  ┌──────────────┐   │
              │  │ HANDLE_FAIL  │   │
              │  │              │   │
              │  │ failures++   │   │
              │  │              │   │
              │  │ >= MAX_FAIL? │   │
              │  │  YES → EXIT(1)   │
              │  │  NO  → sleep │   │
              │  └──────┬───────┘   │
              │         │           │
              │         └─────┬─────┘
              │               │ exit == 0
              │               ▼
              │       ┌────────────────┐
              │       │ CHECK_COMPLETE │
              │       │                │
              │       │ grep token?    │───── oui ──► EXIT(0)
              │       │ prd pending=0? │───── oui ──► EXIT(0)
              │       └───────┬────────┘              "All complete"
              │               │ non
              │               │
              │               ▼
              │       ┌────────────────┐
              │       │   SLEEP        │
              │       │   ${SLEEP_SEC} │
              │       └───────┬────────┘
              │               │
              └───────────────┘
```

### 4.2 Pseudo-code unifie

```
function main():
    init()                              # verifier deps, creer fichiers manquants

    pending = prd_count_pending()
    if pending == 0:
        exit(0)                         # deja tout complete

    consecutive_failures = 0

    for i in 1..MAX_ITERATIONS:
        # Recompter a chaque iteration (un agent peut avoir complete des stories)
        pending = prd_count_pending()
        complete = total - pending

        # Construire le prompt avec tout le contexte
        prompt = build_prompt(i)        # AGENT.md + PRD refs + status instructions

        # Lancer l'agent IA
        exit_code = run_agent(prompt, log_file)

        if exit_code != 0:
            consecutive_failures++
            if consecutive_failures >= 3:
                exit(1)                 # trop d'echecs consecutifs
            sleep(SLEEP_SEC)
            continue                    # retry

        consecutive_failures = 0        # reset sur succes

        # Verifier si tout est fini
        if log contains "<nexus-complete>":
            exit(0)                     # token de completion detecte

        if prd_count_pending() == 0:
            exit(0)                     # PRD confirme tout complete

        sleep(SLEEP_SEC)                # pause avant prochaine iteration

    exit(1)                             # timeout : MAX_ITERATIONS atteint
```

### 4.3 Structure du prompt injecte

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PROMPT INJECTE A CHAQUE ITERATION                     │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌───────────────────────────────────────────────────────────────────┐
  │ "You are Nexus, an autonomous coding agent powered by <CLI>."     │
  │ "Do exactly ONE task per iteration."                               │
  │                                                                   │
  │ ## Context                                                        │
  │ <contenu de AGENT.md si present>                                  │
  │                                                                   │
  │ ## Steps (1-7)                                                    │
  │  1. Lire prd.json → trouver premiere story incomplete             │
  │  2. Lire progress.txt → check learnings precedents                │
  │  3. Lire AGENT.md → patterns codebase                             │
  │  4. Verifier champ unit_test                                      │
  │  5. Implementer UNE SEULE story                                   │
  │  6. Ecrire le test unitaire                                       │
  │  7. Executer le test                                              │
  │                                                                   │
  │ ## Cross-Agent Coordination (si status_file existe)               │
  │  - READ status file avant chaque story                            │
  │  - UPDATE status file quand story complete                        │
  │                                                                   │
  │ ## Completion Criteria (ALL must be true)                         │
  │  1. Implementation done                                           │
  │  2. Build passes                                                  │
  │  3. Typecheck passes                                              │
  │  4. UNIT TEST PASSES                                              │
  │                                                                   │
  │ ## If PASS → update prd.json, commit, append progress.txt         │
  │ ## If FAIL → do NOT commit, append failure to progress.txt        │
  │                                                                   │
  │ ## End Condition                                                  │
  │  Si ALL stories complete → output "<nexus-complete>ALL DONE"      │
  │  Sinon → terminer pour laisser la prochaine iteration             │
  └───────────────────────────────────────────────────────────────────┘
```

### 4.4 Logique de l'agent IA dans une iteration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              CE QUE L'AGENT FAIT DANS UNE ITERATION                        │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────┐
  │ Lire prd.json│
  └──────┬───────┘
         │
         ▼
  ┌──────────────────────┐     toutes complete
  │ Trouver 1ere story   │────────────────────────► Output "<nexus-complete>"
  │ status != "complete" │
  └──────┬───────────────┘
         │ story trouvee
         ▼
  ┌──────────────────────┐
  │ Verifier dependances │
  │ dans status.json     │
  └──────┬───────────────┘
         │
    ┌────┴────┐
    │         │
  deps OK   deps pas pretes
    │         │
    │         ▼
    │    ┌──────────────┐
    │    │ Log "waiting"│
    │    │ Sleep 30s    │
    │    │ Re-check     │──── boucle interne
    │    └──────────────┘
    │
    ▼
  ┌──────────────────────┐
  │ Lire progress.txt    │
  │ (learnings passees)  │
  └──────┬───────────────┘
         │
         ▼
  ┌──────────────────────┐
  │ IMPLEMENTER la story │
  │ + ecrire unit test   │
  └──────┬───────────────┘
         │
         ▼
  ┌──────────────────────┐
  │ Executer les checks  │
  │ build + typecheck    │
  │ + unit test          │
  └──────┬───────────────┘
         │
    ┌────┴────┐
    │         │
  PASS      FAIL
    │         │
    ▼         ▼
  ┌────────┐ ┌───────────────────────┐
  │ UPDATE │ │ NE PAS commiter       │
  │prd.json│ │ Append echec →        │
  │ status │ │   progress.txt        │
  │→"done" │ │ Laisser loop retenter │
  │        │ └───────────────────────┘
  │ UPDATE │
  │status. │
  │ json   │
  │(jq)    │
  │        │
  │ COMMIT │
  │ git    │
  │        │
  │ APPEND │
  │progress│
  │.txt    │
  └────────┘
```

---

## 5. Coordination inter-agents

### 5.1 Layers de dependances

Le `DependencyTracker` analyse le graphe de dependances des stories et les regroupe en couches (layers) executables en parallele.

```
Algorithme calculateLayers(stories) :

  assigned = {}         # stories deja placees dans un layer
  remaining = stories   # stories restantes
  level = 0

  while remaining non vide:
      layer = []

      pour chaque story dans remaining:
          si story.dependsOn ⊂ assigned:   # toutes deps satisfaites
              layer.append(story.id)

      # Detection de dependance circulaire
      si layer vide ET remaining non vide:
          layer = remaining.map(id)         # forcer le placement

      layers.append(DependencyLayer(level, layer))
      assigned = assigned ∪ layer
      remaining = remaining \ layer
      level++

  return layers
```

**Exemple concret :**

```
Stories:
  US-001 (deps: [])          ─┐
  US-002 (deps: [])          ─┤── Layer 0 (parallele)
  US-003 (deps: [])          ─┘
  US-004 (deps: [US-001])    ─┐
  US-005 (deps: [US-002])    ─┤── Layer 1 (attend Layer 0)
  US-006 (deps: [US-003])    ─┘
  US-007 (deps: [US-004, US-005]) ── Layer 2 (attend Layer 1)

Dispatch:
  t=0   ─── Layer 0: Slot1[US-001], Slot2[US-002], Slot3[US-003]
               │  tous en parallele
               ▼
  t=T1  ─── Layer 0 complete (StatusMonitor detecte)
               │  LayeredDispatcher.handleLayerComplete()
               ▼
  t=T1  ─── Layer 1: Slot1[US-004], Slot2[US-005], Slot3[US-006]
               │  tous en parallele
               ▼
  t=T2  ─── Layer 1 complete
               │
               ▼
  t=T2  ─── Layer 2: Slot1[US-007]
               │
               ▼
  t=T3  ─── ALL COMPLETE → onComplete()
```

### 5.2 Fichier status.json

```json
{
  "sessionId": "uuid",
  "prdName": "Feature Name",
  "startedAt": "2026-02-07T10:00:00Z",
  "updatedAt": "2026-02-07T10:30:00Z",
  "currentLayer": 1,
  "layers": [
    ["US-001", "US-002", "US-003"],
    ["US-004", "US-005"],
    ["US-006"]
  ],
  "stories": {
    "US-001": {
      "id": "US-001",
      "status": "complete",
      "assignedToSlot": 1,
      "dependsOn": [],
      "startedAt": "2026-02-07T10:00:05Z",
      "completedAt": "2026-02-07T10:15:00Z",
      "lastError": null
    },
    "US-004": {
      "id": "US-004",
      "status": "in_progress",
      "assignedToSlot": 1,
      "dependsOn": ["US-001"],
      "startedAt": "2026-02-07T10:20:00Z",
      "completedAt": null,
      "lastError": null
    }
  }
}
```

### 5.3 Boucle du StatusMonitor

```
StatusMonitor (actor, poll toutes les 5s) :

  while isMonitoring:
      data = read(statusFilePath)
      currentStatus = decode(data)

      si premier chargement:
          lastKnownStatus = currentStatus
          continue

      pour chaque story dans currentStatus:
          si story.status a change:
              si nouveau status == "complete":
                  emit onStoryComplete(event)

      si stories completes dans cette iteration:
          checkLayerCompletion():
              pour chaque layer:
                  si toutes stories du layer complete:
                      si layer+1 existe:
                          emit onLayerComplete(event)
                          → LayeredDispatcher.handleLayerComplete()
                          → launchCurrentLayer() du prochain layer

      si TOUTES stories complete:
          emit onAllComplete()
          → LayeredDispatcher.handleAllComplete()
          → stopMonitoring()

      lastKnownStatus = currentStatus
      sleep(5s)
```

---

## 6. Variantes par agent

Les trois scripts de boucle partagent 95% de leur logique via `common.sh`. Seul le `run_agent()` et quelques details de prompt different.

### 6.1 Comparaison

```
┌───────────────────┬──────────────────┬──────────────────┬──────────────────┐
│                   │   nexus-loop     │   gemini-loop    │   codex-loop     │
│                   │   (Claude)       │   (Gemini)       │   (Codex)        │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ CLI executable    │ claude           │ gemini           │ codex            │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ run_agent()       │ claude           │ gemini           │ printf | codex   │
│ invocation        │  --dangerously-  │  --sandbox=false │  --full-auto     │
│                   │  skip-permissions│  -p "$prompt"    │  --cd "$(pwd)"   │
│                   │  -p "$prompt"    │                  │  -               │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ Prompt input      │ argument -p      │ argument -p      │ stdin via pipe   │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ Extra prompt      │ —                │ MCP tools section│ —                │
│ section           │                  │ (filesystem,     │                  │
│                   │                  │  shell via MCP)  │                  │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ Dep check         │ check_all_deps() │ check_gemini_    │ check_codex_     │
│                   │                  │   deps()         │   deps()         │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ Log file prefix   │ nexus_loop_      │ gemini_loop_     │ codex_loop_      │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ Agent color       │ BLUE             │ YELLOW           │ GREEN            │
├───────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ Default args      │ --dangerously-   │ --sandbox=false  │ --full-auto      │
│ (AppSettings)     │ skip-permissions │                  │                  │
└───────────────────┴──────────────────┴──────────────────┴──────────────────┘
```

### 6.2 Invariants communs (common.sh)

Tous les scripts partagent :

```
Constants:
  MAX_ITERATIONS    = arg $1 (default 10)
  SLEEP_SECONDS     = arg $2 (default 3)
  MAX_CONSECUTIVE_FAILURES = 3
  COMPLETION_TOKEN  = "<nexus-complete>"

Files (from common.sh):
  PRD_FILE          = "prd.json"
  PROGRESS_FILE     = "progress.txt"
  AGENTS_FILE       = "AGENT.md"
  LOG_DIR           = "logs"

Functions:
  init()            → banner + deps + file creation
  build_prompt()    → context assembly (AGENT.md, status, iteration)
  main()            → iteration loop with failure tracking
  show_*_banner()   → visual feedback (iteration, completion, timeout)
```

---

## 7. Cycle de vie complet

### 7.1 Timeline d'une orchestration typique

```
t=0s     USER: Load PRD, assign 3 slots, click Start
         │
         ├─ LayeredDispatcher.startDispatch()
         ├─ DependencyTracker.calculateLayers() → 2 layers
         ├─ DependencyTracker.initializeStatusFile() → status.json
         │
t=2s     ├─ createAllWorktrees()
         │   ├─ git worktree add worktrees/slot-1-claude-us-001
         │   ├─ git worktree add worktrees/slot-2-gemini-us-002
         │   └─ git worktree add worktrees/slot-3-codex-us-003
         │
t=4s     ├─ validateWorktrees() ✓
         ├─ startStatusMonitor(poll=5s)
         │
t=5s     ├─ launchCurrentLayer() [Layer 0]
         │   │
         │   ├─ Slot 1: LoopLauncher.launchLoop()
         │   │   ├─ prepareWorktree() → prd.json, AGENT.md, progress.txt
         │   │   └─ PTY: nexus-loop 15 5
         │   │
         │   ├─ Slot 2: LoopLauncher.launchLoop()
         │   │   └─ PTY: gemini-loop 15 5
         │   │
         │   └─ Slot 3: LoopLauncher.launchLoop()
         │       └─ PTY: codex-loop 15 5
         │
t=6s     │   [3 agents travaillent en parallele]
         │
         │   StatusMonitor poll #1: aucun changement
t=11s    │   StatusMonitor poll #2: aucun changement
         │   ...
         │
t=180s   │   Claude complete US-001 → met a jour status.json
         │   StatusMonitor detecte: onStoryComplete("US-001")
         │
t=240s   │   Gemini complete US-002 → status.json
         │
t=300s   │   Codex complete US-003 → status.json
         │   StatusMonitor detecte: Layer 0 complete
         │   → onLayerComplete(layer=0, next=[US-004, US-005])
         │
t=301s   ├─ launchCurrentLayer() [Layer 1]
         │   ├─ Slot 1: relaunch avec US-004
         │   └─ Slot 2: relaunch avec US-005
         │
         │   [2 agents travaillent]
         │
t=500s   │   US-004 et US-005 completes
         │   StatusMonitor: ALL stories complete
         │   → onAllComplete()
         │
t=501s   ├─ stopMonitoring()
         ├─ currentPhase = .completed
         └─ onComplete() → UI notification
```

### 7.2 Gestion des echecs

```
Niveau 1 : Echec d'une iteration agent
──────────────────────────────────────
  L'agent IA echoue (exit != 0)
  → consecutive_failures++ dans le script
  → Si < 3 : sleep + retry
  → Si >= 3 : script EXIT(1)

Niveau 2 : Echec d'un script de boucle
──────────────────────────────────────
  Le script termine avec exit != 0
  → PTYProcess.onTermination(exitCode != 0)
  → LoopLauncher: session.status ne passe PAS a .completed
  → LayeredDispatcher.handleSlotTermination():
      slot.status = .failed
      Si aucun slot running et aucun pending:
          dispatch = .completed (avec echecs partiels)

Niveau 3 : Echec de creation worktree
──────────────────────────────────────
  git worktree add echoue
  → LoopLauncherError.worktreeCreationFailed
  → LayeredDispatcher: phase = .failed, onError()
  → L'orchestration entiere s'arrete

Niveau 4 : Story bloquee par dependance
──────────────────────────────────────
  L'agent poll status.json, dependency pas "complete"
  → Agent log "Waiting for dependencies..."
  → Agent sleep 30s en boucle interne
  → Si le dependency agent echoue : l'agent attendra
    jusqu'au timeout (MAX_ITERATIONS)
```

---

## 8. Diagrammes d'etats

### 8.1 Etats du Slot (SlotLaunchInfo.SlotLaunchStatus)

```
                    ┌─────────┐
                    │ pending │
                    └────┬────┘
                         │ createAllWorktrees()
                         ▼
                ┌─────────────────┐
                │ worktreeCreated │
                └────────┬────────┘
                         │ launchCurrentLayer()
                         ▼
                  ┌────────────┐
                  │ launching  │
                  └─────┬──────┘
                        │ PTY started
                        ▼
                  ┌────────────┐
              ┌───│  running   │───┐
              │   └────────────┘   │
              │                    │
         exit == 0            exit != 0
              │                    │
              ▼                    ▼
       ┌────────────┐      ┌────────────┐
       │ completed  │      │  failed    │
       └────────────┘      └────────────┘
```

### 8.2 Etats du Dispatch (DispatchPhase)

```
    ┌──────┐
    │ idle │
    └──┬───┘
       │ startDispatch()
       ▼
  ┌──────────────────┐
  │ preparingWorktrees│───── erreur ──► ┌────────┐
  └────────┬─────────┘                  │ failed │
           │                            └────────┘
           ▼                                 ▲
  ┌──────────────────┐                       │
  │validatingWorktrees│───── erreur ─────────┘
  └────────┬─────────┘                       │
           │                                 │
           ▼                                 │
  ┌──────────────────┐                       │
  │  launchingLayer  │───── erreur ─────────┘
  └────────┬─────────┘
           │
           ▼
  ┌──────────────────┐   layer complete
  │   monitoring     │──────────────────► launchingLayer
  └────────┬─────────┘                    (prochain layer)
           │
           │ all complete
           ▼
  ┌──────────────────┐
  │   completed      │
  └──────────────────┘
```

### 8.3 Etats d'une Story (StoryOrchestrationStatus)

```
    ┌─────────┐
    │ pending │
    └────┬────┘
         │ deps calculees
    ┌────┴────┐
    │         │
  no deps   has deps
    │         │
    │         ▼
    │   ┌──────────┐   deps satisfaites
    │   │ blocked  │──────────────────────┐
    │   └──────────┘                      │
    │                                     │
    └────────────────────┬────────────────┘
                         │
                         ▼
                   ┌──────────┐
                   │  ready   │
                   └────┬─────┘
                        │ agent commence
                        ▼
                  ┌────────────┐
              ┌───│ inProgress │───┐
              │   └────────────┘   │
              │                    │
          all pass              fail
              │                    │
              ▼                    ▼
       ┌────────────┐      ┌────────────┐
       │ complete   │      │  failed    │
       └────────────┘      └────────────┘
```

### 8.4 Etats de Session (SessionStatus)

```
    ┌────────┐
    │ active │
    └───┬────┘
        │
   ┌────┼────────────┐
   │    │             │
   │  pause       exit(0)
   │    │             │
   │    ▼             ▼
   │ ┌────────┐  ┌───────────┐
   │ │ paused │  │ completed │
   │ └───┬────┘  └───────────┘
   │     │
   │   resume
   │     │
   └─────┘
        │
     archive
        │
        ▼
   ┌──────────┐
   │ archived │
   └──────────┘
```

---

## Sources

- `scripts/lib/common.sh` — Bibliotheque partagee, variables et templates
- `scripts/nexus-loop` — Boucle Claude Code
- `scripts/gemini-loop` — Boucle Gemini CLI
- `scripts/codex-loop` — Boucle Codex CLI
- `XRoads/Services/LoopLauncher.swift` — Preparation worktree et lancement PTY
- `XRoads/Services/LayeredDispatcher.swift` — Orchestration par couches
- `XRoads/Services/StatusMonitor.swift` — Polling status.json
- `XRoads/Services/DependencyTracker.swift` — Calcul des layers
- `XRoads/Services/PTYProcess.swift` — Gestion processus pseudo-terminal
- `XRoads/Services/SessionPersistenceService.swift` — Persistance sessions
- `XRoads/Models/AppSettings.swift` — Configuration CLI par agent
