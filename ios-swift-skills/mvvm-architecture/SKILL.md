---
name: mvvm-architecture
description: MVVM (Model-View-ViewModel) architecture pattern for SwiftUI apps. Use when building SwiftUI applications with proper separation of concerns, managing app state with ObservableObject, implementing ViewModels with @MainActor for thread safety, dependency injection, and testable code. Essential for scalable, maintainable iOS/macOS apps.
---

# MVVM Architecture - Building Scalable SwiftUI Apps

Master the MVVM pattern for creating well-structured, testable SwiftUI applications.

## Quick Start

### New to MVVM?
1. Read [mvvm-essentials.md](references/mvvm-essentials.md) for complete MVVM guide
2. Understand the @MainActor requirement for ViewModels
3. Review Maestro-specific patterns (multi-session management, event bus)

### Basic ViewModel

```swift
@MainActor
class SessionsViewModel: ObservableObject {
    // State - UI updates automatically when these change
    @Published var sessions: [Session] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Dependencies
    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
    }

    // Actions from View
    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await sessionService.fetchSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### View Integration

```swift
struct SessionsView: View {
    @ObservedObject var viewModel: SessionsViewModel

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                List(viewModel.sessions) { session in
                    SessionRow(session: session)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .task {
            await viewModel.loadSessions()
        }
    }
}
```

## When to Use This Skill

Trigger this skill when:
- Building SwiftUI applications with proper architecture
- Separating UI logic from business logic
- Managing application state with @Published properties
- Creating testable ViewModels
- Implementing dependency injection
- Questions about ObservableObject, @MainActor, @StateObject, @ObservedObject
- Building complex apps like Maestro with multiple features

## Core Concepts

### 1. MVVM Components

```
┌─────────┐      ┌──────────────┐      ┌───────┐
│  View   │◄─────│  ViewModel   │◄─────│ Model │
│ SwiftUI │      │ @MainActor   │      │ Data  │
└─────────┘      └──────────────┘      └───────┘
```

- **Model**: Data structures and business logic
- **View**: SwiftUI views (UI only, no logic)
- **ViewModel**: Mediates between View and Model, manages state

### 2. @MainActor - Thread Safety

All ViewModels MUST be marked with `@MainActor` to ensure UI updates happen on the main thread.

```swift
// ✅ Always use @MainActor
@MainActor
class ViewModel: ObservableObject {
    @Published var data: [Item] = []

    func updateData() async {
        // Even if this fetches from background thread,
        // assignment to @Published always happens on main thread
        data = await fetchData()
    }
}
```

### 3. @Published - Automatic UI Updates

Properties marked `@Published` automatically trigger View updates when changed.

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var count = 0        // View updates when count changes
    @Published var items: [Item] = [] // View updates when items changes
    @Published var isLoading = false  // View updates when isLoading changes
}
```

### 4. Dependency Injection

Inject dependencies (services, managers) through the initializer for testability.

```swift
protocol SessionService {
    func fetchSessions() async throws -> [Session]
}

@MainActor
class ViewModel: ObservableObject {
    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
    }
}

// Easy to test with mock services
let mockService = MockSessionService()
let viewModel = ViewModel(sessionService: mockService)
```

## Common Patterns for Maestro-like Apps

### Pattern 1: Multi-Session Management

```swift
@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var selectedSession: Session?
    @Published var isCreatingSession = false
    @Published var errorMessage: String?

    private let sessionService: SessionService
    private let processManager: ProcessManager
    private let gitService: GitService

    init(
        sessionService: SessionService,
        processManager: ProcessManager,
        gitService: GitService
    ) {
        self.sessionService = sessionService
        self.processManager = processManager
        self.gitService = gitService
    }

    func createSession(name: String, repoPath: String) async {
        isCreatingSession = true
        defer { isCreatingSession = false }

        do {
            // Create git worktree
            let worktreePath = try await gitService.createWorktree(
                repoPath: repoPath,
                branch: "session-\(name)"
            )

            // Launch Claude Code
            let processId = try await processManager.launch(
                executable: "/usr/local/bin/claude",
                arguments: ["code", "--cwd", worktreePath]
            )

            let session = Session(
                id: UUID(),
                name: name,
                worktreePath: worktreePath,
                processId: processId,
                status: .running
            )

            sessions.append(session)
            selectedSession = session

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopSession(_ session: Session) async {
        await processManager.terminate(id: session.processId)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].status = .stopped
        }
    }
}
```

