//
//  PRDTemplate.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-023: Models for PRD Assistant - templates and wizard state
//

import Foundation

// MARK: - PRDTemplate

/// Template types for PRD generation
enum PRDTemplateType: String, Codable, CaseIterable, Identifiable, Sendable {
    case feature
    case refactor
    case test
    case artDirection = "art-direction"
    case assets
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feature: return "New Feature"
        case .refactor: return "Refactoring"
        case .test: return "Test Suite"
        case .artDirection: return "Art Direction"
        case .assets: return "Design Assets"
        case .custom: return "Custom PRD"
        }
    }

    var description: String {
        switch self {
        case .feature: return "Create a PRD for implementing a new feature with user stories"
        case .refactor: return "Plan a refactoring effort with code cleanup tasks"
        case .test: return "Generate a test suite PRD with comprehensive test cases"
        case .artDirection: return "Generate an art direction bible and design tokens from references"
        case .assets: return "Create design assets from an Art Bible specification"
        case .custom: return "Build a custom PRD from scratch with full control"
        }
    }

    var iconName: String {
        switch self {
        case .feature: return "sparkles"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .test: return "testtube.2"
        case .artDirection: return "paintbrush.pointed"
        case .assets: return "paintpalette"
        case .custom: return "doc.badge.gearshape"
        }
    }

    var defaultStoryPrefix: String {
        switch self {
        case .feature: return "US"
        case .refactor: return "RF"
        case .test: return "TS"
        case .artDirection: return "AD"
        case .assets: return "AS"
        case .custom: return "CS"
        }
    }
}

// MARK: - PRDWizardStep

/// Steps in the PRD creation wizard
enum PRDWizardStep: Int, CaseIterable, Identifiable {
    case selectTemplate = 0
    case defineFeature = 1
    case generateStories = 2
    case review = 3
    case export = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .selectTemplate: return "Template"
        case .defineFeature: return "Definition"
        case .generateStories: return "Stories"
        case .review: return "Review"
        case .export: return "Export"
        }
    }

    var description: String {
        switch self {
        case .selectTemplate: return "Choose a PRD template"
        case .defineFeature: return "Describe the feature"
        case .generateStories: return "Generate user stories"
        case .review: return "Review and refine"
        case .export: return "Export and launch"
        }
    }

    var iconName: String {
        switch self {
        case .selectTemplate: return "square.grid.2x2"
        case .defineFeature: return "pencil.line"
        case .generateStories: return "list.bullet.rectangle"
        case .review: return "eye"
        case .export: return "arrow.up.doc"
        }
    }

    var next: PRDWizardStep? {
        PRDWizardStep(rawValue: rawValue + 1)
    }

    var previous: PRDWizardStep? {
        PRDWizardStep(rawValue: rawValue - 1)
    }

    var isFirst: Bool { self == .selectTemplate }
    var isLast: Bool { self == .export }
}

// MARK: - PRDUserStory

/// A user story within a PRD
struct PRDUserStory: Codable, Hashable, Sendable, Identifiable {
    let id: String
    var title: String
    var description: String
    var priority: PRDPriority
    var status: PRDStoryStatus
    var acceptanceCriteria: [String]
    var dependsOn: [String]
    var estimatedComplexity: Int
    var unitTest: PRDUnitTest?
    var completedAt: Date?

    init(
        id: String,
        title: String,
        description: String,
        priority: PRDPriority = .medium,
        status: PRDStoryStatus = .pending,
        acceptanceCriteria: [String] = [],
        dependsOn: [String] = [],
        estimatedComplexity: Int = 3,
        unitTest: PRDUnitTest? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.acceptanceCriteria = acceptanceCriteria
        self.dependsOn = dependsOn
        self.estimatedComplexity = estimatedComplexity
        self.unitTest = unitTest
        self.completedAt = nil
    }

    /// Generate a default unit test for this story
    mutating func generateDefaultUnitTest(testDir: String = "tests") {
        let sanitizedId = id.replacingOccurrences(of: "-", with: "_").lowercased()
        unitTest = PRDUnitTest(
            file: "\(testDir)/\(sanitizedId)_test.swift",
            name: "test_\(sanitizedId)",
            description: "Verify \(title.lowercased())",
            assertions: acceptanceCriteria.map { "Assert: \($0)" },
            status: .pending
        )
    }
}

// MARK: - PRDPriority

/// Priority levels for user stories
enum PRDPriority: String, Codable, CaseIterable, Sendable {
    case critical
    case high
    case medium
    case low

