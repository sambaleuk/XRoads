//
//  AssetPRDPreviewView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-025: Preview and export the asset PRD generated from an Art Bible
//

import SwiftUI

// MARK: - Asset PRD Preview

struct AssetPRDPreviewView: View {
    @Environment(\.appState) private var appState

    let artBible: ArtBible

    @State private var document: PRDDocument?
    @State private var errorMessage: String?
    @State private var exportPath: String = "prd-assets.json"
    @State private var isExporting: Bool = false
    @State private var exportSuccess: Bool = false
    @State private var exportError: String?

    private let generator = AssetPRDGenerator()

    init(artBible: ArtBible) {
        self.artBible = artBible
        let generator = AssetPRDGenerator()
        if let document = try? generator.generateDocument(from: artBible) {
            _document = State(initialValue: document)
            _errorMessage = State(initialValue: nil)
        } else {
            _document = State(initialValue: nil)
            _errorMessage = State(initialValue: "No components found in the Art Bible.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header

            if let document {
                PRDPreviewView(document: document)
            } else {
                EmptyStateCard(
                    title: "No Components Detected",
                    subtitle: errorMessage ?? "Add components or design tokens to the Art Bible."
                )
            }

            exportPanel
        }
        .padding(Theme.Spacing.lg)
        .background(Color.bgApp)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Asset PRD Generator")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("Generate and export an asset PRD directly from the Art Bible")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Export Panel

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Export")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: Theme.Spacing.sm) {
                TextField("prd-assets.json", text: $exportPath)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)

                Button {
                    exportAssetPRD()
                } label: {
                    HStack(spacing: 6) {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.doc")
                        }
                        Text(isExporting ? "Exporting..." : "Export PRD")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(document == nil || isExporting || exportPath.isEmpty)
            }
            .padding(Theme.Spacing.sm)
            .background(Color.bgSurface)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )

            if let exportError {
                Text(exportError)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.statusError)
            }

            if exportSuccess {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.statusSuccess)
                    Text("Asset PRD exported successfully")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.statusSuccess)

                    Spacer()

                    Button {
                        launchLoop()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Launch Loop")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgSurface)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func exportAssetPRD() {
        guard let document else {
            exportError = "Generate an asset PRD before exporting."
            return
        }

        guard let outputURL = resolveExportURL() else {
            exportError = "Invalid export path."
            return
        }

        isExporting = true
        exportError = nil
        exportSuccess = false

        do {
            try generator.export(document: document, to: outputURL)
            exportSuccess = true
            appState.setActivePRD(url: outputURL, name: document.featureName)
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    private func launchLoop() {
        guard let document else { return }
        guard let projectPath = appState.projectPath else {
            exportError = "Set a project path before launching the loop."
            return
        }

        let repoURL = URL(fileURLWithPath: projectPath)
        Task {
            await appState.startOrchestration(document: document, repoPath: repoURL)
        }
    }

    private func resolveExportURL() -> URL? {
        guard !exportPath.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }

        if exportPath.hasPrefix("/") {
            return URL(fileURLWithPath: exportPath)
        }

        if let projectPath = appState.projectPath {
            return URL(fileURLWithPath: exportPath, relativeTo: URL(fileURLWithPath: projectPath))
                .standardizedFileURL
        }

        return URL(fileURLWithPath: exportPath)
    }
}

// MARK: - Empty State Card

private struct EmptyStateCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AssetPRDPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        AssetPRDPreviewView(artBible: sampleArtBible)
            .frame(width: 780, height: 680)
            .padding()
            .background(Color.bgApp)
    }

    static var sampleArtBible: ArtBible {
        ArtBible(
            project: "XRoads",
            version: "1.0.0",
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
                    description: "Main call-to-action button",
                    tokens: ["accent.primary", "radius.md"],
                    styleSpecs: nil,
                    visualPrompt: nil,
                    interaction: nil
                ),
                ArtBibleComponent(
                    name: "Card",
                    description: "Surface container for content",
                    tokens: ["background.secondary", "radius.lg"],
                    styleSpecs: nil,
                    visualPrompt: nil,
                    interaction: nil
                )
            ]
        )
    }
}
#endif