### Pattern 2: Session Detail with Terminal Output

```swift
@MainActor
class SessionDetailViewModel: ObservableObject {
    @Published var output: String = ""
    @Published var status: SessionStatus
    @Published var commitMessage = ""
    @Published var isCommitting = false

    let session: Session
    private let processManager: ProcessManager
    private let gitService: GitService

    init(
        session: Session,
        processManager: ProcessManager,
        gitService: GitService
    ) {
        self.session = session
        self.status = session.status
        self.processManager = processManager
        self.gitService = gitService

        Task {
            await startOutputMonitoring()
        }
    }

    private func startOutputMonitoring() async {
        for await line in processManager.outputStream(for: session.processId) {
            output += line + "\n"
        }
    }

    func commitChanges() async {
        guard !commitMessage.isEmpty else { return }

        isCommitting = true
        defer { isCommitting = false }

        do {
            try await gitService.commit(
                worktreePath: session.worktreePath,
                message: commitMessage
            )
            commitMessage = ""
            output += "\n✅ Committed successfully\n"
        } catch {
            output += "\n❌ Commit failed: \(error.localizedDescription)\n"
        }
    }
}
```

### Pattern 3: Loading State Management

```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
}

@MainActor
class ViewModel: ObservableObject {
    @Published var state: LoadingState<[Session]> = .idle

    func loadData() async {
        state = .loading

        do {
            let sessions = try await sessionService.fetchSessions()
            state = .loaded(sessions)
        } catch {
            state = .error(error)
        }
    }
}

// View handles all states
struct ContentView: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        switch viewModel.state {
        case .idle:
            Text("Tap to load")
        case .loading:
            ProgressView()
        case .loaded(let sessions):
            SessionsList(sessions: sessions)
        case .error(let error):
            ErrorView(error: error)
        }
    }
}
```

### Pattern 4: Form Validation

```swift
@MainActor
class CreateSessionViewModel: ObservableObject {
    @Published var sessionName = ""
    @Published var repoPath = ""
    @Published var nameError: String?
    @Published var pathError: String?
    @Published var isSubmitting = false

    var isValid: Bool {
        !sessionName.isEmpty &&
        !repoPath.isEmpty &&
        nameError == nil &&
        pathError == nil
    }

    func validateName() {
        if sessionName.isEmpty {
            nameError = "Name is required"
        } else if sessionName.count < 3 {
            nameError = "Name must be at least 3 characters"
        } else {
            nameError = nil
        }
    }

    func validatePath() {
        if !FileManager.default.fileExists(atPath: repoPath) {
            pathError = "Path does not exist"
        } else {
            pathError = nil
        }
    }

    func submit() async -> Bool {
        validateName()
        validatePath()

        guard isValid else { return false }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await sessionService.createSession(
                name: sessionName,
                repoPath: repoPath
            )
            return true
        } catch {
            return false
        }
    }
}
```

## Property Wrappers in Views

### @StateObject vs @ObservedObject

```swift
struct ParentView: View {
    // ✅ @StateObject - View owns and creates the ViewModel
    @StateObject private var viewModel = SessionsViewModel()

    var body: some View {
        ChildView(viewModel: viewModel)
    }
}

struct ChildView: View {
    // ✅ @ObservedObject - View receives ViewModel from parent
    @ObservedObject var viewModel: SessionsViewModel

    var body: some View {
        Text("\(viewModel.sessions.count) sessions")
    }
}
```

**Rules:**
- Use `@StateObject` when the View creates and owns the ViewModel
- Use `@ObservedObject` when the ViewModel is passed from a parent

### @EnvironmentObject - App-wide State

```swift
@main
struct MaestroApp: App {
    @StateObject private var sessionsViewModel = SessionsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionsViewModel)
        }
    }
}

struct AnyChildView: View {
    @EnvironmentObject var sessionsViewModel: SessionsViewModel

    var body: some View {
        Text("\(sessionsViewModel.sessions.count) sessions")
    }
}
```

