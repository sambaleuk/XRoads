# async/await - Programmation Asynchrone Moderne

Guide complet de la programmation asynchrone avec async/await en Swift.

## Introduction

async/await simplifie le code asynchrone en le rendant aussi lisible que du code synchrone, tout en évitant le "callback hell" et la complexité des closures imbriquées.

## Fonctions Asynchrones (async)

### Déclaration de fonctions async

```swift
// Fonction asynchrone qui retourne une valeur
func fetchUserData() async -> User {
    // Simulation d'un appel réseau
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
    return User(name: "Alice", age: 30)
}

// Fonction asynchrone qui peut throw
func fetchData(from url: URL) async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}

// Fonction asynchrone sans retour
func saveData(_ data: Data) async {
    // Sauvegarde asynchrone
}
```

### Appeler des fonctions async avec await

```swift
// Dans une autre fonction async
func loadUser() async {
    let user = await fetchUserData()
    print("Loaded user: \(user.name)")
}

// Avec gestion d'erreurs
func loadDataSafely() async {
    do {
        let url = URL(string: "https://api.example.com/data")!
        let data = try await fetchData(from: url)
        print("Received \(data.count) bytes")
    } catch {
        print("Error: \(error)")
    }
}
```

## Lancer du Code Asynchrone

### Task - Créer une nouvelle tâche asynchrone

```swift
// Dans du code synchrone (comme viewDidLoad)
func viewDidLoad() {
    Task {
        let user = await fetchUserData()
        print("User loaded: \(user.name)")
    }
}

// Task avec gestion d'erreurs
Task {
    do {
        let data = try await fetchData(from: url)
        processData(data)
    } catch {
        handleError(error)
    }
}

// Task détaché (non lié au contexte parent)
Task.detached {
    let result = await heavyComputation()
    print("Result: \(result)")
}
```

### Task avec valeur de retour

```swift
let task = Task {
    return await fetchUserData()
}

// Récupérer le résultat plus tard
let user = await task.value
```

### Annulation de Task

```swift
let task = Task {
    for i in 1...10 {
        // Vérifier l'annulation
        if Task.isCancelled {
            print("Task cancelled")
            return
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        print("Step \(i)")
    }
}

// Annuler la task
task.cancel()
```

## Concurrence avec async let

Exécuter plusieurs opérations asynchrones en parallèle.

```swift
func loadMultipleResources() async throws {
    // Lancer les 3 requêtes en parallèle
    async let users = fetchUsers()
    async let posts = fetchPosts()
    async let comments = fetchComments()

    // Attendre tous les résultats
    let (usersList, postsList, commentsList) = try await (users, posts, comments)

    print("Loaded \(usersList.count) users, \(postsList.count) posts")
}

// Exemple avec URLSession
func downloadMultipleImages() async throws {
    let urls = [
        URL(string: "https://example.com/image1.jpg")!,
        URL(string: "https://example.com/image2.jpg")!,
        URL(string: "https://example.com/image3.jpg")!
    ]

    // Télécharger en parallèle
    async let image1 = URLSession.shared.data(from: urls[0])
    async let image2 = URLSession.shared.data(from: urls[1])
    async let image3 = URLSession.shared.data(from: urls[2])

    // Attendre tous les téléchargements
    let (data1, data2, data3) = try await (image1, image2, image3)

    // Traiter les images...
}
```

## Continuations - Pont entre async et callbacks

Convertir du code basé sur callbacks en async/await.

### withCheckedContinuation

```swift
// API legacy avec callback
func fetchDataOldStyle(completion: @escaping (Result<Data, Error>) -> Void) {
    // ...
}

// Convertir en async/await
func fetchDataAsync() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        fetchDataOldStyle { result in
            switch result {
            case .success(let data):
                continuation.resume(returning: data)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### Exemple avec URLSession (ancien style)

```swift
// Avant: callback hell
func loadUser(completion: @escaping (User?) -> Void) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data else {
            completion(nil)
            return
        }

        let user = try? JSONDecoder().decode(User.self, from: data)
        completion(user)
    }.resume()
}

// Après: async/await
func loadUser() async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    let user = try JSONDecoder().decode(User.self, from: data)
    return user
}
```

## AsyncSequence - Séquences Asynchrones

Traiter des flux de données asynchrones.

```swift
// Créer une AsyncSequence
func generateNumbers() -> AsyncStream<Int> {
    AsyncStream { continuation in
        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
                continuation.yield(i)
            }
            continuation.finish()
        }
    }
}

// Consommer une AsyncSequence
func processNumbers() async {
    for await number in generateNumbers() {
        print("Received: \(number)")
    }
    print("Stream finished")
}
```

### AsyncSequence avec URLSession

```swift
// Télécharger avec progression
func downloadFile(from url: URL) async throws {
    let (bytes, response) = try await URLSession.shared.bytes(from: url)

    var data = Data()
    for try await byte in bytes {
        data.append(byte)

        // Mettre à jour la progression
        if data.count % 1024 == 0 {
            print("Downloaded \(data.count) bytes")
        }
    }
}
```

## MainActor - Code sur le Thread Principal

Garantir l'exécution sur le thread principal (UI).

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var users: [User] = []

    // Automatiquement exécuté sur le main thread
    func loadUsers() async {
        let users = await fetchUsers()
        self.users = users // ✅ Safe pour UI
    }
}

// Fonction isolée au main actor
@MainActor
func updateUI() {
    // Ce code s'exécute sur le main thread
    label.text = "Updated"
}

// Forcer l'exécution sur MainActor
func backgroundWork() async {
    let data = await fetchData()

    // Revenir au main thread pour la UI
    await MainActor.run {
        updateLabel(with: data)
    }
}
```

