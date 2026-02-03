# 📇 Index des Ressources

Index complet de toutes les ressources disponibles dans le repository iOS/Swift Skills.

## 📦 Skills Packagées

| Skill | Version | Status | Fichier |
|-------|---------|--------|---------|
| swift-language | 1.0 | ✅ Disponible | `swift-language.skill` |
| swift-concurrency | - | 🚧 En cours | - |
| memory-management | - | 📋 Planifié | - |

---

## 📄 Documentation Principale

### Guides Généraux

| Document | Description | Chemin |
|----------|-------------|--------|
| README.md | Vue d'ensemble complète du repository | `/README.md` |
| QUICK_START.md | Guide de démarrage rapide (3 min) | `/QUICK_START.md` |
| INDEX.md | Ce document - Index de toutes les ressources | `/INDEX.md` |

### Documentation par Skill

#### swift-language

| Type | Fichier | Description |
|------|---------|-------------|
| 📘 Skill | SKILL.md | Guide principal de la skill |
| 📖 Référence | fundamentals.md | Référence complète Swift (variables, optionals, collections, functions, closures, enums, structs, classes, protocols, extensions, generics, error handling, property wrappers) |
| 🖥️ Référence | macos-specifics.md | Spécificités macOS (SwiftUI/AppKit, window management, menu bars, file operations, preferences, keyboard shortcuts, sandboxing, interop, status bar, drag & drop) |
| 🛠️ Script | generate_model.py | Générateur de modèles Swift avec Codable |
| 🎨 Template | macos-app-template.swift | Template complet d'app macOS avec sidebar, menus, settings |

---

## 🛠️ Scripts Disponibles

### swift-language/scripts/

#### generate_model.py
**Générateur de modèles de données Swift**

**Fonctionnalités:**
- Génère des structs Swift avec Codable
- Support des types optionnels
- Conformité Identifiable (option)
- Initializer personnalisé (option)
- Génération d'exemples d'usage

**Usage:**
```bash
# Modèle basique
python3 scripts/generate_model.py \
  --name User \
  --properties "name:String,age:Int,email:String?"

# Avec Identifiable
python3 scripts/generate_model.py \
  --name Product \
  --properties "id:UUID,name:String,price:Double" \
  --identifiable

# Sans Codable
python3 scripts/generate_model.py \
  --name Point \
  --properties "x:Double,y:Double" \
  --no-codable

# Sans initializer
python3 scripts/generate_model.py \
  --name Config \
  --properties "apiKey:String" \
  --no-init

# Avec exemple d'utilisation
python3 scripts/generate_model.py \
  --name User \
  --properties "name:String,age:Int" \
  --example

# Sauvegarder dans fichier
python3 scripts/generate_model.py \
  --name User \
  --properties "name:String,age:Int" \
  --output User.swift
```

**Exemples de sortie:**
```swift
struct User: Codable {
    let name: String
    let age: Int
    let email: String?

    init(name: String, age: Int, email: String? = nil) {
        self.name = name
        self.age = age
        self.email = email
    }
}
```

---

## 🎨 Templates et Assets

### swift-language/assets/

#### macos-app-template.swift
**Template complet d'application macOS**

**Inclut:**
- ✅ Structure d'app SwiftUI moderne
- ✅ Sidebar navigation avec sections
- ✅ Multiple views (Home, Projects, Documents, Preferences)
- ✅ Menu commands personnalisés avec keyboard shortcuts
- ✅ Settings/Preferences window avec tabs
- ✅ @AppStorage pour les settings persistants
- ✅ Best practices Apple (HIG)

**Fonctionnalités:**
- WindowGroup pour la fenêtre principale
- Settings scene pour les préférences
- CommandMenu pour menus personnalisés
- Keyboard shortcuts (⌘D, ⌘⇧A, etc.)
- NavigationView avec sidebar
- TabView dans Settings
- Form avec grouped style

**Utilisation:**
1. Copier le template dans votre projet Xcode
2. Remplacer "MyMacApp" par le nom de votre app
3. Personnaliser les views (HomeView, ProjectsView, etc.)
4. Ajouter votre logique métier

**Structure:**
```swift
MyMacApp (App)
├── ContentView
│   ├── SidebarView
│   │   ├── Main section
│   │   │   ├── Home
│   │   │   ├── Projects
│   │   │   └── Documents
│   │   └── Settings section
│   │       └── Preferences
│   └── DetailView
│       ├── HomeView
│       ├── ProjectsView
│       ├── DocumentsView
│       └── PreferencesView
└── SettingsView
    ├── GeneralSettingsView
    ├── AccountsSettingsView
    └── AdvancedSettingsView
```

