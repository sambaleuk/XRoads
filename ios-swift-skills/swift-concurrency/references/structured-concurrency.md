# Structured Concurrency - Task Groups et Patterns

Guide complet de la concurrence structurée avec Task Groups et patterns avancés.

## Qu'est-ce que la Structured Concurrency ?

La structured concurrency garantit que toutes les tâches enfants sont terminées (ou annulées) avant que la tâche parente ne se termine. Cela évite les tâches "orphelines" et simplifie la gestion des erreurs.

## TaskGroup - Groupes de Tâches

### withTaskGroup - Sans Erreurs

Exécuter plusieurs tâches en parallèle qui ne peuvent pas échouer (throwing).

```swift
func downloadImages(urls: [URL]) async -> [UIImage] {
    await withTaskGroup(of: UIImage?.self) { group in
        // Ajouter une tâche pour chaque URL
        for url in urls {
            group.addTask {
                return await self.downloadImage(from: url)
            }
        }

        // Collecter les résultats
        var images: [UIImage] = []
        for await image in group {
            if let image = image {
                images.append(image)
            }
        }
        return images
    }
}
```

### withThrowingTaskGroup - Avec Erreurs

Exécuter des tâches qui peuvent throw des erreurs.

```swift
func fetchMultipleResources() async throws -> [Resource] {
    try await withThrowingTaskGroup(of: Resource.self) { group in
        let urls = ["https://api.example.com/resource1",
                    "https://api.example.com/resource2",
                    "https://api.example.com/resource3"]

        for url in urls {
            group.addTask {
                try await self.fetchResource(from: URL(string: url)!)
            }
        }

        // Collecter tous les résultats
        var resources: [Resource] = []
        for try await resource in group {
            resources.append(resource)
        }
        return resources
    }
}

// Si une tâche throw, toutes les autres sont annulées
```

## Patterns de TaskGroup

### Pattern 1: Map Parallèle

Transformer un array en parallèle.

```swift
func processImagesParallel(_ images: [UIImage]) async -> [ProcessedImage] {
    await withTaskGroup(of: (Int, ProcessedImage).self) { group in
        // Ajouter index pour préserver l'ordre
        for (index, image) in images.enumerated() {
            group.addTask {
                let processed = await self.processImage(image)
                return (index, processed)
            }
        }

        // Collecter avec ordre préservé
        var results = [(Int, ProcessedImage)]()
        for await (index, processed) in group {
            results.append((index, processed))
        }

        // Trier par index et retourner
        return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
    }
}
```

### Pattern 2: Premiers N Résultats

Obtenir les premiers résultats disponibles.

```swift
func fetchFastestServers(count: Int) async throws -> [Server] {
    try await withThrowingTaskGroup(of: Server.self) { group in
        // Lancer requêtes vers tous les serveurs
        for serverURL in allServerURLs {
            group.addTask {
                try await self.fetchServer(from: serverURL)
            }
        }

        // Prendre les N premiers qui répondent
        var servers: [Server] = []
        for try await server in group {
            servers.append(server)

            if servers.count == count {
                group.cancelAll() // Annuler les autres
                break
            }
        }

        return servers
    }
}
```

### Pattern 3: Racing (Premier Résultat)

Prendre le premier résultat disponible et annuler les autres.

```swift
func fetchFromFastestSource<T>(
    sources: [() async throws -> T]
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        for source in sources {
            group.addTask {
                try await source()
            }
        }

        // Attendre le premier résultat
        let result = try await group.next()!

        // Annuler toutes les autres tâches
        group.cancelAll()

        return result
    }
}

// Usage
let data = try await fetchFromFastestSource(sources: [
    { try await self.fetchFromServer1() },
    { try await self.fetchFromServer2() },
    { try await self.fetchFromServer3() }
])
```

### Pattern 4: Batch Processing

Traiter des items par batches pour limiter la concurrence.

```swift
func processBatches<T, R>(
    items: [T],
    batchSize: Int,
    transform: @escaping (T) async throws -> R
) async throws -> [R] {
    var results: [R] = []

    // Découper en batches
    let batches = stride(from: 0, to: items.count, by: batchSize).map {
        Array(items[$0..<min($0 + batchSize, items.count)])
    }

    // Traiter chaque batch
    for batch in batches {
        let batchResults = try await withThrowingTaskGroup(of: R.self) { group in
            for item in batch {
                group.addTask {
                    try await transform(item)
                }
            }

            var collected: [R] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }

        results.append(contentsOf: batchResults)
    }

    return results
}

// Usage : traiter 100 images par batch de 10
let processed = try await processBatches(
    items: images,
    batchSize: 10
) { image in
    await processImage(image)
}
```

### Pattern 5: Progress Tracking

Suivre la progression d'un groupe de tâches.

