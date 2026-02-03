#!/usr/bin/env python3
"""
Swift Async Code Generator

Génère du code Swift asynchrone (API clients, actors, TaskGroups, etc.)

Usage:
    python3 generate_async_code.py --type api-client --name UserAPI
    python3 generate_async_code.py --type actor --name DataStore
    python3 generate_async_code.py --type task-group --name processImages
"""

import argparse
import sys


def generate_api_client(name: str, endpoints: list[tuple[str, str]]) -> str:
    """Génère un API client async"""

    lines = [
        f"// {name} - Generated API Client",
        "",
        "import Foundation",
        "",
        f"actor {name} {{",
        "    private let baseURL: String",
        "    private let session: URLSession",
        "",
        "    init(baseURL: String, session: URLSession = .shared) {",
        "        self.baseURL = baseURL",
        "        self.session = session",
        "    }",
        "",
        "    // MARK: - Generic Request",
        "",
        "    private func request<T: Decodable>(",
        "        endpoint: String,",
        "        method: String = \"GET\",",
        "        body: Data? = nil",
        "    ) async throws -> T {",
        "        guard let url = URL(string: baseURL + endpoint) else {",
        "            throw URLError(.badURL)",
        "        }",
        "",
        "        var request = URLRequest(url: url)",
        "        request.httpMethod = method",
        "        request.httpBody = body",
        "        request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")",
        "",
        "        let (data, response) = try await session.data(for: request)",
        "",
        "        guard let httpResponse = response as? HTTPURLResponse,",
        "              (200...299).contains(httpResponse.statusCode) else {",
        "            throw URLError(.badServerResponse)",
        "        }",
        "",
        "        return try JSONDecoder().decode(T.self, from: data)",
        "    }",
        "",
        "    // MARK: - Endpoints",
        ""
    ]

    # Ajouter les endpoints
    for endpoint_name, return_type in endpoints:
        lines.extend([
            f"    func {endpoint_name}() async throws -> {return_type} {{",
            f"        try await request(endpoint: \"/{endpoint_name}\")",
            "    }",
            ""
        ])

    lines.append("}")

    return "\n".join(lines)


def generate_actor(name: str, properties: list[tuple[str, str]]) -> str:
    """Génère un actor thread-safe"""

    lines = [
        f"// {name} - Generated Actor",
        "",
        "import Foundation",
        "",
        f"actor {name} {{",
    ]

    # Propriétés privées
    for prop_name, prop_type in properties:
        lines.append(f"    private var {prop_name}: {prop_type}")

    lines.extend([
        "",
        "    // MARK: - Initialization",
        "",
        "    init(",
    ])

    # Paramètres d'initialisation
    init_params = [f"        {name}: {type_}" for name, type_ in properties]
    lines.append(",\n".join(init_params))
    lines.extend([
        "    ) {",
    ])

    # Corps de l'initializer
    for prop_name, _ in properties:
        lines.append(f"        self.{prop_name} = {prop_name}")

    lines.extend([
        "    }",
        "",
        "    // MARK: - Getters",
        "",
    ])

    # Générer getters
    for prop_name, prop_type in properties:
        lines.extend([
            f"    func get{prop_name.capitalize()}() -> {prop_type} {{",
            f"        return {prop_name}",
            "    }",
            ""
        ])

    lines.extend([
        "    // MARK: - Setters",
        ""
    ])

    # Générer setters
    for prop_name, prop_type in properties:
        lines.extend([
            f"    func set{prop_name.capitalize()}(_ newValue: {prop_type}) {{",
            f"        {prop_name} = newValue",
            "    }",
            ""
        ])

    lines.append("}")

    return "\n".join(lines)


