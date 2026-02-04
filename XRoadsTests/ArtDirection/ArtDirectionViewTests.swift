//
//  ArtDirectionViewTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-027: Unit tests for Art Direction pipeline view
//

import XCTest
@testable import XRoadsLib

final class ArtDirectionViewTests: XCTestCase {

    // MARK: - Pipeline Step Tests

    func test_allStepsAccessible() throws {
        // All 4 steps should be accessible
        XCTAssertEqual(ArtPipelineStep.allCases.count, 4)
        XCTAssertEqual(ArtPipelineStep.createBible.rawValue, 0)
        XCTAssertEqual(ArtPipelineStep.generatePRD.rawValue, 1)
        XCTAssertEqual(ArtPipelineStep.runLoop.rawValue, 2)
        XCTAssertEqual(ArtPipelineStep.viewComponents.rawValue, 3)
    }

    func test_stepNavigationNext() throws {
        XCTAssertEqual(ArtPipelineStep.createBible.next, .generatePRD)
        XCTAssertEqual(ArtPipelineStep.generatePRD.next, .runLoop)
        XCTAssertEqual(ArtPipelineStep.runLoop.next, .viewComponents)
        XCTAssertNil(ArtPipelineStep.viewComponents.next)
    }

    func test_stepNavigationPrevious() throws {
        XCTAssertNil(ArtPipelineStep.createBible.previous)
        XCTAssertEqual(ArtPipelineStep.generatePRD.previous, .createBible)
        XCTAssertEqual(ArtPipelineStep.runLoop.previous, .generatePRD)
        XCTAssertEqual(ArtPipelineStep.viewComponents.previous, .runLoop)
    }

