# 🍎 iOS/Swift Skills Repository

Repository de skills Anthropic pour le développement iOS/Swift, de la conception à l'implémentation. Conçu pour accompagner les développeurs de tous niveaux dans la création d'applications macOS et iOS.

## 📋 Vue d'ensemble

Ce repository contient des skills (compétences modulaires) pour Claude qui fournissent :
- 📚 Connaissance procédurale spécialisée pour Swift et les frameworks Apple
- 🛠️ Scripts d'automatisation pour les tâches répétitives
- 📖 Documentation de référence complète
- 🎨 Templates et boilerplates prêts à l'emploi

## 🎯 Structure du Repository

```
ios-swift-skills/
├── swift-language/          ✅ Disponible
│   ├── SKILL.md
│   ├── scripts/
│   │   └── generate_model.py
│   ├── references/
│   │   ├── fundamentals.md
│   │   └── macos-specifics.md
│   └── assets/
│       └── macos-app-template.swift
│
├── swift-concurrency/       ✅ Disponible
├── memory-management/       ✅ Disponible
├── swiftui/                 ✅ Disponible
├── process-management/      ✅ Disponible
├── mvvm-architecture/       ✅ Disponible
├── file-operations/         ✅ Disponible
├── uikit/                   📋 Planifié
└── ...
```

## 🚀 Skills Disponibles

### ✅ swift-language (v1.0)
**Fondamentaux du langage Swift 5.x**

Maîtrisez les concepts essentiels de Swift pour construire des applications macOS et iOS.

**Concepts couverts :**
- Variables, constantes, types de données
- Optionals et gestion de l'absence de valeur
- Collections (Array, Dictionary, Set)
- Fonctions et closures
- Structures et classes (value vs reference types)
- Protocols et extensions
- Generics et type safety
- Error handling
- Property wrappers
- Patterns macOS spécifiques

**Ressources incluses :**
- 📖 Guide complet des fondamentaux Swift (fundamentals.md)
- 🖥️ Spécificités macOS - AppKit/SwiftUI (macos-specifics.md)
- 🛠️ Générateur de modèles Swift avec Codable
- 🎨 Template d'application macOS complet

**Utilisation :**
```bash
# Installer la skill
cp swift-language.skill ~/.anthropic/skills/

# Générer un modèle de données
python3 swift-language/scripts/generate_model.py \
  --name User \
  --properties "name:String,age:Int,email:String?" \
  --example
```

**Triggers :**
- "Écris du code Swift"
- "Explique-moi les optionals"
- "Comment créer une app macOS"
- "Quelle est la différence entre struct et class"

---

### ✅ swift-concurrency (v1.0)
**Concurrence moderne avec async/await, actors et structured concurrency**

Maîtrisez la programmation asynchrone moderne pour écrire du code concurrent safe et performant.

**Concepts couverts :**
- async/await pour code asynchrone lisible
- Task pour lancer des opérations asynchrones
- Actors pour protection thread-safe automatique
- MainActor pour garantir exécution UI thread
- async let pour parallélisme (count fixe)
- TaskGroup pour parallélisme dynamique
- Structured concurrency et cancellation
- AsyncSequence pour flux de données asynchrones
- Patterns avancés (retry, timeout, cache, progress)

**Ressources incluses :**
- 📖 Guide complet async/await (380+ lignes)
- 📖 Actors et thread safety (450+ lignes)
- 📖 Structured concurrency et TaskGroups (390+ lignes)
- 🛠️ Générateur de code async (API clients, actors, ViewModels)
- 🎨 Template API client async complet avec cache et retry

**Utilisation :**
```bash
# Installer la skill
cp swift-concurrency.skill ~/.anthropic/skills/

# Générer un API client async
python3 swift-concurrency/scripts/generate_async_code.py \
  --type api-client \
  --name UserAPI
```

**Triggers :**
- "Comment utiliser async/await"
- "Qu'est-ce qu'un actor"
- "Éviter les data races"
- "TaskGroup pour parallélisme"
- "MainActor pour UI thread"

---

### ✅ memory-management (v1.0)
**Gestion mémoire avec ARC, prévention des retain cycles et debugging leaks**

Maîtrisez la gestion mémoire automatique de Swift et prévenez les memory leaks.

