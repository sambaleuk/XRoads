# ARC - Automatic Reference Counting

Guide complet de la gestion mémoire automatique en Swift.

## Qu'est-ce que ARC ?

ARC (Automatic Reference Counting) gère automatiquement la mémoire en comptant les références aux objets. Quand le compteur atteint zéro, l'objet est désalloué.

**Important** : ARC s'applique uniquement aux types **référence** (classes). Les types valeur (struct, enum) sont copiés et n'utilisent pas ARC.

## Fonctionnement de Base

```swift
class Person {
    let name: String

    init(name: String) {
        self.name = name
        print("\(name) est initialisé")
    }

    deinit {
        print("\(name) est désalloué")
    }
}

// Création d'une instance
var person1: Person? = Person(name: "Alice")
// Output: "Alice est initialisé"
// Reference count: 1

var person2 = person1  // Reference count: 2
var person3 = person1  // Reference count: 3

person1 = nil  // Reference count: 2
person2 = nil  // Reference count: 1
person3 = nil  // Reference count: 0
// Output: "Alice est désalloué"
```

## Types de Références

### Strong References (par défaut)

Les références fortes incrémentent le compteur de références.

```swift
class Device {
    var owner: Person  // Strong reference

    init(owner: Person) {
        self.owner = owner
    }
}

let person = Person(name: "Bob")
let device = Device(owner: person)
// person a maintenant 2 références fortes
```

### weak - Références Faibles

Les références faibles ne maintiennent pas l'objet en vie.

```swift
class Apartment {
    let number: Int
    weak var tenant: Person?  // weak reference

    init(number: Int) {
        self.number = number
    }

    deinit {
        print("Apartment \(number) est désalloué")
    }
}

class Person {
    let name: String
    var apartment: Apartment?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("\(name) est désalloué")
    }
}

var john: Person? = Person(name: "John")
var unit4A: Apartment? = Apartment(number: 4)

john?.apartment = unit4A
unit4A?.tenant = john  // weak reference

john = nil
// Output: "John est désalloué"
// apartment.tenant devient automatiquement nil

unit4A = nil
// Output: "Apartment 4 est désalloué"
```

**Caractéristiques de weak** :
- Doit toujours être `var` (pas `let`)
- Doit toujours être optionnel (`?`)
- Devient automatiquement `nil` quand l'objet est désalloué
- Utilisé pour éviter les retain cycles

### unowned - Références Non-Possédées

Comme `weak`, mais suppose que la référence n'est jamais `nil`.

```swift
class Customer {
    let name: String
    var card: CreditCard?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("\(name) est désalloué")
    }
}

class CreditCard {
    let number: UInt64
    unowned let customer: Customer  // unowned reference

    init(number: UInt64, customer: Customer) {
        self.number = number
        self.customer = customer
    }

    deinit {
        print("Carte \(number) est désallouée")
    }
}

var john: Customer? = Customer(name: "John Doe")
john?.card = CreditCard(number: 1234_5678_9012_3456, customer: john!)

john = nil
// Output:
// "John Doe est désalloué"
// "Carte 1234567890123456 est désallouée"
```

**Caractéristiques de unowned** :
- Peut être `let` ou `var`
- N'est jamais optionnel
- Ne devient PAS automatiquement `nil` (⚠️ peut crasher si accédé après désallocation)
- Utilisé quand la référence a toujours la même durée de vie ou plus courte

## Quand Utiliser Chaque Type ?

| Type | Usage | Optionnel | Peut devenir nil |
|------|-------|-----------|------------------|
| **strong** | Par défaut, ownership | Non requis | Non (sauf si optionnel) |
| **weak** | Référence optionnelle, peut disparaître | ✅ Oui | ✅ Oui |
| **unowned** | Référence garantie présente | ❌ Non | ❌ Non (crash si désalloué) |

### Guidelines

**Utilisez `weak` quand** :
- La référence peut légitimement être `nil`
- Parent → Enfant optionnel (delegate patterns)
- Observateurs, closures capturant `self`