def generate_task_group(name: str, item_type: str = "Item") -> str:
    """Génère une fonction avec TaskGroup"""

    lines = [
        f"// {name} - Generated TaskGroup Function",
        "",
        "import Foundation",
        "",
        f"func {name}(items: [{item_type}]) async throws -> [ProcessedItem] {{",
        "    try await withThrowingTaskGroup(of: (Int, ProcessedItem).self) { group in",
        "        // Ajouter les tâches",
        "        for (index, item) in items.enumerated() {",
        "            group.addTask {",
        f"                let processed = try await process(item)",
        "                return (index, processed)",
        "            }",
        "        }",
        "",
        "        // Collecter les résultats",
        "        var results: [(Int, ProcessedItem)] = []",
        "        for try await result in group {",
        "            results.append(result)",
        "        }",
        "",
        "        // Retourner dans l'ordre",
        "        return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }",
        "    }",
        "}",
        "",
        "// Helper function (à implémenter)",
        f"private func process(_ item: {item_type}) async throws -> ProcessedItem {{",
        "    // TODO: Implémenter le traitement",
        "    fatalError(\"Not implemented\")",
        "}",
    ]

    return "\n".join(lines)


def generate_mainactor_viewmodel(name: str) -> str:
    """Génère un ViewModel avec @MainActor"""

    lines = [
        f"// {name} - Generated ViewModel",
        "",
        "import Foundation",
        "import Combine",
        "",
        "@MainActor",
        f"class {name}: ObservableObject {{",
        "    @Published var data: [Item] = []",
        "    @Published var isLoading = false",
        "    @Published var errorMessage: String?",
        "",
        "    // MARK: - Loading",
        "",
        "    func loadData() async {",
        "        isLoading = true",
        "        errorMessage = nil",
        "",
        "        do {",
        "            // TODO: Fetch data",
        "            data = try await fetchData()",
        "        } catch {",
        "            errorMessage = error.localizedDescription",
        "        }",
        "",
        "        isLoading = false",
        "    }",
        "",
        "    // MARK: - Refresh",
        "",
        "    func refresh() async {",
        "        await loadData()",
        "    }",
        "",
        "    // TODO: Implement data fetching",
        "    private func fetchData() async throws -> [Item] {",
        "        fatalError(\"Not implemented\")",
        "    }",
        "}",
        "",
        "// TODO: Define Item model",
        "struct Item: Identifiable {",
        "    let id: String",
        "    // Add properties",
        "}",
    ]

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate Swift async code",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # API Client
  python3 generate_async_code.py --type api-client --name UserAPI

  # Actor
  python3 generate_async_code.py --type actor --name DataStore

  # TaskGroup function
  python3 generate_async_code.py --type task-group --name processImages

  # MainActor ViewModel
  python3 generate_async_code.py --type viewmodel --name UserViewModel
        """
    )

    parser.add_argument(
        "--type",
        required=True,
        choices=["api-client", "actor", "task-group", "viewmodel"],
        help="Type of code to generate"
    )

    parser.add_argument(
        "--name",
        required=True,
        help="Name of the generated type/function"
    )

    parser.add_argument(
        "--output",
        help="Output file path (default: stdout)"
    )

    args = parser.parse_args()

    # Générer le code selon le type
    if args.type == "api-client":
        # Endpoints par défaut
        endpoints = [
            ("fetchItems", "[Item]"),
            ("fetchItem", "Item"),
        ]
        code = generate_api_client(args.name, endpoints)

    elif args.type == "actor":
        # Propriétés par défaut
        properties = [
            ("data", "[String: Any]"),
            ("lastUpdated", "Date?"),
        ]
        code = generate_actor(args.name, properties)

    elif args.type == "task-group":
        code = generate_task_group(args.name)

    elif args.type == "viewmodel":
        code = generate_mainactor_viewmodel(args.name)

    else:
        print(f"Unknown type: {args.type}", file=sys.stderr)
        sys.exit(1)

    # Output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(code + "\n")
        print(f"✅ Generated {args.name} at {args.output}", file=sys.stderr)
    else:
        print(code)


if __name__ == "__main__":
    main()
