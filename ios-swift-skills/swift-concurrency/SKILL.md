---
name: swift-concurrency
description: Modern Swift concurrency with async/await, actors, and structured concurrency (Task, TaskGroup, MainActor). Use when writing asynchronous code, handling concurrent operations, preventing data races, or managing background tasks. Covers async functions, actors for thread safety, Task groups for parallel execution, cancellation, priorities, and async sequences. Essential for network calls, database operations, and responsive UIs.
---

# Swift Concurrency - async/await & Actors

Master modern Swift concurrency for writing safe, performant asynchronous code.

## Quick Start

### New to async/await?
1. Read [async-await.md](references/async-await.md) for core async/await concepts
2. Read [actors.md](references/actors.md) to understand thread-safe actors
3. Read [structured-concurrency.md](references/structured-concurrency.md) for TaskGroups

### Common Tasks

**Generate async code:**
```bash
# API Client
python3 scripts/generate_async_code.py --type api-client --name UserAPI

# Thread-safe Actor
python3 scripts/generate_async_code.py --type actor --name DataStore

# MainActor ViewModel
python3 scripts/generate_async_code.py --type viewmodel --name UserViewModel
```

**Use the networking template:**
Copy `assets/async-networking-template.swift` for a complete async API client with cache, error handling, and SwiftUI integration.

## When to Use This Skill

Trigger this skill when:
- Writing asynchronous code (network, database, file I/O)
- Converting callback-based code to async/await
- Preventing data races in concurrent code
- Using actors for thread safety
- Managing parallel operations with TaskGroups
- Questions about MainActor, Task, or concurrency
- Building responsive UIs with async operations

## Core Concepts Overview

### 1. async/await - Asynchronous Functions

async/await simplifies asynchronous code by making it read like synchronous code.

**Before (Callbacks):**
```swift
func loadUser(completion: @escaping (User?) -> Void) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        // Callback hell...
        guard let data = data else {
            completion(nil)
            return
        }
        let user = try? JSONDecoder().decode(User.self, from: data)
        completion(user)
    }.resume()
}
```

**After (async/await):**
```swift
func loadUser() async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// Usage
let user = try await loadUser()
```

### 2. Task - Launch Async Work

```swift
// From synchronous context (e.g., viewDidLoad)
Task {
    let data = await fetchData()
    print("Data loaded: \(data)")
}

// Task with cancellation
let task = Task {
    for i in 1...100 {
        if Task.isCancelled { return }
        await doWork(i)
    }
}

// Cancel later
task.cancel()
```

### 3. Actors - Thread-Safe Types

Actors protect mutable state from data races automatically.

**Problem with Classes:**
```swift
// ❌ Data race possible!
class Counter {
    var value = 0
    func increment() { value += 1 }
}
```

**Solution with Actors:**
```swift
// ✅ Thread-safe automatically
actor Counter {
    var value = 0
    func increment() { value += 1 }
}

// Usage (requires await)
let counter = Counter()
await counter.increment()
```

### 4. MainActor - UI Thread Safety

Guarantee code runs on the main thread (required for UI updates).

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var users: [User] = []

    func loadUsers() async {
        let users = await fetchUsers()
        self.users = users // ✅ Safe - automatically on main thread
    }
}
```

### 5. async let - Parallel Execution

Run multiple async operations in parallel.

```swift
// ❌ Sequential (slow)
let users = await fetchUsers()
let posts = await fetchPosts()

