import Foundation

/// Defines the types of actions (loops) available in XRoads
/// Each action represents a specialized workflow that can be executed by an AI agent
enum ActionType: String, Codable, Hashable, Sendable, CaseIterable {
    case implement
    case review
    case integrationTest
    case write
    case custom
    case debug

    /// Human-readable display name for the action
    var displayName: String {
        switch self {
        case .implement: return "Implement"
        case .review: return "Review"
        case .integrationTest: return "Integration Test"
        case .write: return "Write Docs"
        case .custom: return "Custom"
        case .debug: return "Debug"
        }
    }

    /// SF Symbol icon name for UI display
    var iconName: String {
        switch self {
        case .implement: return "hammer.fill"
        case .review: return "eye.fill"
        case .integrationTest: return "testtube.2"
        case .write: return "doc.text.fill"
        case .custom: return "gearshape.fill"
        case .debug: return "ladybug.fill"
        }
    }

    /// Description of what this action does
    var description: String {
        switch self {
        case .implement:
            return "PRD → User Stories → Code + Unit Tests"
        case .review:
            return "Analyze code for issues, suggest fixes"
        case .integrationTest:
            return "Generate integration, e2e, and performance tests (NOT unit tests)"
        case .write:
            return "Generate documentation, README, API docs"
        case .custom:
            return "Custom action with user-defined skills"
        case .debug:
            return "Systematic bug reproduction, diagnosis, fix, and verification"
        }
    }

    /// Skills required to execute this action
    var requiredSkills: [String] {
        switch self {
        case .implement:
            return ["prd", "code-writer", "commit"]
        case .review:
            return ["code-reviewer", "lint"]
        case .integrationTest:
            return ["integration-test", "e2e-test", "perf-test", "agent-browser"]
        case .write:
            return ["doc-generator"]
        case .custom:
            return [] // Custom actions have user-defined skills
        case .debug:
            return ["bug-reproducer", "code-reviewer", "commit"]
        }
    }

    /// Additional skills available for all actions (research, automation)
    static var universalSkills: [String] {
        return ["agent-browser", "find-skills"]
    }

    /// Category for grouping actions in UI
    var category: ActionCategory {
        switch self {
        case .implement, .review:
            return .dev
        case .integrationTest, .debug:
            return .qa
        case .write, .custom:
            return .ops
        }
    }

    /// Whether this action includes unit tests as part of its workflow
    var includesUnitTests: Bool {
        switch self {
        case .implement, .debug:
            return true
        case .review, .integrationTest, .write, .custom:
            return false
        }
    }
}

/// Categories for grouping actions in the UI
enum ActionCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case dev
    case qa
    case ops

    var displayName: String {
        switch self {
        case .dev: return "Development"
        case .qa: return "Quality Assurance"
        case .ops: return "Operations"
        }
    }
}
