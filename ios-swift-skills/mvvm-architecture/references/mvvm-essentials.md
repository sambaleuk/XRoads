# MVVM Architecture for SwiftUI

Guide complet pour implémenter le pattern MVVM dans des applications SwiftUI comme Maestro.

## Qu'est-ce que MVVM ?

MVVM (Model-View-ViewModel) est un pattern architectural qui sépare:
- **Model**: Données et logique métier
- **View**: Interface utilisateur (SwiftUI)
- **ViewModel**: Intermédiaire entre Model et View, gère l'état

```
┌─────────┐      ┌──────────────┐      ┌───────┐
│  View   │◄─────│  ViewModel   │◄─────│ Model │
│ SwiftUI │      │ @MainActor   │      │ Data  │
└─────────┘      └──────────────┘      └───────┘
    │                    │
    │                    │
    └─── Binding ────────┘
```

## ViewModel de Base

### Structure Essentielle

```swift
@MainActor
class SessionViewModel: ObservableObject {
    // Published properties - UI se met à jour automatiquement
    @Published var sessions: [Session] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Private dependencies
    private let sessionService: SessionService
    private let gitService: GitService

    init(sessionService: SessionService, gitService: GitService) {
        self.sessionService = sessionService
        self.gitService = gitService
    }

    // Public methods - Actions from View
    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await sessionService.fetchSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSession(name: String) async {
        do {
            let session = try await sessionService.createSession(name: name)
            sessions.append(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### @MainActor - Thread Safety pour UI

**Pourquoi @MainActor ?**
- Garantit que toutes les modifications UI se font sur le main thread
- Évite les crashes UI
- Swift concurrency assure la sécurité

```swift
// ❌ Sans @MainActor - peut crasher !
class ViewModel: ObservableObject {
    @Published var data: [Item] = []

    func loadData() async {
        let items = await fetchData()
        data = items  // ⚠️ Peut être sur background thread !
    }
}

// ✅ Avec @MainActor - toujours safe
@MainActor
class ViewModel: ObservableObject {
    @Published var data: [Item] = []

    func loadData() async {
        let items = await fetchData()
        data = items  // ✅ Toujours sur main thread
    }
}
```

## Pattern Maestro: Multi-Session Management

### SessionsViewModel - Grid de sessions

```swift
@MainActor
class SessionsViewModel: ObservableObject {
    // State
    @Published var sessions: [Session] = []
    @Published var selectedSession: Session?
    @Published var isCreatingSession = false
    @Published var errorMessage: String?

    // Services
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

    // MARK: - Actions

    func loadSessions() async {
        do {
            sessions = try await sessionService.loadSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
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

            // Launch Claude Code session
            let processId = try await processManager.launch(
                executable: "/usr/local/bin/claude",
                arguments: ["code", "--cwd", worktreePath]
            )

            // Create session model
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
            errorMessage = "Failed to create session: \(error.localizedDescription)"
        }
    }

    func stopSession(_ session: Session) async {
        do {
            try await processManager.terminate(id: session.processId)

            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index].status = .stopped
            }
        } catch {
            errorMessage = "Failed to stop session: \(error.localizedDescription)"
        }
    }

    func deleteSession(_ session: Session) async {
        // Stop if running
        if session.status == .running {
            await stopSession(session)
        }

        // Remove worktree
        do {
            try await gitService.removeWorktree(path: session.worktreePath)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = "Failed to delete session: \(error.localizedDescription)"
        }
    }
}
```

### SessionDetailViewModel - Terminal output et controls

```swift
@MainActor
class SessionDetailViewModel: ObservableObject {
    // State
    @Published var output: String = ""
    @Published var status: SessionStatus
    @Published var commitMessage = ""
    @Published var isCommitting = false

    let session: Session

    // Services
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