**Utilisez `unowned` quand** :
- La référence ne sera jamais `nil` pendant sa durée de vie
- Enfant → Parent garanti présent
- Relations de même durée de vie

**Utilisez `strong` (défaut) quand** :
- Vous voulez posséder l'objet
- Pas de risque de retain cycle

## Retain Cycles - Problème Principal

### Qu'est-ce qu'un Retain Cycle ?

Deux objets se référencent mutuellement avec des références fortes, créant un cycle qui empêche leur désallocation.

```swift
// ❌ Retain cycle !
class Person {
    var apartment: Apartment?  // Strong
    deinit { print("Person désalloué") }
}

class Apartment {
    var tenant: Person?  // Strong
    deinit { print("Apartment désalloué") }
}

var john: Person? = Person()
var unit: Apartment? = Apartment()

john?.apartment = unit
unit?.tenant = john

john = nil
unit = nil

// ❌ RIEN n'est désalloué ! Retain cycle !
// Les objets se tiennent mutuellement en vie
```

### Solution : Casser le Cycle avec weak

```swift
// ✅ Pas de retain cycle
class Person {
    var apartment: Apartment?
    deinit { print("Person désalloué") }
}

class Apartment {
    weak var tenant: Person?  // ✅ weak !
    deinit { print("Apartment désalloué") }
}

var john: Person? = Person()
var unit: Apartment? = Apartment()

john?.apartment = unit
unit?.tenant = john

john = nil
// Output: "Person désalloué"
// apartment.tenant devient nil automatiquement

unit = nil
// Output: "Apartment désalloué"
```

## Closures et Capture Lists

Les closures capturent fortement leurs références par défaut, créant des retain cycles potentiels.

### Problème : Closure retient self

```swift
class ViewController {
    var name = "Home"
    var onButtonTap: (() -> Void)?

    func setupButton() {
        // ❌ Retain cycle !
        onButtonTap = {
            print("Button tapped in \(self.name)")
            // self retient closure, closure retient self
        }
    }

    deinit {
        print("ViewController désalloué")
    }
}

var vc: ViewController? = ViewController()
vc?.setupButton()
vc = nil
// ❌ ViewController n'est JAMAIS désalloué !
```

### Solution : Capture List avec [weak self]

```swift
class ViewController {
    var name = "Home"
    var onButtonTap: (() -> Void)?

    func setupButton() {
        // ✅ Pas de retain cycle
        onButtonTap = { [weak self] in
            guard let self = self else { return }
            print("Button tapped in \(self.name)")
        }
    }

    deinit {
        print("ViewController désalloué")
    }
}

var vc: ViewController? = ViewController()
vc?.setupButton()
vc = nil
// ✅ Output: "ViewController désalloué"
```

### Pattern avec [unowned self]

Utilisez quand self est garanti présent pendant la vie de la closure.

```swift
class ViewController {
    var completion: (() -> Void)?

    func setup() {
        // ✅ unowned si self existe toujours quand closure s'exécute
        completion = { [unowned self] in
            self.handleCompletion()
        }
    }
}
```

### Multiples Captures

```swift
class DataManager {
    var cache: Cache?

    func loadData() {
        fetchFromNetwork { [weak self, weak cache] data in
            guard let self = self,
                  let cache = cache else { return }

            cache.store(data)
            self.processData(data)
        }
    }
}
```

## Patterns Courants

### Pattern 1: Delegates

```swift
// ❌ Retain cycle
protocol DataSourceDelegate {
    func didUpdate()
}

class DataSource {
    var delegate: DataSourceDelegate?  // Strong !
}

// ✅ Solution
protocol DataSourceDelegate: AnyObject {  // Limiter aux classes
    func didUpdate()
}

class DataSource {
    weak var delegate: DataSourceDelegate?  // ✅ weak
}
```

### Pattern 2: Parent-Child

```swift
class Parent {
    var children: [Child] = []  // Strong - parent possède enfants

    func addChild(_ child: Child) {
        child.parent = self
        children.append(child)
    }
}

class Child {
    weak var parent: Parent?  // ✅ weak - enfant ne possède pas parent
}
```