```swift
actor ProgressTracker {
    private(set) var completed = 0
    private(set) var total = 0

    func setTotal(_ count: Int) {
        total = count
    }

    func increment() {
        completed += 1
    }

    func progress() -> Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

func downloadWithProgress(urls: [URL]) async -> [Data] {
    let tracker = ProgressTracker()
    await tracker.setTotal(urls.count)

    return await withTaskGroup(of: (Int, Data?).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let data = try? await URLSession.shared.data(from: url).0

                await tracker.increment()

                let progress = await tracker.progress()
                print("Progress: \(Int(progress * 100))%")

                return (index, data)
            }
        }

        var results: [(Int, Data?)] = []
        for await result in group {
            results.append(result)
        }

        return results
            .sorted(by: { $0.0 < $1.0 })
            .compactMap { $0.1 }
    }
}
```

## Task Priorities

Contrôler la priorité d'exécution des tâches.

### Niveaux de Priorité

```swift
// Priorités disponibles (du plus haut au plus bas)
Task(priority: .high) { }
Task(priority: .medium) { }  // Défaut
Task(priority: .low) { }
Task(priority: .background) { }
Task(priority: .userInitiated) { }
Task(priority: .utility) { }
```

### Utilisation avec TaskGroup

```swift
func fetchData() async {
    await withTaskGroup(of: Void.self) { group in
        // Tâche prioritaire
        group.addTask(priority: .high) {
            await self.fetchCriticalData()
        }

        // Tâches normales
        group.addTask(priority: .medium) {
            await self.fetchRegularData()
        }

        // Tâches en background
        group.addTask(priority: .background) {
            await self.fetchOptionalData()
        }
    }
}
```

### Héritage de Priorité

```swift
func parentTask() async {
    // Cette tâche hérite de la priorité du parent
    Task {
        await childWork() // Même priorité que parent
    }
}

// Override la priorité
Task(priority: .high) {
    Task(priority: .low) {
        await backgroundWork() // .low, pas .high
    }
}
```

## Annulation Structurée

### Propagation d'Annulation

```swift
func downloadFiles(urls: [URL]) async throws -> [Data] {
    try await withThrowingTaskGroup(of: Data.self) { group in
        for url in urls {
            group.addTask {
                try await self.downloadFile(from: url)
            }
        }

        var files: [Data] = []
        for try await file in group {
            files.append(file)
        }
        return files
    }
}

// L'annulation se propage automatiquement
let task = Task {
    try await downloadFiles(urls: urls)
}

// Annuler la tâche parente annule toutes les enfants
task.cancel()
```

### Vérifier l'Annulation

```swift
func longRunningTask() async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for i in 1...100 {
            group.addTask {
                // Vérifier l'annulation
                try Task.checkCancellation()

                // Ou
                if Task.isCancelled {
                    return
                }

                await self.processItem(i)
            }
        }

        // Attendre toutes les tâches
        try await group.waitForAll()
    }
}
```

## Patterns Avancés

### Pattern: Timeout avec TaskGroup

```swift
enum TimeoutError: Error {
    case timedOut
}

func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Tâche principale
        group.addTask {
            try await operation()
        }

        // Tâche timeout
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timedOut
        }

        // Premier résultat gagne
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// Usage
do {
    let data = try await withTimeout(seconds: 5) {
        try await fetchData()
    }
} catch TimeoutError.timedOut {
    print("Operation timed out")
}
```

### Pattern: Retry avec Backoff Exponentiel

```swift
func withExponentialBackoff<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    var delay = initialDelay
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            print("Attempt \(attempt) failed: \(error)")

            if attempt < maxAttempts {
                // Backoff exponentiel
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2
            }
        }
    }

    throw lastError!
}

// Usage
let data = try await withExponentialBackoff(maxAttempts: 5) {
    try await fetchData(from: url)
}
```

### Pattern: Circuit Breaker

```swift
actor CircuitBreaker {
    enum State {
        case closed  // Fonctionnement normal
        case open    // Échecs répétés, bloquer les requêtes
        case halfOpen // Test si service récupéré
    }

    private var state: State = .closed
    private var failureCount = 0
    private let threshold: Int
    private let timeout: TimeInterval
    private var lastFailureTime: Date?

    init(threshold: Int = 5, timeout: TimeInterval = 60) {
        self.threshold = threshold
        self.timeout = timeout
    }

    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        switch state {
        case .open:
            // Vérifier si timeout écoulé
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                state = .halfOpen
            } else {
                throw CircuitBreakerError.open
            }

        case .halfOpen:
            // Tester une requête
            do {
                let result = try await operation()
                state = .closed
                failureCount = 0
                return result
            } catch {
                state = .open
                lastFailureTime = Date()
                throw error
            }

        case .closed:
            break
        }

        // État closed : exécuter normalement
        do {
            let result = try await operation()
            failureCount = 0
            return result
        } catch {
            failureCount += 1
            if failureCount >= threshold {
                state = .open
                lastFailureTime = Date()
            }
            throw error
        }
    }
}

// Usage
let breaker = CircuitBreaker(threshold: 3, timeout: 30)

for _ in 1...10 {
    do {
        let data = try await breaker.execute {
            try await fetchData(from: url)
        }
        print("Success: \(data)")
    } catch {
        print("Failed: \(error)")
    }
    try? await Task.sleep(nanoseconds: 1_000_000_000)
}
```

