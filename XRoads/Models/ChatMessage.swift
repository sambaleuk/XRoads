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
enum ChatRole: String, Codable, Sendable, CaseIterable {
    case user
    case assistant
    case system

    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Orchestrator"
        case .system:
            return "System"
        }
    }

    var iconName: String {
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
enum OrchestratorMode: String, Codable, Sendable, CaseIterable {
    case api      // Fast chat via Anthropic API
    case terminal // Full execution via Claude CLI

    var displayName: String {
        switch self {
        case .api:
            return "API"
        case .terminal:
            return "Terminal"
        }
    }

    var iconName: String {
        switch self {
        case .api:
            return "bolt.fill"
        case .terminal:
            return "terminal.fill"
        }
    }

    var description: String {
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
enum ChatMessageStatus: Codable, Sendable, Equatable {
    case pending       // Message being sent
    case streaming     // Response is streaming
    case complete      // Message fully received
    case error(String) // Error with message

    var isLoading: Bool {
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
struct ChatAction: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let type: ChatActionType
    let label: String
    let payload: [String: String]?

    init(
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
enum ChatActionType: String, Codable, Sendable {
    case createPRD         // Generate a PRD from the conversation
    case launchLoop        // Start a nexus loop with PRD
    case openFile          // Open a file in editor
    case createWorktree    // Create a new worktree
    case runCommand        // Execute a shell command
    case viewArtBible      // View art direction bible
    case viewSkills        // Browse available skills
}

// MARK: - ChatMessage

/// Represents a single message in the orchestrator chat
struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
    var status: ChatMessageStatus
    var actions: [ChatAction]?
    var metadata: [String: String]?

    init(
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
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }

    /// Create an assistant message
    static func assistant(_ content: String, status: ChatMessageStatus = .complete) -> ChatMessage {
        ChatMessage(role: .assistant, content: content, status: status)
    }

    /// Create a system message
    static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }

    /// Create a streaming placeholder message
    static func streamingPlaceholder() -> ChatMessage {
        ChatMessage(role: .assistant, content: "", status: .streaming)
    }

    /// Formatted timestamp for display [HH:mm]
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ChatContext

/// Context information injected into orchestrator prompts
struct ChatContext: Codable, Sendable {
    let projectPath: String?
    let currentBranch: String?
    let worktrees: [String]
    let availableSkills: [String]
    let mcpServers: [String]
    let dashboardMode: String

    init(
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
    var systemPromptSection: String {
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