## Testing ViewModels

```swift
class MockSessionService: SessionService {
    var mockSessions: [Session] = []
    var shouldFail = false

    func fetchSessions() async throws -> [Session] {
        if shouldFail {
            throw NSError(domain: "test", code: 1)
        }
        return mockSessions
    }
}

@MainActor
class ViewModelTests: XCTestCase {
    func testLoadSessions() async {
        // Arrange
        let mockService = MockSessionService()
        mockService.mockSessions = [
            Session(id: UUID(), name: "Test 1"),
            Session(id: UUID(), name: "Test 2")
        ]

        let viewModel = SessionsViewModel(sessionService: mockService)

        // Act
        await viewModel.loadSessions()

        // Assert
        XCTAssertEqual(viewModel.sessions.count, 2)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadSessionsError() async {
        // Arrange
        let mockService = MockSessionService()
        mockService.shouldFail = true

        let viewModel = SessionsViewModel(sessionService: mockService)

        // Act
        await viewModel.loadSessions()

        // Assert
        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
```

## Resources

### references/
- **mvvm-essentials.md** - Complete MVVM guide with Maestro patterns (multi-session management, terminal output ViewModels, dependency injection, event bus, parent-child ViewModels, testing with mocks, best practices)

Read this file for detailed architectural patterns and advanced techniques.

## Best Practices

### 1. Always use @MainActor
```swift
// ✅ Good
@MainActor
class ViewModel: ObservableObject { }

// ❌ Bad - UI updates may crash
class ViewModel: ObservableObject { }
```

### 2. Keep Views dumb
```swift
// ✅ Good - View only displays data
struct SessionsView: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        List(viewModel.sessions) { session in
            Text(session.name)
        }
    }
}

// ❌ Bad - View has business logic
struct SessionsView: View {
    func fetchSessions() async {
        // Complex API calls, database queries...
        // ❌ This belongs in ViewModel!
    }
}
```

### 3. Use dependency injection
```swift
// ✅ Good - testable
@MainActor
class ViewModel: ObservableObject {
    init(service: SessionService) { }
}

// ❌ Bad - hard to test
@MainActor
class ViewModel: ObservableObject {
    private let service = SessionServiceImpl()  // ❌ Hard-coded!
}
```

### 4. Avoid [weak self] in ViewModels
```swift
@MainActor
class ViewModel: ObservableObject {
    func loadData() async {
        // ✅ No [weak self] needed - async/await doesn't retain
        let data = await service.fetch()
        self.items = data
    }
}
```

### 5. Use LoadingState enum
```swift
// ✅ Good - single source of truth
@Published var state: LoadingState<[Session]> = .idle

// ❌ Bad - multiple booleans
@Published var isLoading = false
@Published var hasError = false
@Published var data: [Session]?
```

## Common Mistakes

### ❌ Forgetting @MainActor
```swift
// ❌ Crash risk!
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```

### ❌ Business logic in View
```swift
// ❌ View doing too much
struct View {
    var body: some View {
        Button("Load") {
            Task {
                let data = await fetchFromAPI()
                processData(data)
                saveToDatabase(data)
            }
        }
    }
}
```

### ❌ Not injecting dependencies
```swift
// ❌ Can't test this
@MainActor
class ViewModel: ObservableObject {
    private let api = APIClient()  // Hard-coded!
}
```

## Integration with Other Skills

- **swiftui** - Build Views that use ViewModels
- **swift-concurrency** - Use async/await in ViewModels with @MainActor
- **memory-management** - Avoid retain cycles in closures
- **process-management** - Integrate process management into ViewModels

## Key Takeaways

✅ **MVVM** separates UI (View) from logic (ViewModel) and data (Model)
✅ **@MainActor** ensures all ViewModel code runs on main thread
✅ **@Published** triggers automatic View updates
✅ **ObservableObject** makes ViewModels observable by Views
✅ **@StateObject** when View owns ViewModel
✅ **@ObservedObject** when ViewModel comes from parent
✅ **Dependency Injection** enables testing with mock services
✅ **LoadingState enum** simplifies state management
✅ **Keep Views dumb** - all logic in ViewModel
