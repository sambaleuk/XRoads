//
//  AssetPRDGenerator.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-025: Generate an asset PRD from art-bible.json
//

import Foundation

// MARK: - Errors

enum AssetPRDGeneratorError: LocalizedError {
    case noComponents
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noComponents:
            return "Art bible does not contain any components or tokens to generate an asset PRD."
        case .writeFailed(let path):
            return "Failed to write asset PRD to \(path)."
        }
    }
}

// MARK: - Generator

struct AssetPRDGenerator {

    // MARK: - Public API

    func loadArtBible(from url: URL) throws -> ArtBible {
        let data = try Data(contentsOf: url)
        return try decodeArtBible(from: data)
    }

    func generateDocument(from artBible: ArtBible) throws -> PRDDocument {
        let components = resolveComponents(from: artBible)
        guard !components.isEmpty else {
            throw AssetPRDGeneratorError.noComponents
        }

        let prefix = PRDTemplateType.assets.defaultStoryPrefix
        let stories = makeStories(from: components, prefix: prefix)

        let projectName = artBible.project.trimmingCharacters(in: .whitespacesAndNewlines)
        let featureName = projectName.isEmpty ? "Design Assets" : "\(projectName) Design Assets"

        var document = PRDDocument(
            featureName: featureName,
            description: "Generate design system assets from the Art Bible specification.",
            templateType: .assets,
            userStories: stories,
            vision: PRDVision(
                summary: "Translate art direction into reusable UI assets.",
                keyConcepts: ["Token fidelity", "Component coverage", "Design system"]
            )
        )

        document.successMetrics = [
            "All art bible components represented as user stories",
            "Each component has a matching unit test spec",
            "PRD ready to launch asset generation loop"
        ]

        return document
    }

    @discardableResult
    func exportAssetsPRD(from artBibleURL: URL, outputURL: URL? = nil) throws -> PRDDocument {
        let artBible = try loadArtBible(from: artBibleURL)
        let document = try generateDocument(from: artBible)
        let targetURL = outputURL ?? defaultOutputURL(near: artBibleURL)
        try export(document: document, to: targetURL)
        return document
    }

