//
//  PRDAssistantView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-023: Guided PRD creation wizard with AI assistance and live preview
//

import SwiftUI

// MARK: - PRD Assistant View

struct PRDAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState

    @StateObject private var wizardState = PRDWizardState()
    @StateObject private var viewModel = PRDAssistantViewModel()

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .background(Color.borderMuted)

            HSplitView {
                wizardColumn
                    .frame(minWidth: 520)

                sidePanel
                    .frame(minWidth: 360, idealWidth: 420)
            }

            Divider()
                .background(Color.borderMuted)

            footer
        }
        .background(Color.bgApp)
        .frame(width: 1200, height: 760)
        .task {
            await viewModel.loadContext(from: appState)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("PRD Assistant")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Build a PRD with AI guidance and live preview")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if let error = errorMessage ?? viewModel.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.statusError)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 4)
                .background(Color.statusError.opacity(0.12))
                .cornerRadius(Theme.Radius.sm)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Close PRD Assistant")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.bgSurface)
    }

    // MARK: - Wizard Column

    private var wizardColumn: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            wizardStepsBar

            Divider()
                .background(Color.borderMuted)

            wizardStepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.bottom, Theme.Spacing.md)
        }
        .padding(Theme.Spacing.lg)
    }

    private var wizardStepsBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(PRDWizardStep.allCases) { step in
                StepChip(
                    step: step,
                    isActive: step == wizardState.currentStep,
                    isComplete: step.rawValue < wizardState.currentStep.rawValue
                ) {
                    if step.rawValue <= wizardState.currentStep.rawValue {
                        wizardState.goToStep(step)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var wizardStepContent: some View {
        switch wizardState.currentStep {
        case .selectTemplate:
            PRDTemplateSelectionStep(state: wizardState)
        case .defineFeature:
            PRDFeatureDefinitionStep(state: wizardState)
        case .generateStories:
            PRDGenerateStoriesStep(state: wizardState) {
                await viewModel.generateStories(for: wizardState)
            }
        case .review:
            PRDReviewStep(state: wizardState) { story, prompt in
                await viewModel.refineStory(story, prompt: prompt)
            }
        case .export:
            PRDExportStep(state: wizardState) { url in
                try await exportPRD(to: url)
            } onLaunchLoop: {
                launchLoop()
            }
        }
    }

    // MARK: - Side Panel

    private var sidePanel: some View {
        VStack(spacing: Theme.Spacing.md) {
            PRDPreviewView(document: wizardState.currentDocument)

            PRDAssistantChatPanel(viewModel: viewModel)
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgCanvas)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Reset") {
                wizardState.reset()
                errorMessage = nil
                viewModel.clearChat()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Back") {
                wizardState.goToPreviousStep()
            }
            .buttonStyle(.bordered)
            .disabled(wizardState.currentStep.isFirst)

            Button(wizardState.currentStep.isLast ? "Done" : "Next") {
                if wizardState.currentStep.isLast {
                    dismiss()
                } else {
                    advanceStep()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!wizardState.canProceed)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.bgSurface)
    }

    private func advanceStep() {
        if wizardState.currentStep == .review {
            wizardState.editedStories = wizardState.generatedStories
        }
        wizardState.goToNextStep()
    }

    // MARK: - Export + Launch

    private func exportPRD(to url: URL) async throws {
        do {
            try wizardState.exportPRD(to: url)
            await MainActor.run {
                appState.setActivePRD(url: url, name: wizardState.featureName)
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }

    private func launchLoop() {
        guard let projectPath = appState.projectPath else {
            errorMessage = "Set a project path before launching the loop."
            return
        }

        let repoURL = URL(fileURLWithPath: projectPath)
        let document = wizardState.currentDocument

        Task {
            await appState.startOrchestration(document: document, repoPath: repoURL)
        }
    }
}

// MARK: - Step Chip

private struct StepChip: View {
    let step: PRDWizardStep
    let isActive: Bool
    let isComplete: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : step.iconName)
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? Color.accentPrimary : Color.textTertiary)

                Text(step.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentPrimary.opacity(0.15) : Color.bgElevated)
            .cornerRadius(Theme.Radius.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Panel

private struct PRDAssistantChatPanel: View {
    @ObservedObject var viewModel: PRDAssistantViewModel

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            Divider()
                .background(Color.borderMuted)

            chatMessages

            ChatInputBar(
                text: $viewModel.inputText,
                mode: $viewModel.mode,
                isLoading: viewModel.isLoading,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                },
                onStop: {
                    Task {
                        await viewModel.stopGeneration()
                    }
                }
            )
        }
        .background(Color.bgSurface)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    private var chatHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(Color.statusSuccess)

            Text("PRD Copilot")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if !viewModel.messages.isEmpty {
                Button {
                    viewModel.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear chat")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.bgSurface)
    }

    private var chatMessages: some View {
        Group {
            if viewModel.messages.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Ask the orchestrator to refine stories or generate ideas.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("Try: \"Suggest user stories for onboarding\"")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Theme.Spacing.lg)
                .background(Color.bgCanvas)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgCanvas)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation(.easeOut(duration: Theme.Animation.fast)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class PRDAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var mode: OrchestratorMode = .api
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let orchestratorService = OrchestratorService()
    private var context: ChatContext?

    func loadContext(from appState: AppState) async {
        let worktreeNames = appState.worktrees.map { $0.name }

        var branch: String?
        if let projectPath = appState.projectPath {
            let gitService = GitService()
            branch = try? await gitService.getCurrentBranch(path: projectPath)
        }

        context = ChatContext(
            projectPath: appState.projectPath,
            currentBranch: branch,
            worktrees: worktreeNames,
            availableSkills: [],
            mcpServers: ["xroads-mcp"],
            dashboardMode: appState.dashboardMode == .single ? "single" : "agentic"
        )

        if let ctx = context {
            await orchestratorService.setContext(ctx)
            await orchestratorService.updateSystemPrompt()
        }

        if let apiKey = UserDefaults.standard.string(forKey: "anthropicAPIKey") {
            await orchestratorService.setAPIKey(apiKey)
        }
    }

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = ""
        isLoading = true
        errorMessage = nil

        do {
            let response = try await sendPrompt(trimmed, recordToChat: true)
            errorMessage = response.isEmpty ? "No response received." : nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func stopGeneration() async {
        await orchestratorService.stopTerminalProcess()
        isLoading = false

        if let lastIndex = messages.indices.last,
           messages[lastIndex].status == .streaming {
            messages[lastIndex] = ChatMessage(
                id: messages[lastIndex].id,
                role: messages[lastIndex].role,
                content: messages[lastIndex].content + "\n\n*[Generation stopped]*",
                timestamp: messages[lastIndex].timestamp,
                status: .complete
            )
        }
    }

    func clearChat() {
        messages.removeAll()
        Task {
            await orchestratorService.clearConversation()
        }
    }

    // MARK: - Story Generation

    func generateStories(for state: PRDWizardState) async {
        guard !state.isGenerating else { return }
        state.isGenerating = true
        errorMessage = nil

        let prompt = buildStoryPrompt(from: state)

        do {
            let response = try await sendPrompt(prompt, recordToChat: true)
            let stories = parseStories(from: response, template: state.selectedTemplate)

            if stories.isEmpty {
                state.generatedStories = fallbackStories(for: state)
                errorMessage = "AI response could not be parsed. Added starter stories instead."
            } else {
                state.generatedStories = stories
            }
        } catch {
            state.generatedStories = fallbackStories(for: state)
            errorMessage = "Using starter stories due to AI error: \(error.localizedDescription)"
        }

        state.isGenerating = false
    }

    func refineStory(_ story: PRDUserStory, prompt: String) async -> PRDUserStory? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return story }

        let request = buildRefinementPrompt(for: story, prompt: trimmed)

        do {
            let response = try await sendPrompt(request, recordToChat: true)
            if let refined = parseRefinedStory(from: response, original: story) {
                return refined
            }
            errorMessage = "AI refinement response could not be parsed."
        } catch {
            errorMessage = "AI refinement failed: \(error.localizedDescription)"
        }

        var fallback = story
        fallback.acceptanceCriteria.append("AI refinement requested: \(trimmed)")
        return fallback
    }

    // MARK: - Prompt Helpers

    private func buildStoryPrompt(from state: PRDWizardState) -> String {
        let template = state.selectedTemplate.displayName
        let featureName = state.featureName.isEmpty ? "Untitled Feature" : state.featureName
        let description = state.featureDescription.isEmpty ? "No description provided" : state.featureDescription
        let vision = state.visionSummary.isEmpty ? "N/A" : state.visionSummary
        let concepts = state.keyConcepts.isEmpty ? "N/A" : state.keyConcepts.joined(separator: ", ")

        return """
        You are generating a PRD for XRoads. Provide 4-6 user stories in JSON.

        Template: \(template)
        Feature: \(featureName)
        Description: \(description)
        Vision: \(vision)
        Key Concepts: \(concepts)

        Return JSON only. Example format:
        {
          "stories": [
            {
              "title": "...",
              "description": "...",
              "priority": "high",
              "acceptanceCriteria": ["...", "..."],
              "estimatedComplexity": 3
            }
          ]
        }
        """
    }

    private func buildRefinementPrompt(for story: PRDUserStory, prompt: String) -> String {
        return """
        Refine this PRD user story and return JSON only.

        Current story:
        Title: \(story.title)
        Description: \(story.description)
        Priority: \(story.priority.rawValue)
        Acceptance Criteria: \(story.acceptanceCriteria.joined(separator: "; "))

        Refinement request: \(prompt)

        Return JSON with fields: title, description, priority, acceptanceCriteria, estimatedComplexity.
        """
    }

    // MARK: - Response Parsing

    private func sendPrompt(_ prompt: String, recordToChat: Bool) async throws -> String {
        await orchestratorService.setMode(mode)

        if recordToChat {
            let userMessage = ChatMessage.user(prompt)
            messages.append(userMessage)
            messages.append(ChatMessage.streamingPlaceholder())
        }

        let response = try await orchestratorService.sendMessage(prompt)

        if recordToChat, let index = messages.lastIndex(where: { $0.status == .streaming }) {
            messages[index] = response
        }

        return response.content
    }

    private func parseStories(from response: String, template: PRDTemplateType) -> [PRDUserStory] {
        guard let data = extractJSONData(from: response) else { return [] }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let envelope = try? decoder.decode(AIStoryEnvelope.self, from: data) {
            return mapStories(envelope.stories, template: template)
        }

        if let stories = try? decoder.decode([AIStory].self, from: data) {
            return mapStories(stories, template: template)
        }

        return []
    }

    private func parseRefinedStory(from response: String, original: PRDUserStory) -> PRDUserStory? {
        guard let data = extractJSONData(from: response) else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let refined = try? decoder.decode(AIStory.self, from: data) {
            return mergeStory(original: original, aiStory: refined)
        }

        if let envelope = try? decoder.decode(AIStoryEnvelope.self, from: data),
           let first = envelope.stories.first {
            return mergeStory(original: original, aiStory: first)
        }

        return nil
    }

    private func mergeStory(original: PRDUserStory, aiStory: AIStory) -> PRDUserStory {
        var updated = original
        if let title = aiStory.title, !title.isEmpty {
            updated.title = title
        }
        if let description = aiStory.description, !description.isEmpty {
            updated.description = description
        }
        if let priority = aiStory.priority {
            updated.priority = priority
        }
        if let criteria = aiStory.acceptanceCriteria, !criteria.isEmpty {
            updated.acceptanceCriteria = criteria
        }
        if let estimate = aiStory.estimatedComplexity {
            updated.estimatedComplexity = estimate
        }
        return updated
    }

    private func mapStories(_ stories: [AIStory], template: PRDTemplateType) -> [PRDUserStory] {
        let prefix = template.defaultStoryPrefix
        return stories.enumerated().map { index, story in
            let id = story.id ?? "\(prefix)-\(String(format: "%03d", index + 1))"
            var mapped = PRDUserStory(
                id: id,
                title: story.title ?? "Untitled Story",
                description: story.description ?? "",
                priority: story.priority ?? .medium,
                acceptanceCriteria: story.acceptanceCriteria ?? [],
                dependsOn: story.dependsOn ?? [],
                estimatedComplexity: story.estimatedComplexity ?? 3
            )
            mapped.generateDefaultUnitTest()
            return mapped
        }
    }

    private func extractJSONData(from response: String) -> Data? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fenced = extractCodeBlock(from: trimmed) {
            return fenced.data(using: .utf8)
        }
        return trimmed.data(using: .utf8)
    }

    private func extractCodeBlock(from text: String) -> String? {
        guard let startRange = text.range(of: "```") else { return nil }
        let afterStart = text[startRange.upperBound...]
        guard let endRange = afterStart.range(of: "```") else { return nil }
        let block = String(afterStart[..<endRange.lowerBound])
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        if let first = lines.first, first.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "json" {
            return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func fallbackStories(for state: PRDWizardState) -> [PRDUserStory] {
        let prefix = state.selectedTemplate.defaultStoryPrefix
        let featureName = state.featureName.isEmpty ? "Feature" : state.featureName

        let templates: [(String, String, PRDPriority, [String])] = {
            switch state.selectedTemplate {
            case .feature:
                return [
                    ("Define core \(featureName) flow", "Capture the primary workflow and constraints.", .high, ["Flow documented", "Edge cases listed"]),
                    ("Implement \(featureName) UI", "Build the interface for the new feature.", .medium, ["UI matches design", "Responsive layout"]),
                    ("Add \(featureName) tests", "Cover the feature with unit and integration tests.", .medium, ["Unit tests added", "Integration test added"])
                ]
            case .refactor:
                return [
                    ("Audit modules", "Identify modules to refactor for maintainability.", .high, ["Hotspots listed", "Refactor goals defined"]),
                    ("Refactor core logic", "Simplify and restructure the most complex modules.", .medium, ["No behavior regression", "Code coverage maintained"]),
                    ("Update tests", "Adjust and expand tests for refactored areas.", .medium, ["Tests updated", "CI passes"])
                ]
            case .test:
                return [
                    ("Define test strategy", "Outline coverage goals and tooling.", .high, ["Coverage targets set", "Tooling selected"]),
                    ("Implement unit tests", "Create unit tests for core modules.", .medium, ["Critical paths covered", "Mocks added"]),
                    ("Add integration tests", "Verify workflows end-to-end.", .medium, ["Key flows covered", "Regression suite added"])
                ]
            case .assets:
                return [
                    ("Extract design tokens", "Define colors, typography, spacing.", .high, ["Tokens documented", "Tokens reviewed"]),
                    ("Build core components", "Implement foundational UI components.", .medium, ["Components match tokens", "Variants included"]),
                    ("Validate assets", "Review and export design assets.", .medium, ["Preview approved", "Export complete"])
                ]
            case .custom:
                return [
                    ("Define scope", "Clarify requirements and constraints.", .high, ["Scope agreed", "Constraints listed"]),
                    ("Implement plan", "Execute the core plan steps.", .medium, ["Deliverables completed", "Review complete"]),
                    ("Validate output", "Ensure requirements are met.", .medium, ["Acceptance criteria met", "Stakeholders sign off"])
                ]
            }
        }()

        return templates.enumerated().map { index, template in
            var story = PRDUserStory(
                id: "\(prefix)-\(String(format: "%03d", index + 1))",
                title: template.0,
                description: template.1,
                priority: template.2,
                acceptanceCriteria: template.3,
                estimatedComplexity: 3
            )
            story.generateDefaultUnitTest()
            return story
        }
    }
}

// MARK: - AI Story Types

private struct AIStoryEnvelope: Decodable {
    let stories: [AIStory]
}

private struct AIStory: Decodable {
    var id: String?
    var title: String?
    var description: String?
    var priority: PRDPriority?
    var acceptanceCriteria: [String]?
    var dependsOn: [String]?
    var estimatedComplexity: Int?
}

// MARK: - Preview

#if DEBUG
struct PRDAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        PRDAssistantView()
            .environment(\.appState, AppState())
    }
}
#endif
