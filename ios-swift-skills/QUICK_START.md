# 🚀 Guide de Démarrage Rapide

Bienvenue dans le repository de skills iOS/Swift ! Ce guide vous aidera à démarrer rapidement.

## ⚡ Installation en 3 minutes

### 1. Installer la skill swift-language

```bash
# Copier la skill dans votre dossier de skills Claude
cp swift-language.skill ~/.anthropic/skills/

# Vérifier l'installation
ls ~/.anthropic/skills/
```

### 2. Tester la skill avec Claude

Ouvrez une conversation avec Claude et essayez :

```
"Explique-moi comment fonctionnent les optionals en Swift"
```

La skill `swift-language` se chargera automatiquement !

### 3. Créer votre première app macOS

```
"Utilise le template macOS pour créer une app de todo list"
```

Claude utilisera automatiquement le template inclus dans la skill.

---

## 🎯 Cas d'Usage Courants

### Pour Débutants

#### 1. Apprendre les fondamentaux Swift
```
"Je débute en Swift, explique-moi les concepts de base"
"Quelle est la différence entre var et let ?"
"Comment fonctionnent les closures ?"
```

#### 2. Créer des modèles de données
```
"Crée un modèle User avec nom, email et age"
"Génère un struct Product avec Codable"
```

#### 3. Comprendre les patterns macOS
```
"Comment créer une app macOS avec sidebar ?"
"Montre-moi comment ouvrir un file picker"
"Comment ajouter des menu commands ?"
```

### Pour Développeurs Intermédiaires

#### 1. Patterns avancés
```
"Explique le pattern Result pour la gestion d'erreurs"
"Comment utiliser les property wrappers ?"
"Montre-moi un exemple de generics"
```

#### 2. Architecture
```
"Crée une structure de projet MVVM"
"Comment organiser mon code pour une app complexe ?"
```

#### 3. Debugging
```
"Comment débugger un memory leak ?"
"Explique-moi ARC et les retain cycles"
```

---

## 🛠️ Utiliser les Scripts

### Générateur de Modèles Swift

Le script `generate_model.py` vous fait gagner du temps :

```bash
# Modèle simple
python3 swift-language/scripts/generate_model.py \
  --name User \
  --properties "name:String,age:Int,email:String?"

# Avec identifiable (pour SwiftUI Lists)
python3 swift-language/scripts/generate_model.py \
  --name Product \
  --properties "id:UUID,name:String,price:Double" \
  --identifiable

# Avec exemple d'utilisation
python3 swift-language/scripts/generate_model.py \
  --name Config \
  --properties "apiKey:String,timeout:Int,retries:Int" \
  --example

# Sauvegarder dans un fichier
python3 swift-language/scripts/generate_model.py \
  --name User \
  --properties "name:String,age:Int" \
  --output User.swift
```

**Résultat:**
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

## 📚 Accéder à la Documentation

### Documentation de référence

Les skills incluent de la documentation détaillée que Claude charge selon vos besoins :

#### fundamentals.md
Référence complète du langage Swift :
- Variables, constantes, types
- Optionals et unwrapping
- Collections (Array, Dictionary, Set)
- Fonctions et closures
- Structs vs Classes
- Protocols et Extensions
- Generics
- Error Handling
- Property Wrappers
- Patterns courants

#### macos-specifics.md
Spécificités du développement macOS :
- SwiftUI vs AppKit
- Structure d'app macOS
- Window management
- Menu bars et toolbars
- Sidebar navigation
- File operations (NSOpenPanel, NSSavePanel)
- Preferences window
- Keyboard shortcuts
- App Sandbox & Entitlements
- AppKit interop
- Status bar apps
- Alerts & Dialogs
- Drag & Drop

**Astuce**: Demandez à Claude de consulter ces références :

```
"Lis fundamentals.md et explique-moi les generics"
"Consulte macos-specifics.md pour les file operations"
```

---

## 🎨 Utiliser les Templates

### Template macOS App

Le template `macos-app-template.swift` fournit :

✅ Structure d'app complète avec SwiftUI
✅ Sidebar navigation
✅ Menu commands personnalisés
✅ Fenêtre de préférences (Settings)
✅ Keyboard shortcuts
✅ Bonnes pratiques Apple

**Utilisation:**

```
"Crée une app macOS basée sur le template, pour gérer des notes"
"Adapte le template macOS pour une app de gestion de projets"
```

Claude copiera et adaptera le template selon vos besoins !

---

## 🎓 Parcours d'Apprentissage

### Semaine 1: Fondamentaux Swift
**Objectif**: Maîtriser les bases du langage

**Jour 1-2**: Variables, constantes, types, optionals
```
"Explique-moi les optionals avec des exemples concrets"
"Quelle est la différence entre let et var ?"
```