    var displayName: String {
        rawValue.capitalized
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    var iconName: String {
        switch self {
        case .critical: return "exclamationmark.3"
        case .high: return "exclamationmark.2"
        case .medium: return "exclamationmark"
        case .low: return "minus"
        }
    }

    var weight: Int {
        switch self {
        case .critical: return 20
        case .high: return 10
        case .medium: return 5
        case .low: return 1
        }
    }
}

// MARK: - PRDStoryStatus

/// Status of a user story
enum PRDStoryStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in_progress"
    case complete
    case blocked

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .complete: return "Complete"
        case .blocked: return "Blocked"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "circle.fill"
        case .complete: return "checkmark.circle.fill"
        case .blocked: return "xmark.circle.fill"
        }
    }
}

// MARK: - PRDUnitTest

/// Unit test specification for a story
struct PRDUnitTest: Codable, Hashable, Sendable {
    var file: String
    var name: String
    var description: String
    var assertions: [String]
    var status: PRDTestStatus

    init(
        file: String,
        name: String,
        description: String,
        assertions: [String] = [],
        status: PRDTestStatus = .pending
    ) {
        self.file = file
        self.name = name
        self.description = description
        self.assertions = assertions
        self.status = status
    }
}

// MARK: - PRDTestStatus

/// Status of a unit test
enum PRDTestStatus: String, Codable, Sendable {
    case pending
    case passing
    case failing

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .passing: return "checkmark.circle.fill"
        case .failing: return "xmark.circle.fill"
        }
    }
}

// MARK: - PRDDocument

/// Complete PRD document structure
struct PRDDocument: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var version: String
    var featureName: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var author: String
    var templateType: PRDTemplateType
    var userStories: [PRDUserStory]

    // Optional metadata
    var vision: PRDVision?
    var architecture: [String: String]?
    var successMetrics: [String]?
    var designContext: DesignContext?

    init(
        id: UUID = UUID(),
        version: String = "1.0",
        featureName: String,
        description: String,
        author: String = "Nexus",
        templateType: PRDTemplateType = .feature,
        userStories: [PRDUserStory] = [],
        vision: PRDVision? = nil,
        designContext: DesignContext? = nil
    ) {
        self.id = id
        self.version = version
        self.featureName = featureName
        self.description = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.author = author
        self.templateType = templateType
        self.userStories = userStories
        self.vision = vision
        self.architecture = nil
        self.successMetrics = nil
        self.designContext = designContext
    }

    // MARK: - Computed Properties

    var totalStories: Int { userStories.count }

    var completedStories: Int {
        userStories.filter { $0.status == .complete }.count
    }

    var pendingStories: Int {
        userStories.filter { $0.status == .pending }.count
    }

    var progress: Double {
        guard totalStories > 0 else { return 0 }
        return Double(completedStories) / Double(totalStories)
    }

    var nextIncompleteStory: PRDUserStory? {
        userStories.first { $0.status != .complete }
    }

    var isComplete: Bool {
        !userStories.isEmpty && userStories.allSatisfy { $0.status == .complete }
    }

    // MARK: - JSON Export

    /// Export as JSON string for prd.json file
    func toJSON(prettyPrinted: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : []
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw PRDExportError.encodingFailed
        }
        return json
    }

    /// Export as dictionary for compatibility with existing prd.json format
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "version": version,
            "feature_name": featureName,
            "description": description,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
            "author": author,
            "total_stories": totalStories,
            "completed_stories": completedStories,
            "pending_stories": pendingStories
        ]

        dict["user_stories"] = userStories.map { story -> [String: Any] in
            var storyDict: [String: Any] = [
                "id": story.id,
                "title": story.title,
                "description": story.description,
                "priority": story.priority.rawValue,
                "status": story.status.rawValue,
                "acceptance_criteria": story.acceptanceCriteria,
                "depends_on": story.dependsOn,
                "estimated_complexity": story.estimatedComplexity
            ]

            if let unitTest = story.unitTest {
                storyDict["unit_test"] = [
                    "file": unitTest.file,
                    "name": unitTest.name,
                    "description": unitTest.description,
                    "assertions": unitTest.assertions,
                    "status": unitTest.status.rawValue
                ]
            }

            return storyDict
        }

        if let vision = vision {
            dict["vision"] = [
                "summary": vision.summary,
                "key_concepts": vision.keyConcepts
            ]
        }

        if let metrics = successMetrics {
            dict["success_metrics"] = metrics
        }

        if let dc = designContext {
            dict["design_context"] = dc.prdSection
        }

        return dict
    }
}

// MARK: - PRDVision

/// Vision section of a PRD
struct PRDVision: Codable, Hashable, Sendable {
    var summary: String
    var keyConcepts: [String]

    init(summary: String = "", keyConcepts: [String] = []) {
        self.summary = summary
        self.keyConcepts = keyConcepts
    }
}