---

## 📖 Références Détaillées

### swift-language/references/

#### fundamentals.md
**Référence complète du langage Swift**

**Table des matières:**
1. Variables & Constants (`let`, `var`, type inference)
2. Optionals (unwrapping, `if let`, `guard`, `??`, optional chaining)
3. String Interpolation
4. Collections (Arrays, Dictionaries, Sets)
5. Functions (parameters, return values, argument labels, default params, variadic, inout)
6. Closures (syntax, trailing closure, capturing values)
7. Enumerations (simple, associated values, raw values, pattern matching)
8. Structures (properties, methods, computed properties, `mutating`)
9. Classes (inheritance, `override`, reference types)
10. Protocols (blueprint, conformance, protocol as type, composition)
11. Extensions (add functionality, protocol conformance)
12. Generics (generic functions, types, constraints)
13. Error Handling (`throw`, `try`, `do-catch`, `try?`, `try!`)
14. Property Wrappers (custom property behavior)
15. Common Patterns (Result, guard-let, defer)

**Exemples de code pour chaque concept**
**Best practices incluses**

#### macos-specifics.md
**Développement macOS avec Swift**

**Table des matières:**
1. AppKit vs SwiftUI (quand utiliser quoi)
2. Basic macOS App Structure (SwiftUI)
3. macOS Window Management (WindowGroup, Settings, Window, DocumentGroup)
4. Menu Bar Integration (CommandGroup, CommandMenu)
5. Toolbar Customization
6. Sidebar Navigation (NavigationView, List, sidebar style)
7. File Operations (NSOpenPanel, NSSavePanel, UTType)
8. Preferences Window Pattern (TabView)
9. Keyboard Shortcuts (keyboardShortcut modifier)
10. App Sandbox & Entitlements (sandboxing, capabilities)
11. AppKit Interop (NSViewRepresentable, wrapping NSView)
12. Status Bar App (menu bar extra, NSStatusBar)
13. Native Alerts & Dialogs (NSAlert)
14. Drag & Drop (onDrop modifier)

**Exemples de code complets**
**Patterns spécifiques à macOS**

---

## 🎯 Parcours de Lecture Recommandés

### Pour Apprendre Swift de Zéro

**Ordre recommandé:**
1. **QUICK_START.md** - Commencer ici (10 min)
2. **fundamentals.md** - Sections 1-4 (Variables, Optionals, Strings, Collections)
3. **Pratiquer**: Créer des modèles avec `generate_model.py`
4. **fundamentals.md** - Sections 5-7 (Functions, Closures, Enums)
5. **fundamentals.md** - Sections 8-10 (Structs, Classes, Protocols)
6. **fundamentals.md** - Sections 11-15 (Extensions, Generics, Error Handling, Patterns)

**Durée estimée**: 1-2 semaines avec pratique

### Pour Créer une App macOS

**Ordre recommandé:**
1. **QUICK_START.md** - Cas d'usage macOS
2. **macos-specifics.md** - Section "AppKit vs SwiftUI"
3. **macos-specifics.md** - "Basic App Structure"
4. **macos-app-template.swift** - Étudier le template complet
5. **macos-specifics.md** - Features spécifiques (Menu Bar, Sidebar, File Ops)
6. **Pratiquer**: Adapter le template pour votre projet

**Durée estimée**: 3-5 jours avec pratique

### Pour Maîtriser les Patterns Avancés

**Ordre recommandé:**
1. **fundamentals.md** - Generics (section 12)
2. **fundamentals.md** - Property Wrappers (section 14)
3. **fundamentals.md** - Common Patterns (section 15)
4. **macos-specifics.md** - AppKit Interop (si besoin de features AppKit)
5. **Attendre swift-concurrency skill** pour async/await

**Durée estimée**: 1-2 semaines

---

## 🔍 Index par Concept

Trouvez rapidement où un concept est expliqué :

### A-C
- **ARC** - À venir dans skill `memory-management`
- **Arrays** - fundamentals.md § Collections
- **Associated Values** - fundamentals.md § Enumerations
- **async/await** - À venir dans skill `swift-concurrency`
- **Closures** - fundamentals.md § Closures
- **Classes** - fundamentals.md § Classes
- **Codable** - fundamentals.md § Error Handling, generate_model.py
- **Collections** - fundamentals.md § Collections
- **Computed Properties** - fundamentals.md § Structures