        // Start listening to output
        Task {
            await startOutputMonitoring()
        }
    }

    private func startOutputMonitoring() async {
        // Subscribe to process output
        for await line in processManager.outputStream(for: session.processId) {
            output += line + "\n"
        }
    }

    // MARK: - Actions

    func pauseSession() async {
        // Send SIGSTOP to process
        await processManager.pause(id: session.processId)
        status = .paused
    }

    func resumeSession() async {
        // Send SIGCONT to process
        await processManager.resume(id: session.processId)
        status = .running
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
            output += "\n✅ Changes committed successfully\n"

        } catch {
            output += "\n❌ Commit failed: \(error.localizedDescription)\n"
        }
    }

    func pushChanges() async {
        do {
            try await gitService.push(worktreePath: session.worktreePath)
            output += "\n✅ Changes pushed successfully\n"
        } catch {
            output += "\n❌ Push failed: \(error.localizedDescription)\n"
        }
    }
}
```

## Dependency Injection

### Service Protocol

```swift
protocol SessionService {
    func loadSessions() async throws -> [Session]
    func createSession(name: String) async throws -> Session
    func deleteSession(id: UUID) async throws
}

protocol ProcessManager {
    func launch(executable: String, arguments: [String]) async throws -> UUID
    func terminate(id: UUID) async throws
    func outputStream(for id: UUID) -> AsyncStream<String>
}

protocol GitService {
    func createWorktree(repoPath: String, branch: String) async throws -> String
    func removeWorktree(path: String) async throws
    func commit(worktreePath: String, message: String) async throws
    func push(worktreePath: String) async throws
}
```

### Injection dans View

```swift
@main
struct MaestroApp: App {
    // Create services once
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState.sessionsViewModel)
        }
    }
}

class AppState {
    // Services (singletons)
    let sessionService: SessionService
    let processManager: ProcessManager
    let gitService: GitService

    // ViewModels
    lazy var sessionsViewModel: SessionsViewModel = {
        SessionsViewModel(
            sessionService: sessionService,
            processManager: processManager,
            gitService: gitService
        )
    }()

    init() {
        self.sessionService = SessionServiceImpl()
        self.processManager = ProcessManagerImpl()
        self.gitService = GitServiceImpl()
    }
}
```

## State Management Patterns

### Loading State

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

// Usage in View
struct SessionsView: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        switch viewModel.state {
        case .idle:
            Text("Tap to load")
        case .loading:
            ProgressView()
        case .loaded(let sessions):
            List(sessions) { session in
                Text(session.name)
            }
        case .error(let error):
            Text("Error: \(error.localizedDescription)")
        }
    }
}
```

### Form State

```swift
@MainActor
class CreateSessionViewModel: ObservableObject {
    // Form fields
    @Published var sessionName = ""
    @Published var repoPath = ""

    // Validation
    @Published var nameError: String?
    @Published var pathError: String?

    // Submission
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
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: repoPath) {
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

## Communication Between ViewModels

### Event Bus Pattern

```swift
@MainActor
class EventBus: ObservableObject {
    @Published var sessionCreated: Session?
    @Published var sessionDeleted: UUID?
    @Published var sessionUpdated: Session?

    func notifySessionCreated(_ session: Session) {
        sessionCreated = session
    }

    func notifySessionDeleted(_ id: UUID) {
        sessionDeleted = id
    }

    func notifySessionUpdated(_ session: Session) {
        sessionUpdated = session
    }
}

// In SessionsViewModel
@MainActor
class SessionsViewModel: ObservableObject {
    private let eventBus: EventBus
    private var cancellables = Set<AnyCancellable>()

    init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Listen to events
        eventBus.$sessionCreated
            .compactMap { $0 }
            .sink { [weak self] session in
                self?.sessions.append(session)
            }
            .store(in: &cancellables)

        eventBus.$sessionDeleted
            .compactMap { $0 }
            .sink { [weak self] id in
                self?.sessions.removeAll { $0.id == id }
            }
            .store(in: &cancellables)
    }
}
```

### Parent-Child ViewModel

```swift
@MainActor
class ParentViewModel: ObservableObject {
    @Published var sessions: [Session] = []

