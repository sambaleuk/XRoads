# Actors - Protection Contre les Data Races

Guide complet des actors pour écrire du code concurrent thread-safe.

## Qu'est-ce qu'un Actor ?

Un actor est un type de référence qui protège automatiquement ses propriétés mutables contre les data races en garantissant qu'une seule tâche peut accéder à son état à la fois.

### Problème : Data Races avec les Classes

```swift
// ❌ Danger : Data race !
class Counter {
    var value = 0

    func increment() {
        value += 1
    }
}

// Accès concurrent = crash ou valeurs incorrectes
let counter = Counter()

Task {
    for _ in 1...1000 {
        counter.increment()
    }
}

Task {
    for _ in 1...1000 {
        counter.increment()
    }
}

// Résultat attendu: 2000
// Résultat réel: variable (1847, 1923, 2000...)
```

### Solution : Actor

```swift
// ✅ Thread-safe automatiquement
actor Counter {
    var value = 0

    func increment() {
        value += 1
    }
}

// Usage avec await
let counter = Counter()

Task {
    for _ in 1...1000 {
        await counter.increment()
    }
}

Task {
    for _ in 1...1000 {
        await counter.increment()
    }
}

// Résultat: toujours 2000 ✅
```

## Déclaration d'Actors

### Actor Simple

```swift
actor BankAccount {
    private var balance: Double = 0

    func deposit(amount: Double) {
        balance += amount
    }

    func withdraw(amount: Double) -> Bool {
        guard balance >= amount else {
            return false
        }
        balance -= amount
        return true
    }

    func getBalance() -> Double {
        return balance
    }
}

// Usage
let account = BankAccount()
await account.deposit(amount: 100)
let balance = await account.getBalance()
```

### Actor avec Initializer

```swift
actor DataStore {
    private var cache: [String: Data]

    init(initialCache: [String: Data] = [:]) {
        self.cache = initialCache
    }

    func get(key: String) -> Data? {
        return cache[key]
    }

    func set(key: String, value: Data) {
        cache[key] = value
    }
}
```

## Propriétés d'Actor

### Propriétés Isolées (par défaut)

Toutes les propriétés stored sont automatiquement isolées (protégées).

```swift
actor UserManager {
    // Propriétés isolées (accès via await)
    private var users: [User] = []
    private var cache: [String: User] = [:]

    // Méthodes isolées
    func addUser(_ user: User) {
        users.append(user)
        cache[user.id] = user
    }

    func getUser(id: String) -> User? {
        return cache[id]
    }
}

// Accès isolé
let manager = UserManager()
await manager.addUser(user)
let user = await manager.getUser(id: "123")
```

### Propriétés Non-Isolées (nonisolated)

Propriétés accessibles sans await (lecture seule recommandée).

```swift
actor Configuration {
    let apiKey: String // Constante = OK sans isolation
    private var settings: [String: Any]

    nonisolated let appVersion: String = "1.0.0"

    init(apiKey: String) {
        self.apiKey = apiKey
        self.settings = [:]
    }

    // Méthode non-isolée (pas d'accès à l'état mutable)
    nonisolated func buildURL(endpoint: String) -> URL {
        return URL(string: "https://api.example.com/\(endpoint)")!
    }
}

// Usage
let config = Configuration(apiKey: "abc123")
let url = config.buildURL(endpoint: "users") // Pas d'await nécessaire
let key = await config.apiKey // await pour propriété isolée
```

## Isolation des Actors

### Actor Isolation

Comprendre quel code s'exécute dans quel contexte.

```swift
actor ImageCache {
    private var images: [URL: UIImage] = [:]

    // ✅ Isolé à l'actor (peut accéder à images)
    func cacheImage(_ image: UIImage, for url: URL) {
        images[url] = image
    }

    // ✅ Isolé à l'actor
    func getImage(for url: URL) -> UIImage? {
        return images[url]
    }

    // ❌ Erreur : closures ne sont pas isolées par défaut
    func loadAllImages(urls: [URL]) {
        urls.forEach { url in
            // ❌ Erreur : 'self' captured by closure before actor isolation
            images[url] = loadImage(url)
        }
    }

    // ✅ Solution : utiliser async
    func loadAllImages(urls: [URL]) async {
        for url in urls {
            let image = await loadImage(url)
            images[url] = image // ✅ Dans le contexte de l'actor
        }
    }
}
```

### isolated Parameters

Passer l'isolation d'un actor à une fonction.