## Patterns Courants

### Retry avec async/await

```swift
func fetchWithRetry<T>(
    maxAttempts: Int = 3,
    delay: UInt64 = 1_000_000_000,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            print("Attempt \(attempt) failed: \(error)")

            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }

    throw lastError ?? NSError(domain: "RetryFailed", code: -1)
}

// Usage
let data = try await fetchWithRetry {
    try await fetchData(from: url)
}
```

### Timeout

```swift
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Lancer l'opération
        group.addTask {
            try await operation()
        }

        // Lancer le timeout
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        // Retourner le premier résultat
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// Usage
do {
    let data = try await withTimeout(seconds: 5) {
        try await fetchData(from: url)
    }
} catch is TimeoutError {
    print("Operation timed out")
}
```

### Cache avec async/await

```swift
actor Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]

    func get(_ key: Key) -> Value? {
        storage[key]
    }

    func set(_ key: Key, value: Value) {
        storage[key] = value
    }
}

class DataLoader {
    private let cache = Cache<URL, Data>()

    func loadData(from url: URL) async throws -> Data {
        // Vérifier le cache
        if let cached = await cache.get(url) {
            return cached
        }

        // Télécharger
        let (data, _) = try await URLSession.shared.data(from: url)

        // Mettre en cache
        await cache.set(url, value: data)

        return data
    }
}
```

## Migration de Closures vers async/await

### Avant (Closures)

```swift
func loadUserData(completion: @escaping (Result<User, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }

        do {
            let user = try JSONDecoder().decode(User.self, from: data)
            completion(.success(user))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}

// Callback hell
loadUserData { result in
    switch result {
    case .success(let user):
        loadUserPosts(user.id) { postsResult in
            switch postsResult {
            case .success(let posts):
                // Plus de nesting...
                print("Loaded \(posts.count) posts")
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Après (async/await)

```swift
func loadUserData() async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    let user = try JSONDecoder().decode(User.self, from: data)
    return user
}

// Code linéaire et lisible
do {
    let user = try await loadUserData()
    let posts = try await loadUserPosts(user.id)
    print("Loaded \(posts.count) posts")
} catch {
    print("Error: \(error)")
}
```

## Erreurs Communes et Solutions

### ❌ Appeler async depuis sync sans Task

```swift
// ❌ Erreur: 'async' call in a function that does not support concurrency
func viewDidLoad() {
    let user = await fetchUser() // ❌
}
```

**✅ Solution:**
```swift
func viewDidLoad() {
    Task {
        let user = await fetchUser() // ✅
        print(user)
    }
}
```

### ❌ Oublier await

```swift
// ❌ Erreur: Expression is 'async' but is not marked with 'await'
func loadData() async {
    let data = fetchData() // ❌
}
```

**✅ Solution:**
```swift
func loadData() async {
    let data = await fetchData() // ✅
}
```

### ❌ Accès UI depuis background thread

```swift
// ❌ Peut causer des crashes
func loadData() async {
    let data = await fetchData()
    label.text = String(data.count) // ❌ Background thread!
}
```

**✅ Solution:**
```swift
@MainActor
func loadData() async {
    let data = await fetchData()
    label.text = String(data.count) // ✅ Main thread
}

// Ou
func loadData() async {
    let data = await fetchData()
    await MainActor.run {
        label.text = String(data.count) // ✅
    }
}
```

## Best Practices

### 1. Préférer async/await aux closures
```swift
// ❌ Ancien style
func fetchData(completion: @escaping (Data?) -> Void)

// ✅ Nouveau style
func fetchData() async -> Data
```

### 2. Utiliser async let pour parallélisme
```swift
// ❌ Séquentiel (lent)
let users = await fetchUsers()
let posts = await fetchPosts()

// ✅ Parallèle (rapide)
async let users = fetchUsers()
async let posts = fetchPosts()
let (usersList, postsList) = await (users, posts)
```

### 3. Gérer l'annulation
```swift
func longRunningTask() async {
    for i in 1...100 {
        if Task.isCancelled {
            return // ✅ Arrêter proprement
        }
        await doWork(i)
    }
}
```

### 4. Utiliser @MainActor pour la UI
```swift
@MainActor
class ViewModel {
    func updateUI() {
        // Toujours sur le main thread
    }
}
```

### 5. Éviter les data races avec actors
```swift
// ❌ Data race possible
class Counter {
    var value = 0
    func increment() { value += 1 }
}

// ✅ Thread-safe avec actor
actor Counter {
    var value = 0
    func increment() { value += 1 }
}
```