### Pattern: Fan-out / Fan-in

Diviser le travail, traiter en parallèle, puis combiner.

```swift
func fanOutFanIn<Input, Output>(
    inputs: [Input],
    transform: @escaping (Input) async throws -> Output,
    combine: @escaping ([Output]) -> Output
) async throws -> Output {
    // Fan-out : distribuer le travail
    let outputs = try await withThrowingTaskGroup(of: (Int, Output).self) { group in
        for (index, input) in inputs.enumerated() {
            group.addTask {
                let output = try await transform(input)
                return (index, output)
            }
        }

        var results: [(Int, Output)] = []
        for try await result in group {
            results.append(result)
        }

        // Préserver l'ordre
        return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
    }

    // Fan-in : combiner les résultats
    return combine(outputs)
}

// Usage : traiter des chunks en parallèle
let result = try await fanOutFanIn(
    inputs: dataChunks,
    transform: { chunk in
        await processChunk(chunk)
    },
    combine: { processedChunks in
        processedChunks.reduce(into: ProcessedData()) { $0.merge($1) }
    }
)
```

## TaskGroup vs async let

### Quand utiliser TaskGroup

- Nombre de tâches dynamique (déterminé à runtime)
- Besoin de contrôle fin (priorités, annulation)
- Collection de résultats avec traitement
- Patterns avancés (timeout, racing, etc.)

```swift
// ✅ TaskGroup : nombre dynamique
func downloadImages(urls: [URL]) async -> [UIImage] {
    await withTaskGroup(of: UIImage?.self) { group in
        for url in urls { // Nombre variable
            group.addTask {
                await downloadImage(from: url)
            }
        }

        var images: [UIImage] = []
        for await image in group {
            if let image = image {
                images.append(image)
            }
        }
        return images
    }
}
```

### Quand utiliser async let

- Nombre de tâches fixe (connu au compile-time)
- Code simple et direct
- Pas besoin de traitement intermédiaire

```swift
// ✅ async let : nombre fixe
func loadUserProfile() async throws -> UserProfile {
    async let user = fetchUser()
    async let posts = fetchPosts()
    async let followers = fetchFollowers()

    return try await UserProfile(
        user: user,
        posts: posts,
        followers: followers
    )
}
```

## Best Practices

### 1. Limiter la concurrence

```swift
// ❌ Mauvais : peut créer des milliers de tâches
await withTaskGroup(of: Void.self) { group in
    for item in hugeArray { // 10,000 items
        group.addTask {
            await process(item)
        }
    }
}

// ✅ Bon : batching
for batch in hugeArray.chunked(into: 100) {
    await withTaskGroup(of: Void.self) { group in
        for item in batch {
            group.addTask {
                await process(item)
            }
        }
    }
}
```

### 2. Gérer les erreurs proprement

```swift
// ✅ Collecter erreurs et succès
func fetchAllSafely() async -> (successes: [Data], failures: [Error]) {
    await withTaskGroup(of: Result<Data, Error>.self) { group in
        for url in urls {
            group.addTask {
                do {
                    let data = try await fetchData(from: url)
                    return .success(data)
                } catch {
                    return .failure(error)
                }
            }
        }

        var successes: [Data] = []
        var failures: [Error] = []

        for await result in group {
            switch result {
            case .success(let data):
                successes.append(data)
            case .failure(let error):
                failures.append(error)
            }
        }

        return (successes, failures)
    }
}
```

### 3. Toujours vérifier l'annulation

```swift
func longProcess() async {
    await withTaskGroup(of: Void.self) { group in
        for i in 1...1000 {
            group.addTask {
                // ✅ Vérifier régulièrement
                guard !Task.isCancelled else {
                    return
                }

                await doWork(i)
            }
        }
    }
}
```

### 4. Utiliser des priorités appropriées

```swift
// ✅ Bon usage des priorités
await withTaskGroup(of: Void.self) { group in
    // UI critique
    group.addTask(priority: .userInitiated) {
        await loadVisibleContent()
    }

    // Données auxiliaires
    group.addTask(priority: .utility) {
        await prefetchNextPage()
    }

    // Analytics
    group.addTask(priority: .background) {
        await sendAnalytics()
    }
}
```
