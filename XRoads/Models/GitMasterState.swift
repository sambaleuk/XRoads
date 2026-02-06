//
//  GitMasterState.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  State and enums for the GitMaster intelligent resolver
//

import Foundation

// MARK: - GitMaster Mode

/// Current operational mode of GitMaster
enum GitMasterMode: String, Codable, Sendable, CaseIterable {
    case idle           // No operation in progress
    case monitoring     // Watching agent branches for completion
    case preparing      // Preparing merge plan (dry-run)
    case merging        // Merge operation in progress
    case resolving      // Resolving conflicts
    case reviewing      // Waiting for user validation

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .monitoring: return "Monitoring"
        case .preparing: return "Preparing"
        case .merging: return "Merging"
        case .resolving: return "Resolving"
        case .reviewing: return "Review"
        }
    }

    var iconName: String {
        switch self {
        case .idle: return "moon.zzz"
        case .monitoring: return "eye"
        case .preparing: return "doc.text.magnifyingglass"
        case .merging: return "arrow.triangle.merge"
        case .resolving: return "wrench.and.screwdriver"
        case .reviewing: return "checkmark.circle"
        }
    }
}

// MARK: - GitMaster Status

/// Overall status of GitMaster
enum GitMasterStatus: String, Codable, Sendable, CaseIterable {
    case ready          // Ready to operate
    case busy           // Operation in progress
    case needsAttention // Conflicts requiring intervention
    case error          // Error encountered
    case success        // Last operation succeeded

    var displayName: String {
        switch self {
        case .ready: return "Ready"
        case .busy: return "Busy"
        case .needsAttention: return "Needs Attention"
        case .error: return "Error"
        case .success: return "Success"
        }
    }

    var color: String {
        switch self {
        case .ready: return "textSecondary"
        case .busy: return "accentPrimary"
        case .needsAttention: return "terminalMagenta"
        case .error: return "statusError"
        case .success: return "statusSuccess"
        }
    }
}

// MARK: - Conflict Type

/// Type of conflict detected
enum ConflictType: String, Codable, Sendable, CaseIterable {
    case trivial        // Whitespace, formatting, comments
    case parallel       // Parallel modifications in same zone
    case dependent      // One change depends on another
    case structural     // File structure modified
    case semantic       // Logic/behavior modified
    case binary         // Binary file conflict

    var displayName: String {
        switch self {
        case .trivial: return "Trivial"
        case .parallel: return "Parallel"
        case .dependent: return "Dependent"
        case .structural: return "Structural"
        case .semantic: return "Semantic"
        case .binary: return "Binary"
        }
    }

    var description: String {
        switch self {
        case .trivial: return "Whitespace or formatting differences"
        case .parallel: return "Both modified same code section"
        case .dependent: return "Changes depend on each other"
        case .structural: return "File structure was reorganized"
        case .semantic: return "Logic or behavior changed"
        case .binary: return "Binary file cannot be merged"
        }
    }

    var iconName: String {
        switch self {
        case .trivial: return "text.alignleft"
        case .parallel: return "arrow.left.arrow.right"
        case .dependent: return "link"
        case .structural: return "rectangle.3.group"
        case .semantic: return "brain"
        case .binary: return "doc.zipper"
        }
    }
}

// MARK: - Conflict Complexity

/// Complexity of resolution required
enum ConflictComplexity: String, Codable, Sendable, CaseIterable {
    case auto           // Automatic resolution possible
    case assisted       // AI proposes, human validates
    case manual         // Human intervention required

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .assisted: return "Review"
        case .manual: return "Manual"
        }
    }

    var badgeColor: String {
        switch self {
        case .auto: return "statusSuccess"
        case .assisted: return "statusWarning"
        case .manual: return "statusError"
        }
    }

    var description: String {
        switch self {
        case .auto: return "Can be resolved automatically"
        case .assisted: return "AI suggestion available, needs review"
        case .manual: return "Requires manual intervention"
        }
    }
}

// MARK: - Resolution Strategy Type

/// Type of resolution strategy
enum ResolutionStrategyType: String, Codable, Sendable, CaseIterable {
    case keepOurs       // Keep our version
    case keepTheirs     // Keep their version
    case combine        // AI-generated merge
    case reorder        // Reorder changes
    case defer_         // Defer to developer (using defer_ to avoid keyword)

    var displayName: String {
        switch self {
        case .keepOurs: return "Keep Ours"
        case .keepTheirs: return "Keep Theirs"
        case .combine: return "AI Merge"
        case .reorder: return "Reorder"
        case .defer_: return "Defer"
        }
    }

