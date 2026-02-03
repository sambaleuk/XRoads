# XRoads Dashboard v3 — Handoff Document

**Date:** 2026-02-03
**Branch:** `feat/crossroads-v1`
**Dernier commit:** `a409eb5`

---

## Résumé de la Session

Implémentation complète du Dashboard v3 avec layout hexagonal multi-terminaux et orchestrateur central "Cyberbrain".

---

## Ce qui a été fait

### 1. Architecture Dashboard v3

**Nouveaux fichiers créés :**

| Fichier | Description |
|---------|-------------|
| `Models/TerminalSlot.swift` | Modèle pour les 6 slots du dashboard hexagonal |
| `Models/DashboardMode.swift` | Enum Single/Agentic avec propriétés de layout |
| `Models/OrchestratorVisualState.swift` | États visuels du cyberbrain (idle, monitoring, etc.) |
| `Views/Dashboard/XRoadsDashboardView.swift` | Container principal du dashboard |
| `Views/Dashboard/TerminalSlotView.swift` | Composant slot terminal compact |
| `Views/Dashboard/TerminalGridLayout.swift` | Layout hexagonal + SingleTerminalLayout |
| `Views/Dashboard/OrchestratorCreatureView.swift` | Cyberbrain alien animé |
| `Views/Dashboard/GitInfoPanel.swift` | Panneau Git compact (gauche) |

**Fichiers modifiés :**

| Fichier | Modifications |
|---------|---------------|
| `Package.swift` | Ajout des nouveaux fichiers sources |
| `Resources/Theme.swift` | Couleurs créature + bordures slots |
| `ViewModels/AppState.swift` | Ajout dashboardMode, terminalSlots, orchestratorState |
| `Views/MainWindowView.swift` | Intégration XRoadsDashboardView, mode Agentic par défaut |

**Fichiers supprimés :**

| Fichier | Raison |
|---------|--------|
| `Views/Dashboard/MCPLogsPanel.swift` | Legacy, remplacé par vue intégrée |
| `Views/Dashboard/GitBranchesPanel.swift` | Legacy, remplacé par GitInfoPanel |

### 2. Fonctionnalités Implémentées

- **Mode Single** : 1 terminal large, vue simplifiée
- **Mode Agentic** : 6 terminaux en hexagone autour du cyberbrain
- **Cyberbrain central** : Cerveau alien avec synapses animées vers les slots actifs
- **GitInfoPanel** : Branche courante, tracking (ahead/behind), commits récents, worktrees
- **Sélection Agent/Worktree** : Menus dropdown dans chaque slot
- **Toggle mode** : Barre supérieure avec switch Single/Agentic
- **Actions globales** : Start All / Stop All

---

## Problèmes Rencontrés & Solutions

### Problème 1 : Ambiguïté cos/sin

**Symptôme :** Erreur de compilation "Ambiguous use of 'cos'"

**Cause :** Swift ne sait pas quelle version de cos/sin utiliser (Foundation vs Darwin)

**Solution :**
```swift
// Avant (erreur)
let x = center.x + radius * cos(angle.radians)

// Après (OK)
let x = center.x + radius * CGFloat(Darwin.cos(angle.radians))
```

**Fichiers affectés :** `TerminalGridLayout.swift`, `OrchestratorCreatureView.swift`

---

### Problème 2 : Méthode GitService.listBranches inexistante

**Symptôme :** Erreur "Value of type 'GitService' has no member 'listBranches'"

**Cause :** La méthode n'existait pas dans GitService

**Solution :** Utiliser `appState.worktrees` pour construire la liste des branches au lieu d'appeler GitService

---

### Problème 3 : Dashboard non visible (ancien dashboard affiché)

**Symptôme :** Malgré le code correct, l'utilisateur voyait toujours l'ancien dashboard

**Diagnostic :** Ajout de banners debug colorés (RED pour ON, BLUE pour OFF) pour confirmer le chemin d'exécution

**Solution :** Le code était correct, problème de cache/état. Après rebuild complet, le dashboard s'affichait correctement.

---

### Problème 4 : Mise à jour des slots non réactive

**Symptôme :** Quand on sélectionne un agent/worktree, l'UI ne se met pas à jour. Il faut quitter et revenir pour voir le changement.

**Cause :** L'implémentation `Equatable` de `TerminalSlot` ne comparait que l'`id` :

```swift
// Avant (problème)
static func == (lhs: TerminalSlot, rhs: TerminalSlot) -> Bool {
    lhs.id == rhs.id  // SwiftUI pense que rien n'a changé !
}
```

**Solution :** Comparer toutes les propriétés visuellement pertinentes :

