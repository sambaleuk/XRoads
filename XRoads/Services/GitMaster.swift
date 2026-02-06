//
//  GitMaster.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  Intelligent Git resolution agent
//

import Foundation

// MARK: - GitMaster Actor

/// Intelligent Git resolution agent that handles complex merge operations
actor GitMaster {

    private let gitService: GitService

    private(set) var state: GitMasterState

    init(gitService: GitService = GitService()) {
        self.gitService = gitService
        self.state = GitMasterState()
    }

    // MARK: - State Management

    /// Update the GitMaster state
    func updateState(_ update: (inout GitMasterState) -> Void) {
        update(&state)
    }

    /// Reset GitMaster to idle state
    func reset() {
        state.reset()
    }

    /// Set target branch for merging
    func setTargetBranch(_ branch: String) {
        state.targetBranch = branch
    }

    // MARK: - Branch Tracking

    /// Start tracking a branch for merge
    func trackBranch(
        name: String,
        worktreePath: String? = nil,
        agentType: AgentType? = nil
    ) {
        let tracked = TrackedBranch(
            name: name,
            worktreePath: worktreePath,
            agentType: agentType,
            status: .pending
        )
        state.trackedBranches.append(tracked)
    }

    /// Update status of a tracked branch
    func updateBranchStatus(name: String, status: TrackedBranchStatus) {
        if let index = state.trackedBranches.firstIndex(where: { $0.name == name }) {
            state.trackedBranches[index].status = status
        }
    }

    /// Mark a branch as completed (agent finished)
    func markBranchCompleted(name: String, lastCommit: String? = nil, message: String? = nil) {
        if let index = state.trackedBranches.firstIndex(where: { $0.name == name }) {
            state.trackedBranches[index].status = .completed
            state.trackedBranches[index].lastCommit = lastCommit
            state.trackedBranches[index].lastCommitMessage = message
        }

        // Check if all branches are complete
        if state.allBranchesComplete {
            state.mode = .preparing
        }
    }

    /// Remove a tracked branch
    func untrackBranch(name: String) {
        state.trackedBranches.removeAll { $0.name == name }
    }

    /// Clear all tracked branches
    func clearTrackedBranches() {
        state.trackedBranches.removeAll()
    }

    // MARK: - Conflict Analysis

    /// Analyze a single conflict and generate suggestions
    func analyzeConflict(
        file: String,
        repoPath: URL
    ) async throws -> GitConflict {
        // Read file content
        let fileURL = repoPath.appendingPathComponent(file)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Parse conflict markers
        guard let parsed = GitConflict.parseFromContent(
            content,
            file: file,
            oursBranch: state.targetBranch,
            theirsBranch: "incoming"
        ) else {
            throw GitMasterError.invalidState(message: "Could not parse conflict markers in \(file)")
        }

        // Detect type
        let conflictType = GitConflict.detectType(
            ours: parsed.ours,
            theirs: parsed.theirs,
            base: parsed.base
        )

        // Estimate complexity
        let complexity = GitConflict.estimateComplexity(
            type: conflictType,
            ours: parsed.ours,
            theirs: parsed.theirs
        )

        // Generate suggestion if auto-resolvable
        var suggestion: ResolutionStrategy? = nil
        var aiAnalysis: String? = nil

        if complexity == .auto {
            suggestion = generateAutoResolution(
                type: conflictType,
                ours: parsed.ours,
                theirs: parsed.theirs,
                base: parsed.base
            )
            aiAnalysis = "Auto-resolution available: \(conflictType.description)"
        } else if complexity == .assisted {
            // For assisted, we'd typically call an AI service
            // For now, provide basic suggestions
            suggestion = generateAssistedSuggestion(
                type: conflictType,
                ours: parsed.ours,
                theirs: parsed.theirs
            )
            aiAnalysis = "AI analysis: \(conflictType.description). Review suggested resolution."
        }

        return GitConflict(
            file: file,
            oursContent: parsed.ours,
            theirsContent: parsed.theirs,
            baseContent: parsed.base,
            conflictType: conflictType,
            complexity: complexity,
            suggestedResolution: suggestion,
            aiAnalysis: aiAnalysis,
            oursBranch: state.targetBranch,
            theirsBranch: "incoming"
        )
    }

    /// Analyze all conflicts in the repository
    func analyzeAllConflicts(repoPath: URL) async throws -> [GitConflict] {
        state.mode = .resolving
        state.status = .busy

        let conflictedFiles = try await gitService.listConflictedFiles(repoPath: repoPath.path)

        var conflicts: [GitConflict] = []

        for file in conflictedFiles {
            do {
                let conflict = try await analyzeConflict(file: file, repoPath: repoPath)
                conflicts.append(conflict)
            } catch {
                // Create a manual conflict for files we couldn't analyze
                let conflict = GitConflict(
                    file: file,
                    oursContent: "",
                    theirsContent: "",
                    conflictType: .semantic,
                    complexity: .manual,
                    aiAnalysis: "Could not analyze: \(error.localizedDescription)"
                )
                conflicts.append(conflict)
            }
        }

        state.pendingConflicts = conflicts

        // Update status based on conflicts
        if conflicts.isEmpty {
            state.status = .ready
        } else if conflicts.allSatisfy({ $0.complexity == .auto }) {
            state.status = .busy // Can auto-resolve
        } else {
            state.status = .needsAttention
        }

        return conflicts
    }

    // MARK: - Resolution

    /// Generate auto-resolution for trivial conflicts
    private func generateAutoResolution(
        type: ConflictType,
        ours: String,
        theirs: String,
        base: String?
    ) -> ResolutionStrategy {
        switch type {
        case .trivial:
            // For trivial (whitespace) conflicts, prefer theirs (incoming changes)
            return .keepTheirs()

        case .dependent:
            // If changes are dependent, combine them
            if let base = base {
                // Simple combine: base + ours changes + theirs changes
                let combined = combineChanges(base: base, ours: ours, theirs: theirs)
                return .combine(merged: combined)
            }
            return .keepTheirs()

        default:
            return .keepTheirs()
        }
    }

    /// Generate assisted suggestion for more complex conflicts
    private func generateAssistedSuggestion(
        type: ConflictType,
        ours: String,
        theirs: String
    ) -> ResolutionStrategy {
        // For assisted conflicts, try to combine if possible
        // This is a simple heuristic - in production, would use AI

        // If both are small, try to combine
        let oursLines = ours.components(separatedBy: .newlines)
        let theirsLines = theirs.components(separatedBy: .newlines)

        if oursLines.count + theirsLines.count < 30 {
            // Simple combination: ours first, then theirs
            let combined = ours + "\n" + theirs
            return .combine(merged: combined)
        }

        // Default to keeping theirs for larger changes
        return .keepTheirs()
    }

    /// Simple change combiner
    private func combineChanges(base: String, ours: String, theirs: String) -> String {
        let baseLines = Set(base.components(separatedBy: .newlines))
        let oursLines = ours.components(separatedBy: .newlines)
        let theirsLines = theirs.components(separatedBy: .newlines)

        // Get additions from each side
        let oursAdditions = oursLines.filter { !baseLines.contains($0) }
        let theirsAdditions = theirsLines.filter { !baseLines.contains($0) }

        // Combine: base + ours additions + theirs additions
        var result = base.components(separatedBy: .newlines)
        result.append(contentsOf: oursAdditions)
        result.append(contentsOf: theirsAdditions)

        return result.joined(separator: "\n")
    }

    /// Resolve a single conflict
    func resolveConflict(
        conflict: GitConflict,
        strategy: ResolutionStrategy,
        repoPath: URL
    ) async throws {
        let filePath = repoPath.appendingPathComponent(conflict.file)

        switch strategy.type {
        case .keepOurs:
            try await gitService.resolveConflict(
                repoPath: repoPath.path,
                file: conflict.file,
                keepOurs: true
            )

        case .keepTheirs:
            try await gitService.resolveConflict(
                repoPath: repoPath.path,
                file: conflict.file,
                keepOurs: false
            )

        case .combine:
            guard let merged = strategy.mergedContent else {
                throw GitMasterError.resolutionFailed(
                    file: conflict.file,
                    reason: "No merged content provided"
                )
            }
            // Write merged content
            try merged.write(to: filePath, atomically: true, encoding: .utf8)

        case .reorder:
            // Reorder would require more complex logic
            // For now, treat as manual
            throw GitMasterError.humanInterventionRequired(file: conflict.file)

        case .defer_:
            throw GitMasterError.humanInterventionRequired(file: conflict.file)
        }

        // Stage the resolved file
        try await gitService.stageFile(repoPath: repoPath.path, file: conflict.file)

        // Update state
        state.resolvedFiles.append(conflict.file)
        state.pendingConflicts.removeAll { $0.id == conflict.id }
    }

    /// Resolve all auto-resolvable conflicts
    func resolveAutoConflicts(repoPath: URL) async throws -> ConflictResolutionResult {
        var resolved: [String] = []
        var deferred: [GitConflict] = []
        var errors: [String] = []

        for conflict in state.pendingConflicts {
            if conflict.complexity == .auto, let strategy = conflict.suggestedResolution {
                do {
                    try await resolveConflict(
                        conflict: conflict,
                        strategy: strategy,
                        repoPath: repoPath
                    )
                    resolved.append(conflict.file)
                } catch {
                    errors.append("\(conflict.file): \(error.localizedDescription)")
                    deferred.append(conflict)
                }
            } else {
                deferred.append(conflict)
            }
        }

        return ConflictResolutionResult(
            resolved: resolved,
            deferred: deferred,
            errors: errors
        )
    }

    // MARK: - Merge Operations

    /// Simple branch info for merge operations
    struct BranchToMerge {
        let name: String
        let id: UUID
    }

    /// Prepare a merge by checking for conflicts (dry-run)
    func prepareMerge(repoPath: URL) async throws -> [String: [String]] {
        state.mode = .preparing
        state.status = .busy

        let completedBranches = state.trackedBranches.filter { $0.status == .completed }

        guard !completedBranches.isEmpty else {
            throw GitMasterError.noBranchesToMerge
        }

        // Checkout target branch
        try await gitService.checkout(branch: state.targetBranch, repoPath: repoPath.path)

        var conflictsByBranch: [String: [String]] = [:]

        // Dry-run merge for each branch to detect conflicts
        for branch in completedBranches {
            do {
                try await gitService.merge(
                    branch: branch.name,
                    repoPath: repoPath.path,
                    noCommit: true,
                    noFastForward: true
                )
                try await gitService.resetHard(repoPath: repoPath.path)
                conflictsByBranch[branch.name] = [] // No conflicts
            } catch {
                let files = try await gitService.listConflictedFiles(repoPath: repoPath.path)
                conflictsByBranch[branch.name] = files
                try? await gitService.abortMerge(repoPath: repoPath.path)
            }
        }

        // Update state based on conflicts
        let hasConflicts = conflictsByBranch.values.contains { !$0.isEmpty }

        if hasConflicts {
            state.mode = .resolving
            state.status = .needsAttention
        } else {
            state.mode = .reviewing
            state.status = .ready
        }

        return conflictsByBranch
    }

    /// Execute merge for all completed branches
    func executeMerge(repoPath: URL) async throws -> MergeResult {
        state.mode = .merging
        state.status = .busy

        let completedBranches = state.trackedBranches.filter { $0.status == .completed }

        guard !completedBranches.isEmpty else {
            throw GitMasterError.noBranchesToMerge
        }

        // Checkout target branch
        try await gitService.checkout(branch: state.targetBranch, repoPath: repoPath.path)

        var mergedBranches: [String] = []
        var conflicts: [MergeConflict] = []
        var rolledBack = false

        for branch in completedBranches {
            do {
                try await gitService.merge(
                    branch: branch.name,
                    repoPath: repoPath.path,
                    noCommit: false,
                    noFastForward: true
                )
                mergedBranches.append(branch.name)
                updateBranchStatus(name: branch.name, status: .merged)
            } catch GitError.commandFailed(_, _, let stderr) {
                let files = try await gitService.listConflictedFiles(repoPath: repoPath.path)
                conflicts.append(
                    MergeConflict(
                        branch: branch.name,
                        files: files,
                        message: stderr
                    )
                )
                try? await gitService.abortMerge(repoPath: repoPath.path)
                rolledBack = true
                break
            }
        }

        let result = MergeResult(
            baseBranch: state.targetBranch,
            mergedBranches: mergedBranches,
            conflicts: conflicts,
            success: conflicts.isEmpty,
            rolledBack: rolledBack
        )

        // Update state
        if result.success {
            state.mode = .idle
            state.status = .success
            state.lastMergeResult = result
        } else {
            state.mode = .resolving
            state.status = .needsAttention
            _ = try await analyzeAllConflicts(repoPath: repoPath)
        }

        return result
    }

    /// Full merge workflow: prepare, analyze, resolve auto, execute
    func performFullMerge(repoPath: URL) async throws -> MergeResult {
        // 1. Prepare merge (dry-run)
        let conflictsByBranch = try await prepareMerge(repoPath: repoPath)

        // 2. Check for conflicts
        let hasConflicts = conflictsByBranch.values.contains { !$0.isEmpty }

        if hasConflicts {
            // 3. Attempt actual merge
            let initialResult = try await executeMerge(repoPath: repoPath)

            if !initialResult.success {
                // 4. Analyze conflicts
                _ = try await analyzeAllConflicts(repoPath: repoPath)

                // 5. Auto-resolve what we can
                let resolution = try await resolveAutoConflicts(repoPath: repoPath)

                if resolution.success {
                    // All conflicts resolved
                    state.mode = .idle
                    state.status = .success

                    return MergeResult(
                        baseBranch: state.targetBranch,
                        mergedBranches: resolution.resolved,
                        conflicts: [],
                        success: true,
                        rolledBack: false
                    )
                } else {
                    // Still have conflicts
                    let remaining = resolution.deferred.map {
                        MergeConflict(
                            branch: $0.theirsBranch,
                            files: [$0.file],
                            message: $0.aiAnalysis ?? "Manual resolution required"
                        )
                    }

                    state.mode = .reviewing
                    state.status = .needsAttention

                    return MergeResult(
                        baseBranch: state.targetBranch,
                        mergedBranches: resolution.resolved,
                        conflicts: remaining,
                        success: false,
                        rolledBack: false
                    )
                }
            }

            return initialResult
        }

        // No conflicts predicted, execute directly
        return try await executeMerge(repoPath: repoPath)
    }
}
