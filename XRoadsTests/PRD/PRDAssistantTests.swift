//
//  PRDAssistantTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-023: Unit tests for PRD Assistant wizard flow
//

import XCTest
@testable import XRoadsLib

final class PRDAssistantTests: XCTestCase {

    // MARK: - Test: Wizard Steps Navigate Correctly

    @MainActor
    func test_prdWizardFlow_stepsNavigateCorrectly() {
        let state = PRDWizardState()

        XCTAssertEqual(state.currentStep, .selectTemplate, "Initial step should be template selection")

        state.goToNextStep()
        XCTAssertEqual(state.currentStep, .defineFeature, "Next step should be definition")

        state.goToNextStep()
        XCTAssertEqual(state.currentStep, .generateStories, "Next step should be story generation")

        state.goToPreviousStep()
        XCTAssertEqual(state.currentStep, .defineFeature, "Previous step should navigate back")

        state.goToStep(.export)
        XCTAssertEqual(state.currentStep, .export, "Should jump directly to export")
    }

    // MARK: - Test: PRD Preview Updates

    @MainActor
    func test_prdPreviewUpdates_withStateChanges() {
        let state = PRDWizardState()

        state.featureName = "Realtime Analytics"
        state.featureDescription = "Add analytics dashboards for team insights"
        state.selectedTemplate = .feature
        state.generatedStories = [
            PRDUserStory(
                id: "US-001",
                title: "Capture analytics events",
                description: "Track core events for analytics",
                priority: .high,
                acceptanceCriteria: ["Events tracked"],
                estimatedComplexity: 3
            )
        ]

        let document = state.currentDocument
        XCTAssertEqual(document.featureName, "Realtime Analytics")
        XCTAssertEqual(document.description, "Add analytics dashboards for team insights")
        XCTAssertEqual(document.templateType, .feature)
        XCTAssertEqual(document.userStories.count, 1)
        XCTAssertEqual(document.userStories.first?.id, "US-001")
    }

    // MARK: - Test: Export Creates Valid JSON

    @MainActor
    func test_exportCreatesValidJSON() throws {
        let state = PRDWizardState()
        state.featureName = "Exported Feature"
        state.featureDescription = "Verify export flow"
        state.selectedTemplate = .refactor
        state.generatedStories = [
            PRDUserStory(
                id: "RF-001",
                title: "Refactor service layer",
                description: "Simplify service dependencies",
                priority: .medium,
                acceptanceCriteria: ["No regressions"],
                estimatedComplexity: 4
            )
        ]

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")

        defer { try? FileManager.default.removeItem(at: tempURL) }

        try state.exportPRD(to: tempURL)

        let data = try Data(contentsOf: tempURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(jsonObject?["feature_name"] as? String, "Exported Feature")

        let stories = jsonObject?["user_stories"] as? [[String: Any]]
        XCTAssertEqual(stories?.count, 1, "Exported JSON should include one story")
    }
}
