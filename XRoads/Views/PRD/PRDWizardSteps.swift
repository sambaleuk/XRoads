//
//  PRDWizardSteps.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-023: Step-by-step wizard views for PRD creation
//

import SwiftUI

// MARK: - Step 1: Template Selection

/// First step: Select a PRD template type
struct PRDTemplateSelectionStep: View {
    @ObservedObject var state: PRDWizardState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeader(
                title: "Choose a Template",
                subtitle: "Select the type of PRD you want to create"
            )

            // Template grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.md),
                    GridItem(.flexible(), spacing: Theme.Spacing.md)
                ],
                spacing: Theme.Spacing.md
            ) {
                ForEach(PRDTemplateType.allCases) { template in
                    TemplateCard(
                        template: template,
                        isSelected: state.selectedTemplate == template
                    ) {
                        withAnimation(.easeInOut(duration: Theme.Animation.fast)) {
                            state.selectedTemplate = template
                        }
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: PRDTemplateType
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Icon
                Image(systemName: template.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentPrimary : Color.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(isSelected ? Color.accentPrimary.opacity(0.15) : Color.bgElevated)
                    )

                // Title
                Text(template.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                // Description
                Text(template.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(isHovered || isSelected ? Color.bgElevated : Color.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(isSelected ? Color.accentPrimary : Color.borderDefault, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Step 2: Feature Definition

/// Second step: Define the feature details
struct PRDFeatureDefinitionStep: View {
    @ObservedObject var state: PRDWizardState
    @State private var newConcept: String = ""
    @State private var newMetric: String = ""
    @State private var newReferenceURL: String = ""
    @State private var newImageReference: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                StepHeader(
                    title: "Define Your \(state.selectedTemplate.displayName)",
                    subtitle: "Provide details about what you want to build"
                )

                // Feature name
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Feature Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    TextField("e.g., User Authentication System", text: $state.featureName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                }

                // Feature description
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    TextEditor(text: $state.featureDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100, maxHeight: 150)
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )

                    Text("Describe what you want to achieve with this \(state.selectedTemplate.displayName.lowercased())")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }

                Divider()
                    .background(Color.borderMuted)

                // Vision summary
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Vision Summary (Optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    TextField("High-level vision for this feature...", text: $state.visionSummary)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                }

                // Key concepts
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Key Concepts")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    // Existing concepts
                    PRDFlowLayout(spacing: 6) {
                        ForEach(state.keyConcepts.indices, id: \.self) { index in
                            ConceptChip(
                                text: state.keyConcepts[index],
                                onRemove: { state.removeKeyConcept(at: index) }
                            )
                        }
                    }

                    // Add new concept
                    HStack {
                        TextField("Add a key concept...", text: $newConcept)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textPrimary)
                            .onSubmit {
                                state.addKeyConcept(newConcept)
                                newConcept = ""
                            }

                        Button {
                            state.addKeyConcept(newConcept)
                            newConcept = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(newConcept.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(Color.borderDefault, lineWidth: 1)
                    )
                }

                // Success metrics
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Success Metrics (Optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    ForEach(state.successMetrics.indices, id: \.self) { index in
                        HStack {
                            Text(state.successMetrics[index])
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Button {
                                state.removeSuccessMetric(at: index)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(Theme.Spacing.xs)
                    }

                    HStack {
                        TextField("Add a success metric...", text: $newMetric)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textPrimary)
                            .onSubmit {
                                state.addSuccessMetric(newMetric)
                                newMetric = ""
                            }

                        Button {
                            state.addSuccessMetric(newMetric)
                            newMetric = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(newMetric.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(Color.borderDefault, lineWidth: 1)
                    )
                }

                if state.selectedTemplate == .artDirection {
                    // Reference URLs
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Reference URLs")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        PRDFlowLayout(spacing: 6) {
                            ForEach(state.referenceURLs.indices, id: \.self) { index in
                                ConceptChip(
                                    text: state.referenceURLs[index],
                                    onRemove: { state.removeReferenceURL(at: index) }
                                )
                            }
                        }

                        HStack {
                            TextField("Add reference URL...", text: $newReferenceURL)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textPrimary)
                                .onSubmit {
                                    state.addReferenceURL(newReferenceURL)
                                    newReferenceURL = ""
                                }

                            Button {
                                state.addReferenceURL(newReferenceURL)
                                newReferenceURL = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                            .buttonStyle(.plain)
                            .disabled(newReferenceURL.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                    }

                    // Image references
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Image References")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        PRDFlowLayout(spacing: 6) {
                            ForEach(state.imageReferences.indices, id: \.self) { index in
                                ConceptChip(
                                    text: state.imageReferences[index],
                                    onRemove: { state.removeImageReference(at: index) }
                                )
                            }
                        }

                        HStack {
                            TextField("Add image URL or path...", text: $newImageReference)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textPrimary)
                                .onSubmit {
                                    state.addImageReference(newImageReference)
                                    newImageReference = ""
                                }

                            Button {
                                state.addImageReference(newImageReference)
                                newImageReference = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                            .buttonStyle(.plain)
                            .disabled(newImageReference.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - Concept Chip

private struct ConceptChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Color.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentPrimary.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Step 3: Generate Stories

/// Third step: Generate user stories with AI assistance
struct PRDGenerateStoriesStep: View {
    @ObservedObject var state: PRDWizardState
    let onGenerateWithAI: () async -> Void

    @State private var showAddStorySheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeader(
                title: "Generate User Stories",
                subtitle: "Create user stories for your \(state.selectedTemplate.displayName.lowercased())"
            )

            // AI generation button
            HStack {
                Button {
                    Task {
                        await onGenerateWithAI()
                    }
                } label: {
                    HStack {
                        if state.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(state.isGenerating ? "Generating..." : "Generate with AI")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isGenerating)

                Spacer()

                Button {
                    showAddStorySheet = true
                } label: {
                    Label("Add Manually", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            // Stories list
            if state.generatedStories.isEmpty {
                emptyState
            } else {
                storiesList
            }
        }
        .sheet(isPresented: $showAddStorySheet) {
            AddStorySheet(state: state, isPresented: $showAddStorySheet)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            Text("No stories yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            Text("Generate stories with AI or add them manually")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
    }

    private var storiesList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(state.generatedStories) { story in
                    StoryCard(story: story) {
                        if let index = state.generatedStories.firstIndex(where: { $0.id == story.id }) {
                            state.removeStory(at: index)
                        }
                    }
                }
                .onMove { state.moveStory(from: $0, to: $1) }
            }
        }
    }
}

// MARK: - Story Card

private struct StoryCard: View {
    let story: PRDUserStory
    let onDelete: () -> Void

    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                // ID badge
                Text(story.id)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentPrimary.opacity(0.15))
                    .cornerRadius(4)

                // Priority
                HStack(spacing: 2) {
                    Image(systemName: story.priority.iconName)
                        .font(.system(size: 9))
                    Text(story.priority.displayName)
                        .font(.system(size: 10))
                }
                .foregroundStyle(priorityColor)

                Spacer()

                // Expand/Collapse
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)

                // Delete
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.statusError)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }

            // Title
            Text(story.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            // Description (collapsed)
            if !isExpanded {
                Text(story.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(story.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)

                    if !story.acceptanceCriteria.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Acceptance Criteria")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)

                            ForEach(story.acceptanceCriteria, id: \.self) { criterion in
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.statusSuccess)
                                    Text(criterion)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                    }

                    // Unit test info
                    if let unitTest = story.unitTest {
                        HStack(spacing: 4) {
                            Image(systemName: "testtube.2")
                                .font(.system(size: 10))
                            Text(unitTest.file)
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundStyle(Color.terminalCyan)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(isHovered ? Color.bgElevated : Color.bgSurface)
        .cornerRadius(Theme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    private var priorityColor: Color {
        switch story.priority {
        case .critical: return .statusError
        case .high: return .statusWarning
        case .medium: return .statusInfo
        case .low: return .textTertiary
        }
    }
}

// MARK: - Add Story Sheet

private struct AddStorySheet: View {
    @ObservedObject var state: PRDWizardState
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: PRDPriority = .medium
    @State private var acceptanceCriteria: [String] = []
    @State private var newCriterion: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add User Story")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.md)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        TextField("Story title...", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(Theme.Spacing.sm)
                            .background(Color.bgElevated)
                            .cornerRadius(Theme.Radius.sm)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        TextEditor(text: $description)
                            .font(.system(size: 12))
                            .scrollContentBackground(.hidden)
                            .frame(height: 80)
                            .padding(Theme.Spacing.sm)
                            .background(Color.bgElevated)
                            .cornerRadius(Theme.Radius.sm)
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Priority")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        Picker("", selection: $priority) {
                            ForEach(PRDPriority.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Acceptance Criteria
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Acceptance Criteria")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        ForEach(acceptanceCriteria.indices, id: \.self) { index in
                            HStack {
                                Text("- \(acceptanceCriteria[index])")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textPrimary)

                                Spacer()

                                Button {
                                    acceptanceCriteria.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack {
                            TextField("Add criterion...", text: $newCriterion)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .onSubmit {
                                    if !newCriterion.isEmpty {
                                        acceptanceCriteria.append(newCriterion)
                                        newCriterion = ""
                                    }
                                }

                            Button {
                                if !newCriterion.isEmpty {
                                    acceptanceCriteria.append(newCriterion)
                                    newCriterion = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                    }
                }
                .padding(Theme.Spacing.md)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Add Story") {
                    addStory()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(Theme.Spacing.md)
        }
        .frame(width: 450, height: 500)
        .background(Color.bgSurface)
    }

    private func addStory() {
        let storyCount = state.generatedStories.count + 1
        let storyId = "\(state.selectedTemplate.defaultStoryPrefix)-\(String(format: "%03d", storyCount))"

        var story = PRDUserStory(
            id: storyId,
            title: title,
            description: description,
            priority: priority,
            acceptanceCriteria: acceptanceCriteria
        )
        story.generateDefaultUnitTest()

        state.addStory(story)
        isPresented = false
    }
}

// MARK: - Step 4: Review

/// Fourth step: Review and refine generated stories
struct PRDReviewStep: View {
    @ObservedObject var state: PRDWizardState
    let onRefineWithAI: (PRDUserStory, String) async -> PRDUserStory?

    @State private var refinementPrompt: String = ""
    @State private var selectedStoryId: String?

    var body: some View {
        HSplitView {
            // Stories list
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                StepHeader(
                    title: "Review Stories",
                    subtitle: "Review and edit your user stories"
                )

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(state.generatedStories) { story in
                            ReviewStoryRow(
                                story: story,
                                isSelected: selectedStoryId == story.id
                            ) {
                                selectedStoryId = story.id
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 300)

            // Detail/Edit panel
            if let storyId = selectedStoryId,
               let index = state.generatedStories.firstIndex(where: { $0.id == storyId }) {
                StoryEditPanel(
                    story: $state.generatedStories[index],
                    refinementPrompt: $refinementPrompt,
                    onRefine: onRefineWithAI
                )
            } else {
                VStack {
                    Text("Select a story to edit")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bgCanvas)
            }
        }
    }
}

// MARK: - Review Story Row

private struct ReviewStoryRow: View {
    let story: PRDUserStory
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(story.id)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.accentPrimary)

                        Text(story.priority.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                    }

                    Text(story.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                if story.unitTest != nil {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.terminalCyan)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(Theme.Spacing.sm)
            .background(isSelected ? Color.bgElevated : Color.bgSurface)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Color.accentPrimary : Color.borderDefault, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Story Edit Panel

private struct StoryEditPanel: View {
    @Binding var story: PRDUserStory
    @Binding var refinementPrompt: String
    let onRefine: (PRDUserStory, String) async -> PRDUserStory?

    @State private var newCriterion: String = ""
    @State private var isRefining: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Story ID
                HStack {
                    Text(story.id)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentPrimary)

                    Spacer()

                    // Priority picker
                    Picker("Priority", selection: $story.priority) {
                        ForEach(PRDPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)

                    TextField("Title", text: $story.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                }

                // Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)

                    TextEditor(text: $story.description)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .padding(Theme.Spacing.sm)
                        .background(Color.bgElevated)
                        .cornerRadius(Theme.Radius.sm)
                }

                // Acceptance Criteria
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acceptance Criteria")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)

                    ForEach(story.acceptanceCriteria.indices, id: \.self) { index in
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.statusSuccess)

                            TextField("Criterion", text: $story.acceptanceCriteria[index])
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))

                            Button {
                                story.acceptanceCriteria.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Add criterion...", text: $newCriterion)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .onSubmit {
                                if !newCriterion.isEmpty {
                                    story.acceptanceCriteria.append(newCriterion)
                                    newCriterion = ""
                                }
                            }

                        Button {
                            if !newCriterion.isEmpty {
                                story.acceptanceCriteria.append(newCriterion)
                                newCriterion = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Color.bgSurface)
                    .cornerRadius(Theme.Radius.sm)
                }

                Divider()

                // AI Refinement
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refine with AI")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)

                    HStack {
                        TextField("Ask AI to improve this story...", text: $refinementPrompt)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))

                        Button {
                            Task {
                                isRefining = true
                                if let refined = await onRefine(story, refinementPrompt) {
                                    story = refined
                                }
                                refinementPrompt = ""
                                isRefining = false
                            }
                        } label: {
                            if isRefining {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(refinementPrompt.isEmpty || isRefining)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Color.bgSurface)
                    .cornerRadius(Theme.Radius.sm)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Color.bgCanvas)
    }
}

// MARK: - Step 5: Export

/// Fifth step: Export PRD and optionally launch loop
struct PRDExportStep: View {
    @ObservedObject var state: PRDWizardState
    let onExport: (URL) async throws -> Void
    let onLaunchLoop: () -> Void

    @State private var showFilePicker: Bool = false
    @State private var isExporting: Bool = false
    @State private var exportSuccess: Bool = false
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeader(
                title: "Export PRD",
                subtitle: "Save your PRD and optionally launch the Nexus Loop"
            )

            // Summary
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Summary")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: Theme.Spacing.lg) {
                    SummaryItem(
                        icon: "doc.text",
                        label: "Template",
                        value: state.selectedTemplate.displayName
                    )

                    SummaryItem(
                        icon: "list.bullet",
                        label: "Stories",
                        value: "\(state.generatedStories.count)"
                    )

                    SummaryItem(
                        icon: "testtube.2",
                        label: "Tests",
                        value: "\(state.generatedStories.filter { $0.unitTest != nil }.count)"
                    )
                }
                .padding(Theme.Spacing.md)
                .background(Color.bgSurface)
                .cornerRadius(Theme.Radius.md)
            }

            // Export path
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Export Path")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                HStack {
                    TextField("prd.json", text: $state.exportPath)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)

                    Button("Browse...") {
                        showFilePicker = true
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Color.bgElevated)
                .cornerRadius(Theme.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            }

            // Launch loop toggle
            Toggle(isOn: $state.launchLoopAfterExport) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Color.terminalCyan)
                    Text("Launch Nexus Loop after export")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .toggleStyle(.switch)

            if state.launchLoopAfterExport {
                // Agent selection
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Assign to Agent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    Picker("", selection: $state.selectedAgent) {
                        ForEach(AgentType.allCases, id: \.self) { agent in
                            HStack {
                                Image(systemName: agent.iconName)
                                Text(agent.displayName)
                            }
                            .tag(agent)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Spacer()

            // Export button
            if let error = exportError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.statusError)
            }

            if exportSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.statusSuccess)
                    Text("PRD exported successfully!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.statusSuccess)
                }

                if state.launchLoopAfterExport {
                    Button {
                        onLaunchLoop()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Launch Loop Now")
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button {
                    Task {
                        await exportPRD()
                    }
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.doc")
                        }
                        Text(isExporting ? "Exporting..." : "Export PRD")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting || state.exportPath.isEmpty)
            }
        }
        .fileExporter(
            isPresented: $showFilePicker,
            document: PRDFileDocument(document: state.currentDocument),
            contentType: .json,
            defaultFilename: "prd.json"
        ) { result in
            switch result {
            case .success(let url):
                state.exportPath = url.path
            case .failure(let error):
                exportError = error.localizedDescription
            }
        }
    }

    private func exportPRD() async {
        isExporting = true
        exportError = nil

        do {
            let url = URL(fileURLWithPath: state.exportPath)
            try await onExport(url)
            exportSuccess = true
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }
}

// MARK: - Summary Item

private struct SummaryItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.textSecondary)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Step Header

struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Flow Layout

struct PRDFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func calculateLayout(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return (CGSize(width: totalWidth, height: y + lineHeight), positions)
    }
}

// MARK: - PRD File Document

import UniformTypeIdentifiers

struct PRDFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let document: PRDDocument

    init(document: PRDDocument) {
        self.document = document
    }

    init(configuration: ReadConfiguration) throws {
        self.document = PRDDocument(featureName: "", description: "")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let json = try document.toJSON()
        let data = json.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}