```swift
// Après (OK)
static func == (lhs: TerminalSlot, rhs: TerminalSlot) -> Bool {
    lhs.id == rhs.id &&
    lhs.slotNumber == rhs.slotNumber &&
    lhs.worktree?.id == rhs.worktree?.id &&
    lhs.agentType == rhs.agentType &&
    lhs.status == rhs.status &&
    lhs.currentTask == rhs.currentTask &&
    lhs.progress == rhs.progress &&
    lhs.logs.count == rhs.logs.count
}
```

**Leçon :** SwiftUI utilise `Equatable` pour déterminer si une vue doit être re-rendue. Une implémentation trop simpliste bloque les updates.

---

## RETEX (Retour d'Expérience)

### Ce qui a bien fonctionné

1. **Architecture modulaire** : Séparation claire Models/Views/ViewModels facilite les modifications
2. **Binding pattern** : `@Binding var slot: TerminalSlot` permet la modification bidirectionnelle
3. **Swift Actors** : GitService en actor évite les problèmes de concurrence
4. **Debug visuel** : Les banners colorés ont permis de diagnostiquer rapidement le problème de visibilité

### Points d'attention pour la suite

1. **Equatable custom** : Toujours vérifier que l'implémentation inclut toutes les propriétés UI-relevant
2. **cos/sin sur macOS** : Utiliser `Darwin.cos()` explicitement pour éviter les ambiguïtés
3. **Méthodes GitService** : Vérifier l'existence des méthodes avant de les utiliser
4. **Cache SwiftUI** : Un rebuild complet (`swift build`) peut être nécessaire après des changements structurels

### Patterns réutilisables

```swift
// Pattern: Position hexagonale
var positionAngle: Double {
    let startAngle: Double = -90  // Top
    let spacing: Double = 60
    return startAngle + Double(slotNumber - 1) * spacing
}

// Pattern: Position calculée
let position = CGPoint(
    x: center.x + radius * CGFloat(Darwin.cos(angle.radians)),
    y: center.y + radius * CGFloat(Darwin.sin(angle.radians))
)

// Pattern: Animation synapse
withAnimation(.easeIn(duration: 0.6).repeatForever(autoreverses: false)) {
    impulsePosition = 1.0
}
```

---

## Dernières Implémentations

### Cyberbrain Alien (OrchestratorCreatureView)

Structure visuelle :
- **Hémisphères cérébraux** avec gyri (plis) visibles
- **Fissure centrale** lumineuse pulsante
- **Nœud de conscience** central avec anneau rotatif
- **Aura alien** éthérée

Connexions synaptiques :
- **Axones** (fibres nerveuses) vers chaque slot actif
- **Gaines de myéline** (segments le long de l'axone)
- **Impulsion neurale** animée qui voyage du cerveau au slot
- **Terminal synaptique** (bulbe) à l'extrémité

États visuels (`OrchestratorVisualState`) :
| État | Couleur | Description |
|------|---------|-------------|
| idle | Gris | Animation minimale |
| planning | Ambre | Réflexion en cours |
| distributing | Bleu | Envoi de tâches |
| monitoring | Vert | Surveillance active |
| synthesizing | Violet | Rassemblement résultats |
| celebrating | Or | Succès |
| concerned | Rouge | Problèmes détectés |
| sleeping | Gris foncé | Aucun agent actif |

---

## Configuration Actuelle

```swift
// MainWindowView.swift
@AppStorage(UserDefaults.Keys.fullAgenticMode)
private var isFullAgenticMode: Bool = true  // Agentic mode par défaut

// AppState.swift
var dashboardMode: DashboardMode = .agentic  // 6 slots par défaut
var terminalSlots: [TerminalSlot] = (1...6).map { TerminalSlot(slotNumber: $0) }
var orchestratorState: OrchestratorVisualState = .idle
```

---

## Prochaines Étapes Suggérées

1. **Intégration ProcessRunner** : Connecter les slots aux vrais processus CLI (Claude, Gemini, Codex)
2. **Streaming logs** : Afficher les logs en temps réel dans chaque slot
3. **Persistance slots** : Sauvegarder la configuration des slots entre sessions
4. **Orchestration automatique** : Claude orchestre la création de worktrees et l'assignation des tâches
5. **Merge Coordinator** : Fusion automatique des branches après complétion

---

## Commandes Utiles

```bash
# Build
swift build

# Run
swift run XRoads

# Test
swift test

# Git
git log --oneline -10
git diff HEAD~1
```

---

## Contacts

- **Repo:** https://github.com/sambaleuk/XRoads
- **Branch:** feat/crossroads-v1
- **Dernier commit:** a409eb5

---

*Document généré le 2026-02-03*