**Concepts couverts :**
- ARC (Automatic Reference Counting)
- strong/weak/unowned references
- Retain cycles et comment les casser
- [weak self] dans les closures
- Delegates toujours weak
- Timers et observers (invalidation requise)
- Memory Graph Debugger
- Instruments Leaks tool
- deinit logging pour vérification
- Patterns courants et erreurs à éviter

**Ressources incluses :**
- 📖 Guide complet ARC (120+ lignes concepts + patterns)
- 📖 Debugging memory leaks (workflow complet, outils Xcode)
- ✅ Checklist anti-leak
- 🔍 Exemples réels de leaks et corrections

**Utilisation :**
```bash
# Installer la skill
cp memory-management.skill ~/.anthropic/skills/
```

**Triggers :**
- "Memory leak dans mon app"
- "Pourquoi deinit n'est pas appelé"
- "Différence entre weak et unowned"
- "[weak self] dans closure"
- "Retain cycle delegate"
- "Instruments Leaks"

---

### ✅ swiftui (v1.0)
**UI déclarative, @State, @Binding, navigation moderne**

Créez des interfaces utilisateur modernes avec SwiftUI pour macOS et iOS.

**Concepts couverts :**
- SwiftUI syntax et structure déclarative
- @State pour état local
- @StateObject et @ObservedObject pour ViewModels
- @Binding pour passage de données
- @EnvironmentObject pour état global
- Grids (LazyVGrid, LazyHGrid) pour layouts complexes
- Navigation (NavigationStack, NavigationLink)
- Animations et transitions
- Terminal UI components (pour apps Maestro-like)
- Status indicators et badges

**Ressources incluses :**
- 📖 Guide SwiftUI essentials avec patterns Maestro
- 🎨 Exemples de grid layouts pour sessions multiples
- 🖥️ Components terminal-style pour output monitoring

**Utilisation :**
```bash
# Installer la skill
cp swiftui.skill ~/.anthropic/skills/
```

**Triggers :**
- "Créer une interface SwiftUI"
- "Comment utiliser @State"
- "@StateObject vs @ObservedObject"
- "Grid layout SwiftUI"
- "Navigation SwiftUI"

---

### ✅ process-management (v1.0)
**Lancement et gestion de processus système, shell commands, intégration git**

Exécutez et gérez des processus externes, intégrez git et des CLIs dans votre app macOS.

**Concepts couverts :**
- Process (NSTask) pour exécuter commands
- Pipes pour capturer stdout/stderr
- Async ProcessManager avec actors
- PTY (Pseudo-Terminal) pour processus interactifs
- Git operations (worktree, commit, push)
- Claude Code integration
- Shell command execution
- Process monitoring et termination

**Ressources incluses :**
- 📖 Guide complet Process API et patterns
- 💻 ProcessManager actor thread-safe
- 🔧 GitService pour opérations git
- 🎯 Claude Code session management
- 📋 Shell command helpers

**Utilisation :**
```bash
# Installer la skill
cp process-management.skill ~/.anthropic/skills/
```

**Triggers :**
- "Exécuter une commande shell"
- "Lancer un process en Swift"
- "Git operations depuis Swift"
- "PTY interactive terminal"
- "Capturer output processus"

---

### ✅ mvvm-architecture (v1.0)
**Pattern MVVM pour SwiftUI avec @MainActor, ViewModels, dependency injection**

Structurez vos applications SwiftUI avec MVVM pour un code maintenable et testable.

**Concepts couverts :**
- MVVM architecture (Model-View-ViewModel)
- @MainActor pour thread safety UI
- ObservableObject et @Published
- @StateObject vs @ObservedObject vs @EnvironmentObject
- Dependency injection pour testabilité
- LoadingState enum pattern
- Form validation
- Event bus pattern
- Parent-child ViewModels
- Mock services pour tests

**Ressources incluses :**
- 📖 Guide MVVM complet avec patterns Maestro
- 🎯 Multi-session management ViewModel
- 📋 Terminal output ViewModel avec logs
- 🧪 Exemples de tests avec mocks

**Utilisation :**
```bash
# Installer la skill
cp mvvm-architecture.skill ~/.anthropic/skills/
```

**Triggers :**
- "Architecture MVVM SwiftUI"
- "Créer un ViewModel"
- "@MainActor pour UI"
- "Dependency injection Swift"
- "Tester un ViewModel"

---

### ✅ file-operations (v1.0)
**FileManager pour lecture/écriture fichiers, gestion directories, logs, config**

Gérez le système de fichiers pour logs, configurations et organisation de données.

