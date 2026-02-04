//
//  ArtDirectionView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-027: Unified interface for the Art Direction pipeline
//

import SwiftUI

// MARK: - Art Direction View

struct ArtDirectionView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = ArtDirectionViewModel()
    @State private var showFilePicker: Bool = false
    @State private var showExportPanel: Bool = false
    @State private var exportPath: String = "prd-assets.json"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.borderDefault)

            ArtPipelineProgress(
                currentStep: $viewModel.currentStep,
                stepStatuses: viewModel.stepStatuses,
                onStepSelected: { step in
                    viewModel.selectStep(step)
                }
            )
            .padding(Theme.Spacing.md)

            Divider().background(Color.borderDefault)

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.errorMessage != nil || viewModel.progressMessage != nil {
                statusBar
            }
        }
        .background(Color.bgApp)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Art Direction Pipeline")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("Transform visual identity into generated components")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            HStack(spacing: Theme.Spacing.sm) {
                ArtPipelineProgressCompact(
                    currentStep: viewModel.currentStep,
                    stepStatuses: viewModel.stepStatuses
                )

                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }

            Button {
                viewModel.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Reset pipeline")
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .createBible:
            createBibleStepView
        case .generatePRD:
            generatePRDStepView
        case .runLoop:
            runLoopStepView
        case .viewComponents:
            viewComponentsStepView
        }
    }

    // MARK: - Step 1: Create Bible

    private var createBibleStepView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let artBible = viewModel.artBible {
                ArtBiblePreviewView(artBible: artBible)

                HStack {
                    Button {
                        viewModel.clearArtBible()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                            Text("Clear")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        viewModel.goToNextStep()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Generate PRD")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)
            } else {
                emptyBibleState
            }
        }
    }

    private var emptyBibleState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "paintpalette")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            VStack(spacing: Theme.Spacing.xs) {
                Text("No Art Bible Loaded")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("Load an existing art-bible.json or create one using the /art-director skill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Theme.Spacing.md) {
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("Load Art Bible")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)

                Button {
                    loadFromProject()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Scan Project")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Step 2: Generate PRD

    private var generatePRDStepView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let artBible = viewModel.artBible {
                if let assetPRD = viewModel.assetPRD {
                    AssetPRDPreviewView(artBible: artBible)

                    HStack {
                        Button {
                            viewModel.goToPreviousStep()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            showExportPanel = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.doc")
                                Text("Export PRD")
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.goToNextStep()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Run Loop")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
                } else {
                    generatePRDPrompt
                }
            } else {
                missingArtBiblePrompt
            }
        }
        .sheet(isPresented: $showExportPanel) {
            exportSheet
        }
    }

    private var generatePRDPrompt: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Ready to Generate Asset PRD")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("This will create user stories for each component in your art bible")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await viewModel.generateAssetPRD()
                }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(viewModel.isLoading ? "Generating..." : "Generate Asset PRD")
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
    }

    private var missingArtBiblePrompt: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.statusWarning)

            Text("Art Bible Required")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("Go back to Step 1 and load an art bible first")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)

            Button {
                viewModel.selectStep(.createBible)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Go to Step 1")
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
    }

    private var exportSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Export Asset PRD")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            TextField("File path", text: $exportPath)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showExportPanel = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Export") {
                    exportPRD()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 400)
    }

    // MARK: - Step 3: Run Loop

    private var runLoopStepView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            let status = viewModel.stepStatuses[.runLoop] ?? .pending

            Spacer()

            if status == .inProgress {
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.large)

                    Text("Running Asset Loop...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    ProgressView(value: viewModel.loopProgress)
                        .frame(width: 200)

                    Text("\(Int(viewModel.loopProgress * 100))% complete")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            } else if status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.statusSuccess)

                Text("Asset Loop Completed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Button {
                    viewModel.goToNextStep()
                } label: {
                    HStack(spacing: 6) {
                        Text("View Components")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
            } else if status == .error {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.statusError)

                Text("Loop Failed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.statusError)
                }

                Button {
                    launchLoop()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Retry")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
            } else {
                Image(systemName: "play.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.textTertiary)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Ready to Run Asset Loop")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Launch the nexus loop to generate components from the asset PRD")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    launchLoop()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Launch Loop")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.assetPRD == nil)
            }

            Spacer()

            HStack {
                Button {
                    viewModel.goToPreviousStep()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Step 4: View Components

    private var viewComponentsStepView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let context = viewModel.componentContext {
                componentContextView(context)
            } else {
                loadComponentsPrompt
            }
        }
    }

    private func componentContextView(_ context: ComponentContext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generated Components")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text("\(context.components.count) components found")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            if let projectPath = appState.projectPath {
                                await viewModel.refreshComponentContext(projectURL: URL(fileURLWithPath: projectPath))
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(context.components, id: \.name) { component in
                    componentRow(component)
                }

                if !context.missingComponents.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Missing Components")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.statusWarning)

                        ForEach(context.missingComponents, id: \.name) { component in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(Color.statusWarning)

                                Text(component.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)

                                Text("(not generated)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Color.statusWarning.opacity(0.1))
                    .cornerRadius(Theme.Radius.md)
                }

                HStack {
                    Button {
                        viewModel.goToPreviousStep()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        updateAgentsFile()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                            Text("Update AGENTS.md")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private func componentRow(_ component: ComponentContext.Component) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(component.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text(component.source.rawValue.capitalized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgElevated)
                    .cornerRadius(4)
            }

            if let description = component.description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }

            Text("Usage: \(component.usageExample)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.textTertiary)

            if let filePath = component.filePath {
                Text(filePath)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentPrimary)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Color.bgSurface)
        .cornerRadius(Theme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    private var loadComponentsPrompt: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Scan for Components")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("Detect generated components in your project")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }

            Button {
                Task {
                    if let projectPath = appState.projectPath {
                        await viewModel.loadComponentContext(projectURL: URL(fileURLWithPath: projectPath))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(viewModel.isLoading ? "Scanning..." : "Scan Components")
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading || appState.projectPath == nil)

            if appState.projectPath == nil {
                Text("Set a project path in settings first")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.statusWarning)
            }

            Spacer()

            HStack {
                Button {
                    viewModel.goToPreviousStep()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let error = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.statusError)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.statusError)

                Spacer()

                Button {
                    viewModel.clearError()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            } else if let progress = viewModel.progressMessage {
                ProgressView()
                    .controlSize(.small)
                Text(progress)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.bgSurface)
    }

    // MARK: - Actions

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    await viewModel.loadArtBible(from: url)
                }
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func loadFromProject() {
        guard let projectPath = appState.projectPath else {
            viewModel.errorMessage = "Set a project path first."
            return
        }

        let projectURL = URL(fileURLWithPath: projectPath)
        let candidates = ["art-bible.json", "art_bible.json"]

        for filename in candidates {
            let url = projectURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: url.path) {
                Task {
                    await viewModel.loadArtBible(from: url)
                }
                return
            }
        }

        viewModel.errorMessage = "No art-bible.json found in project directory."
    }

    private func exportPRD() {
        guard let assetPRD = viewModel.assetPRD else { return }

        let url: URL
        if exportPath.hasPrefix("/") {
            url = URL(fileURLWithPath: exportPath)
        } else if let projectPath = appState.projectPath {
            url = URL(fileURLWithPath: projectPath).appendingPathComponent(exportPath)
        } else {
            url = URL(fileURLWithPath: exportPath)
        }

        Task {
            do {
                try await viewModel.exportAssetPRD(to: url)
                appState.setActivePRD(url: url, name: assetPRD.featureName)
                showExportPanel = false
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func launchLoop() {
        guard let assetPRD = viewModel.assetPRD else {
            viewModel.errorMessage = "Generate an asset PRD first."
            return
        }

        guard let projectPath = appState.projectPath else {
            viewModel.errorMessage = "Set a project path first."
            return
        }

        viewModel.markLoopStarted()

        let repoURL = URL(fileURLWithPath: projectPath)
        Task {
            await appState.startOrchestration(document: assetPRD, repoPath: repoURL)
            viewModel.markLoopCompleted()
        }
    }

    private func updateAgentsFile() {
        guard let projectPath = appState.projectPath else {
            viewModel.errorMessage = "Set a project path first."
            return
        }

        let projectURL = URL(fileURLWithPath: projectPath)
        let agentsURL = projectURL.appendingPathComponent("AGENTS.md")
        let builder = ComponentContextBuilder()

        do {
            try builder.updateAgentsFile(at: agentsURL, projectURL: projectURL)
            viewModel.progressMessage = "AGENTS.md updated successfully"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                viewModel.progressMessage = nil
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ArtDirectionView_Previews: PreviewProvider {
    static var previews: some View {
        ArtDirectionView()
            .frame(width: 900, height: 700)
            .background(Color.bgApp)
    }
}
#endif