    func createChildViewModel(for session: Session) -> SessionDetailViewModel {
        SessionDetailViewModel(
            session: session,
            onUpdate: { [weak self] updatedSession in
                self?.updateSession(updatedSession)
            }
        )
    }

    private func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }
}

@MainActor
class SessionDetailViewModel: ObservableObject {
    @Published var session: Session
    let onUpdate: (Session) -> Void

    init(session: Session, onUpdate: @escaping (Session) -> Void) {
        self.session = session
        self.onUpdate = onUpdate
    }

    func updateStatus(_ status: SessionStatus) {
        session.status = status
        onUpdate(session)  // Notify parent
    }
}
```

## Testing ViewModels

### Mock Services

```swift
class MockSessionService: SessionService {
    var mockSessions: [Session] = []
    var shouldFail = false

    func loadSessions() async throws -> [Session] {
        if shouldFail {
            throw NSError(domain: "test", code: 1)
        }
        return mockSessions
    }

    func createSession(name: String) async throws -> Session {
        let session = Session(id: UUID(), name: name)
        mockSessions.append(session)
        return session
    }
}

// Test
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
        XCTAssertEqual(viewModel.sessions[0].name, "Test 1")
    }

    func testLoadSessionsError() async {
        // Arrange
        let mockService = MockSessionService()
        mockService.shouldFail = true

        let viewModel = SessionsViewModel(sessionService: mockService)

        // Act
        await viewModel.loadSessions()

        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
```

## Best Practices

### 1. Toujours utiliser @MainActor

```swift
// ✅ Bon
@MainActor
class ViewModel: ObservableObject {
    @Published var data: [Item] = []
}

// ❌ Mauvais (peut crasher UI)
class ViewModel: ObservableObject {
    @Published var data: [Item] = []
}
```

### 2. Séparer la logique métier

```swift
// ✅ Bon - logique dans service
@MainActor
class ViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    private let service: SessionService

    func loadSessions() async {
        sessions = try? await service.fetchSessions()
    }
}

// ❌ Mauvais - logique dans ViewModel
@MainActor
class ViewModel: ObservableObject {
    func loadSessions() async {
        // Complex database queries, API calls, etc.
        // ❌ Trop de logique ici !
    }
}
```

### 3. Éviter les retain cycles

```swift
// ✅ Bon - [weak self] dans closures
eventBus.$sessionCreated
    .sink { [weak self] session in
        self?.sessions.append(session)
    }
    .store(in: &cancellables)

// ❌ Mauvais - retain cycle
eventBus.$sessionCreated
    .sink { session in
        self.sessions.append(session)  // ❌ Retain cycle !
    }
    .store(in: &cancellables)
```

### 4. Gérer les erreurs gracieusement

```swift
// ✅ Bon - errorMessage optionnel
@Published var errorMessage: String?

func loadData() async {
    do {
        data = try await service.fetch()
        errorMessage = nil  // Clear previous errors
    } catch {
        errorMessage = error.localizedDescription
    }
}

// ❌ Mauvais - crash ou ignoré
func loadData() async {
    data = try! await service.fetch()  // ❌ Crash si erreur
}
```

### 5. Utiliser LoadingState enum

```swift
// ✅ Bon - un seul state
@Published var loadingState: LoadingState<[Session]> = .idle

// ❌ Mauvais - multiples booleans
@Published var isLoading = false
@Published var hasError = false
@Published var data: [Session]?
// Difficile de gérer tous les états possibles
```

## Résumé

✅ **MVVM** sépare View, ViewModel, Model
✅ **@MainActor** garantit thread safety pour UI
✅ **@Published** déclenche les mises à jour UI
✅ **ObservableObject** rend le ViewModel observable
✅ **Dependency Injection** facilite les tests
✅ **LoadingState enum** simplifie la gestion d'état
✅ **[weak self]** évite les retain cycles
✅ **Services** séparent la logique métier
✅ **Mock services** permettent les tests unitaires