// MARK: - PRDExportError

/// Errors during PRD export
enum PRDExportError: Error, LocalizedError {
    case encodingFailed
    case writeFailed(path: String)
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode PRD to JSON"
        case .writeFailed(let path):
            return "Failed to write PRD to \(path)"
        case .invalidFormat:
            return "Invalid PRD format"
        }
    }
}

// MARK: - PRDWizardState

/// State object for the PRD creation wizard
@MainActor
final class PRDWizardState: ObservableObject {
    // Navigation
    @Published var currentStep: PRDWizardStep = .selectTemplate
    @Published var isGenerating: Bool = false
    @Published var error: String?

    // Template selection
    @Published var selectedTemplate: PRDTemplateType = .feature

    // Feature definition
    @Published var featureName: String = ""
    @Published var featureDescription: String = ""
    @Published var visionSummary: String = ""
    @Published var keyConcepts: [String] = []
    @Published var successMetrics: [String] = []
    @Published var referenceURLs: [String] = []
    @Published var imageReferences: [String] = []

    // Generated content
    @Published var generatedStories: [PRDUserStory] = []
    @Published var aiSuggestions: [String] = []

    // Review edits
    @Published var editedStories: [PRDUserStory] = []

    // Export settings
    @Published var exportPath: String = "prd.json"
    @Published var launchLoopAfterExport: Bool = true
    @Published var selectedAgent: AgentType = .claude

    // MARK: - Computed Properties

    var canProceed: Bool {
        switch currentStep {
        case .selectTemplate:
            return true
        case .defineFeature:
            return !featureName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !featureDescription.trimmingCharacters(in: .whitespaces).isEmpty
        case .generateStories:
            return !generatedStories.isEmpty
        case .review:
            return !editedStories.isEmpty
        case .export:
            return !exportPath.isEmpty
        }
    }

    var currentDocument: PRDDocument {
        PRDDocument(
            featureName: featureName,
            description: featureDescription,
            templateType: selectedTemplate,
            userStories: editedStories.isEmpty ? generatedStories : editedStories,
            vision: PRDVision(summary: visionSummary, keyConcepts: keyConcepts)
        )
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard let next = currentStep.next else { return }
        currentStep = next
    }

    func goToPreviousStep() {
        guard let prev = currentStep.previous else { return }
        currentStep = prev
    }

    func goToStep(_ step: PRDWizardStep) {
        currentStep = step
    }

    // MARK: - Story Management

    func addStory(_ story: PRDUserStory) {
        generatedStories.append(story)
    }

    func removeStory(at index: Int) {
        guard index >= 0 && index < generatedStories.count else { return }
        generatedStories.remove(at: index)
    }

    func updateStory(_ story: PRDUserStory) {
        if let index = generatedStories.firstIndex(where: { $0.id == story.id }) {
            generatedStories[index] = story
        }
    }

    func moveStory(from source: IndexSet, to destination: Int) {
        generatedStories.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Concept & Metric Management

    func addKeyConcept(_ concept: String) {
        guard !concept.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        keyConcepts.append(concept)
    }

    func removeKeyConcept(at index: Int) {
        guard index >= 0 && index < keyConcepts.count else { return }
        keyConcepts.remove(at: index)
    }

    // MARK: - Reference Management (Art Direction)

    func addReferenceURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        referenceURLs.append(trimmed)
    }

    func removeReferenceURL(at index: Int) {
        guard index >= 0 && index < referenceURLs.count else { return }
        referenceURLs.remove(at: index)
    }

    func addImageReference(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        imageReferences.append(trimmed)
    }

    func removeImageReference(at index: Int) {
        guard index >= 0 && index < imageReferences.count else { return }
        imageReferences.remove(at: index)
    }

    func addSuccessMetric(_ metric: String) {
        guard !metric.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        successMetrics.append(metric)
    }

    func removeSuccessMetric(at index: Int) {
        guard index >= 0 && index < successMetrics.count else { return }
        successMetrics.remove(at: index)
    }

    // MARK: - Reset

    func reset() {
        currentStep = .selectTemplate
        isGenerating = false
        error = nil
        selectedTemplate = .feature
        featureName = ""
        featureDescription = ""
        visionSummary = ""
        keyConcepts = []
        successMetrics = []
        generatedStories = []
        aiSuggestions = []
        editedStories = []
        exportPath = "prd.json"
        launchLoopAfterExport = true
    }

    // MARK: - Export

    func exportPRD(to url: URL) throws {
        let document = currentDocument
        let json = try document.toJSON()
        try json.write(to: url, atomically: true, encoding: .utf8)
    }
}