### Pattern 3: Observers / Notifications

```swift
class Observer {
    init() {
        // ❌ Retain cycle potentiel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification),
            name: .someNotification,
            object: nil
        )
    }

    deinit {
        // ✅ TOUJOURS retirer les observers !
        NotificationCenter.default.removeObserver(self)
    }

    @objc func handleNotification() {
        // ...
    }
}
```

### Pattern 4: Timers

```swift
class TimerManager {
    var timer: Timer?

    func startTimer() {
        // ❌ Timer retient fortement self !
        timer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in  // ✅ weak self
            self?.tick()
        }
    }

    func stopTimer() {
        timer?.invalidate()  // ✅ CRITICAL : invalider le timer
        timer = nil
    }

    deinit {
        stopTimer()  // ✅ Arrêter dans deinit
    }
}
```

### Pattern 5: Async/Await

```swift
class DataLoader {
    func loadData() async {
        // ✅ async/await ne crée pas de retain cycle
        let data = await fetchData()
        processData(data)  // self est capturé, mais pas problématique
    }

    // Task peut créer des cycles
    func loadInBackground() {
        Task { [weak self] in  // ✅ weak si nécessaire
            guard let self = self else { return }
            let data = await self.fetchData()
            await self.processData(data)
        }
    }
}
```

## Debugging Memory Issues

### Utiliser deinit

```swift
class MyClass {
    let id = UUID()

    deinit {
        print("MyClass \(id) désalloué")
    }
}

// Si deinit n'est jamais appelé → memory leak !
```

### Instruments - Leaks Tool

1. Product → Profile (⌘I)
2. Choisir "Leaks"
3. Exécuter l'app
4. Les leaks apparaissent en rouge

### Memory Graph Debugger

1. Exécuter l'app
2. Cliquer sur l'icône Debug Memory Graph (Xcode)
3. Voir tous les objets en mémoire
4. Les retain cycles apparaissent avec "!"

## Best Practices

### 1. Toujours utiliser [weak self] dans les closures

```swift
// ✅ Bon
viewModel.loadData { [weak self] data in
    self?.updateUI(data)
}

// ❌ Mauvais (retain cycle probable)
viewModel.loadData { data in
    self.updateUI(data)
}
```

### 2. Delegates toujours weak

```swift
protocol MyDelegate: AnyObject { }

class MyClass {
    weak var delegate: MyDelegate?  // ✅
}
```

### 3. Retirer les observers

```swift
deinit {
    NotificationCenter.default.removeObserver(self)  // ✅
}
```

### 4. Invalider les timers

```swift
deinit {
    timer?.invalidate()  // ✅
}
```

### 5. Tester la désallocation

```swift
// Ajouter des prints dans deinit
deinit {
    print("✅ \(type(of: self)) désalloué")
}

// Si jamais appelé → memory leak !
```

## Erreurs Courantes

### ❌ Oublier weak dans une closure

```swift
class ViewController {
    func loadData() {
        api.fetch { data in
            self.data = data  // ❌ Retain cycle !
        }
    }
}
```

### ❌ Utiliser unowned alors que weak est nécessaire

```swift
class View {
    unowned var controller: Controller  // ❌ Peut crasher !

    func refresh() {
        controller.reload()  // ⚠️ Crash si controller désalloué
    }
}
```

### ❌ Ne pas invalider les timers

```swift
class Manager {
    var timer: Timer?

    // ❌ Memory leak - timer jamais invalidé !
    deinit {
        // Oublié timer?.invalidate()
    }
}
```

## Résumé

✅ **ARC** gère automatiquement la mémoire des classes
✅ **strong** = référence propriétaire (défaut)
✅ **weak** = référence optionnelle, devient nil
✅ **unowned** = référence non-optionnelle, ne devient pas nil
✅ **Retain cycles** = deux objets se retiennent mutuellement
✅ **[weak self]** dans closures pour éviter les cycles
✅ **Delegates weak** pour éviter les cycles
✅ **Invalider timers/observers** dans deinit
✅ **Instruments & Memory Graph** pour détecter les leaks
