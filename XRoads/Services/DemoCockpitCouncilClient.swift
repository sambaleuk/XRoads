import Foundation

// MARK: - DemoCockpitCouncilClient

/// Offline demo council client for testing Cockpit Mode without the
/// cockpit-council Python module. Returns 3 sample slot assignments.
final class DemoCockpitCouncilClient: CockpitCouncilClientProtocol, @unchecked Sendable {

    func deliberate(input: ChairmanInput) async throws -> ChairmanOutput {
        // Simulate Chairman deliberation delay
        try await Task.sleep(for: .milliseconds(800))

        let projectName = (input.projectPath as NSString).lastPathComponent

        return ChairmanOutput(
            decision: "Demo mode: assigning 3 agents to \(projectName)",
            summary: """
                ## Chairman Brief (Demo)
                Project: \(projectName)
                Branches: \(input.openBranches.joined(separator: ", "))
                PRD: \(input.prdSummary?.featureName ?? "none")
                Agents: 3 slots assigned for parallel development.
                """,
            assignments: [
                SlotAssignment(
                    slotIndex: 0,
                    skillName: "code-architect",
                    agentType: "claude",
                    branch: "xroads/slot-0-architect",
                    taskDescription: "Architecture review and scaffolding"
                ),
                SlotAssignment(
                    slotIndex: 1,
                    skillName: "feature-builder",
                    agentType: "claude",
                    branch: "xroads/slot-1-feature",
                    taskDescription: "Implement core feature logic"
                ),
                SlotAssignment(
                    slotIndex: 2,
                    skillName: "test-engineer",
                    agentType: "gemini",
                    branch: "xroads/slot-2-tests",
                    taskDescription: "Write comprehensive test suite"
                ),
            ]
        )
    }
}
