//
//  ChatDispatchParser.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  Phase 2: Parse chat intents and create dispatch requests
//

import Foundation

// MARK: - Chat Dispatch Intent

/// Parsed intent from chat messages for dispatch operations
struct ChatDispatchIntent: Sendable {
    let action: ChatDispatchAction
    let slotNumber: Int?
    let agentType: AgentType?
    let actionType: ActionType?
    let storyIds: [String]?
    let worktreePath: String?
    let rawText: String

    enum ChatDispatchAction: String, Sendable {
        case launchSlot      // "launch slot 1 with claude"
        case stopSlot        // "stop slot 2"
        case startAll        // "start all agents"
        case stopAll         // "stop all agents"
        case configureSlot   // "configure slot 3 with gemini for testing"
        case queryStatus     // "what's the status of slot 1?"
        case none            // Not a dispatch intent
    }
}

// MARK: - ChatDispatchParser

/// Parses chat messages to extract dispatch intents
actor ChatDispatchParser {

    // MARK: - Patterns

    private let launchSlotPatterns: [NSRegularExpression] = {
        let patterns = [
            // English patterns
            #"(?:launch|start|run|execute)\s+slot\s*(\d+)"#,
            #"slot\s*(\d+)\s+(?:with|using)\s+(claude|gemini|codex)"#,
            #"(?:run|start)\s+(claude|gemini|codex)\s+(?:on|in)\s+slot\s*(\d+)"#,

            // French patterns
            #"(?:lancer|démarrer|exécuter)\s+slot\s*(\d+)"#,
            #"slot\s*(\d+)\s+avec\s+(claude|gemini|codex)"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private let stopSlotPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:stop|kill|terminate|halt)\s+slot\s*(\d+)"#,
            #"(?:arrêter|stopper)\s+slot\s*(\d+)"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private let startAllPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:start|launch|run)\s+all\s+(?:agents?|slots?)"#,
            #"(?:démarrer|lancer)\s+tous?\s+(?:les\s+)?(?:agents?|slots?)"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private let stopAllPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:stop|kill|terminate|halt)\s+all\s+(?:agents?|slots?)"#,
            #"(?:arrêter|stopper)\s+tous?\s+(?:les\s+)?(?:agents?|slots?)"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private let configureSlotPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:configure|setup|set)\s+slot\s*(\d+)\s+(?:with|for|using)\s+(claude|gemini|codex)"#,
            #"(?:configurer|paramétrer)\s+slot\s*(\d+)\s+avec\s+(claude|gemini|codex)"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    // MARK: - Parsing

    /// Parse a chat message and extract dispatch intent
    func parse(_ message: String) -> ChatDispatchIntent {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check stop all first (before start all)
        if matchesAny(text, patterns: stopAllPatterns) {
            return ChatDispatchIntent(
                action: .stopAll,
                slotNumber: nil,
                agentType: nil,
                actionType: nil,
                storyIds: nil,
                worktreePath: nil,
                rawText: text
            )
        }

        // Check start all
        if matchesAny(text, patterns: startAllPatterns) {
            return ChatDispatchIntent(
                action: .startAll,
                slotNumber: nil,
                agentType: nil,
                actionType: nil,
                storyIds: nil,
                worktreePath: nil,
                rawText: text
            )
        }

        // Check stop slot
        if let match = firstMatch(text, patterns: stopSlotPatterns) {
            let slotNumber = extractSlotNumber(from: match, in: text)
            return ChatDispatchIntent(
                action: .stopSlot,
                slotNumber: slotNumber,
                agentType: nil,
                actionType: nil,
                storyIds: nil,
                worktreePath: nil,
                rawText: text
            )
        }

        // Check configure slot
        if let match = firstMatch(text, patterns: configureSlotPatterns) {
            let slotNumber = extractSlotNumber(from: match, in: text)
            let agentType = extractAgentType(from: match, in: text)
            let actionType = extractActionType(from: text)
            return ChatDispatchIntent(
                action: .configureSlot,
                slotNumber: slotNumber,
                agentType: agentType,
                actionType: actionType,
                storyIds: nil,
                worktreePath: nil,
                rawText: text
            )
        }

        // Check launch slot
        if let match = firstMatch(text, patterns: launchSlotPatterns) {
            let slotNumber = extractSlotNumber(from: match, in: text)
            let agentType = extractAgentType(from: match, in: text)
            return ChatDispatchIntent(
                action: .launchSlot,
                slotNumber: slotNumber,
                agentType: agentType,
                actionType: nil,
                storyIds: nil,
                worktreePath: nil,
                rawText: text
            )
        }

        // No dispatch intent found
        return ChatDispatchIntent(
            action: .none,
            slotNumber: nil,
            agentType: nil,
            actionType: nil,
            storyIds: nil,
            worktreePath: nil,
            rawText: text
        )
    }

    /// Convert a ChatDispatchIntent to a DispatchRequest (if applicable)
    func toDispatchRequest(_ intent: ChatDispatchIntent) -> DispatchRequest? {
        switch intent.action {
        case .launchSlot:
            guard let slotNumber = intent.slotNumber else { return nil }
            return DispatchRequest.chat(
                intent: "launch_slot",
                slotNumber: slotNumber,
                agentType: intent.agentType
            )

        case .startAll:
            return DispatchRequest(
                mode: .chat,
                source: .chat,
                chatIntent: "start_all"
            )

        case .stopSlot:
            return DispatchRequest(
                mode: .chat,
                source: .chat,
                slotNumber: intent.slotNumber,
                chatIntent: "stop_slot"
            )

        case .stopAll:
            return DispatchRequest(
                mode: .chat,
                source: .chat,
                chatIntent: "stop_all"
            )

        case .configureSlot:
            guard let slotNumber = intent.slotNumber else { return nil }
            return DispatchRequest(
                mode: .chat,
                source: .chat,
                slotNumber: slotNumber,
                agentType: intent.agentType,
                actionType: intent.actionType,
                chatIntent: "configure_slot"
            )

        case .queryStatus, .none:
            return nil
        }
    }

    // MARK: - Helpers

    private func matchesAny(_ text: String, patterns: [NSRegularExpression]) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return patterns.contains { $0.firstMatch(in: text, range: range) != nil }
    }

    private func firstMatch(_ text: String, patterns: [NSRegularExpression]) -> NSTextCheckingResult? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            if let match = pattern.firstMatch(in: text, range: range) {
                return match
            }
        }
        return nil
    }

    private func extractSlotNumber(from match: NSTextCheckingResult, in text: String) -> Int? {
        for i in 1..<match.numberOfRanges {
            let range = match.range(at: i)
            if range.location != NSNotFound,
               let swiftRange = Range(range, in: text) {
                let captured = String(text[swiftRange])
                if let number = Int(captured) {
                    return number
                }
            }
        }
        return nil
    }

    private func extractAgentType(from match: NSTextCheckingResult, in text: String) -> AgentType? {
        for i in 1..<match.numberOfRanges {
            let range = match.range(at: i)
            if range.location != NSNotFound,
               let swiftRange = Range(range, in: text) {
                let captured = String(text[swiftRange]).lowercased()
                switch captured {
                case "claude":
                    return AgentType.claude
                case "gemini":
                    return AgentType.gemini
                case "codex":
                    return AgentType.codex
                default:
                    break
                }
            }
        }
        return nil
    }

    private func extractActionType(from text: String) -> ActionType? {
        let lower = text.lowercased()
        if lower.contains("test") || lower.contains("testing") {
            return .integrationTest
        } else if lower.contains("review") {
            return .review
        } else if lower.contains("doc") || lower.contains("write") {
            return .write
        } else if lower.contains("implement") || lower.contains("build") || lower.contains("code") {
            return .implement
        }
        return nil
    }
}
