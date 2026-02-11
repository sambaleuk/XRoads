//
//  DebugDispatcher.swift
//  XRoads
//
//  Generates a structured debug PRD from a BugReport and dispatches it
//  through the existing LayeredDispatcher pipeline.
//

import Foundation

// MARK: - DebugDispatcher

/// Generates a debug PRD from a BugReport and dispatches via LayeredDispatcher.
///
/// The debug workflow organizes investigation into dependency layers:
/// - Layer 0 (Recon): Reproduce, blast radius analysis, regression detection
/// - Layer 1 (Diagnosis): Hypothesis investigation
/// - Layer 2 (Fix): Minimal fix + guard tests
/// - Layer 3 (Verification): Full suite + pattern scan
/// - Layer 4 (Capitalisation): RETEX + knowledge update
actor DebugDispatcher {

    // MARK: - Types

    /// Slot assignment tuple matching LayeredDispatcher's expected format
    typealias SlotAssignment = (agentType: AgentType, actionType: ActionType, storyIds: [String])

    // MARK: - Public API

    /// Generate a debug PRD and slot assignments from a bug report.
    ///
    /// Adapts the number of stories and layers based on available slot count:
    /// - 2 slots: Collapsed recon + collapsed fix (3 layers)
    /// - 3 slots: Full recon, merged hypothesis+fix (4 layers)
    /// - 4+ slots: Full 5-layer plan
    func generateDebugPRD(
        report: BugReport,
        slotCount: Int
    ) -> (prd: PRDDocument, assignments: [Int: SlotAssignment]) {
        let stories: [PRDUserStory]
        let assignments: [Int: SlotAssignment]

        if slotCount <= 2 {
            (stories, assignments) = generateCollapsedPlan(report: report, slotCount: slotCount)
        } else if slotCount == 3 {
            (stories, assignments) = generateMediumPlan(report: report)
        } else {
            (stories, assignments) = generateFullPlan(report: report, slotCount: slotCount)
        }

        let prd = PRDDocument(
            featureName: "Debug: \(report.signal.prefix(60))",
            description: buildPRDDescription(report: report),
            author: "DebugDispatcher",
            templateType: .custom,
            userStories: stories,
            bugReport: report
        )

        return (prd, assignments)
    }

    /// Dispatch a debug workflow: generate PRD, then delegate to UnifiedDispatcher.
    func dispatch(
        report: BugReport,
        slotCount: Int,
        repoPath: URL,
        dispatcher: UnifiedDispatcher,
        callbacks: DispatchCallbacks
    ) async throws -> DispatchResult {
        let (prd, assignments) = generateDebugPRD(report: report, slotCount: slotCount)

        let request = DispatchRequest(
            mode: .debug,
            source: .quickAction,
            prd: prd,
            slotAssignments: assignments,
            repoPath: repoPath
        )

        return try await dispatcher.dispatch(request, callbacks: callbacks)
    }

    // MARK: - Full Plan (4+ slots, 5 layers)

    private func generateFullPlan(
        report: BugReport,
        slotCount: Int
    ) -> ([PRDUserStory], [Int: SlotAssignment]) {
        let priority = report.severity.priority
        var stories: [PRDUserStory] = []

        // Layer 0: Recon (parallel)
        let repro = makeStory(
            id: "BUG-REPRO", title: "Reproduce bug with failing test",
            description: "Write a minimal failing test that demonstrates: \(report.signal)",
            priority: priority, dependsOn: []
        )
        let blast = makeStory(
            id: "BUG-BLAST", title: "Map blast radius of affected code",
            description: "Identify all callers, contracts, and coverage for affected area",
            priority: priority, dependsOn: []
        )
        let regr = makeStory(
            id: "BUG-REGR", title: "Detect regression origin",
            description: "Use git blame/bisect to find when the bug was introduced\(report.suspectCommit.map { ". Suspect commit: \($0)" } ?? "")",
            priority: priority, dependsOn: []
        )
        stories.append(contentsOf: [repro, blast, regr])

        // Layer 1: Diagnosis (parallel, depends on recon)
        let h1 = makeStory(
            id: "BUG-H1", title: "Investigate hypothesis from reproduction",
            description: "Analyze the failing test to form and investigate a root-cause hypothesis",
            priority: priority, dependsOn: ["BUG-REPRO", "BUG-BLAST"]
        )
        let h2 = makeStory(
            id: "BUG-H2", title: "Investigate hypothesis from blast radius",
            description: "Use blast radius + regression data to explore an alternative hypothesis",
            priority: priority, dependsOn: ["BUG-REPRO", "BUG-BLAST"]
        )
        stories.append(contentsOf: [h1, h2])

        // Layer 2: Fix (parallel, depends on diagnosis)
        let fix = makeStory(
            id: "BUG-FIX", title: "Implement minimal fix",
            description: "Implement the minimal fix. The repro test MUST go GREEN.",
            priority: priority, dependsOn: ["BUG-H1", "BUG-H2"]
        )
        let guard_ = makeStory(
            id: "BUG-GUARD", title: "Write non-regression tests",
            description: "Write tests for callers and edge cases to prevent regression",
            priority: priority, dependsOn: ["BUG-H1", "BUG-H2"]
        )
        stories.append(contentsOf: [fix, guard_])

        // Layer 3: Verification (parallel, depends on fix)
        let suite = makeStory(
            id: "BUG-SUITE", title: "Run full test suite",
            description: "Run `swift build && swift test` and report results",
            priority: .high, dependsOn: ["BUG-FIX", "BUG-GUARD"]
        )
        let scan = makeStory(
            id: "BUG-SCAN", title: "Scan for same anti-pattern",
            description: "Search the entire codebase for the same anti-pattern that caused this bug",
            priority: .medium, dependsOn: ["BUG-FIX", "BUG-GUARD"]
        )
        stories.append(contentsOf: [suite, scan])

        // Layer 4: Capitalisation
        let retex = makeStory(
            id: "BUG-RETEX", title: "Write RETEX document",
            description: "Write a RETEX (lessons learned) document and update project knowledge base",
            priority: .low, dependsOn: ["BUG-SUITE", "BUG-SCAN"]
        )
        stories.append(retex)

        // Build slot assignments: distribute stories across available slots round-robin per layer
        let assignments = buildAssignments(stories: stories, slotCount: slotCount)

        return (stories, assignments)
    }

    // MARK: - Medium Plan (3 slots, 4 layers)

    private func generateMediumPlan(
        report: BugReport
    ) -> ([PRDUserStory], [Int: SlotAssignment]) {
        let priority = report.severity.priority
        var stories: [PRDUserStory] = []

        // Layer 0: Full recon (3 parallel stories)
        stories.append(makeStory(
            id: "BUG-REPRO", title: "Reproduce bug with failing test",
            description: "Write a minimal failing test that demonstrates: \(report.signal)",
            priority: priority, dependsOn: []
        ))
        stories.append(makeStory(
            id: "BUG-BLAST", title: "Map blast radius of affected code",
            description: "Identify all callers, contracts, and coverage for affected area",
            priority: priority, dependsOn: []
        ))
        stories.append(makeStory(
            id: "BUG-REGR", title: "Detect regression origin",
            description: "Use git blame/bisect to find when the bug was introduced\(report.suspectCommit.map { ". Suspect commit: \($0)" } ?? "")",
            priority: priority, dependsOn: []
        ))

        // Layer 1: Merged hypothesis + fix (depends on recon)
        stories.append(makeStory(
            id: "BUG-H1", title: "Investigate and implement fix",
            description: "Analyze reproduction + blast radius, form hypothesis, implement minimal fix. Repro test MUST go GREEN.",
            priority: priority, dependsOn: ["BUG-REPRO", "BUG-BLAST", "BUG-REGR"]
        ))
        stories.append(makeStory(
            id: "BUG-GUARD", title: "Write non-regression tests",
            description: "Write tests for callers and edge cases to prevent regression",
            priority: priority, dependsOn: ["BUG-REPRO", "BUG-BLAST", "BUG-REGR"]
        ))

        // Layer 2: Verification
        stories.append(makeStory(
            id: "BUG-SUITE", title: "Run full test suite",
            description: "Run `swift build && swift test` and report results",
            priority: .high, dependsOn: ["BUG-H1", "BUG-GUARD"]
        ))
        stories.append(makeStory(
            id: "BUG-SCAN", title: "Scan for same anti-pattern",
            description: "Search the entire codebase for the same anti-pattern that caused this bug",
            priority: .medium, dependsOn: ["BUG-H1", "BUG-GUARD"]
        ))

        // Layer 3: Capitalisation
        stories.append(makeStory(
            id: "BUG-RETEX", title: "Write RETEX document",
            description: "Write a RETEX (lessons learned) document and update project knowledge base",
            priority: .low, dependsOn: ["BUG-SUITE", "BUG-SCAN"]
        ))

        let assignments = buildAssignments(stories: stories, slotCount: 3)
        return (stories, assignments)
    }

    // MARK: - Collapsed Plan (2 slots, 3 layers)

    private func generateCollapsedPlan(
        report: BugReport,
        slotCount: Int
    ) -> ([PRDUserStory], [Int: SlotAssignment]) {
        let priority = report.severity.priority
        var stories: [PRDUserStory] = []

        // Layer 0: Merged recon
        stories.append(makeStory(
            id: "BUG-REPRO", title: "Reproduce and analyze bug",
            description: "Reproduce the bug with a failing test, map blast radius, and check git blame. Signal: \(report.signal)",
            priority: priority, dependsOn: []
        ))

        // Layer 1: Fix + guard (depends on recon)
        stories.append(makeStory(
            id: "BUG-FIX", title: "Investigate, fix, and guard",
            description: "Investigate root cause, implement minimal fix (repro test MUST go GREEN), write non-regression tests",
            priority: priority, dependsOn: ["BUG-REPRO"]
        ))

        // Layer 2: Verify + capitalise
        stories.append(makeStory(
            id: "BUG-SUITE", title: "Verify and write RETEX",
            description: "Run full test suite, scan for same anti-pattern elsewhere, write RETEX document",
            priority: .high, dependsOn: ["BUG-FIX"]
        ))

        let effectiveSlots = min(slotCount, 2)
        let assignments = buildAssignments(stories: stories, slotCount: effectiveSlots)
        return (stories, assignments)
    }

    // MARK: - Helpers

    private func makeStory(
        id: String,
        title: String,
        description: String,
        priority: PRDPriority,
        dependsOn: [String]
    ) -> PRDUserStory {
        PRDUserStory(
            id: id,
            title: title,
            description: description,
            priority: priority,
            status: dependsOn.isEmpty ? .pending : .blocked,
            acceptanceCriteria: [],
            dependsOn: dependsOn,
            estimatedComplexity: 3
        )
    }

    /// Build slot assignments by distributing stories across available slots.
    /// Stories are grouped by layer (via dependencies), then assigned round-robin.
    private func buildAssignments(
        stories: [PRDUserStory],
        slotCount: Int
    ) -> [Int: SlotAssignment] {
        var assignments: [Int: SlotAssignment] = [:]

        // Group stories by their dependency layer
        let layers = computeLayers(stories: stories)

        // For each layer, assign stories round-robin to slots
        var slotIndex = 0
        for layer in layers {
            for story in layer {
                let slot = (slotIndex % slotCount) + 1
                let role = inferRole(storyId: story.id)
                let agent = role?.preferredAgent ?? .claude

                if let existing = assignments[slot] {
                    var ids = existing.storyIds
                    ids.append(story.id)
                    assignments[slot] = (agentType: existing.agentType, actionType: .debug, storyIds: ids)
                } else {
                    assignments[slot] = (agentType: agent, actionType: .debug, storyIds: [story.id])
                }
                slotIndex += 1
            }
        }

        return assignments
    }

    /// Compute layers from story dependency graph (topological sort by depth)
    private func computeLayers(stories: [PRDUserStory]) -> [[PRDUserStory]] {
        let storyMap = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
        var depths: [String: Int] = [:]

        func depth(of id: String) -> Int {
            if let cached = depths[id] { return cached }
            guard let story = storyMap[id] else { return 0 }
            if story.dependsOn.isEmpty {
                depths[id] = 0
                return 0
            }
            let d = story.dependsOn.map { depth(of: $0) }.max()! + 1
            depths[id] = d
            return d
        }

        for story in stories {
            _ = depth(of: story.id)
        }

        let maxDepth = depths.values.max() ?? 0
        var layers: [[PRDUserStory]] = []
        for d in 0...maxDepth {
            let layerStories = stories.filter { depths[$0.id] == d }
            if !layerStories.isEmpty {
                layers.append(layerStories)
            }
        }

        return layers
    }

    /// Infer the DebugRole from a story ID prefix
    private func inferRole(storyId: String) -> DebugRole? {
        if storyId.hasPrefix("BUG-REPRO") { return .reproducer }
        if storyId.hasPrefix("BUG-BLAST") { return .blastRadiusAnalyst }
        if storyId.hasPrefix("BUG-REGR") { return .regressionDetector }
        if storyId.hasPrefix("BUG-H") { return .investigator }
        if storyId.hasPrefix("BUG-FIX") { return .fixAuthor }
        if storyId.hasPrefix("BUG-GUARD") { return .guardAuthor }
        if storyId.hasPrefix("BUG-SUITE") { return .suiteRunner }
        if storyId.hasPrefix("BUG-SCAN") { return .patternScanner }
        if storyId.hasPrefix("BUG-RETEX") { return .retexAuthor }
        return nil
    }

    private func buildPRDDescription(report: BugReport) -> String {
        var lines: [String] = []
        lines.append("## Bug Report")
        lines.append("")
        lines.append("**Signal:** \(report.signal)")
        lines.append("**Expected:** \(report.expected)")
        lines.append("**Actual:** \(report.actual)")
        lines.append("**Severity:** \(report.severity.displayName)")
        lines.append("**Reproducibility:** \(report.reproducibility.displayName)")

        if !report.affectedFiles.isEmpty {
            lines.append("**Affected files:** \(report.affectedFiles.joined(separator: ", "))")
        }
        if let trace = report.stackTrace {
            lines.append("")
            lines.append("### Stack Trace")
            lines.append("```")
            lines.append(trace)
            lines.append("```")
        }
        if let commit = report.suspectCommit {
            lines.append("**Suspect commit:** \(commit)")
        }

        return lines.joined(separator: "\n")
    }
}