// ✅ Parallel (fast)
async let users = fetchUsers()
async let posts = fetchPosts()
let (usersList, postsList) = await (users, posts)
```

### 6. TaskGroup - Dynamic Parallel Execution

For dynamic number of concurrent operations.

```swift
func downloadImages(urls: [URL]) async -> [UIImage] {
    await withTaskGroup(of: UIImage?.self) { group in
        for url in urls {
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

## Common Patterns

### Pattern: API Client with Actor

```swift
actor APIClient {
    private let baseURL: String
    private let session: URLSession

    init(baseURL: String) {
        self.baseURL = baseURL
        self.session = .shared
    }

    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// Usage
let client = APIClient(baseURL: "https://api.example.com")
let users: [User] = try await client.fetch("/users")
```

### Pattern: Retry with Exponential Backoff

```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    operation: () async throws -> T
) async throws -> T {
    var delay: UInt64 = 1_000_000_000 // 1 second

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: delay)
                delay *= 2 // Exponential backoff
            } else {
                throw error
            }
        }
    }

    fatalError("Should not reach here")
}

// Usage
let data = try await withRetry {
    try await fetchData(from: url)
}
```

### Pattern: Timeout

```swift
func withTimeout<T>(
    seconds: TimeInterval,
    operation: () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Operation
        group.addTask {
            try await operation()
        }

        // Timeout
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timedOut
        }

        // First to finish wins
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

### Pattern: Cache with Actor

```swift
actor Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]

    func get(_ key: Key) -> Value? {
        storage[key]
    }

    func set(_ key: Key, value: Value) {
        storage[key] = value
    }

    func clear() {
        storage.removeAll()
    }
}

// Usage
let cache = Cache<URL, Data>()
await cache.set(url, value: data)
let cached = await cache.get(url)
```

### Pattern: Progress Tracking

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

// Usage in TaskGroup
func processWithProgress(items: [Item]) async {
    let tracker = ProgressTracker()
    await tracker.setTotal(items.count)

    await withTaskGroup(of: Void.self) { group in
        for item in items {
            group.addTask {
                await process(item)
                await tracker.increment()

                let progress = await tracker.progress()
                print("Progress: \(Int(progress * 100))%")
            }
        }
    }
}
```

## Resources

### references/
- **async-await.md** - Complete async/await guide (async functions, Task, async let, continuations, AsyncSequence, MainActor, error handling, migration from closures)
- **actors.md** - Thread-safe actors (actor declaration, isolation, MainActor, patterns, reentrancy, actors vs classes/structs, best practices)
- **structured-concurrency.md** - TaskGroups and structured concurrency (TaskGroup patterns, priorities, cancellation, advanced patterns like timeout/retry/circuit breaker, fan-out/fan-in)

Read these files when you need detailed information about specific concurrency features.

### scripts/
- **generate_async_code.py** - Generate async Swift code (API clients, actors, TaskGroups, ViewModels)

Example:
```bash
# Generate API Client
python3 scripts/generate_async_code.py --type api-client --name UserAPI

# Generate Actor
python3 scripts/generate_async_code.py --type actor --name DataStore

# Generate TaskGroup function
python3 scripts/generate_async_code.py --type task-group --name processImages

# Generate MainActor ViewModel
python3 scripts/generate_async_code.py --type viewmodel --name UserViewModel
```

### assets/
- **async-networking-template.swift** - Complete async API client template with actor-based cache, error handling, retry logic, TaskGroup batch operations, MainActor ViewModel, and SwiftUI integration. Copy and customize for your projects.

## Migration from Closures

### Closure-Based Code
```swift
func loadData(completion: @escaping (Result<Data, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }

        completion(.success(data))
    }.resume()
}
```

### async/await Version
```swift
func loadData() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

## Common Mistakes & Solutions

### ❌ Calling async without await
```swift
func loadData() async {
    let data = fetchData() // ❌ Error
}
```

**✅ Solution:**
```swift
func loadData() async {
    let data = await fetchData() // ✅
}
```

### ❌ Calling async from sync without Task
```swift
func viewDidLoad() {
    let data = await fetchData() // ❌ Error
}
```

**✅ Solution:**
```swift
func viewDidLoad() {
    Task {
        let data = await fetchData() // ✅
    }
}
```

### ❌ UI updates on background thread
```swift
func loadData() async {
    let data = await fetchData()
    label.text = String(data.count) // ❌ Can crash!
}
```

**✅ Solution:**
```swift
@MainActor
func loadData() async {
    let data = await fetchData()
    label.text = String(data.count) // ✅ On main thread
}

// Or use MainActor.run
func loadData() async {
    let data = await fetchData()
    await MainActor.run {
        label.text = String(data.count) // ✅
    }
}
```

### ❌ Data race with class
```swift
class Counter {
    var value = 0 // ❌ Not thread-safe
}
```

**✅ Solution:**
```swift
actor Counter {
    var value = 0 // ✅ Thread-safe
}
```

## Best Practices

### 1. Use async/await over closures
```swift
// ❌ Old way
func fetchData(completion: @escaping (Data?) -> Void)

// ✅ Modern way
func fetchData() async -> Data
```

### 2. Use actors for mutable shared state
```swift
// ✅ Actor for shared mutable state
actor Database {
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        cache[key]
    }

    func set(_ key: String, value: Data) {
        cache[key] = value
    }
}
```

### 3. Use @MainActor for UI code
```swift
@MainActor
class ViewModel: ObservableObject {
    // All properties and methods automatically on main thread
}
```

### 4. Use async let for known parallelism
```swift
// ✅ Fixed number of operations
async let users = fetchUsers()
async let posts = fetchPosts()
let (u, p) = await (users, posts)
```

### 5. Use TaskGroup for dynamic parallelism
```swift
// ✅ Variable number of operations
await withTaskGroup(of: Image.self) { group in
    for url in urls { // Dynamic count
        group.addTask {
            await download(from: url)
        }
    }
}
```

### 6. Check for cancellation in long operations
```swift
func longProcess() async {
    for i in 1...1000 {
        if Task.isCancelled { return } // ✅ Check regularly
        await doWork(i)
    }
}
```

### 7. Avoid actor reentrancy issues
```swift
actor BankAccount {
    var balance = 1000.0

    func withdraw(amount: Double) async -> Bool {
        let balanceBefore = balance

        await checkFraudDetection()

        // ✅ Re-check after suspension
        guard balance == balanceBefore else {
            return false
        }

        balance -= amount
        return true
    }
}
```

## Next Steps

After mastering Swift concurrency:
1. **memory-management** - ARC, retain cycles with async code
2. **swiftui** - Integrate async operations with SwiftUI
3. **networking** - Advanced networking patterns with async/await
4. **core-data** - Async database operations

## Learning Path

1. **Start with async/await** - Understand basic async functions and Task
2. **Learn actors** - Thread-safe types for concurrent access
3. **Master MainActor** - UI thread safety
4. **Explore TaskGroups** - Parallel execution patterns
5. **Advanced patterns** - Retry, timeout, progress tracking
6. **Integration** - Combine with SwiftUI and networking

## Key Takeaways

✅ **async/await** makes asynchronous code readable
✅ **Actors** prevent data races automatically
✅ **MainActor** guarantees UI thread execution
✅ **Task** bridges sync and async code
✅ **async let** runs operations in parallel (fixed count)
✅ **TaskGroup** runs operations in parallel (dynamic count)
✅ **Structured concurrency** ensures all tasks complete or cancel
✅ **Cancellation** propagates automatically through task hierarchy
