//
//  ArtBibleDetector.swift
//  XRoads
//
//  Created by Nexus on 2026-02-10.
//  Detects art-bible JSON blocks in chat responses.
//

import Foundation

// MARK: - ArtBibleDetector

/// Detects ```art-bible code blocks in orchestrator chat messages
struct ArtBibleDetector: Sendable {

    /// Regex pattern for ```art-bible { ... } ``` blocks
    private static let pattern = #"```art-bible\s*\n(\{[\s\S]*?\})\s*```"#

    /// Detect an art-bible JSON block in message content.
    /// Returns the raw JSON string if found, nil otherwise.
    static func detect(in content: String) -> String? {
        guard content.contains("```art-bible") else { return nil }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, options: [], range: range),
              let jsonRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let jsonString = String(content[jsonRange])

        // Validate it's parseable JSON
        guard let data = jsonString.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }

        return jsonString
    }
}