    var iconName: String {
        switch self {
        case .keepOurs: return "arrow.left"
        case .keepTheirs: return "arrow.right"
        case .combine: return "wand.and.stars"
        case .reorder: return "arrow.up.arrow.down"
        case .defer_: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Resolution Strategy

/// Complete resolution strategy with content
struct ResolutionStrategy: Codable, Sendable, Equatable {
    let type: ResolutionStrategyType
    let mergedContent: String?      // For combine strategy
    let instructions: String?       // For reorder strategy
    let reason: String?             // For defer strategy

    static func keepOurs() -> ResolutionStrategy {
        ResolutionStrategy(type: .keepOurs, mergedContent: nil, instructions: nil, reason: nil)
    }

    static func keepTheirs() -> ResolutionStrategy {
        ResolutionStrategy(type: .keepTheirs, mergedContent: nil, instructions: nil, reason: nil)
    }

    static func combine(merged: String) -> ResolutionStrategy {
        ResolutionStrategy(type: .combine, mergedContent: merged, instructions: nil, reason: nil)
    }

    static func reorder(instructions: String) -> ResolutionStrategy {
        ResolutionStrategy(type: .reorder, mergedContent: nil, instructions: instructions, reason: nil)
    }

    static func defer_(reason: String) -> ResolutionStrategy {
        ResolutionStrategy(type: .defer_, mergedContent: nil, instructions: nil, reason: reason)
    }
}

// MARK: - Branch Status

/// Status of a branch being tracked for merge
struct TrackedBranch: Identifiable, Sendable {
    let id: UUID
    let name: String
    let worktreePath: String?
    let agentType: AgentType?
    var status: TrackedBranchStatus
    var lastCommit: String?
    var lastCommitMessage: String?

    init(
        id: UUID = UUID(),
        name: String,
        worktreePath: String? = nil,
        agentType: AgentType? = nil,
        status: TrackedBranchStatus = .pending,
        lastCommit: String? = nil,
        lastCommitMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.worktreePath = worktreePath
        self.agentType = agentType
        self.status = status
        self.lastCommit = lastCommit
        self.lastCommitMessage = lastCommitMessage
    }
}

enum TrackedBranchStatus: String, Sendable {
    case pending        // Not yet started
    case inProgress     // Agent working
    case completed      // Agent done, ready to merge
    case merged         // Already merged
    case error          // Error occurred

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .merged: return "Merged"
        case .error: return "Error"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle"
        case .merged: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle"
        }
    }
}

// MARK: - GitMaster State

/// Main state container for GitMaster
struct GitMasterState: Sendable {
    var mode: GitMasterMode
    var status: GitMasterStatus
    var targetBranch: String
    var trackedBranches: [TrackedBranch]
    var pendingConflicts: [GitConflict]
    var resolvedFiles: [String]
    var lastError: String?
    var lastMergeResult: MergeResult?

    init(
        mode: GitMasterMode = .idle,
        status: GitMasterStatus = .ready,
        targetBranch: String = "main",
        trackedBranches: [TrackedBranch] = [],
        pendingConflicts: [GitConflict] = [],
        resolvedFiles: [String] = [],
        lastError: String? = nil,
        lastMergeResult: MergeResult? = nil
    ) {
        self.mode = mode
        self.status = status
        self.targetBranch = targetBranch
        self.trackedBranches = trackedBranches
        self.pendingConflicts = pendingConflicts
        self.resolvedFiles = resolvedFiles
        self.lastError = lastError
        self.lastMergeResult = lastMergeResult
    }

    /// Number of branches ready to merge
    var branchesReadyToMerge: Int {
        trackedBranches.filter { $0.status == .completed }.count
    }

    /// Whether all tracked branches are complete
    var allBranchesComplete: Bool {
        !trackedBranches.isEmpty && trackedBranches.allSatisfy { $0.status == .completed || $0.status == .merged }
    }

    /// Number of auto-resolvable conflicts
    var autoResolvableCount: Int {
        pendingConflicts.filter { $0.complexity == .auto }.count
    }

    /// Number of conflicts needing review
    var needsReviewCount: Int {
        pendingConflicts.filter { $0.complexity == .assisted }.count
    }

    /// Number of manual conflicts
    var manualCount: Int {
        pendingConflicts.filter { $0.complexity == .manual }.count
    }

    /// Whether there are any conflicts
    var hasConflicts: Bool {
        !pendingConflicts.isEmpty
    }

    /// Reset state to idle
    mutating func reset() {
        mode = .idle
        status = .ready
        pendingConflicts.removeAll()
        resolvedFiles.removeAll()
        lastError = nil
    }
}

// MARK: - Merge Result Extension

/// Extended merge result for GitMaster
extension MergeResult {
    var isFullySuccessful: Bool {
        success && conflicts.isEmpty && !rolledBack
    }
}
