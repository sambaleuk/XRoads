import Foundation
import SwiftUI

struct AgentDashboardEntry: Identifiable, Sendable {
    let id: String
    let agentType: AgentType?
    let stories: [String]
    let currentStoryId: String?
    let progress: Double
    let state: AgentRunState
    let message: String
    let lastUpdate: Date
    let averageStoryTime: TimeInterval?
    let successRate: Double?
    let activeHealthIssue: AgentHealthIssue?

    var displayName: String {
        if let agentType {
            return agentType.displayName
        }
        return "Agent \(id.prefix(6))"
    }

    var statusColor: AgentStatusColor {
        AgentStatusColor(state: state)
    }

    var formattedAverageStoryTime: String {
        guard let averageStoryTime, averageStoryTime > 0 else { return "–" }
        return averageStoryTime.cr_formattedDuration
    }

    var formattedSuccessRate: String {
        guard let successRate else { return "–" }
        return "\(Int(successRate * 100))%"
    }
}

struct AgentStatusColor {
    let background: ColorToken
    let foreground: ColorToken

    init(state: AgentRunState) {
        switch state {
        case .idle:
            background = .blueMuted
            foreground = .blueBright
        case .working:
            background = .purpleMuted
            foreground = .purpleBright
        case .needsInput:
            background = .yellowMuted
            foreground = .yellowBright
        case .blocked:
            background = .orangeMuted
            foreground = .orangeBright
        case .finished:
            background = .greenMuted
            foreground = .greenBright
        case .error:
            background = .redMuted
            foreground = .redBright
        }
    }

    enum ColorToken {
        case blueMuted, blueBright
        case purpleMuted, purpleBright
        case yellowMuted, yellowBright
        case orangeMuted, orangeBright
        case greenMuted, greenBright
        case redMuted, redBright

        var color: Color {
            switch self {
            case .blueMuted: return Color(red: 0.18, green: 0.22, blue: 0.35)
            case .blueBright: return Color(red: 0.45, green: 0.64, blue: 1.0)
            case .purpleMuted: return Color(red: 0.24, green: 0.18, blue: 0.33)
            case .purpleBright: return Color(red: 0.63, green: 0.46, blue: 0.98)
            case .yellowMuted: return Color(red: 0.34, green: 0.28, blue: 0.11)
            case .yellowBright: return Color(red: 0.99, green: 0.86, blue: 0.38)
            case .orangeMuted: return Color(red: 0.33, green: 0.20, blue: 0.12)
            case .orangeBright: return Color(red: 0.98, green: 0.61, blue: 0.30)
            case .greenMuted: return Color(red: 0.18, green: 0.30, blue: 0.21)
            case .greenBright: return Color(red: 0.42, green: 0.90, blue: 0.52)
            case .redMuted: return Color(red: 0.31, green: 0.15, blue: 0.17)
            case .redBright: return Color(red: 0.98, green: 0.40, blue: 0.44)
            }
        }
    }
}

struct AgentTimelineEvent: Identifiable, Sendable {
    let id = UUID()
    let agentId: String
    let agentType: AgentType?
    let state: AgentRunState
    let message: String
    let timestamp: Date
}

extension TimeInterval {
    var cr_formattedDuration: String {
        guard self > 0 else { return "–" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: self) ?? "\(self)s"
    }
}
