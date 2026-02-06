//
//  GitConflict.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  Enhanced conflict model with semantic analysis
//

import Foundation

// MARK: - GitConflict

/// Represents a git conflict with semantic analysis
struct GitConflict: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let file: String
    let oursContent: String
    let theirsContent: String
    let baseContent: String?  // Common ancestor (if available)

    // Analysis results
    let conflictType: ConflictType
    let complexity: ConflictComplexity
    var suggestedResolution: ResolutionStrategy?
    var aiAnalysis: String?

    // Metadata
    let oursBranch: String
    let theirsBranch: String
    let detectedAt: Date

    init(
        id: UUID = UUID(),
        file: String,
        oursContent: String,
        theirsContent: String,
        baseContent: String? = nil,
        conflictType: ConflictType,
        complexity: ConflictComplexity,
        suggestedResolution: ResolutionStrategy? = nil,
        aiAnalysis: String? = nil,
        oursBranch: String = "HEAD",
        theirsBranch: String = "incoming",
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.file = file
        self.oursContent = oursContent
        self.theirsContent = theirsContent
        self.baseContent = baseContent
        self.conflictType = conflictType
        self.complexity = complexity
        self.suggestedResolution = suggestedResolution
        self.aiAnalysis = aiAnalysis
        self.oursBranch = oursBranch
        self.theirsBranch = theirsBranch
        self.detectedAt = detectedAt
    }

    // MARK: - Computed Properties

    /// File name without path
    var fileName: String {
        URL(fileURLWithPath: file).lastPathComponent
    }

    /// File extension
    var fileExtension: String {
        URL(fileURLWithPath: file).pathExtension
    }

    /// Whether this conflict has a suggested resolution
    var hasSuggestion: Bool {
        suggestedResolution != nil
    }

    /// Whether this conflict can be auto-resolved
    var canAutoResolve: Bool {
        complexity == .auto && suggestedResolution != nil
    }

    /// Short description for display
    var shortDescription: String {
        "\(conflictType.displayName) conflict in \(fileName)"
    }

    /// Lines changed indicator
    var linesChanged: Int {
        let oursLines = oursContent.components(separatedBy: .newlines).count
        let theirsLines = theirsContent.components(separatedBy: .newlines).count
        return max(oursLines, theirsLines)
    }

    // MARK: - Hashable

    static func == (lhs: GitConflict, rhs: GitConflict) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Conflict Parsing

extension GitConflict {
    /// Parse conflict markers from file content
    static func parseFromContent(
        _ content: String,
        file: String,
        oursBranch: String,
        theirsBranch: String
    ) -> (ours: String, theirs: String, base: String?)? {
        // Standard git conflict markers:
        // <<<<<<< HEAD (or branch name)
        // our content
        // ||||||| base (optional, only with diff3)
        // base content
        // =======
        // their content
        // >>>>>>> incoming-branch

        let lines = content.components(separatedBy: .newlines)
        var ours: [String] = []
        var theirs: [String] = []
        var base: [String]? = nil
        var section: ConflictSection = .outside

        enum ConflictSection {
            case outside, ours, base, theirs
        }

        for line in lines {
            if line.hasPrefix("<<<<<<<") {
                section = .ours
            } else if line.hasPrefix("|||||||") {
                base = []
                section = .base
            } else if line.hasPrefix("=======") {
                section = .theirs
            } else if line.hasPrefix(">>>>>>>") {
                section = .outside
            } else {
                switch section {
                case .ours:
                    ours.append(line)
                case .base:
                    base?.append(line)
                case .theirs:
                    theirs.append(line)
                case .outside:
                    break
                }
            }
        }

        guard !ours.isEmpty || !theirs.isEmpty else { return nil }

        return (
            ours: ours.joined(separator: "\n"),
            theirs: theirs.joined(separator: "\n"),
            base: base?.joined(separator: "\n")
        )
    }

    /// Detect conflict type based on content analysis
    static func detectType(
        ours: String,
        theirs: String,
        base: String?
    ) -> ConflictType {
        // Check for binary
        if ours.contains("\0") || theirs.contains("\0") {
            return .binary
        }

        // Check for trivial (whitespace only)
        let oursNormalized = ours.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces).joined()
        let theirsNormalized = theirs.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces).joined()

        if oursNormalized == theirsNormalized {
            return .trivial
        }

        // Check for structural (significant line count difference)
        let oursLines = ours.components(separatedBy: .newlines).count
        let theirsLines = theirs.components(separatedBy: .newlines).count
        let lineDiff = abs(oursLines - theirsLines)

        if lineDiff > max(oursLines, theirsLines) / 2 {
            return .structural
        }

        // Check for dependent (if base exists and both diverged)
        if let base = base {
            let baseLines = Set(base.components(separatedBy: .newlines))
            let oursLineSet = Set(ours.components(separatedBy: .newlines))
            let theirsLineSet = Set(theirs.components(separatedBy: .newlines))

            let oursChanges = oursLineSet.subtracting(baseLines)
            let theirsChanges = theirsLineSet.subtracting(baseLines)

            // If one set of changes is subset of other, it's dependent
            if oursChanges.isSubset(of: theirsChanges) || theirsChanges.isSubset(of: oursChanges) {
                return .dependent
            }
        }

        // Check for semantic (function/method signatures changed)
        let semanticPatterns = ["func ", "def ", "function ", "class ", "struct ", "enum "]
        let oursHasSemantic = semanticPatterns.contains { ours.contains($0) }
        let theirsHasSemantic = semanticPatterns.contains { theirs.contains($0) }

        if oursHasSemantic && theirsHasSemantic {
            return .semantic
        }

        // Default to parallel
        return .parallel
    }

    /// Estimate complexity based on type and content
    static func estimateComplexity(
        type: ConflictType,
        ours: String,
        theirs: String
    ) -> ConflictComplexity {
        switch type {
        case .trivial:
            return .auto

        case .binary:
            return .manual

        case .parallel:
            // If changes are small, AI can assist
            let totalLines = ours.components(separatedBy: .newlines).count +
                             theirs.components(separatedBy: .newlines).count
            return totalLines < 50 ? .assisted : .manual

        case .dependent:
            return .assisted

        case .structural:
            return .manual

        case .semantic:
            // Semantic conflicts are complex
            return .manual
        }
    }
}

// MARK: - Conflict Resolution Result

/// Result of attempting to resolve conflicts
struct ConflictResolutionResult: Sendable {
    let resolved: [String]      // Files successfully resolved
    let deferred: [GitConflict] // Conflicts that need manual intervention
    let errors: [String]        // Error messages

    var success: Bool {
        deferred.isEmpty && errors.isEmpty
    }

    var totalResolved: Int {
        resolved.count
    }

    var totalDeferred: Int {
        deferred.count
    }
}

// MARK: - GitMaster Error

/// Errors specific to GitMaster operations
enum GitMasterError: Error, LocalizedError, Sendable {
    case humanInterventionRequired(file: String)
    case noConflictsToResolve
    case mergeInProgress
    case noBranchesToMerge
    case invalidState(message: String)
    case resolutionFailed(file: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .humanInterventionRequired(let file):
            return "Human intervention required for: \(file)"
        case .noConflictsToResolve:
            return "No conflicts to resolve"
        case .mergeInProgress:
            return "A merge operation is already in progress"
        case .noBranchesToMerge:
            return "No branches available to merge"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .resolutionFailed(let file, let reason):
            return "Failed to resolve \(file): \(reason)"
        }
    }
}