```swift
actor Counter {
    var value = 0

    func increment() {
        value += 1
    }
}

// Fonction qui prend un counter isolé
func performOperations(on counter: isolated Counter) {
    // Pas besoin d'await ici car on est dans le contexte de l'actor
    counter.value += 10
}

// Usage
let counter = Counter()
await performOperations(on: counter)
```

## MainActor - Actor Global pour l'UI

`MainActor` garantit l'exécution sur le thread principal (nécessaire pour les opérations UI).

### Marquer une classe avec @MainActor

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false

    // Toutes les propriétés et méthodes sont sur le main thread
    func loadUsers() async {
        isLoading = true

        // Opération background
        let users = await fetchUsers()

        // Retour automatique au main thread
        self.users = users // ✅ Safe pour UI
        isLoading = false
    }
}
```

### Marquer des fonctions avec @MainActor

```swift
// Fonction garantie sur le main thread
@MainActor
func updateLabel(text: String) {
    label.text = text // ✅ Safe
}

// Utiliser depuis background
func backgroundWork() async {
    let data = await fetchData()

    // Appeler sur le main thread
    await updateLabel(text: "Data loaded: \(data.count)")
}
```

### MainActor.run

Exécuter un bloc de code sur le main thread.

```swift
func processData() async {
    let data = await fetchData() // Background

    // Revenir au main thread
    await MainActor.run {
        // Code UI ici
        label.text = "Loaded \(data.count) bytes"
        activityIndicator.stopAnimating()
    }
}
```

## Patterns Courants avec Actors

### Cache Thread-Safe

```swift
actor Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private let maxSize: Int

    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    func get(_ key: Key) -> Value? {
        return storage[key]
    }

    func set(_ key: Key, value: Value) {
        // Éviction simple si trop de clés
        if storage.count >= maxSize {
            storage.removeFirst()
        }
        storage[key] = value
    }

    func clear() {
        storage.removeAll()
    }
}

// Usage
let cache = Cache<URL, Data>(maxSize: 50)
await cache.set(url, value: data)
let cached = await cache.get(url)
```

### Database Manager

```swift
actor DatabaseManager {
    private var connection: DatabaseConnection?
    private var transactionCount = 0

    func connect() async throws {
        guard connection == nil else { return }
        connection = try await DatabaseConnection.open()
    }

    func execute(query: String) async throws -> [Row] {
        guard let connection = connection else {
            throw DatabaseError.notConnected
        }
        return try await connection.execute(query)
    }

    func beginTransaction() async {
        transactionCount += 1
    }

    func commitTransaction() async throws {
        transactionCount -= 1
        if transactionCount == 0 {
            try await connection?.commit()
        }
    }
}
```

### Download Manager avec Progress

```swift
actor DownloadManager {
    private var activeDownloads: [URL: Task<Data, Error>] = [:]
    private var progress: [URL: Double] = [:]

    func download(from url: URL) async throws -> Data {
        // Vérifier si déjà en cours
        if let existing = activeDownloads[url] {
            return try await existing.value
        }

        // Créer nouvelle tâche
        let task = Task {
            try await performDownload(from: url)
        }

        activeDownloads[url] = task

        do {
            let data = try await task.value
            activeDownloads.removeValue(forKey: url)
            progress.removeValue(forKey: url)
            return data
        } catch {
            activeDownloads.removeValue(forKey: url)
            progress.removeValue(forKey: url)
            throw error
        }
    }

    func updateProgress(_ value: Double, for url: URL) {
        progress[url] = value
    }

    func getProgress(for url: URL) -> Double {
        return progress[url] ?? 0.0
    }

    func cancelDownload(for url: URL) {
        activeDownloads[url]?.cancel()
        activeDownloads.removeValue(forKey: url)
        progress.removeValue(forKey: url)
    }
}
```

### Event Logger

```swift
actor EventLogger {
    private var events: [Event] = []
    private let maxEvents: Int
    private var fileHandle: FileHandle?

    init(maxEvents: Int = 1000, logFile: URL? = nil) {
        self.maxEvents = maxEvents

        if let logFile = logFile {
            fileHandle = try? FileHandle(forWritingTo: logFile)
        }
    }

    func log(_ event: Event) {
        events.append(event)

        // Éviction des vieux events
        if events.count > maxEvents {
            events.removeFirst()
        }

        // Écrire dans le fichier
        if let fileHandle = fileHandle,
           let data = event.description.data(using: .utf8) {
            try? fileHandle.write(contentsOf: data)
        }
    }

    func getEvents(matching predicate: (Event) -> Bool) -> [Event] {
        return events.filter(predicate)
    }

    func clear() {
        events.removeAll()
    }
}
```

## Actor Reentrancy

Les actors peuvent être réentrants : pendant qu'une tâche attend (await), d'autres tâches peuvent accéder à l'actor.

### Problème de Reentrancy

```swift
actor BankAccount {
    var balance: Double = 1000

    func withdraw(amount: Double) async -> Bool {
        // Point de suspension 1
        await checkFraudDetection()

        // ⚠️ Balance pourrait avoir changé ici !
        guard balance >= amount else {
            return false
        }

        // Point de suspension 2
        await logTransaction(amount: amount)

        // ⚠️ Balance pourrait avoir changé ici aussi !
        balance -= amount
        return true
    }

    private func checkFraudDetection() async {
        // Simule vérification externe
    }

    private func logTransaction(amount: Double) async {
        // Log async
    }
}

