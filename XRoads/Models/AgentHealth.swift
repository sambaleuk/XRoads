import Foundation

enum AgentHealthIssueType: String, Codable, Sendable {
    case nonResponsive
    case repeatedMessage
}

enum AgentHealthIssueState: String, Codable, Sendable {
    case active
    case snoozed
    case resolved
    case actionRequested
}

enum AgentHealthAction: String, Sendable {
    case wait
    case restart
    case reassign
    case abort
}

struct AgentHealthIssue: Identifiable, Sendable {
    let id: UUID
    let agentId: String
    let agentType: AgentType?
    let type: AgentHealthIssueType
    let detectedAt: Date
    var message: String
    var occurrences: Int
    var state: AgentHealthIssueState
    var snoozedUntil: Date?

    init(
        id: UUID = UUID(),
        agentId: String,
        agentType: AgentType?,
        type: AgentHealthIssueType,
        detectedAt: Date = Date(),
        message: String,
        occurrences: Int = 1,
        state: AgentHealthIssueState = .active,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.agentId = agentId
        self.agentType = agentType
        self.type = type
        self.detectedAt = detectedAt
        self.message = message
        self.occurrences = occurrences
        self.state = state
        self.snoozedUntil = snoozedUntil
    }
}

struct AgentHealthMetrics: Sendable {
    var agentId: String
    var agentType: AgentType?
    var totalStories: Int
    var completedStories: Int
    var storyDurations: [TimeInterval]
    var nonResponsiveHits: Int
    var repeatedMessageHits: Int

    init(
        agentId: String,
        agentType: AgentType?,
        totalStories: Int
    ) {
        self.agentId = agentId
        self.agentType = agentType
        self.totalStories = totalStories
        self.completedStories = 0
        self.storyDurations = []
        self.nonResponsiveHits = 0
        self.repeatedMessageHits = 0
    }

    var averageStoryTime: TimeInterval {
        guard !storyDurations.isEmpty else { return 0 }
        return storyDurations.reduce(0, +) / Double(storyDurations.count)
    }

    var successRate: Double {
        guard totalStories > 0 else { return 0 }
        return Double(completedStories) / Double(totalStories)
    }
}
