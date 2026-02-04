//
//  ArtDirectionViewModel.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-027: ViewModel for the unified Art Direction pipeline view
//

import Foundation
import SwiftUI

// MARK: - Pipeline Step

enum ArtPipelineStep: Int, CaseIterable, Hashable, Sendable {
    case createBible = 0
    case generatePRD = 1
    case runLoop = 2
    case viewComponents = 3

    var title: String {
        switch self {
        case .createBible: return "Create Art Bible"
        case .generatePRD: return "Generate Asset PRD"
        case .runLoop: return "Run Asset Loop"
        case .viewComponents: return "View Components"
        }
    }

    var subtitle: String {
        switch self {
        case .createBible: return "Define design tokens and component specs"
        case .generatePRD: return "Transform art bible into user stories"
        case .runLoop: return "Execute code generation loop"
        case .viewComponents: return "Review generated components"
        }
    }

    var iconName: String {
        switch self {
        case .createBible: return "paintpalette"
        case .generatePRD: return "doc.text"
        case .runLoop: return "play.circle"
        case .viewComponents: return "square.stack.3d.up"
        }
    }

    var next: ArtPipelineStep? {
        ArtPipelineStep(rawValue: rawValue + 1)
    }

    var previous: ArtPipelineStep? {
        ArtPipelineStep(rawValue: rawValue - 1)
    }
}

// MARK: - Step Status

enum ArtPipelineStepStatus: String, Hashable, Sendable {
    case pending
    case inProgress
    case completed
    case error

    var color: Color {
        switch self {
        case .pending: return .textTertiary
        case .inProgress: return .accentPrimary
        case .completed: return .statusSuccess
        case .error: return .statusError
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class ArtDirectionViewModel {

    // MARK: - State

    var currentStep: ArtPipelineStep = .createBible
    var stepStatuses: [ArtPipelineStep: ArtPipelineStepStatus] = [
        .createBible: .pending,
        .generatePRD: .pending,
        .runLoop: .pending,
        .viewComponents: .pending
    ]

    var artBible: ArtBible?
    var artBibleURL: URL?
    var assetPRD: PRDDocument?
    var assetPRDURL: URL?
    var componentContext: ComponentContext?

    var isLoading: Bool = false
    var errorMessage: String?
    var progressMessage: String?
    var loopProgress: Double = 0

    // MARK: - Computed

    var canProceedToNext: Bool {
        switch currentStep {
        case .createBible:
            return artBible != nil
        case .generatePRD:
            return assetPRD != nil
        case .runLoop:
            return stepStatuses[.runLoop] == .completed
        case .viewComponents:
            return true
        }
    }

    var overallProgress: Double {
        let completedCount = stepStatuses.values.filter { $0 == .completed }.count
        return Double(completedCount) / Double(ArtPipelineStep.allCases.count)
    }

    var currentStepIndex: Int {
        currentStep.rawValue
    }

    // MARK: - Services

    private let generator = AssetPRDGenerator()
    private let contextBuilder = ComponentContextBuilder()
    private let fileManager = FileManager.default

    // MARK: - Step Navigation

    func selectStep(_ step: ArtPipelineStep) {
        currentStep = step
    }

    func goToNextStep() {
        guard let next = currentStep.next else { return }
        currentStep = next
    }

    func goToPreviousStep() {
        guard let previous = currentStep.previous else { return }
        currentStep = previous
    }

    // MARK: - Step 1: Load/Create Art Bible

    func loadArtBible(from url: URL) async {
        isLoading = true
        errorMessage = nil
        progressMessage = "Loading art bible..."
        stepStatuses[.createBible] = .inProgress

        do {
            artBible = try generator.loadArtBible(from: url)
            artBibleURL = url
            stepStatuses[.createBible] = .completed
            progressMessage = nil
        } catch {
            errorMessage = "Failed to load art bible: \(error.localizedDescription)"
            stepStatuses[.createBible] = .error
        }

        isLoading = false
    }

    func setArtBible(_ bible: ArtBible, url: URL?) {
        artBible = bible
        artBibleURL = url
        stepStatuses[.createBible] = .completed
    }

    func clearArtBible() {
        artBible = nil
        artBibleURL = nil
        stepStatuses[.createBible] = .pending
        // Reset downstream steps
        assetPRD = nil
        assetPRDURL = nil
        stepStatuses[.generatePRD] = .pending
        stepStatuses[.runLoop] = .pending
        stepStatuses[.viewComponents] = .pending
        componentContext = nil
    }

    // MARK: - Step 2: Generate Asset PRD

    func generateAssetPRD() async {
        guard let artBible else {
            errorMessage = "Load an art bible first."
            return
        }

        isLoading = true
        errorMessage = nil
        progressMessage = "Generating asset PRD..."
        stepStatuses[.generatePRD] = .inProgress

        do {
            assetPRD = try generator.generateDocument(from: artBible)
            stepStatuses[.generatePRD] = .completed
            progressMessage = nil
        } catch {
            errorMessage = "Failed to generate asset PRD: \(error.localizedDescription)"
            stepStatuses[.generatePRD] = .error
        }

        isLoading = false
    }

    func exportAssetPRD(to url: URL) async throws {
        guard let assetPRD else {
            throw AssetPRDGeneratorError.noComponents
        }

        try generator.export(document: assetPRD, to: url)
        assetPRDURL = url
    }

    // MARK: - Step 3: Run Loop (Delegate to AppState)

    func markLoopStarted() {
        stepStatuses[.runLoop] = .inProgress
        loopProgress = 0
        progressMessage = "Running asset loop..."
    }

    func updateLoopProgress(_ progress: Double) {
        loopProgress = progress
    }

    func markLoopCompleted() {
        stepStatuses[.runLoop] = .completed
        loopProgress = 1.0
        progressMessage = nil
    }

    func markLoopFailed(error: String) {
        stepStatuses[.runLoop] = .error
        errorMessage = error
        progressMessage = nil
    }

    // MARK: - Step 4: View Components

    func loadComponentContext(projectURL: URL) async {
        isLoading = true
        errorMessage = nil
        progressMessage = "Scanning generated components..."
        stepStatuses[.viewComponents] = .inProgress

        do {
            componentContext = try contextBuilder.buildContext(projectURL: projectURL)
            stepStatuses[.viewComponents] = .completed
            progressMessage = nil
        } catch {
            errorMessage = "Failed to load components: \(error.localizedDescription)"
            stepStatuses[.viewComponents] = .error
        }

        isLoading = false
    }

    func refreshComponentContext(projectURL: URL) async {
        await loadComponentContext(projectURL: projectURL)
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
    }

    func reset() {
        currentStep = .createBible
        stepStatuses = [
            .createBible: .pending,
            .generatePRD: .pending,
            .runLoop: .pending,
            .viewComponents: .pending
        ]
        artBible = nil
        artBibleURL = nil
        assetPRD = nil
        assetPRDURL = nil
        componentContext = nil
        isLoading = false
        errorMessage = nil
        progressMessage = nil
        loopProgress = 0
    }
}
