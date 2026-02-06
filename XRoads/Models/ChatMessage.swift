//
//  ChatMessage.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-013: Chat message model for orchestrator conversation
//

import Foundation

// MARK: - ChatRole

/// Role of the message sender in the orchestrator chat
public enum ChatRole: String, Codable, Sendable, CaseIterable {
    case user
    case assistant
    case system

    public var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Orchestrator"
        case .system:
            return "System"
        }
    }

    public var iconName: String {
        switch self {
        case .user:
            return "person.fill"
        case .assistant:
            return "brain.head.profile"
        case .system:
            return "gearshape.fill"
        }
    }
}

// MARK: - OrchestratorMode

/// Operating mode for the orchestrator
public enum OrchestratorMode: String, Codable, Sendable, CaseIterable {
    case api      // Fast chat via Anthropic API
    case terminal // Full execution via Claude CLI

    public var displayName: String {
        switch self {
        case .api:
            return "API"
        case .terminal:
            return "Terminal"
        }
    }

    public var iconName: String {
        switch self {
        case .api:
            return "bolt.fill"
        case .terminal:
            return "terminal.fill"
        }
    }

    public var description: String {
        switch self {
        case .api:
            return "Fast responses for PRD generation and quick questions"
        case .terminal:
            return "Full execution with file operations and loop orchestration"
        }
    }
}

// MARK: - ChatMessageStatus

/// Status of a chat message (for streaming and error states)
public enum ChatMessageStatus: Codable, Sendable, Equatable {
    case pending       // Message being sent
    case streaming     // Response is streaming
    case complete      // Message fully received
    case error(String) // Error with message

    public var isLoading: Bool {
        switch self {
        case .pending, .streaming:
            return true
        case .complete, .error:
            return false
        }
    }
}

// MARK: - ChatAction

/// Actions that can be triggered from orchestrator responses
public struct ChatAction: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let type: ChatActionType
    public let label: String
    public let payload: [String: String]?

    public init(
        id: UUID = UUID(),
        type: ChatActionType,
        label: String,
        payload: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.payload = payload
    }
}

// MARK: - ChatActionType

/// Types of actions the orchestrator can trigger
public enum ChatActionType: String, Codable, Sendable {
    case createPRD         // Generate a PRD from the conversation
    case launchLoop        // Start a nexus loop with PRD
    case openFile          // Open a file in editor
    case createWorktree    // Create a new worktree
    case runCommand        // Execute a shell command
    case viewArtBible      // View art direction bible
    case viewSkills        // Browse available skills

    // Dispatch-related actions (Phase 2)
    case launchSlot        // Launch a specific slot with agent
    case startAllSlots     // Start all configured slots
    case stopSlot          // Stop a running slot
    case stopAllSlots      // Stop all running agents
    case configureSlot     // Configure a slot with agent/action
}

// MARK: - ChatMessage

/// Represents a single message in the orchestrator chat
public struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public let content: String
    public let timestamp: Date
    public var status: ChatMessageStatus
    public var actions: [ChatAction]?
    public var metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        timestamp: Date = Date(),
        status: ChatMessageStatus = .complete,
        actions: [ChatAction]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.status = status
        self.actions = actions
        self.metadata = metadata
    }

    /// Create a user message
    public static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }

    /// Create an assistant message
    public static func assistant(_ content: String, status: ChatMessageStatus = .complete) -> ChatMessage {
        ChatMessage(role: .assistant, content: content, status: status)
    }

    /// Create a system message
    public static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }

    /// Create a streaming placeholder message
    public static func streamingPlaceholder() -> ChatMessage {
        ChatMessage(role: .assistant, content: "", status: .streaming)
    }

    /// Formatted timestamp for display [HH:mm]
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ChatContext

/// Context information injected into orchestrator prompts
public struct ChatContext: Codable, Sendable {
    public let projectPath: String?
    public let currentBranch: String?
    public let worktrees: [String]
    public let availableSkills: [String]
    public let mcpServers: [String]
    public let dashboardMode: String

    public init(
        projectPath: String? = nil,
        currentBranch: String? = nil,
        worktrees: [String] = [],
        availableSkills: [String] = [],
        mcpServers: [String] = [],
        dashboardMode: String = "single"
    ) {
        self.projectPath = projectPath
        self.currentBranch = currentBranch
        self.worktrees = worktrees
        self.availableSkills = availableSkills
        self.mcpServers = mcpServers
        self.dashboardMode = dashboardMode
    }

    /// Generate system prompt context string
    public var systemPromptSection: String {
        var lines: [String] = []
        lines.append("## Current XRoads Context")

        if let path = projectPath {
            lines.append("- Project: \(path)")
        }
        if let branch = currentBranch {
            lines.append("- Branch: \(branch)")
        }
        if !worktrees.isEmpty {
            lines.append("- Active Worktrees: \(worktrees.joined(separator: ", "))")
        }
        if !availableSkills.isEmpty {
            lines.append("- Available Skills: \(availableSkills.joined(separator: ", "))")
        }
        if !mcpServers.isEmpty {
            lines.append("- MCP Servers: \(mcpServers.joined(separator: ", "))")
        }
        lines.append("- Dashboard Mode: \(dashboardMode)")

        return lines.joined(separator: "\n")
    }
}
