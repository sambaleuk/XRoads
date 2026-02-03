import Foundation

// MARK: - ImplementActionError

/// Errors that can occur during implement action execution
enum ImplementActionError: LocalizedError {
    case prdNotFound(path: String)
    case prdParsingFailed(underlying: Error)
    case noPendingStories
    case storyNotFound(id: String)
    case dependencyNotComplete(story: String, dependency: String)
    case circularDependency(stories: [String])
    case planGenerationFailed(reason: String)
    case storyImplementationFailed(storyId: String, reason: String)
    case buildFailed(output: String)
    case testsFailed(output: String)
    case commitFailed(storyId: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .prdNotFound(let path):
            return "PRD file not found at: \(path)"
        case .prdParsingFailed(let underlying):
            return "Failed to parse PRD: \(underlying.localizedDescription)"
        case .noPendingStories:
            return "No pending stories found in PRD"
        case .storyNotFound(let id):
            return "Story '\(id)' not found in PRD"
        case .dependencyNotComplete(let story, let dependency):
            return "Story '\(story)' depends on '\(dependency)' which is not complete"
        case .circularDependency(let stories):
            return "Circular dependency detected: \(stories.joined(separator: " → "))"
        case .planGenerationFailed(let reason):
            return "Failed to generate implementation plan: \(reason)"
        case .storyImplementationFailed(let storyId, let reason):
            return "Failed to implement story '\(storyId)': \(reason)"
        case .buildFailed(let output):
            return "Build failed: \(output)"
        case .testsFailed(let output):
            return "Tests failed: \(output)"
        case .commitFailed(let storyId, let reason):
            return "Failed to commit story '\(storyId)': \(reason)"
        }
    }
}

// MARK: - ImplementationPlan

/// An implementation plan for a single user story
struct StoryImplementationPlan: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let storyId: String
    let title: String
    let description: String
    let priority: TaskPriority
    let dependencies: [String]
    let acceptanceCriteria: [String]
    let unitTests: [String]
    let filesToCreate: [String]
    let filesToModify: [String]
    let estimatedComplexity: Int

    /// Whether all dependencies have been completed
    var dependenciesComplete: Bool = false

    /// Status of this story's implementation
    var status: StoryImplementationStatus = .pending

    /// Timestamp when implementation started
    var startedAt: Date?

    /// Timestamp when implementation completed
    var completedAt: Date?

    /// Commit SHA after successful implementation
    var commitSHA: String?

    /// Error message if implementation failed
    var errorMessage: String?
}

/// Status of a story implementation
enum StoryImplementationStatus: String, Codable, Sendable {
    case pending
    case ready           // Dependencies complete, ready to implement
    case inProgress
    case implemented     // Code done, needs testing
    case tested          // Tests passing
    case committed
    case failed

    var isComplete: Bool {
        self == .committed
    }

    var canStart: Bool {
        self == .ready
    }
}

/// Full implementation plan for a PRD
struct ImplementationPlan: Identifiable, Codable, Sendable {
    let id: UUID
    let prdPath: String
    let featureName: String
    let description: String
    var stories: [StoryImplementationPlan]
    let createdAt: Date
    var updatedAt: Date

    /// Total number of stories
    var totalStories: Int { stories.count }

    /// Number of completed stories
    var completedStories: Int {
        stories.filter { $0.status.isComplete }.count
    }

    /// Progress as a percentage (0.0 - 1.0)
    var progress: Double {
        guard totalStories > 0 else { return 0.0 }
        return Double(completedStories) / Double(totalStories)
    }

    /// Whether all stories are complete
    var isComplete: Bool {
        completedStories == totalStories
    }

    /// Get the next story ready to implement
    var nextReadyStory: StoryImplementationPlan? {
        stories.first { $0.status == .ready }
    }

    /// Get all stories in implementation order (respecting dependencies)
    var orderedStories: [StoryImplementationPlan] {
        topologicalSort(stories)
    }

