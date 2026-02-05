//
//  PRDDetector.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Detects PRD JSON blocks in chat responses and extracts metadata.
//

import Foundation

// MARK: - DetectedPRD

/// A PRD detected in a chat response with metadata
struct DetectedPRD: Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let complexity: PRDComplexity
    let storyCount: Int
    let suggestedAgent: AgentType
    let suggestedBranch: String
    let rawJSON: String
    let prdData: PRDData?

    /// Parsed PRD data structure
    struct PRDData: Codable, Sendable {
        let project_name: String?
        let feature_name: String?
        let description: String?
        let user_stories: [UserStory]?

        struct UserStory: Codable, Sendable {
            let id: String?
            let title: String?
            let priority: String?
            let description: String?
        }
    }
}

// MARK: - PRDComplexity

/// Complexity level of a detected PRD
enum PRDComplexity: String, Sendable {
    case trivial = "trivial"      // 1 story, simple change
    case simple = "simple"        // 1-2 stories
    case moderate = "moderate"    // 3-5 stories
    case complex = "complex"      // 6+ stories, multi-agent recommended

    var displayName: String {
        switch self {
        case .trivial: return "Triviale"
        case .simple: return "Simple"
        case .moderate: return "Modérée"
        case .complex: return "Complexe"
        }
    }

    var icon: String {
        switch self {
        case .trivial: return "leaf"
        case .simple: return "bolt"
        case .moderate: return "square.stack"
        case .complex: return "square.stack.3d.up"
        }
    }

    var recommendsMultiAgent: Bool {
        self == .complex
    }
}

// MARK: - PRDDetector

/// Service that detects PRD blocks in chat messages
struct PRDDetector: Sendable {

    // MARK: - Detection Patterns

    /// Regex patterns to find PRD blocks
    private static let prdBlockPatterns = [
        // ```prd ... ``` or ```json ... ``` with PRD content
        #"```(?:prd|json)\s*\n(\{[\s\S]*?"user_stories"[\s\S]*?\})\s*```"#,
        // Inline JSON with user_stories
        #"(\{[^{}]*"user_stories"\s*:\s*\[[\s\S]*?\]\s*[^{}]*\})"#
    ]

    // MARK: - Public API

    /// Detect PRD in a message content
    /// Returns nil if no PRD found
    static func detect(in content: String) -> DetectedPRD? {
        // Try each pattern
        for pattern in prdBlockPatterns {
            if let match = findPRDMatch(in: content, pattern: pattern) {
                return match
            }
        }
        return nil
    }

    /// Check if content likely contains a PRD (quick check)
    static func mightContainPRD(_ content: String) -> Bool {
        content.contains("user_stories") &&
        (content.contains("```prd") || content.contains("```json") || content.contains("\"title\""))
    }

    // MARK: - Private Helpers

    private static func findPRDMatch(in content: String, pattern: String) -> DetectedPRD? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, options: [], range: range) else {
            return nil
        }

        // Extract the JSON part
        guard let jsonRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let jsonString = String(content[jsonRange])

        // Try to parse
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        // Attempt to decode
        let decoder = JSONDecoder()
        let prdData = try? decoder.decode(DetectedPRD.PRDData.self, from: jsonData)

        // Extract metadata
        let title = prdData?.feature_name ?? prdData?.project_name ?? "Untitled PRD"
        let description = prdData?.description ?? ""
        let storyCount = prdData?.user_stories?.count ?? 0

        // Determine complexity
        let complexity = determineComplexity(storyCount: storyCount, description: description)

        // Suggest agent based on complexity
        let suggestedAgent = suggestAgent(complexity: complexity, prdData: prdData)

        // Generate branch name
        let suggestedBranch = generateBranchName(title: title)

        return DetectedPRD(
            id: UUID(),
            title: title,
            description: description,
            complexity: complexity,
            storyCount: storyCount,
            suggestedAgent: suggestedAgent,
            suggestedBranch: suggestedBranch,
            rawJSON: jsonString,
            prdData: prdData
        )
    }

    private static func determineComplexity(storyCount: Int, description: String) -> PRDComplexity {
        // Check for complexity indicators in description
        let complexIndicators = ["refactor", "architecture", "migration", "multi", "système", "system"]
        let hasComplexIndicator = complexIndicators.contains { description.lowercased().contains($0) }

        switch storyCount {
        case 0...1:
            return hasComplexIndicator ? .simple : .trivial
        case 2:
            return .simple
        case 3...5:
            return .moderate
        default:
            return .complex
        }
    }

    private static func suggestAgent(complexity: PRDComplexity, prdData: DetectedPRD.PRDData?) -> AgentType {
        // For complex PRDs, suggest Claude as orchestrator
        if complexity == .complex {
            return .claude
        }

        // Check story content for hints
        if let stories = prdData?.user_stories {
            let allTitles = stories.compactMap { $0.title }.joined(separator: " ").lowercased()

            // UI-heavy work might benefit from Gemini
            if allTitles.contains("ui") || allTitles.contains("design") || allTitles.contains("interface") {
                return .gemini
            }

            // Simple/routine work can go to Codex
            if complexity == .trivial && (allTitles.contains("test") || allTitles.contains("fix")) {
                return .codex
            }
        }

        // Default to Claude
        return .claude
    }

    private static func generateBranchName(title: String) -> String {
        let sanitized = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
            .prefix(40)

        return "feat/\(sanitized)"
    }
}
