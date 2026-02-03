import Foundation

/// Coordinates merging worktree branches back into the base branch.
actor MergeCoordinator {

    private let gitService: GitService

    init(gitService: GitService = GitService()) {
        self.gitService = gitService
    }

    func prepareMerge(
        assignments: [WorktreeAssignment],
        repoPath: URL,
        baseBranch: String? = nil
    ) async throws -> MergePlan {
        let base = try await resolveBaseBranch(baseBranch: baseBranch, repoPath: repoPath)
        guard !assignments.isEmpty else {
            return MergePlan(baseBranch: base, steps: [], createdAt: Date())
        }

        try await gitService.checkout(branch: base, repoPath: repoPath.path)

        var steps: [MergePlanStep] = []

        for assignment in assignments {
            var predictedConflicts: [String] = []
            var status: MergeStepStatus = .ready
            do {
                try await gitService.merge(
                    branch: assignment.branchName,
                    repoPath: repoPath.path,
                    noCommit: true,
                    noFastForward: true
                )
                try await gitService.resetHard(repoPath: repoPath.path)
            } catch GitError.commandFailed {
                predictedConflicts = try await gitService.listConflictedFiles(repoPath: repoPath.path)
                try? await gitService.abortMerge(repoPath: repoPath.path)
                status = .blocked
            }

            steps.append(
                MergePlanStep(
                    id: assignment.id,
                    assignment: assignment,
                    status: status,
                    predictedConflicts: predictedConflicts
                )
            )
        }

        return MergePlan(baseBranch: base, steps: steps, createdAt: Date())
    }

    func executeMerge(plan: MergePlan, repoPath: URL) async throws -> MergeResult {
        guard !plan.steps.isEmpty else {
            return MergeResult(baseBranch: plan.baseBranch, mergedBranches: [], conflicts: [], success: true, rolledBack: false)
        }

        try await gitService.checkout(branch: plan.baseBranch, repoPath: repoPath.path)

        var mergedBranches: [String] = []
        var conflicts: [MergeConflict] = []
        var rolledBack = false

        for step in plan.steps {
            guard step.status == .ready else {
                conflicts.append(
                    MergeConflict(
                        branch: step.assignment.branchName,
                        files: step.predictedConflicts,
                        message: "Merge blocked during preparation"
                    )
                )
                continue
            }

            do {
                try await gitService.merge(
                    branch: step.assignment.branchName,
                    repoPath: repoPath.path,
                    noCommit: false,
                    noFastForward: true
                )
                mergedBranches.append(step.assignment.branchName)
            } catch GitError.commandFailed(_, _, let stderr) {
                let files = try await gitService.listConflictedFiles(repoPath: repoPath.path)
                conflicts.append(
                    MergeConflict(
                        branch: step.assignment.branchName,
                        files: files,
                        message: stderr
                    )
                )
                try? await gitService.abortMerge(repoPath: repoPath.path)
                rolledBack = true
                break
            }
        }

        return MergeResult(
            baseBranch: plan.baseBranch,
            mergedBranches: mergedBranches,
            conflicts: conflicts,
            success: conflicts.isEmpty,
            rolledBack: rolledBack
        )
    }
}

private extension MergeCoordinator {
    func resolveBaseBranch(baseBranch: String?, repoPath: URL) async throws -> String {
        if let baseBranch {
            return baseBranch
        }
        return try await gitService.getCurrentBranch(path: repoPath.path)
    }
}
