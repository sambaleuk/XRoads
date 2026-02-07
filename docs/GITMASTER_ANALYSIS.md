# GitMaster - Analyse & Modeles Logiques

> Modelisation du systeme GitMaster et identification des trous et incoherences dans le processus global XRoads.

---

## Table des matieres

1. [Etat de l'implementation](#1-etat-de-limplementation)
2. [Modele logique du GitMaster](#2-modele-logique-du-gitmaster)
3. [Le flux post-orchestration actuel](#3-le-flux-post-orchestration-actuel)
4. [Analyse des trous dans la raquette](#4-analyse-des-trous-dans-la-raquette)
5. [Incoherences systemiques](#5-incoherences-systemiques)
6. [Matrice de responsabilites](#6-matrice-de-responsabilites)
7. [Propositions](#7-propositions)

---

## 1. Etat de l'implementation

### 1.1 Composants existants

| Composant | Fichier | LOC | Status |
|-----------|---------|-----|--------|
| GitMaster actor | `Services/GitMaster.swift` | 535 | Implemente |
| GitMasterState | `Models/GitMasterState.swift` | 355 | Implemente |
| GitConflict model | `Models/GitConflict.swift` | 306 | Implemente |
| GitMasterPanel UI | `Views/Dashboard/GitMasterPanel.swift` | 730 | Implemente |
| ConflictResolutionSheet | `Views/ConflictResolutionSheet.swift` | 134 | Implemente |
| MergeCoordinator | `Services/MergeCoordinator.swift` | 120 | Implemente |
| ServiceContainer | `Services/ServiceContainer.swift` | — | `gitMaster` enregistre |

### 1.2 Ce qui est fonctionnel

GitMaster sait faire :

- Tracker des branches par agent/worktree
- Detecter les conflits par dry-run merge
- Classifier les conflits (trivial/parallel/dependent/structural/semantic/binary)
- Estimer la complexite (auto/assisted/manual)
- Auto-resoudre les conflits triviaux et dependants
- Proposer des suggestions IA pour les conflits assistes
- Executer un merge complet avec rollback en cas d'echec
- Pipeline `performFullMerge()` : prepare → analyse → auto-resolve → execute

**Tout cela est accessible uniquement via le panneau UI GitMasterPanel.**

---

## 2. Modele logique du GitMaster

### 2.1 Machine a etats

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MACHINE A ETATS : GITMASTER                             │
└─────────────────────────────────────────────────────────────────────────────┘

                           ┌──────────┐
                    ┌─────►│   idle   │◄──────────────────────────┐
                    │      └────┬─────┘                           │
                    │           │                                  │
                    │      trackBranch()                           │
                    │           │                                  │
                    │           ▼                                  │
                    │    ┌────────────┐                            │
                    │    │ monitoring │    (suivi branches agents)  │
                    │    └─────┬──────┘                            │
                    │          │                                   │
                    │    allBranchesComplete                       │
                    │          │                                   │
                    │          ▼                                   │
                    │    ┌────────────┐                            │
                    │    │ preparing  │    prepareMerge()          │
                    │    │ (dry-run)  │    detecte conflits        │
                    │    └─────┬──────┘                            │
                    │          │                                   │
                    │    ┌─────┴──────┐                            │
                    │    │            │                            │
                    │  no conflicts  conflicts                    │
                    │    │            │                            │
                    │    │            ▼                            │
                    │    │     ┌────────────┐                      │
                    │    │     │ resolving  │  analyzeAllConflicts │
                    │    │     │            │  resolveAutoConflicts │
                    │    │     └─────┬──────┘                      │
                    │    │           │                             │
                    │    │     ┌─────┴──────┐                     │
                    │    │     │            │                      │
                    │    │   all auto    needs human               │
                    │    │   resolved      │                      │
                    │    │     │            ▼                      │
                    │    │     │     ┌────────────┐                │
                    │    │     │     │ reviewing  │  user valide   │
                    │    │     │     └─────┬──────┘                │
                    │    │     │           │                       │
                    │    └─────┴───────────┘                       │
                    │          │                                   │
                    │          ▼                                   │
                    │    ┌────────────┐                            │
                    │    │  merging   │  executeMerge()            │
                    │    └─────┬──────┘                            │
                    │          │                                   │
                    │    ┌─────┴──────┐                            │
                    │    │            │                            │
                    │  success      failure                       │
                    │    │            │                            │
                    │    │            ▼                            │
                    │    │  ┌──────────────────┐                  │
                    │    │  │ abort + rollback  │                  │
                    │    │  │ → resolving       │──────────────┐  │
                    │    │  └──────────────────┘               │  │
                    │    │                                      │  │
                    └────┘                                      │  │
                    status=success                              │  │
                                                                └──┘
                                                          re-analyze
```

### 2.2 Modele de donnees

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     MCD - GitMaster Domain                                   │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐          ┌──────────────────┐
│ GitMasterState   │          │  TrackedBranch   │
├──────────────────┤          ├──────────────────┤
│ mode: GMMode     │   1,n    │ _id_: UUID       │
│ status: GMStatus │◄────────►│ name: String     │
│ targetBranch     │ surveille│ worktreePath?    │
│ resolvedFiles[]  │          │ agentType?       │
│ lastError?       │          │ status: TBStatus │
│ lastMergeResult? │          │ lastCommit?      │
└────────┬─────────┘          │ lastCommitMsg?   │
         │                    └──────────────────┘
         │ 0,n
         ▼ contient
┌──────────────────┐          ┌──────────────────────┐
│  GitConflict     │          │ ResolutionStrategy   │
├──────────────────┤          ├──────────────────────┤
│ _id_: UUID       │   0,1    │ type: RSType         │
│ file: String     │◄────────►│ mergedContent?       │
│ oursContent      │ suggere  │ instructions?        │
│ theirsContent    │          │ reason?              │
│ baseContent?     │          └──────────────────────┘
│ conflictType     │
│ complexity       │          ┌──────────────────────┐
│ aiAnalysis?      │          │   MergeResult        │
│ oursBranch       │          ├──────────────────────┤
│ theirsBranch     │          │ baseBranch: String   │
└──────────────────┘          │ mergedBranches: []   │
                              │ conflicts: []        │
                              │ success: Bool        │
                              │ rolledBack: Bool     │
                              └──────────────────────┘
```

### 2.3 Pipeline `performFullMerge()`

```
performFullMerge(repoPath) :

  ┌─────────────────────────────────────┐
  │ 1. prepareMerge()                   │
  │    - checkout target branch         │
  │    - pour chaque branche complete:  │
  │      merge --no-commit --no-ff      │
  │      → detecte conflits             │
  │      reset --hard                   │
  └──────────────┬──────────────────────┘
                 │
           ┌─────┴─────┐
           │           │
     no conflicts   conflicts
           │           │
           │           ▼
           │  ┌─────────────────────────────────┐
           │  │ 2. executeMerge()               │
           │  │    merge --no-ff (pour de vrai) │
           │  │    si conflit → abort + break   │
           │  └──────────────┬──────────────────┘
           │                 │
           │           ┌─────┴─────┐
           │           │           │
           │       success     conflit reel
           │           │           │
           │           │           ▼
           │           │  ┌─────────────────────────────────┐
           │           │  │ 3. analyzeAllConflicts()        │
           │           │  │    - lister fichiers conflictes │
           │           │  │    - parser marqueurs           │
           │           │  │    - classifier type            │
           │           │  │    - estimer complexite         │
           │           │  └──────────────┬──────────────────┘
           │           │                 │
           │           │                 ▼
           │           │  ┌─────────────────────────────────┐
           │           │  │ 4. resolveAutoConflicts()       │
           │           │  │    - resoudre auto conflicts    │
           │           │  │    - ecrire fichiers resolus    │
           │           │  │    - git add fichiers           │
           │           │  └──────────────┬──────────────────┘
           │           │                 │
           │           │           ┌─────┴──────┐
           │           │           │            │
           │           │       tout resolu   reste manual
           │           │           │            │
           │           │           ▼            ▼
           │           │    MergeResult     MergeResult
           │           │    success=true    success=false
           │           │                   mode=reviewing
           │           │                   status=needsAttention
           │           │
           └───────────┤
                       │
                       ▼
                  executeMerge()
                  (merge direct, pas de conflits)
                       │
                       ▼
                  MergeResult
                  success=true
```

---

## 3. Le flux post-orchestration actuel

### 3.1 Ce qui se passe reellement

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              FLUX ACTUEL : FIN D'ORCHESTRATION                             │
└─────────────────────────────────────────────────────────────────────────────┘

  StatusMonitor detecte: toutes stories complete
       │
       ▼
  LayeredDispatcher.handleAllComplete()           ← LayeredDispatcher.swift:309
       │
       │  onComplete?()
       │
       ▼
  UnifiedDispatcher.dispatch() wrapper            ← UnifiedDispatcher.swift:241
       │
       │  callbacks.onComplete()
       │
       ▼
  AppState (callback)
       │
       │  Task { await completeOrchestration() }
       │
       ▼
  AppState.completeOrchestration()                ← AppState.swift:2028
       │
       │  orchestrationState = .merging
       │
       ▼
  services.orchestrator.coordinateMerge(          ← AppState.swift:2040
      for: activeWorktreeAssignments)
       │
       ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │  ClaudeOrchestrator.coordinateMerge()         ← ClaudeOrchestrator.swift:128
  │                                                                     │
  │    transition(to: .merging)                                         │
  │    // Placeholder merge result until merge coordinator              │
  │    // is implemented.                                               │
  │    let merged = assignments.map(\.branchName)                       │
  │    transition(to: .complete)                                        │
  │    return MergeResult(                                              │
  │        baseBranch: activeBaseBranch ?? "main",                      │
  │        mergedBranches: merged,      // ← FAKE : juste les noms     │
  │        conflicts: [],               // ← FAKE : toujours vide      │
  │        success: true,               // ← FAKE : toujours vrai      │
  │        rolledBack: false                                            │
  │    )                                                                │
  └─────────────────────────────────────────────────────────────────────┘
       │
       │  result.conflicts.isEmpty → true (toujours)
       │
       ▼
  orchestrationState = .complete                  ← AppState.swift:2044
  "Orchestration complete! Merged N branches"     ← MENSONGE : rien merge
       │
       ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │   ETAT FINAL :                                                      │
  │                                                                     │
  │   - N worktrees existent encore sur disque                          │
  │   - N branches xroads/slot-* existent dans git                      │
  │   - AUCUN merge n'a ete fait vers main                              │
  │   - AUCUN cleanup de worktrees                                      │
  │   - AUCUN cleanup de branches                                       │
  │   - Le code des agents est ISOLE dans des branches mortes           │
  │   - L'utilisateur croit que tout est merge                          │
  │                                                                     │
  └─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Ce qui DEVRAIT se passer

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              FLUX ATTENDU : FIN D'ORCHESTRATION                            │
└─────────────────────────────────────────────────────────────────────────────┘

  StatusMonitor: toutes stories complete
       │
       ▼
  LayeredDispatcher.handleAllComplete()
       │
       │  onComplete()
       │
       ▼
  AppState.completeOrchestration()
       │
       │  1. Tracker les branches dans GitMaster
       │     pour chaque slot → gitMaster.trackBranch()
       │     → gitMaster.markBranchCompleted()
       │
       ▼
  GitMaster.performFullMerge(repoPath)
       │
       ├── prepareMerge()  (dry-run)
       │      │
       │   ┌──┴──┐
       │ clean  conflicts
       │   │      │
       │   │   analyzeAllConflicts()
       │   │      │
       │   │   resolveAutoConflicts()
       │   │      │
       │   │   ┌──┴──┐
       │   │ tout   reste manual
       │   │ resolu    │
       │   │   │       ▼
       │   │   │    GitMasterPanel → user reviewing
       │   │   │       │ user approve
       │   │   │       │
       │   └───┴───────┘
       │       │
       ▼       ▼
  executeMerge()
       │
       ▼
  MergeResult
       │
       ├── si success:
       │    ├── Cleanup worktrees (git worktree remove)
       │    ├── Cleanup branches (git branch -d xroads/slot-*)
       │    ├── Session handoff (sauvegarder contexte)
       │    └── orchestrationState = .complete
       │
       └── si failure:
            ├── mode = .reviewing
            └── Presenter ConflictResolutionSheet
```

---

## 4. Analyse des trous dans la raquette

### TROU #1 : Le Placeholder Merge (CRITIQUE)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TROU #1 : ClaudeOrchestrator.coordinateMerge() est un NO-OP              │
│                                                                            │
│  Severite : ████████████████████ CRITIQUE                                  │
│  Impact   : Le travail des agents n'est JAMAIS integre dans main           │
│                                                                            │
│  Code concerne :                                                           │
│  - ClaudeOrchestrator.swift:128-140  (le placeholder)                      │
│  - AppState.swift:2040               (l'appel)                             │
│  - Orchestrator.swift:206            (le protocole)                        │
│                                                                            │
│  Composants existants mais non cables :                                    │
│  - GitMaster.performFullMerge()      (535 LOC, fonctionnel)               │
│  - MergeCoordinator.executeMerge()   (120 LOC, fonctionnel)               │
│  - ServiceContainer.gitMaster        (enregistre, jamais appele auto)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### TROU #2 : Aucun cleanup post-merge

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TROU #2 : Pas de cleanup automatique apres orchestration                  │
│                                                                            │
│  Severite : ████████████░░░░░░░░ HAUTE                                     │
│                                                                            │
│  Apres une orchestration :                                                 │
│  - Les worktrees restent sur disque     (N * taille projet)                │
│  - Les branches xroads/slot-* persistent dans git                          │
│  - Pas de git worktree prune                                               │
│  - Pas de git branch -d                                                    │
│                                                                            │
│  Code existant mais non appele :                                           │
│  - GitService.removeWorktree()         (fonctionne, UI only)               │
│  - SessionViewModel.removeWorktree()   (fonctionne, UI only)               │
│                                                                            │
│  Consequences :                                                            │
│  - Accumulation de worktrees (5-10 par run × N runs)                       │
│  - Branches fantomes dans git log                                          │
│  - Confusion lors de la prochaine orchestration                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### TROU #3 : GitMaster isole du flux d'orchestration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TROU #3 : GitMaster n'est connecte a rien programmatiquement              │
│                                                                            │
│  Severite : ████████████░░░░░░░░ HAUTE                                     │
│                                                                            │
│  GitMaster est accessible UNIQUEMENT via :                                 │
│  - GitMasterPanel.swift (boutons UI manuels)                               │
│                                                                            │
│  Aucune connexion avec :                                                   │
│  - LayeredDispatcher (pas d'appel apres completion)                        │
│  - AppState.completeOrchestration() (appelle le placeholder)               │
│  - StatusMonitor (pas de notification vers GitMaster)                      │
│  - LoopLauncher (pas de tracking des branches creees)                      │
│                                                                            │
│  En d'autres termes : GitMaster est un ilot fonctionnel deconnecte         │
│  du reste du pipeline.                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### TROU #4 : Pas de handoff post-merge

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TROU #4 : Session handoff ne capture pas le resultat du merge             │
│                                                                            │
│  Severite : ████████░░░░░░░░░░░░ MOYENNE                                   │
│                                                                            │
│  Le systeme de session/handoff (Session.swift, SessionPersistenceService)   │
│  sauvegarde l'etat PENDANT la boucle (auto-persist on loop termination)    │
│  mais ne capture PAS :                                                     │
│  - Le resultat du merge (quels fichiers resolus, quels conflits)           │
│  - Les branches mergees                                                    │
│  - Le commit de merge final                                                │
│  - Le nettoyage effectue                                                   │
│                                                                            │
│  Impact : La prochaine session n'a aucun contexte sur comment              │
│  la precedente s'est terminee.                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### TROU #5 : Le merge se fait sur le repo principal, pas sur une copie

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TROU #5 : Merge directement sur le repo principal sans safety net         │
│                                                                            │
│  Severite : ████████░░░░░░░░░░░░ MOYENNE                                   │
│                                                                            │
│  GitMaster.executeMerge() fait :                                           │
│    gitService.checkout(branch: targetBranch, repoPath)  ← change main     │
│    gitService.merge(branch: agentBranch, ...)           ← merge direct     │
│                                                                            │
│  Si le merge echoue a mi-chemin (2 branches mergees, 3eme echoue) :       │
│    → abort + rolledBack = true                                             │
│    → MAIS les 2 premiers merges sont DEJA commites !                       │
│    → Etat inconsistant sur main                                            │
│                                                                            │
│  Pas de :                                                                  │
│  - Branche temporaire de merge (ex: xroads/merge-session-<uuid>)           │
│  - Rollback atomique (git reset --hard au point de depart)                 │
│  - Dry-run prealable qui teste TOUS les merges ensemble                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Incoherences systemiques

### INCOHERENCE #1 : Trois systemes de merge coexistent

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     TROIS SYSTEMES DE MERGE                                │
└─────────────────────────────────────────────────────────────────────────────┘

                  ┌──────────────────────────────┐
                  │    Orchestrator Protocol      │
                  │    (Orchestrator.swift:206)    │
                  │                               │
                  │  coordinateMerge(assignments)  │
                  │       → MergeResult           │
                  └──────────────┬────────────────┘
                                 │
                    implements   │
                                 │
              ┌──────────────────┤
              │                  │
              ▼                  │   (IGNORE)
   ┌──────────────────────┐      │
   │ ClaudeOrchestrator   │      │
   │                      │      │
   │ coordinateMerge()    │      │
   │ → PLACEHOLDER        │      │
   │ → retourne fake      │      │
   │   success toujours   │      │
   └──────────────────────┘      │
                                 │
                                 │
   ┌──────────────────────┐      │   ┌──────────────────────┐
   │ MergeCoordinator     │      │   │     GitMaster        │
   │                      │      │   │                      │
   │ prepareMerge()       │      │   │ performFullMerge()   │
   │ executeMerge(plan)   │      │   │ prepareMerge()       │
   │                      │      │   │ analyzeAllConflicts()│
   │ → fonctionne mais    │      │   │ resolveAutoConflicts│
   │   PAS de resolution  │      │   │ executeMerge()       │
   │   intelligente       │      │   │                      │
   │ → jamais appele auto │      │   │ → complet mais       │
   └──────────────────────┘      │   │   JAMAIS appele auto │
                                 │   └──────────────────────┘
                                 │
           ┌─────────────────────┘
           │
           ▼
   QUESTION : Lequel devrait faire le travail ?
   REPONSE  : GitMaster (le plus complet)
              MergeCoordinator peut servir de fallback simple
              ClaudeOrchestrator.coordinateMerge doit deleguer a GitMaster
```

### INCOHERENCE #2 : MergeResult utilise par tous mais defini pour un seul

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Le type MergeResult est defini dans Orchestrator.swift (l.182)            │
│  et utilise par :                                                          │
│                                                                            │
│  - ClaudeOrchestrator.coordinateMerge() → retourne MergeResult             │
│  - MergeCoordinator.executeMerge()      → retourne MergeResult             │
│  - GitMaster.executeMerge()             → retourne MergeResult             │
│  - GitMaster.performFullMerge()         → retourne MergeResult             │
│  - AppState.mergeResult                 → stocke MergeResult               │
│  - AppState.completeOrchestration()     → consomme MergeResult             │
│                                                                            │
│  COHERENT en termes de type, mais les SEMANTIQUES different :              │
│                                                                            │
│  ClaudeOrchestrator : mergedBranches = noms de branches (PAS mergees)      │
│  MergeCoordinator   : mergedBranches = branches reellement mergees         │
│  GitMaster          : mergedBranches = branches ou fichiers resolus (!)    │
│                                                                            │
│  → Le champ `mergedBranches` n'a pas la meme signification partout        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### INCOHERENCE #3 : Deux systemes de status tracking paralleles

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Deux sources de verite pour "est-ce que l'agent a fini ?"                 │
│                                                                            │
│  SOURCE 1 : status.json (DependencyTracker / StatusMonitor)                │
│  ─────────                                                                 │
│  - stories[id].status = "complete"                                         │
│  - Poll par StatusMonitor toutes les 5s                                    │
│  - Ecrit par les agents via jq                                             │
│  - Lu par LayeredDispatcher pour progression de layers                     │
│                                                                            │
│  SOURCE 2 : TrackedBranch.status (GitMaster)                               │
│  ─────────                                                                 │
│  - TrackedBranchStatus: pending → inProgress → completed → merged          │
│  - Mis a jour manuellement par l'UI (GitMasterPanel)                       │
│  - NON connecte a StatusMonitor                                            │
│  - NON connecte a LayeredDispatcher                                        │
│                                                                            │
│  PROBLEME :                                                                │
│  GitMaster ne sait pas quand les branches sont "completed"                 │
│  car il ne lit pas status.json.                                            │
│  Il faudrait que StatusMonitor.onAllComplete() → GitMaster.trackBranches() │
└─────────────────────────────────────────────────────────────────────────────┘
```

### INCOHERENCE #4 : Le merge sequentiel n'est pas atomique

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  GitMaster.executeMerge() et MergeCoordinator.executeMerge()               │
│  mergent les branches UNE PAR UNE sequentiellement :                       │
│                                                                            │
│    for branch in completedBranches:                                        │
│        merge(branch)    ← COMMITE immediatement                            │
│        if error:                                                           │
│            abortMerge() ← abort la branche courante seulement              │
│            break         ← MAIS les precedents sont deja commites !        │
│                                                                            │
│  Scenario problematique :                                                  │
│                                                                            │
│    merge(slot-1-claude)  → OK ✓  (commit sur main)                         │
│    merge(slot-2-gemini)  → OK ✓  (commit sur main)                         │
│    merge(slot-3-codex)   → FAIL  (conflit)                                 │
│        → abort merge slot-3                                                │
│        → rolledBack = true                                                 │
│        → MAIS slot-1 et slot-2 sont deja dans main !                       │
│                                                                            │
│  Le MergeResult dit rolledBack=true, mais c'est un MENSONGE partiel :      │
│  seule la derniere branche a ete rollback.                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### INCOHERENCE #5 : L'orchestration a deux chemins de lancement

```
  Rappel de ARCHITECTURE_MODELS.md (section 4.2, "DUAL LAUNCH SYSTEM") :

  Chemin A : SlotAssignmentSheet → UnifiedDispatcher → LayeredDispatcher
             → LoopLauncher
             → onComplete → completeOrchestration() → placeholder merge

  Chemin B : XRoadsDashboardView → AppState.executeActionInSlot
             → ActionRunner
             → PAS de onComplete
             → PAS de merge du tout

  Le chemin B ne declenche AUCUNE logique post-completion.
```

---

## 6. Matrice de responsabilites

### 6.1 Qui fait quoi actuellement

```
                     LayeredDisp  StatusMon  LoopLaunch  GitMaster  MergeCoord  ClaudeOrch  AppState
                     ───────────  ─────────  ──────────  ─────────  ──────────  ──────────  ────────
Creer worktrees      ✅                      ✅
Lancer loops         ✅                      ✅
Tracker stories                   ✅
Detecter completion              ✅
Signal onComplete    ✅
Appeler merge                                                                   ✅(fake)    ✅
Tracker branches                                         ✅(UI)
Preparer merge                                           ✅(UI)     ✅(inutilise)
Detecter conflits                                        ✅(UI)     ✅(inutilise)
Resoudre conflits                                        ✅(UI)
Executer merge                                           ✅(UI)     ✅(inutilise)
Cleanup worktrees                                                                           ✅(UI)
Cleanup branches     —            —          —           —          —           —           —
Handoff post-merge   —            —          —           —          —           —           —
```

### 6.2 Ce qui MANQUE dans la chaine

```
  LayeredDispatcher.handleAllComplete()
       │
       │  ┌─ MANQUE : Enregistrer les branches dans GitMaster
       │  │           gitMaster.trackBranch(slotInfo.branchName,
       │  │             worktreePath, agentType)
       │  │           gitMaster.markBranchCompleted(slotInfo.branchName)
       │
       ▼
  AppState.completeOrchestration()
       │
       │  ┌─ MANQUE : Appeler GitMaster au lieu du placeholder
       │  │           services.gitMaster.setTargetBranch("main")
       │  │           services.gitMaster.performFullMerge(repoPath)
       │
       ▼
  [apres merge reussi]
       │
       │  ┌─ MANQUE : Cleanup worktrees
       │  │           pour chaque worktree:
       │  │             gitService.removeWorktree(repoPath, wtPath)
       │  │
       │  ├─ MANQUE : Cleanup branches
       │  │           pour chaque branche:
       │  │             git branch -d xroads/slot-*
       │  │
       │  ├─ MANQUE : Handoff post-merge
       │  │           sessionPersistence.updateHandoff(
       │  │             sessionId, repoPath, mergeResultSummary)
       │  │
       │  └─ MANQUE : Cleanup status.json
       │             (optionnel : archiver ou supprimer)
```

---

## 7. Propositions

### 7.1 Diagramme cible

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              FLUX CIBLE : FIN D'ORCHESTRATION                              │
└─────────────────────────────────────────────────────────────────────────────┘

  StatusMonitor: all complete
       │
       ▼
  LayeredDispatcher.handleAllComplete()
       │
       │  Collecter slotInfos (branchName, agentType, worktreePath)
       │
       ▼
  AppState.completeOrchestration()
       │
       ├── 1. Tracker branches dans GitMaster
       │       pour chaque slot dans slotInfos:
       │         gitMaster.trackBranch(name, worktreePath, agentType)
       │         gitMaster.markBranchCompleted(name)
       │
       ├── 2. Set target branch
       │       gitMaster.setTargetBranch(baseBranch)
       │
       ├── 3. Creer branche de merge temporaire  ← SAFETY NET
       │       git checkout -b xroads/merge-<sessionId>
       │       (merge sur cette branche, pas directement sur main)
       │
       ├── 4. Lancer merge
       │       gitMaster.performFullMerge(repoPath)
       │       │
       │       ├── success, no conflicts:
       │       │     → fast-forward main vers la branche de merge
       │       │     → cleanup worktrees
       │       │     → cleanup branches agent
       │       │     → sauvegarder handoff
       │       │     → orchestrationState = .complete
       │       │
       │       ├── success, auto-resolved:
       │       │     → idem (tout resolu automatiquement)
       │       │
       │       └── needs review:
       │             → orchestrationState = .merging
       │             → GitMasterPanel affiche les conflits
       │             → User resout manuellement
       │             → Quand resolu : reprendre au fast-forward
       │
       └── 5. Post-merge
               ├── git worktree remove (chaque slot)
               ├── git branch -d xroads/slot-* (chaque branche)
               ├── git branch -d xroads/merge-<sessionId> (si ff)
               ├── sessionPersistence.updateHandoff(summary)
               └── archiver status.json → .crossroads/history/
```

### 7.2 Resume des trous identifies

| # | Trou | Severite | Existe deja | Manque |
|---|------|----------|-------------|--------|
| 1 | Placeholder merge (no-op) | CRITIQUE | GitMaster.performFullMerge() | Le cablage AppState → GitMaster |
| 2 | Pas de cleanup post-merge | HAUTE | GitService.removeWorktree() | L'appel automatique |
| 3 | GitMaster isole du pipeline | HAUTE | GitMaster complet | La connexion orchestration → GitMaster |
| 4 | Pas de handoff post-merge | MOYENNE | SessionPersistenceService | La sauvegarde du resultat merge |
| 5 | Merge non-atomique | MOYENNE | — | Branche temporaire + rollback complet |

### 7.3 Incoherences identifiees

| # | Incoherence | Impact |
|---|-------------|--------|
| 1 | 3 systemes de merge coexistent | Confusion, code mort |
| 2 | mergedBranches semantique differente | Bugs potentiels dans l'UI |
| 3 | Deux sources de verite pour "agent fini" | GitMaster ne sait pas quand commencer |
| 4 | Merge sequentiel non-atomique | Etat inconsistant possible sur main |
| 5 | Deux chemins de lancement (dual launch) | Le chemin B n'a aucun post-processing |

---

## Sources

- `XRoads/Services/GitMaster.swift` — Actor principal (535 LOC)
- `XRoads/Models/GitMasterState.swift` — State machine (355 LOC)
- `XRoads/Models/GitConflict.swift` — Modele conflit (306 LOC)
- `XRoads/Services/MergeCoordinator.swift` — Merge simple (120 LOC)
- `XRoads/Services/ClaudeOrchestrator.swift:128-140` — Le placeholder
- `XRoads/Services/Orchestrator.swift:182-207` — Protocol + MergeResult
- `XRoads/ViewModels/AppState.swift:2028-2061` — completeOrchestration()
- `XRoads/Services/LayeredDispatcher.swift:309-315` — handleAllComplete()
- `XRoads/Services/ServiceContainer.swift` — gitMaster enregistre
- `XRoads/Views/Dashboard/GitMasterPanel.swift` — UI (730 LOC)
- `docs/ARCHITECTURE_MODELS.md` — Section 7 (design GitMaster)