    func test_stepHasTitleAndSubtitle() throws {
        for step in ArtPipelineStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "Step \(step) should have a title")
            XCTAssertFalse(step.subtitle.isEmpty, "Step \(step) should have a subtitle")
            XCTAssertFalse(step.iconName.isEmpty, "Step \(step) should have an icon name")
        }
    }

    // MARK: - Step Status Tests

    func test_stepStatusColors() throws {
        // Each status should have a distinct color representation
        let pending = ArtPipelineStepStatus.pending
        let inProgress = ArtPipelineStepStatus.inProgress
        let completed = ArtPipelineStepStatus.completed
        let error = ArtPipelineStepStatus.error

        // Verify icons are set
        XCTAssertFalse(pending.iconName.isEmpty)
        XCTAssertFalse(inProgress.iconName.isEmpty)
        XCTAssertFalse(completed.iconName.isEmpty)
        XCTAssertFalse(error.iconName.isEmpty)

        // Completed should show checkmark
        XCTAssertTrue(completed.iconName.contains("checkmark"))
        // Error should show xmark
        XCTAssertTrue(error.iconName.contains("xmark"))
    }

    // MARK: - ViewModel Tests

    @MainActor
    func test_viewModelInitialState() async throws {
        let viewModel = ArtDirectionViewModel()

        XCTAssertEqual(viewModel.currentStep, .createBible)
        XCTAssertNil(viewModel.artBible)
        XCTAssertNil(viewModel.assetPRD)
        XCTAssertNil(viewModel.componentContext)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.overallProgress, 0)
    }

    @MainActor
    func test_viewModelStepSelection() async throws {
        let viewModel = ArtDirectionViewModel()

        viewModel.selectStep(.generatePRD)
        XCTAssertEqual(viewModel.currentStep, .generatePRD)

        viewModel.selectStep(.runLoop)
        XCTAssertEqual(viewModel.currentStep, .runLoop)

        viewModel.selectStep(.viewComponents)
        XCTAssertEqual(viewModel.currentStep, .viewComponents)

        viewModel.selectStep(.createBible)
        XCTAssertEqual(viewModel.currentStep, .createBible)
    }

    @MainActor
    func test_viewModelStepNavigation() async throws {
        let viewModel = ArtDirectionViewModel()

        XCTAssertEqual(viewModel.currentStep, .createBible)

        viewModel.goToNextStep()
        XCTAssertEqual(viewModel.currentStep, .generatePRD)

        viewModel.goToNextStep()
        XCTAssertEqual(viewModel.currentStep, .runLoop)

        viewModel.goToPreviousStep()
        XCTAssertEqual(viewModel.currentStep, .generatePRD)

        viewModel.goToPreviousStep()
        XCTAssertEqual(viewModel.currentStep, .createBible)

        // Should not go before first step
        viewModel.goToPreviousStep()
        XCTAssertEqual(viewModel.currentStep, .createBible)
    }

    @MainActor
    func test_viewModelProgressUpdatesCorrectly() async throws {
        let viewModel = ArtDirectionViewModel()

        XCTAssertEqual(viewModel.overallProgress, 0)

        viewModel.stepStatuses[.createBible] = .completed
        XCTAssertEqual(viewModel.overallProgress, 0.25)

        viewModel.stepStatuses[.generatePRD] = .completed
        XCTAssertEqual(viewModel.overallProgress, 0.5)

        viewModel.stepStatuses[.runLoop] = .completed
        XCTAssertEqual(viewModel.overallProgress, 0.75)

        viewModel.stepStatuses[.viewComponents] = .completed
        XCTAssertEqual(viewModel.overallProgress, 1.0)
    }

    @MainActor
    func test_viewModelReset() async throws {
        let viewModel = ArtDirectionViewModel()

        // Set some state
        viewModel.selectStep(.runLoop)
        viewModel.stepStatuses[.createBible] = .completed
        viewModel.stepStatuses[.generatePRD] = .completed
        viewModel.errorMessage = "Test error"

        // Reset
        viewModel.reset()

        XCTAssertEqual(viewModel.currentStep, .createBible)
        XCTAssertEqual(viewModel.stepStatuses[.createBible], .pending)
        XCTAssertEqual(viewModel.stepStatuses[.generatePRD], .pending)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.artBible)
        XCTAssertNil(viewModel.assetPRD)
    }

    @MainActor
    func test_setArtBibleUpdatesStatus() async throws {
        let viewModel = ArtDirectionViewModel()
        let artBible = createSampleArtBible()

        viewModel.setArtBible(artBible, url: nil)

        XCTAssertNotNil(viewModel.artBible)
        XCTAssertEqual(viewModel.stepStatuses[.createBible], .completed)
    }

    @MainActor
    func test_clearArtBibleResetsDownstreamSteps() async throws {
        let viewModel = ArtDirectionViewModel()
        let artBible = createSampleArtBible()

        // Set art bible and generate PRD
        viewModel.setArtBible(artBible, url: nil)
        viewModel.stepStatuses[.generatePRD] = .completed
        viewModel.stepStatuses[.runLoop] = .completed

        // Clear art bible
        viewModel.clearArtBible()

        XCTAssertNil(viewModel.artBible)
        XCTAssertEqual(viewModel.stepStatuses[.createBible], .pending)
        XCTAssertEqual(viewModel.stepStatuses[.generatePRD], .pending)
        XCTAssertEqual(viewModel.stepStatuses[.runLoop], .pending)
    }

    @MainActor
    func test_canProceedToNextRequiresArtBible() async throws {
        let viewModel = ArtDirectionViewModel()

        XCTAssertFalse(viewModel.canProceedToNext, "Should not proceed without art bible")

        let artBible = createSampleArtBible()
        viewModel.setArtBible(artBible, url: nil)

        XCTAssertTrue(viewModel.canProceedToNext, "Should proceed with art bible")
    }

    @MainActor
    func test_loopProgressTracking() async throws {
        let viewModel = ArtDirectionViewModel()

        viewModel.markLoopStarted()
        XCTAssertEqual(viewModel.stepStatuses[.runLoop], .inProgress)
        XCTAssertEqual(viewModel.loopProgress, 0)

        viewModel.updateLoopProgress(0.5)
        XCTAssertEqual(viewModel.loopProgress, 0.5)

        viewModel.markLoopCompleted()
        XCTAssertEqual(viewModel.stepStatuses[.runLoop], .completed)
        XCTAssertEqual(viewModel.loopProgress, 1.0)
    }

    @MainActor
    func test_loopFailureTracking() async throws {
        let viewModel = ArtDirectionViewModel()

        viewModel.markLoopStarted()
        viewModel.markLoopFailed(error: "Test failure")

        XCTAssertEqual(viewModel.stepStatuses[.runLoop], .error)
        XCTAssertEqual(viewModel.errorMessage, "Test failure")
    }

    @MainActor
    func test_generateAssetPRDRequiresArtBible() async throws {
        let viewModel = ArtDirectionViewModel()

        await viewModel.generateAssetPRD()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.assetPRD)
    }

    @MainActor
    func test_generateAssetPRDSucceedsWithArtBible() async throws {
        let viewModel = ArtDirectionViewModel()
        let artBible = createSampleArtBible()

        viewModel.setArtBible(artBible, url: nil)
        await viewModel.generateAssetPRD()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.assetPRD)
        XCTAssertEqual(viewModel.stepStatuses[.generatePRD], .completed)
    }

    // MARK: - Component Context Tests

    func test_componentsShownAfterGeneration() throws {
        // This tests that ComponentContext properly shows generated components
        let context = ComponentContext(
            components: [
                ComponentContext.Component(
                    name: "TestButton",
                    description: "A test button",
                    usageExample: "TestButton()",
                    tokens: ["accent.primary"],
                    source: .codebase,
                    filePath: "XRoads/Views/Components/TestButton.swift"
                )
            ],
            missingComponents: [],
            sourceFiles: []
        )

        XCTAssertEqual(context.components.count, 1)
        XCTAssertEqual(context.components.first?.name, "TestButton")
        XCTAssertTrue(context.missingComponents.isEmpty)
    }

    func test_missingComponentsTracked() throws {
        let context = ComponentContext(
            components: [],
            missingComponents: [
                ComponentContext.Component(
                    name: "MissingWidget",
                    description: "A widget that was not generated",
                    usageExample: "MissingWidget()",
                    tokens: ["widget.token"],
                    source: .artBible,
                    filePath: nil
                )
            ],
            sourceFiles: []
        )

        XCTAssertTrue(context.components.isEmpty)
        XCTAssertEqual(context.missingComponents.count, 1)
        XCTAssertEqual(context.missingComponents.first?.name, "MissingWidget")
    }

    // MARK: - Helpers

    private func createSampleArtBible() -> ArtBible {
        ArtBible(
            project: "TestProject",
            version: "1.0.0",
            generatedAt: Date(),
            designTokens: ArtBibleDesignTokens(
                colors: ["background": ["primary": "#0d1117"]],
                typography: ArtBibleTypographyTokens(
                    fontFamily: ["ui": "SF Pro"],
                    sizes: ["md": 14]
                ),
                spacing: ["md": 16],
                radius: ["md": 8]
            ),
            components: [
                ArtBibleComponent(
                    name: "PrimaryButton",
                    description: "Main CTA button",
                    tokens: ["accent.primary", "radius.md"],
                    styleSpecs: nil,
                    visualPrompt: nil,
                    interaction: nil
                )
            ]
        )
    }
}
