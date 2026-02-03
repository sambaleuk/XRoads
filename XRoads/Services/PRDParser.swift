import Foundation

// MARK: - PRD Parser

enum PRDParserError: LocalizedError {
    case fileNotFound
    case invalidData
    case duplicateStoryID(String)
    case missingDependency(story: String, dependency: String)
    case circularDependency([String])
    case unsupportedPriority(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "PRD file could not be found."
        case .invalidData:
            return "PRD data is invalid or corrupted."
        case .duplicateStoryID(let id):
            return "PRD contains duplicate story id '\(id)'."
        case .missingDependency(let story, let dependency):
            return "Story '\(story)' references missing dependency '\(dependency)'."
        case .circularDependency(let cycle):
            return "Circular dependency detected: \(cycle.joined(separator: " -> "))."
        case .unsupportedPriority(let value):
            return "Unsupported priority value '\(value)'."
        }
    }
}

struct PRDParser {

    func parse(fileURL: URL) async throws -> PRDDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PRDParserError.fileNotFound
        }

        let data = try Data(contentsOf: fileURL)
        return try parse(data: data)
    }

    func parse(data: Data) throws -> PRDDocument {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let raw: RawPRD
        do {
            raw = try decoder.decode(RawPRD.self, from: data)
        } catch {
            throw PRDParserError.invalidData
        }

        let stories = try mapStories(raw.userStories)
        try validateDependencies(in: stories)

        return PRDDocument(
            featureName: raw.featureName,
            description: raw.description,
            userStories: stories
        )
    }

    // MARK: - Mapping & Validation

    private func mapStories(_ rawStories: [RawUserStory]) throws -> [PRDUserStory] {
        var ids = Set<String>()
        return try rawStories.map { story in
            guard ids.insert(story.id).inserted else {
                throw PRDParserError.duplicateStoryID(story.id)
            }

            guard let priority = TaskPriority(rawValue: story.priority.lowercased()) else {
                throw PRDParserError.unsupportedPriority(story.priority)
            }

            return PRDUserStory(
                id: story.id,
                title: story.title,
                description: story.description ?? "",
                priority: priority,
                dependsOn: story.dependsOn ?? []
            )
        }
    }

    private func validateDependencies(in stories: [PRDUserStory]) throws {
        let storyIDs = Set(stories.map(\.id))

        for story in stories {
            for dependency in story.dependsOn {
                guard storyIDs.contains(dependency) else {
                    throw PRDParserError.missingDependency(story: story.id, dependency: dependency)
                }
            }
        }

        var visited = Set<String>()
        var stack = Set<String>()

        let storyMap = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })

        func dfs(_ node: String, path: [String]) throws {
            if stack.contains(node) {
                let cycleStartIndex = path.firstIndex(of: node) ?? 0
                let cycle = Array(path[cycleStartIndex...]) + [node]
                throw PRDParserError.circularDependency(cycle)
            }
            if visited.contains(node) { return }

            visited.insert(node)
            stack.insert(node)

            if let story = storyMap[node] {
                for dep in story.dependsOn {
                    try dfs(dep, path: path + [node])
                }
            }

            stack.remove(node)
        }

        for story in stories {
            try dfs(story.id, path: [])
        }
    }
}

private struct RawPRD: Decodable {
    let featureName: String
    let description: String
    let userStories: [RawUserStory]
}

private struct RawUserStory: Decodable {
    let id: String
    let title: String
    let description: String?
    let priority: String
    let dependsOn: [String]?
}

// MARK: - Task Splitter

enum TaskSplitterError: LocalizedError {
    case noAgentsAvailable

    var errorDescription: String? {
        switch self {
        case .noAgentsAvailable:
            return "No agents were provided for task assignment."
        }
    }
}

struct TaskSplitter {

    func split(prd: PRDDocument, availableAgents: [AgentType]) throws -> [TaskGroup] {
        let agents = availableAgents.isEmpty ? AgentType.allCases : availableAgents
        guard !agents.isEmpty else {
            throw TaskSplitterError.noAgentsAvailable
        }

        let storyMap = Dictionary(uniqueKeysWithValues: prd.userStories.map { ($0.id, $0) })
        var assigned = Set<String>()
        var groups: [TaskGroup] = []
        var highPriorityIndex = 0
        let highPriorityAgents = agents.filter { $0 != .codex }

        let sortedStories = prd.userStories.sorted { $0.priority.weight > $1.priority.weight }

        for story in sortedStories where !assigned.contains(story.id) {
            let cluster = cluster(for: story, storyMap: storyMap, assigned: &assigned)
            let priority = cluster.map(\.priority.weight).max() ?? story.priority.weight
            let agent = selectAgent(
                forWeight: priority,
                basePriority: cluster.max(by: { $0.priority.weight < $1.priority.weight })?.priority ?? story.priority,
                availableAgents: agents,
                highPriorityAgents: highPriorityAgents.isEmpty ? agents : highPriorityAgents,
                highPriorityIndex: &highPriorityIndex
            )

            let group = TaskGroup(
                id: story.id,
                preferredAgent: agent,
                storyIds: cluster.map(\.id),
                estimatedComplexity: cluster.reduce(0) { $0 + $1.priority.weight }
            )

            groups.append(group)
        }

        return groups
    }

    private func cluster(
        for story: PRDUserStory,
        storyMap: [String: PRDUserStory],
        assigned: inout Set<String>
    ) -> [PRDUserStory] {
        var stack: [String] = [story.id]
        var clusterIDs = Set<String>()

        while let current = stack.popLast() {
            guard !clusterIDs.contains(current) else { continue }
            clusterIDs.insert(current)

            if let node = storyMap[current] {
                stack.append(contentsOf: node.dependsOn)
            }
        }

        assigned.formUnion(clusterIDs)
        return clusterIDs.compactMap { storyMap[$0] }
    }

    private func selectAgent(
        forWeight weight: Int,
        basePriority: TaskPriority,
        availableAgents: [AgentType],
        highPriorityAgents: [AgentType],
        highPriorityIndex: inout Int
    ) -> AgentType {
        switch basePriority {
        case .critical:
            if availableAgents.contains(.claude) { return .claude }
            return availableAgents.first!
        case .high:
            let pool = highPriorityAgents.isEmpty ? availableAgents : highPriorityAgents
            let index = highPriorityIndex % pool.count
            highPriorityIndex += 1
            return pool[index]
        case .medium, .low:
            if availableAgents.contains(.codex) { return .codex }
            return availableAgents.first!
        }
    }
}