### D-G
- **Defer** - fundamentals.md § Common Patterns
- **Dictionaries** - fundamentals.md § Collections
- **Drag & Drop** - macos-specifics.md § Drag & Drop
- **Enums** - fundamentals.md § Enumerations
- **Error Handling** - fundamentals.md § Error Handling
- **Extensions** - fundamentals.md § Extensions
- **File Operations** - macos-specifics.md § File Operations
- **Functions** - fundamentals.md § Functions
- **Generics** - fundamentals.md § Generics
- **Guard** - fundamentals.md § Optionals, Common Patterns

### H-O
- **Identifiable** - generate_model.py (--identifiable flag)
- **Initialization** - fundamentals.md § Structures, Classes
- **Keyboard Shortcuts** - macos-specifics.md § Keyboard Shortcuts
- **Menu Bar** - macos-specifics.md § Menu Bar Integration
- **NSOpenPanel** - macos-specifics.md § File Operations
- **Optionals** - fundamentals.md § Optionals

### P-S
- **Protocols** - fundamentals.md § Protocols
- **Property Wrappers** - fundamentals.md § Property Wrappers
- **Reference Types** - fundamentals.md § Classes
- **Result Type** - fundamentals.md § Common Patterns
- **Sandbox** - macos-specifics.md § App Sandbox & Entitlements
- **Sets** - fundamentals.md § Collections
- **Sidebar** - macos-specifics.md § Sidebar Navigation, macos-app-template.swift
- **Status Bar** - macos-specifics.md § Status Bar App
- **String Interpolation** - fundamentals.md § String Interpolation
- **Structures** - fundamentals.md § Structures
- **SwiftUI** - macos-specifics.md (complet), macos-app-template.swift

### T-Z
- **Toolbar** - macos-specifics.md § Toolbar Customization
- **Type Safety** - fundamentals.md § Variables & Constants
- **Value Types** - fundamentals.md § Structures
- **Window Management** - macos-specifics.md § macOS Window Management

---

## 📊 Statistiques du Repository

### Contenu Disponible

| Type | Quantité | Taille totale |
|------|----------|---------------|
| Skills packagées | 1 | ~50 KB |
| Références MD | 2 | ~25 KB |
| Scripts Python | 1 | ~8 KB |
| Templates Swift | 1 | ~6 KB |
| Documentation | 4 | ~40 KB |

### Concepts Couverts

| Catégorie | Concepts |
|-----------|----------|
| **Swift Basics** | 15+ (variables, optionals, collections, functions, etc.) |
| **Swift Advanced** | 10+ (protocols, generics, property wrappers, etc.) |
| **macOS UI** | 14+ (windows, menus, sidebars, file ops, etc.) |
| **Patterns** | 8+ (Result, guard-let, defer, MVVM prep, etc.) |
| **Total** | **47+ concepts** |

---

## 🔄 Mises à Jour

### Version 1.0.0 (Février 2026)
- ✅ Skill `swift-language` complète
- ✅ Documentation fondamentaux Swift
- ✅ Documentation macOS spécifique
- ✅ Script générateur de modèles
- ✅ Template app macOS
- ✅ Guides (README, QUICK_START, INDEX)

### Prochaines Versions

**v1.1.0** (Mars 2026)
- 🚧 Skill `swift-concurrency`
- 🚧 Documentation async/await, actors

**v1.2.0** (Avril 2026)
- 📋 Skill `memory-management`
- 📋 Documentation ARC, retain cycles

**v2.0.0** (Mai 2026+)
- 📋 Skills UI/UX (SwiftUI, UIKit)
- 📋 Skills Architecture (MVVM, Clean)
- 📋 Skills Data & Networking

---

## 🎯 Utilisation de cet Index

### Trouver un concept rapidement
1. Consultez la section "Index par Concept"
2. Notez le fichier de référence
3. Ouvrez le fichier et cherchez la section

### Explorer une skill
1. Consultez "Documentation par Skill"
2. Lisez SKILL.md pour vue d'ensemble
3. Consultez les références selon vos besoins

### Apprendre progressivement
1. Suivez un "Parcours de Lecture Recommandé"
2. Pratiquez avec les scripts et templates
3. Revenez à l'index pour approfondir

### Contribuer
1. Consultez README.md § Contribution
2. Utilisez skill-creator pour créer de nouvelles skills
3. Mettez à jour cet index avec vos ajouts

---

**Dernière mise à jour**: Février 2026
**Version de l'index**: 1.0.0