// Problème : deux retraits concurrents
Task {
    let success = await account.withdraw(amount: 800)
    print("Withdraw 1: \(success)")
}

Task {
    let success = await account.withdraw(amount: 800)
    print("Withdraw 2: \(success)")
}

// Les deux pourraient réussir même avec balance = 1000 !
```

### Solution : Vérification Après Suspension

```swift
actor BankAccount {
    var balance: Double = 1000

    func withdraw(amount: Double) async -> Bool {
        // Vérifier AVANT suspension
        guard balance >= amount else {
            return false
        }

        let balanceBefore = balance

        await checkFraudDetection()

        // ✅ RE-vérifier après suspension
        guard balance == balanceBefore && balance >= amount else {
            return false
        }

        await logTransaction(amount: amount)

        // ✅ RE-vérifier encore
        guard balance == balanceBefore && balance >= amount else {
            return false
        }

        balance -= amount
        return true
    }
}
```

## Actors vs Classes vs Structs

| Caractéristique | Actor | Class | Struct |
|----------------|-------|-------|--------|
| **Type** | Référence | Référence | Valeur |
| **Thread Safety** | ✅ Oui | ❌ Non | ✅ Oui (valeur) |
| **Concurrence** | ✅ Concurrent safe | ❌ Data races | ✅ Pas de race (copie) |
| **Héritage** | ❌ Non | ✅ Oui | ❌ Non |
| **Accès** | async/await | Direct | Direct |
| **Performance** | Moyenne | Rapide | Rapide |

**Quand utiliser quoi :**

- **Actor** : État mutable partagé entre tâches concurrentes
- **Class** : État mutable, pas de concurrence ou MainActor
- **Struct** : Valeurs immuables, données simples

## Best Practices

### 1. Minimiser le nombre d'await dans les actors

```swift
// ❌ Trop de points de suspension
actor SlowProcessor {
    func process(items: [Item]) async {
        for item in items {
            await processOne(item) // ⚠️ Reentrancy à chaque itération
        }
    }
}

// ✅ Batch processing
actor FastProcessor {
    func process(items: [Item]) async {
        let results = await withTaskGroup(of: ProcessedItem.self) { group in
            // Traiter en parallèle
            for item in items {
                group.addTask {
                    await self.processOne(item)
                }
            }

            var processed: [ProcessedItem] = []
            for await result in group {
                processed.append(result)
            }
            return processed
        }

        // Un seul point de modification
        saveResults(results)
    }
}
```

### 2. Utiliser nonisolated quand possible

```swift
actor Configuration {
    private var settings: [String: Any]

    // ✅ Pas d'accès à l'état mutable = nonisolated
    nonisolated func validateKey(_ key: String) -> Bool {
        return key.count > 3
    }

    // ❌ Accès à settings = doit être isolé
    func getSetting(_ key: String) -> Any? {
        return settings[key]
    }
}
```

### 3. Éviter les deadlocks

```swift
// ❌ Deadlock potentiel
actor A {
    func callB(_ b: B) async {
        await b.callA(self) // Attend B qui attend A...
    }
}

actor B {
    func callA(_ a: A) async {
        await a.callB(self) // Attend A qui attend B...
    }
}

// ✅ Solution : éviter les dépendances circulaires
```

### 4. MainActor pour tout ce qui touche l'UI

```swift
// ✅ Bon
@MainActor
class ViewModel: ObservableObject {
    @Published var data: [Item] = []
}

// ❌ Mauvais - data races possibles
class ViewModel: ObservableObject {
    @Published var data: [Item] = []
}
```