**Concepts couverts :**
- FileManager basics (read, write, delete)
- URL vs String paths
- Directory operations (create, list, remove)
- File attributes (size, dates, permissions)
- Session directory structures
- Logs management avec rotation
- Config file management (JSON)
- Temporary files
- File watching (DispatchSource)
- Actors pour thread-safe file operations

**Ressources incluses :**
- 📖 Guide FileManager complet
- 📁 SessionDirectoryManager actor
- 📝 LogsManager avec rotation automatique
- ⚙️ ConfigManager pour settings JSON
- 🔐 Patterns sécurisés pour file access

**Utilisation :**
```bash
# Installer la skill
cp file-operations.skill ~/.anthropic/skills/
```

**Triggers :**
- "Lire un fichier en Swift"
- "Créer un répertoire"
- "FileManager operations"
- "Écrire des logs"
- "Gestion config JSON"

---

## 📊 Roadmap des Skills

### 🔴 Priorité Critique

#### 1. swift-language ✅
Status: **Disponible**
Langage Swift 5.x, optionals, closures, protocols, patterns macOS

#### 2. swift-concurrency ✅
Status: **Disponible**
async/await, actors, structured concurrency, Task, MainActor, TaskGroup, async let

#### 3. memory-management ✅
Status: **Disponible**
ARC, retain cycles, weak/unowned, [weak self], memory leaks debugging

### 🟠 Priorité Élevée

#### 4. swiftui ✅
Status: **Disponible**
Declarative UI, @State, @Binding, @Observable, ViewModifiers, animations, grid layouts

#### 5. process-management ✅
Status: **Disponible**
Process/NSTask, shell commands, PTY, git operations, Claude Code integration

#### 6. mvvm-architecture ✅
Status: **Disponible**
ViewModel, @MainActor, ObservableObject, dependency injection, testability

#### 7. file-operations ✅
Status: **Disponible**
FileManager, read/write files, directories, logs management, config files

#### 8. uikit
UIViewController, UITableView, Auto Layout, programmatic UI

#### 9. networking
URLSession, async/await networking, REST APIs, Codable, error handling

#### 8. core-data
NSManagedObject, fetch requests, migrations, relationships, iCloud sync

#### 9. combine
Publishers, Subscribers, reactive programming, operators

### 🟡 Priorité Moyenne

10. **swiftdata** - Modern persistence (iOS 17+)
11. **coordinator-pattern** - Navigation flow, deep linking
12. **dependency-injection** - Swinject, testability patterns
13. **xctest** - Unit tests, mocking, TDD
14. **clean-architecture** - Use cases, repositories, domain layer
15. **fastlane** - CI/CD automation
16. **instruments** - Performance profiling, memory debugging

### 🟢 Priorité Optionnelle

17. **viper** - Advanced architecture for complex apps
18. **coreml** - Machine Learning on-device
19. **arkit** - Augmented Reality
20. **cloudkit** - iCloud sync, public/private databases

---

## 🎓 Parcours d'apprentissage recommandés

### Pour Débutants (Apprendre Swift/iOS)

1. **swift-language** - Commencez ici pour les fondamentaux
2. **swiftui** - Interface utilisateur moderne
3. **mvvm-architecture** - Structurer votre code
4. **networking** - Communiquer avec des APIs
5. **core-data** - Persistance des données

### Pour Développeurs Intermédiaires

1. **swift-concurrency** - Programmation asynchrone moderne
2. **memory-management** - Optimisation et debugging
3. **combine** - Programmation réactive
4. **clean-architecture** - Apps complexes et maintenables
5. **xctest** - Tests automatisés

### Pour Experts iOS

1. **coordinator-pattern** - Navigation complexe
2. **dependency-injection** - Patterns avancés
3. **instruments** - Performance profiling
4. **viper** - Architecture entreprise
5. **coreml** / **arkit** - Fonctionnalités avancées

### Pour Apps macOS Spécifiquement

1. **swift-language** (section macOS) - Spécificités macOS
2. **swiftui** - UI déclarative multiplateforme
3. **appkit-interop** - Intégration AppKit/SwiftUI
4. **macos-patterns** - Menu bars, toolbars, file operations

---

## 💻 Installation et Utilisation

### Installer une skill

```bash
# Copier la skill dans le dossier de skills Claude
cp swift-language.skill ~/.anthropic/skills/

# Ou pour toutes les skills disponibles
cp *.skill ~/.anthropic/skills/
```

