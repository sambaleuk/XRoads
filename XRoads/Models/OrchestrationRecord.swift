import Foundation

struct AgentRunMetric: Codable, Identifiable, Sendable {
    let id: UUID
    let agentId: String
    let agentType: AgentType?
    let storiesTotal: Int
    let storiesCompleted: Int
    let state: AgentRunState
    let durationSeconds: TimeInterval
    let lastMessage: String?
    let errors: [String]

    init(
        id: UUID = UUID(),
        agentId: String,
        agentType: AgentType?,
        storiesTotal: Int,
        storiesCompleted: Int,
        state: AgentRunState,
        durationSeconds: TimeInterval,
        lastMessage: String?,
        errors: [String]
    ) {
        self.id = id
        self.agentId = agentId
        self.agentType = agentType
        self.storiesTotal = storiesTotal
        self.storiesCompleted = storiesCompleted
        self.state = state
        self.durationSeconds = durationSeconds
        self.lastMessage = lastMessage
        self.errors = errors
    }

    var completionRate: Double {
        guard storiesTotal > 0 else { return 0 }
        return Double(storiesCompleted) / Double(storiesTotal)
    }
}

struct OrchestrationRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let finishedAt: Date?
    let prdName: String
    let prdPath: String?
    let resultSummary: String
    let mergedBranches: [String]
    let conflicts: [String]
    let totalStories: Int
    let completedStories: Int
    let agentMetrics: [AgentRunMetric]
    let errors: [String]

    var durationSeconds: TimeInterval {
        guard let finishedAt else { return 0 }
        return max(finishedAt.timeIntervalSince(startedAt), 0)
    }

    var completionRate: Double {
        guard totalStories > 0 else { return 0 }
        return Double(completedStories) / Double(totalStories)
    }
}

extension OrchestrationRecord {
    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case finishedAt
        case prdName
        case prdPath
        case resultSummary
        case mergedBranches
        case conflicts
        case totalStories
        case completedStories
        case agentMetrics
        case errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        self.finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        self.prdName = try container.decodeIfPresent(String.self, forKey: .prdName) ?? "Unknown PRD"
        self.prdPath = try container.decodeIfPresent(String.self, forKey: .prdPath)
        self.resultSummary = try container.decodeIfPresent(String.self, forKey: .resultSummary) ?? "Unknown"
        self.mergedBranches = try container.decodeIfPresent([String].self, forKey: .mergedBranches) ?? []
        self.conflicts = try container.decodeIfPresent([String].self, forKey: .conflicts) ?? []
        self.totalStories = try container.decodeIfPresent(Int.self, forKey: .totalStories) ?? 0
        self.completedStories = try container.decodeIfPresent(Int.self, forKey: .completedStories) ?? 0
        self.agentMetrics = try container.decodeIfPresent([AgentRunMetric].self, forKey: .agentMetrics) ?? []
        self.errors = try container.decodeIfPresent([String].self, forKey: .errors) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try container.encode(prdName, forKey: .prdName)
        try container.encodeIfPresent(prdPath, forKey: .prdPath)
        try container.encode(resultSummary, forKey: .resultSummary)
        try container.encode(mergedBranches, forKey: .mergedBranches)
        try container.encode(conflicts, forKey: .conflicts)
        try container.encode(totalStories, forKey: .totalStories)
        try container.encode(completedStories, forKey: .completedStories)
        try container.encode(agentMetrics, forKey: .agentMetrics)
        try container.encode(errors, forKey: .errors)
    }
}

struct OrchestrationHistory: Codable, Sendable {
    var records: [OrchestrationRecord]
}