**Jour 3-4**: Collections et fonctions
```
"Comment manipuler des arrays en Swift ?"
"Montre-moi des exemples de map, filter, reduce"
"Explique-moi les closures et trailing closures"
```

**Jour 5-7**: Structs, classes, protocols
```
"Quelle est la différence entre struct et class ?"
"Comment utiliser les protocols en Swift ?"
"Explique-moi les extensions"
```

### Semaine 2: macOS App Basics
**Objectif**: Créer votre première app macOS

**Jour 1-2**: Structure d'app SwiftUI
```
"Crée une app macOS simple avec SwiftUI"
"Comment ajouter une sidebar navigation ?"
```

**Jour 3-4**: File operations et persistence
```
"Comment ouvrir et sauvegarder des fichiers ?"
"Montre-moi comment utiliser NSOpenPanel"
```

**Jour 5-7**: Projet complet
```
"Crée une app macOS de prise de notes avec:
- Sidebar pour lister les notes
- Éditeur de texte
- Sauvegarde/chargement de fichiers
- Menu commands pour New/Save"
```

### Semaine 3-4: Concepts Avancés
**Objectif**: Approfondir vos connaissances

- Error handling et Result type
- Generics et protocols avancés
- Property wrappers (@State, @Binding)
- Combine basics (si skill disponible)
- Async/await (si skill swift-concurrency disponible)

---

## 💡 Conseils et Astuces

### 1. Soyez spécifique dans vos questions

❌ **Mauvais**: "Explique Swift"
✅ **Bon**: "Explique-moi comment fonctionnent les optionals et montre des exemples de unwrapping"

### 2. Demandez des exemples concrets

❌ **Mauvais**: "C'est quoi un protocol ?"
✅ **Bon**: "Montre-moi un exemple de protocol avec une implémentation concrète"

### 3. Construisez progressivement

```
1. "Crée un modèle User simple"
2. "Ajoute une validation email"
3. "Rends-le Codable pour JSON"
4. "Ajoute des exemples d'utilisation"
```

### 4. Explorez les références

```
"Lis fundamentals.md et résume les sections sur les closures"
"Consulte macos-specifics.md pour les patterns de navigation"
```

### 5. Utilisez les scripts

```
"Utilise generate_model.py pour créer un modèle Product"
"Génère plusieurs modèles pour une app e-commerce"
```

---

## 🐛 Résolution de Problèmes

### La skill ne se charge pas

1. Vérifiez l'installation:
```bash
ls ~/.anthropic/skills/
```

2. Réinstallez:
```bash
cp swift-language.skill ~/.anthropic/skills/ --force
```

### Le script Python ne fonctionne pas

1. Vérifiez Python:
```bash
python3 --version  # Doit être 3.7+
```

2. Rendez le script exécutable:
```bash
chmod +x swift-language/scripts/generate_model.py
```

3. Exécutez directement:
```bash
python3 swift-language/scripts/generate_model.py --help
```

### Claude ne trouve pas le template

```
"Liste les assets disponibles dans swift-language"
"Montre-moi le contenu de macos-app-template.swift"
```

---

## 📖 Documentation Complète

Pour aller plus loin :

- **README.md** - Vue d'ensemble complète du repository
- **fundamentals.md** - Référence détaillée du langage Swift
- **macos-specifics.md** - Guide complet macOS
- **ROADMAP.md** - Skills à venir et évolution du projet

---

## 🤝 Prochaines Étapes

### 1. Maîtriser swift-language ✅
Vous êtes ici ! Explorez tous les exemples et créez votre première app.

### 2. Attendre swift-concurrency 🚧
Bientôt disponible : async/await, actors, structured concurrency.

### 3. Explorer memory-management 📋
À venir : ARC, retain cycles, memory debugging.

### 4. Construire des apps complètes
Combinez plusieurs skills pour des projets réels.

---

## 💬 Questions Fréquentes

**Q: Puis-je utiliser ces skills pour iOS en plus de macOS ?**
R: Oui ! Les fondamentaux Swift sont identiques. Seules les sections macOS-specifics sont spécifiques à macOS.

**Q: Combien de temps pour maîtriser Swift ?**
R: Avec pratique régulière et ces skills : 2-4 semaines pour les bases, 2-3 mois pour l'aisance.

**Q: Ai-je besoin d'expérience en programmation ?**
R: Utile mais pas obligatoire. Les skills sont conçues pour les débutants.

**Q: Les skills sont-elles à jour avec Swift 5.x ?**
R: Oui, basées sur Swift 5.x et les dernières pratiques Apple.

**Q: Puis-je contribuer ou créer mes propres skills ?**
R: Absolument ! Voir README.md section "Contribution".

---

## ✨ Amusez-vous bien !

Vous avez maintenant tout ce qu'il faut pour commencer. N'hésitez pas à expérimenter et à poser des questions à Claude !

**Bon code ! 🚀**