### Utiliser une skill avec Claude

Les skills se déclenchent automatiquement quand vous posez des questions pertinentes :

```
Vous: "Comment créer un modèle de données User avec Codable ?"
Claude: [charge automatiquement la skill swift-language]
```

Vous pouvez aussi invoquer explicitement :

```
Vous: "Utilise la skill swift-language pour m'expliquer les optionals"
```

### Développer vos propres skills

Ce repository suit les bonnes pratiques Anthropic pour la création de skills :

1. **Structure modulaire** - Chaque skill est indépendante
2. **Progressive disclosure** - Information chargée selon les besoins
3. **Ressources bundlées** - Scripts, références, assets inclus
4. **Validation automatique** - Garantit la qualité

Voir `skill-creator` pour le guide complet de création de skills.

---

## 📈 Statistiques

| Catégorie | Total | Disponibles | En cours | Planifiées |
|-----------|-------|-------------|----------|------------|
| **Core** | 4 | 3 ✅ | 0 🚧 | 1 📋 |
| **UI/UX** | 4 | 0 | 0 | 4 📋 |
| **Architecture** | 6 | 0 | 0 | 6 📋 |
| **Data & Networking** | 6 | 0 | 0 | 6 📋 |
| **Testing** | 5 | 0 | 0 | 5 📋 |
| **Tooling** | 7 | 0 | 0 | 7 📋 |
| **Advanced** | 8 | 0 | 0 | 8 📋 |
| **Total** | **40** | **3** | **0** | **37** |

---

## 🤝 Contribution

### Créer une nouvelle skill

```bash
# Initialiser une nouvelle skill
python3 /path/to/skill-creator/scripts/init_skill.py my-skill --path .

# Éditer SKILL.md et ajouter les ressources
# ...

# Valider
python3 /path/to/skill-creator/scripts/quick_validate.py my-skill

# Packager
python3 /path/to/skill-creator/scripts/package_skill.py my-skill
```

### Guidelines de contribution

1. **Suivre les principes Anthropic**
   - Concision (le contexte est une ressource partagée)
   - Progressive disclosure (charger selon les besoins)
   - Liberté appropriée (balance spécificité/flexibilité)

2. **Structure obligatoire**
   ```
   skill-name/
   ├── SKILL.md (obligatoire)
   ├── scripts/ (optionnel)
   ├── references/ (optionnel)
   └── assets/ (optionnel)
   ```

3. **Description dans frontmatter**
   - Inclure QUAND utiliser la skill
   - Être spécifique sur les triggers
   - Couvrir tous les cas d'usage

4. **Tester avant de soumettre**
   - Valider avec `quick_validate.py`
   - Tester les scripts inclus
   - Vérifier les références

---

## 📚 Ressources Additionnelles

### Documentation Officielle Apple

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)

### Outils Recommandés

- **Xcode** - IDE officiel Apple
- **Swift Playgrounds** - Apprentissage interactif
- **SF Symbols** - Icônes système Apple
- **Instruments** - Profiling et debugging
- **TestFlight** - Distribution beta

### Communauté

- [Swift Forums](https://forums.swift.org/)
- [Swift Evolution](https://github.com/apple/swift-evolution)
- [Stack Overflow - Swift](https://stackoverflow.com/questions/tagged/swift)

---

## 📄 Licence

Ce repository est destiné à un usage éducatif et professionnel. Les skills suivent les guidelines Anthropic pour la création de skills.

---

## 🎯 Prochaines Étapes

### Court terme (1-2 semaines)
- ✅ Finaliser `swift-language`
- 🚧 Compléter `swift-concurrency`
- 📋 Créer `memory-management`

### Moyen terme (1-2 mois)
- Développer les skills UI/UX (SwiftUI, UIKit)
- Ajouter les patterns d'architecture (MVVM, Clean)
- Créer les skills de data & networking

### Long terme (3-6 mois)
- Couvrir toutes les catégories prioritaires
- Ajouter des skills avancées (CoreML, ARKit)
- Créer des parcours d'apprentissage structurés

---

## ✨ Remerciements

Créé avec ❤️ pour la communauté des développeurs Swift/iOS.

Basé sur les bonnes pratiques Anthropic de création de skills et les Human Interface Guidelines d'Apple.

**Version**: 1.0.0
**Dernière mise à jour**: Février 2026
**Auteur**: Birahim