    /// Topological sort to respect dependencies
    private func topologicalSort(_ stories: [StoryImplementationPlan]) -> [StoryImplementationPlan] {
        var result: [StoryImplementationPlan] = []
        var visited = Set<String>()
        let storyMap = Dictionary(uniqueKeysWithValues: stories.map { ($0.storyId, $0) })

        func visit(_ storyId: String) {
            guard !visited.contains(storyId),
                  let story = storyMap[storyId] else { return }

            visited.insert(storyId)

            // Visit dependencies first
            for depId in story.dependencies {
                visit(depId)
            }

            result.append(story)
        }

        // Sort by priority (critical first) then by dependency order
        let sortedByPriority = stories.sorted { $0.priority.weight > $1.priority.weight }
        for story in sortedByPriority {
            visit(story.storyId)
        }

        return result
    }
}

// MARK: - Story Completion Tracking

/// Tracks the completion status of stories in a PRD
struct StoryCompletionTracker: Sendable {
    private var completedStories: Set<String>
    private var failedStories: Set<String>
    private var inProgressStory: String?

    init() {
        self.completedStories = []
        self.failedStories = []
        self.inProgressStory = nil
    }

    mutating func markStarted(_ storyId: String) {
        inProgressStory = storyId
    }

    mutating func markCompleted(_ storyId: String) {
        completedStories.insert(storyId)
        if inProgressStory == storyId {
            inProgressStory = nil
        }
    }

    mutating func markFailed(_ storyId: String) {
        failedStories.insert(storyId)
        if inProgressStory == storyId {
            inProgressStory = nil
        }
    }

    func isCompleted(_ storyId: String) -> Bool {
        completedStories.contains(storyId)
    }

    func isFailed(_ storyId: String) -> Bool {
        failedStories.contains(storyId)
    }

    func isInProgress(_ storyId: String) -> Bool {
        inProgressStory == storyId
    }

    func areDependenciesComplete(_ dependencies: [String]) -> Bool {
        dependencies.allSatisfy { completedStories.contains($0) }
    }

    var currentStory: String? { inProgressStory }
    var completedCount: Int { completedStories.count }
    var failedCount: Int { failedStories.count }
}

// MARK: - Extended PRD Parsing

/// Extended PRD structure with implementation details
struct ExtendedPRDUserStory: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let priority: String
    let status: String
    let completedAt: String?
    let dependsOn: [String]
    let acceptanceCriteria: [String]
    let unitTests: [String]
    let filesToCreate: [String]
    let filesToModify: [String]
    let estimatedComplexity: Int

    enum CodingKeys: String, CodingKey {
        case id, title, description, priority, status
        case completedAt = "completed_at"
        case dependsOn = "depends_on"
        case acceptanceCriteria = "acceptance_criteria"
        case unitTests = "unit_tests"
        case filesToCreate = "files_to_create"
        case filesToModify = "files_to_modify"
        case estimatedComplexity = "estimated_complexity"
    }

    /// Whether this story is already complete in the PRD
    var isComplete: Bool {
        status.lowercased() == "complete"
    }

    /// Convert to TaskPriority
    var taskPriority: TaskPriority {
        TaskPriority(rawValue: priority.lowercased()) ?? .medium
    }
}

/// Extended PRD document with full story details
struct ExtendedPRDDocument: Codable, Sendable {
    let version: String?
    let featureName: String
    let description: String
    let userStories: [ExtendedPRDUserStory]

    enum CodingKeys: String, CodingKey {
        case version
        case featureName = "feature_name"
        case description
        case userStories = "user_stories"
    }
}

// MARK: - ImplementAction

