// Template : API Client Asynchrone avec Swift Concurrency
// Remplacer "MyAPI" par le nom de votre API

import Foundation

// MARK: - Modèles

struct User: Codable {
    let id: String
    let name: String
    let email: String
}

struct Post: Codable {
    let id: String
    let title: String
    let body: String
    let authorId: String
}

// MARK: - Erreurs

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
}

// MARK: - API Client avec Actor

actor APIClient {
    private let baseURL = "https://api.example.com"
    private let session: URLSession
    private var cache = Cache<String, Data>()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        // Construire URL
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        // Vérifier cache
        if method == "GET", let cached = cache.get(endpoint) {
            return try JSONDecoder().decode(T.self, from: cached)
        }

        // Créer requête
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Exécuter requête
        let (data, response) = try await session.data(for: request)

        // Valider réponse
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Décoder
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)

            // Mettre en cache si GET
            if method == "GET" {
                cache.set(endpoint, value: data)
            }

            return decoded
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Endpoints

    func fetchUsers() async throws -> [User] {
        try await request(endpoint: "/users")
    }

    func fetchUser(id: String) async throws -> User {
        try await request(endpoint: "/users/\(id)")
    }

    func fetchPosts(for userId: String) async throws -> [Post] {
        try await request(endpoint: "/users/\(userId)/posts")
    }

    func createPost(title: String, body: String, authorId: String) async throws -> Post {
        let post = [
            "title": title,
            "body": body,
            "authorId": authorId
        ]

        let data = try JSONEncoder().encode(post)
        return try await request(endpoint: "/posts", method: "POST", body: data)
    }

    // MARK: - Batch Operations

    func fetchUsersWithPosts() async throws -> [(User, [Post])] {
        // Fetch users first
        let users = try await fetchUsers()

        // Fetch posts for all users in parallel
        return try await withThrowingTaskGroup(of: (User, [Post]).self) { group in
            for user in users {
                group.addTask {
                    let posts = try await self.fetchPosts(for: user.id)
                    return (user, posts)
                }
            }

            var results: [(User, [Post])] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        cache.clear()
    }
}

// MARK: - Cache Actor

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
        if storage.count >= maxSize {
            storage.removeFirst()
        }
        storage[key] = value
    }

    func clear() {
        storage.removeAll()
    }
}

// MARK: - ViewModel avec @MainActor

@MainActor
class UserViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            users = try await apiClient.fetchUsers()
        } catch let error as APIError {
            errorMessage = formatError(error)
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadUsersWithPosts() async {
        isLoading = true
        errorMessage = nil

        do {
            let results = try await apiClient.fetchUsersWithPosts()
            // Traiter les résultats...
            print("Loaded \(results.count) users with posts")
        } catch {
            errorMessage = formatError(error)
        }

        isLoading = false
    }

    private func formatError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid server response"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .decodingError:
                return "Failed to decode response"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}

// MARK: - SwiftUI View

import SwiftUI

struct UsersView: View {
    @StateObject private var viewModel = UserViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading users...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task {
                                await viewModel.loadUsers()
                            }
                        }
                    }
                } else {
                    List(viewModel.users, id: \.id) { user in
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        Task {
                            await viewModel.loadUsers()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadUsers()
        }
    }
}

// MARK: - Utilisation Avancée

// Exemple : Téléchargement avec progression
@MainActor
class DownloadViewModel: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var isDownloading = false

    func downloadFile(from url: URL) async throws {
        isDownloading = true
        defer { isDownloading = false }

        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)

        guard let totalBytes = response.expectedContentLength, totalBytes > 0 else {
            throw APIError.invalidResponse
        }

        var data = Data()

        for try await byte in asyncBytes {
            data.append(byte)

            // Mettre à jour la progression
            progress = Double(data.count) / Double(totalBytes)
        }

        // Sauvegarder le fichier...
    }
}

// Exemple : Retry avec backoff exponentiel
extension APIClient {
    func fetchWithRetry<T: Decodable>(
        endpoint: String,
        maxAttempts: Int = 3
    ) async throws -> T {
        var delay: UInt64 = 1_000_000_000 // 1 seconde

        for attempt in 1...maxAttempts {
            do {
                return try await request(endpoint: endpoint)
            } catch {
                print("Attempt \(attempt) failed: \(error)")

                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: delay)
                    delay *= 2 // Backoff exponentiel
                } else {
                    throw error
                }
            }
        }

        fatalError("Should not reach here")
    }
}

// MARK: - Tests d'Utilisation

func exampleUsage() async {
    let apiClient = APIClient()

    // Fetch simple
    do {
        let users = try await apiClient.fetchUsers()
        print("Loaded \(users.count) users")
    } catch {
        print("Error: \(error)")
    }

    // Fetch en parallèle
    do {
        async let users = apiClient.fetchUsers()
        async let user1Posts = apiClient.fetchPosts(for: "user1")
        async let user2Posts = apiClient.fetchPosts(for: "user2")

        let (usersList, posts1, posts2) = try await (users, user1Posts, user2Posts)
        print("Loaded \(usersList.count) users, \(posts1.count + posts2.count) posts")
    } catch {
        print("Error: \(error)")
    }

    // Batch avec TaskGroup
    do {
        let results = try await apiClient.fetchUsersWithPosts()
        print("Loaded \(results.count) users with posts")
    } catch {
        print("Error: \(error)")
    }
}