    func export(document: PRDDocument, to url: URL) throws {
        let json = try document.toJSON()
        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw AssetPRDGeneratorError.writeFailed(url.path)
        }
    }

    // MARK: - Internal Helpers

    private func decodeArtBible(from data: Data) throws -> ArtBible {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArtBible.self, from: data)
    }

    private func resolveComponents(from artBible: ArtBible) -> [ArtBibleComponent] {
        let explicitComponents = artBible.allComponents
        if !explicitComponents.isEmpty {
            return explicitComponents
        }
        return supplementalComponents(from: artBible)
    }

    private func supplementalComponents(from artBible: ArtBible) -> [ArtBibleComponent] {
        var components: [ArtBibleComponent] = []

        if let tokens = artBible.designTokens {
            components.append(
                ArtBibleComponent(
                    name: "Theme",
                    description: "Define core theme tokens for the design system.",
                    tokens: ["design_tokens"],
                    styleSpecs: nil,
                    visualPrompt: nil,
                    interaction: nil
                )
            )

            if let colors = tokens.colors, !colors.isEmpty {
                components.append(
                    ArtBibleComponent(
                        name: "Color Tokens",
                        description: "Translate color tokens into usable palette assets.",
                        tokens: colorTokenList(from: colors),
                        styleSpecs: nil,
                        visualPrompt: nil,
                        interaction: nil
                    )
                )
            }

            if tokens.typography != nil {
                components.append(
                    ArtBibleComponent(
                        name: "Typography Tokens",
                        description: "Define typography scales and text styles.",
                        tokens: ["typography"],
                        styleSpecs: nil,
                        visualPrompt: nil,
                        interaction: nil
                    )
                )
            }

            if let spacing = tokens.spacing, !spacing.isEmpty {
                components.append(
                    ArtBibleComponent(
                        name: "Spacing Scale",
                        description: "Generate spacing scale assets.",
                        tokens: spacing.keys.sorted().map { "spacing.\($0)" },
                        styleSpecs: nil,
                        visualPrompt: nil,
                        interaction: nil
                    )
                )
            }

            if let radius = tokens.radius, !radius.isEmpty {
                components.append(
                    ArtBibleComponent(
                        name: "Radius Scale",
                        description: "Generate corner radius tokens and helpers.",
                        tokens: radius.keys.sorted().map { "radius.\($0)" },
                        styleSpecs: nil,
                        visualPrompt: nil,
                        interaction: nil
                    )
                )
            }
        }

        if let colorSystem = artBible.colorSystem, !colorSystem.isEmpty {
            components.append(
                ArtBibleComponent(
                    name: "Color System",
                    description: "Build semantic color system assets.",
                    tokens: colorSystem.keys.sorted().map { "color_system.\($0)" },
                    styleSpecs: nil,
                    visualPrompt: nil,
                    interaction: nil
                )
            )
        }

        if let typographySystem = artBible.typographySystem, !typographySystem.isEmpty {
            components.append(
                ArtBibleComponent(
                    name: "Typography System",
                    description: "Build typography system assets and documentation.",
                    tokens: typographySystem.keys.sorted().map { "typography_system.\($0)" },
                    styleSpecs: nil,
                    visualPrompt: nil,
                    interaction: nil
                )
            )
        }

        return components
    }

    private func colorTokenList(from colors: [String: [String: String]]) -> [String] {
        let groups = colors.keys.sorted()
        if groups.isEmpty {
            return ["design_tokens.colors"]
        }
        return groups.flatMap { group in
            let tokens = colors[group]?.keys.sorted() ?? []
            if tokens.isEmpty {
                return ["colors.\(group)"]
            }
            return tokens.map { "colors.\(group).\($0)" }
        }
    }

    private func makeStories(from components: [ArtBibleComponent], prefix: String) -> [PRDUserStory] {
        let sortedComponents = components.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return sortedComponents.enumerated().map { index, component in
            let id = "\(prefix)-\(String(format: "%03d", index + 1))"
            let description = component.description ?? "Build the \(component.name) asset based on the art bible."
            let criteria = acceptanceCriteria(for: component)
            let priority = priority(for: component)
            let complexity = estimatedComplexity(for: component)

            var story = PRDUserStory(
                id: id,
                title: "Implement \(component.name)",
                description: description,
                priority: priority,
                acceptanceCriteria: criteria,
                dependsOn: [],
                estimatedComplexity: complexity
            )

            story.unitTest = makeUnitTest(for: component, criteria: criteria)
            return story
        }
    }

    private func acceptanceCriteria(for component: ArtBibleComponent) -> [String] {
        var criteria: [String] = []

        if let summary = tokenSummary(for: component) {
            criteria.append("Applies tokens: \(summary)")
        } else {
            criteria.append("Tokens mapped from art bible to component specs")
        }

        criteria.append("Matches art bible specification for \(component.name)")
        criteria.append("Documented in the design system with usage examples")
        return criteria
    }

    private func tokenSummary(for component: ArtBibleComponent) -> String? {
        guard let tokens = component.tokens, !tokens.isEmpty else { return nil }
        let preview = tokens.prefix(4).joined(separator: ", ")
        if tokens.count > 4 {
            return "\(preview), +\(tokens.count - 4) more"
        }
        return preview
    }

    private func priority(for component: ArtBibleComponent) -> PRDPriority {
        let name = component.name.lowercased()
        if name.contains("theme") || name.contains("color") || name.contains("typography") {
            return .high
        }
        return .medium
    }

    private func estimatedComplexity(for component: ArtBibleComponent) -> Int {
        let tokenCount = component.tokens?.count ?? 0
        let base = 2 + (tokenCount / 3)
        return min(8, max(2, base))
    }

    private func makeUnitTest(for component: ArtBibleComponent, criteria: [String]) -> PRDUnitTest {
        let slug = slugify(component.name)
        return PRDUnitTest(
            file: "XRoadsTests/ArtDirection/\(slug)AssetTests.swift",
            name: "test_\(slug)_asset_spec",
            description: "Verify \(component.name) asset specification",
            assertions: criteria,
            status: .pending
        )
    }

    private func slugify(_ value: String) -> String {
        var result = ""
        var lastWasUnderscore = false

        for scalar in value.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.append(String(scalar).lowercased())
                lastWasUnderscore = false
            } else if !lastWasUnderscore {
                result.append("_")
                lastWasUnderscore = true
            }
        }

        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return result.isEmpty ? "component" : result
    }

    private func defaultOutputURL(near artBibleURL: URL) -> URL {
        let folder = artBibleURL.deletingLastPathComponent()
        return folder.appendingPathComponent("prd-assets.json")
    }
}