/// The 'implement' action that processes PRD → User Stories → Code + Unit Tests
/// This action:
/// 1. Loads and parses the prd.json from the repository
/// 2. Identifies pending user stories and their dependencies
/// 3. Generates an implementation plan respecting dependency order
/// 4. Tracks story completion as code is generated
/// 5. Commits changes per story (code + tests together)
actor ImplementAction {

    // MARK: - Dependencies

    private let prdParser: PRDParser
    private let fileManager: FileManager

    // MARK: - State

    private var currentPlan: ImplementationPlan?
    private var tracker: StoryCompletionTracker

    // MARK: - Initialization

    init(prdParser: PRDParser = PRDParser()) {
        self.prdParser = prdParser
        self.fileManager = .default
        self.tracker = StoryCompletionTracker()
    }

    // MARK: - Public API

    /// Load and parse the PRD from the specified path
    /// - Parameter prdPath: Path to the prd.json file
    /// - Returns: The parsed extended PRD document
    func loadPRD(from prdPath: String) async throws -> ExtendedPRDDocument {
        guard fileManager.fileExists(atPath: prdPath) else {
            throw ImplementActionError.prdNotFound(path: prdPath)
        }

        let url = URL(fileURLWithPath: prdPath)
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(ExtendedPRDDocument.self, from: data)
        } catch {
            throw ImplementActionError.prdParsingFailed(underlying: error)
        }
    }

    /// Parse user stories from the PRD and extract pending ones
    /// - Parameter prd: The parsed PRD document
    /// - Returns: Array of pending stories in dependency order
    func parsePendingStories(from prd: ExtendedPRDDocument) throws -> [ExtendedPRDUserStory] {
        // Filter out completed stories
        let pendingStories = prd.userStories.filter { !$0.isComplete }

        if pendingStories.isEmpty {
            throw ImplementActionError.noPendingStories
        }

        // Validate dependencies exist
        let allStoryIds = Set(prd.userStories.map { $0.id })
        for story in pendingStories {
            for dep in story.dependsOn {
                guard allStoryIds.contains(dep) else {
                    throw ImplementActionError.storyNotFound(id: dep)
                }
            }
        }

        // Check for circular dependencies
        try validateNoCycles(stories: pendingStories)

        // Sort by dependency order (topological sort)
        return sortByDependencies(pendingStories, allStories: prd.userStories)
    }

    /// Generate an implementation plan for the PRD
    /// - Parameters:
    ///   - prdPath: Path to the PRD file
    ///   - prd: The parsed PRD document
    /// - Returns: The generated implementation plan
    func generatePlan(prdPath: String, prd: ExtendedPRDDocument) throws -> ImplementationPlan {
        let completedStoryIds = Set(prd.userStories.filter { $0.isComplete }.map { $0.id })

        // Convert stories to implementation plans
        let storyPlans: [StoryImplementationPlan] = prd.userStories.compactMap { story in
            // Skip already completed stories
            guard !story.isComplete else { return nil }

            // Determine if dependencies are complete
            let depsComplete = story.dependsOn.allSatisfy { completedStoryIds.contains($0) }

            return StoryImplementationPlan(
                id: UUID().uuidString,
                storyId: story.id,
                title: story.title,
                description: story.description,
                priority: story.taskPriority,
                dependencies: story.dependsOn,
                acceptanceCriteria: story.acceptanceCriteria,
                unitTests: story.unitTests,
                filesToCreate: story.filesToCreate,
                filesToModify: story.filesToModify,
                estimatedComplexity: story.estimatedComplexity,
                dependenciesComplete: depsComplete,
                status: depsComplete ? .ready : .pending
            )
        }

        guard !storyPlans.isEmpty else {
            throw ImplementActionError.noPendingStories
        }

        let plan = ImplementationPlan(
            id: UUID(),
            prdPath: prdPath,
            featureName: prd.featureName,
            description: prd.description,
            stories: storyPlans,
            createdAt: Date(),
            updatedAt: Date()
        )

        currentPlan = plan
        return plan
    }

    /// Get the next story that is ready to be implemented
    /// - Returns: The next ready story, or nil if none are ready
    func getNextReadyStory() -> StoryImplementationPlan? {
        currentPlan?.nextReadyStory
    }

    /// Get stories in the correct implementation order
    /// - Returns: Ordered array of story plans
    func getOrderedStories() -> [StoryImplementationPlan] {
        currentPlan?.orderedStories ?? []
    }

    /// Mark a story as started
    /// - Parameter storyId: The story ID to mark
    func markStoryStarted(_ storyId: String) {
        tracker.markStarted(storyId)
        updateStoryStatus(storyId, status: .inProgress, startedAt: Date())
    }

    /// Mark a story as implemented (code done, needs testing)
    /// - Parameter storyId: The story ID to mark
    func markStoryImplemented(_ storyId: String) {
        updateStoryStatus(storyId, status: .implemented)
    }

    /// Mark a story as tested (tests passing)
    /// - Parameter storyId: The story ID to mark
    func markStoryTested(_ storyId: String) {
        updateStoryStatus(storyId, status: .tested)
    }

    /// Mark a story as completed and committed
    /// - Parameters:
    ///   - storyId: The story ID to mark
    ///   - commitSHA: The commit SHA
    func markStoryCompleted(_ storyId: String, commitSHA: String) {
        tracker.markCompleted(storyId)
        updateStoryStatus(storyId, status: .committed, completedAt: Date(), commitSHA: commitSHA)

        // Update dependencies for other stories
        updateDependencyStatus()
    }

    /// Mark a story as failed
    /// - Parameters:
    ///   - storyId: The story ID to mark
    ///   - error: The error message
    func markStoryFailed(_ storyId: String, error: String) {
        tracker.markFailed(storyId)
        updateStoryStatus(storyId, status: .failed, errorMessage: error)
    }

    /// Get the current implementation plan
    /// - Returns: The current plan if available
    func getCurrentPlan() -> ImplementationPlan? {
        currentPlan
    }

    /// Get the completion tracker
    /// - Returns: The story completion tracker
    func getTracker() -> StoryCompletionTracker {
        tracker
    }

    /// Check if all stories are complete
    /// - Returns: True if all stories are complete
    func isComplete() -> Bool {
        currentPlan?.isComplete ?? false
    }

    /// Get the current progress
    /// - Returns: Progress as a percentage (0.0 - 1.0)
    func getProgress() -> Double {
        currentPlan?.progress ?? 0.0
    }

    /// Generate a commit message for a story
    /// - Parameter story: The story to generate a message for
    /// - Returns: The formatted commit message
    func generateCommitMessage(for story: StoryImplementationPlan) -> String {
        // Determine scope from files
        let scope = determineScope(from: story.filesToCreate + story.filesToModify)

        // Format: feat(scope): US-XXX description
        return """
        feat(\(scope)): \(story.storyId) \(story.title)

        \(story.description)

        Acceptance criteria:
        \(story.acceptanceCriteria.map { "- \($0)" }.joined(separator: "\n"))

        Unit tests:
        \(story.unitTests.map { "- \($0)" }.joined(separator: "\n"))
        """
    }

    /// Generate instructions for implementing a story
    /// - Parameter story: The story to implement
    /// - Returns: Implementation instructions string
    func generateImplementationInstructions(for story: StoryImplementationPlan) -> String {
        var instructions: [String] = []

        instructions.append("## Implementing: \(story.storyId) - \(story.title)")
        instructions.append("")
        instructions.append("### Description")
        instructions.append(story.description)
        instructions.append("")

        if !story.dependencies.isEmpty {
            instructions.append("### Dependencies (already complete)")
            for dep in story.dependencies {
                instructions.append("- \(dep)")
            }
            instructions.append("")
        }

        instructions.append("### Acceptance Criteria")
        for criteria in story.acceptanceCriteria {
            instructions.append("- [ ] \(criteria)")
        }
        instructions.append("")

        instructions.append("### Required Unit Tests")
        instructions.append("MANDATORY: Write these tests WITH the implementation:")
        for test in story.unitTests {
            instructions.append("- [ ] \(test)")
        }
        instructions.append("")

        if !story.filesToCreate.isEmpty {
            instructions.append("### Files to Create")
            for file in story.filesToCreate {
                instructions.append("- \(file)")
            }
            instructions.append("")
        }

        if !story.filesToModify.isEmpty {
            instructions.append("### Files to Modify")
            for file in story.filesToModify {
                instructions.append("- \(file)")
            }
            instructions.append("")
        }

        instructions.append("### Commit Format")
        instructions.append("After implementation and tests pass, commit with:")
        instructions.append("```")
        instructions.append("feat(\(determineScope(from: story.filesToCreate + story.filesToModify))): \(story.storyId) \(story.title)")
        instructions.append("```")

        return instructions.joined(separator: "\n")
    }

    // MARK: - Private Methods

    private func validateNoCycles(stories: [ExtendedPRDUserStory]) throws {
        var visited = Set<String>()
        var stack = Set<String>()
        let storyMap = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })

        func dfs(_ storyId: String, path: [String]) throws {
            if stack.contains(storyId) {
                let cycleStart = path.firstIndex(of: storyId) ?? 0
                let cycle = Array(path[cycleStart...]) + [storyId]
                throw ImplementActionError.circularDependency(stories: cycle)
            }

            guard !visited.contains(storyId) else { return }

            visited.insert(storyId)
            stack.insert(storyId)

            if let story = storyMap[storyId] {
                for dep in story.dependsOn {
                    try dfs(dep, path: path + [storyId])
                }
            }

            stack.remove(storyId)
        }

        for story in stories {
            try dfs(story.id, path: [])
        }
    }

    private func sortByDependencies(
        _ pendingStories: [ExtendedPRDUserStory],
        allStories: [ExtendedPRDUserStory]
    ) -> [ExtendedPRDUserStory] {
        var result: [ExtendedPRDUserStory] = []
        var visited = Set<String>()
        let storyMap = Dictionary(uniqueKeysWithValues: allStories.map { ($0.id, $0) })
        let pendingSet = Set(pendingStories.map { $0.id })

        func visit(_ storyId: String) {
            guard !visited.contains(storyId),
                  pendingSet.contains(storyId),
                  let story = storyMap[storyId] else { return }

            visited.insert(storyId)

            // Visit dependencies first (if they're pending)
            for depId in story.dependsOn {
                visit(depId)
            }

            result.append(story)
        }

        // Sort by priority first (critical → low), then by dependency order
        let sortedByPriority = pendingStories.sorted {
            $0.taskPriority.weight > $1.taskPriority.weight
        }

        for story in sortedByPriority {
            visit(story.id)
        }

        return result
    }

    private func updateStoryStatus(
        _ storyId: String,
        status: StoryImplementationStatus,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        commitSHA: String? = nil,
        errorMessage: String? = nil
    ) {
        guard var plan = currentPlan,
              let index = plan.stories.firstIndex(where: { $0.storyId == storyId }) else {
            return
        }

        plan.stories[index].status = status
        if let startedAt = startedAt {
            plan.stories[index].startedAt = startedAt
        }
        if let completedAt = completedAt {
            plan.stories[index].completedAt = completedAt
        }
        if let commitSHA = commitSHA {
            plan.stories[index].commitSHA = commitSHA
        }
        if let errorMessage = errorMessage {
            plan.stories[index].errorMessage = errorMessage
        }
        plan.updatedAt = Date()

        currentPlan = plan
    }

    private func updateDependencyStatus() {
        guard var plan = currentPlan else { return }

        let completedIds = Set(plan.stories.filter { $0.status.isComplete }.map { $0.storyId })

        for i in plan.stories.indices {
            if plan.stories[i].status == .pending {
                let depsComplete = plan.stories[i].dependencies.allSatisfy { completedIds.contains($0) }
                if depsComplete {
                    plan.stories[i].dependenciesComplete = true
                    plan.stories[i].status = .ready
                }
            }
        }

        plan.updatedAt = Date()
        currentPlan = plan
    }

    private func determineScope(from files: [String]) -> String {
        // Extract common path components to determine scope
        guard let firstFile = files.first else { return "core" }

        let components = firstFile.split(separator: "/")

        // Look for known patterns
        for component in components {
            let lowered = component.lowercased()
            if lowered.contains("model") { return "models" }
            if lowered.contains("view") { return "views" }
            if lowered.contains("service") { return "services" }
            if lowered.contains("action") { return "actions" }
            if lowered.contains("test") { return "tests" }
        }

        // Default to first meaningful directory
        if components.count >= 2 {
            return String(components[1]).lowercased()
        }

        return "core"
    }
}

// MARK: - ImplementAction Convenience Extensions

extension ImplementAction {

    /// Load PRD and generate plan in one step
    /// - Parameter prdPath: Path to the PRD file
    /// - Returns: The generated implementation plan
    func loadAndGeneratePlan(from prdPath: String) async throws -> ImplementationPlan {
        let prd = try await loadPRD(from: prdPath)
        return try generatePlan(prdPath: prdPath, prd: prd)
    }

    /// Get summary of current plan status
    /// - Returns: A human-readable status summary
    func getPlanSummary() -> String {
        guard let plan = currentPlan else {
            return "No plan loaded"
        }

        let completed = plan.completedStories
        let total = plan.totalStories
        let progress = Int(plan.progress * 100)

        var summary = "Feature: \(plan.featureName)\n"
        summary += "Progress: \(completed)/\(total) stories (\(progress)%)\n"

        if let next = plan.nextReadyStory {
            summary += "Next: \(next.storyId) - \(next.title)"
        } else if plan.isComplete {
            summary += "Status: All stories complete!"
        } else {
            summary += "Status: Waiting for dependencies"
        }

        return summary
    }
}
