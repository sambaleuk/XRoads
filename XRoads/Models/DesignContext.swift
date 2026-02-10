//
//  DesignContext.swift
//  XRoads
//
//  Created by Nexus on 2026-02-10.
//  Lightweight injectable summary of art-bible.json for agent/PRD injection
//

import Foundation

// MARK: - DesignContext

/// A flat, Sendable summary of an ArtBible optimized for injection into prompts and PRDs.
/// Unlike the full ArtBible (335 LOC, nested types), this is compact and agent-friendly.
public struct DesignContext: Codable, Hashable, Sendable {
    public let projectName: String
    public let palette: [String: String]             // semantic name -> hex ("accent.primary" -> "#388bfd")
    public let typography: [String: String]          // role -> spec ("heading.h1" -> "Inter Bold 32px")
    public let spacing: [String: Double]             // token -> value ("sm" -> 8, "md" -> 16)
    public let radius: [String: Double]              // token -> value ("sm" -> 4, "md" -> 8)
    public let moodKeywords: [String]                // ["minimal", "dark", "professional"]
    public let componentTokenMap: [String: [String]] // component -> tokens used

    // MARK: - Factory

    /// Build from a full ArtBible model
    static func from(_ artBible: ArtBible) -> DesignContext {
        // Palette: merge designTokens.colors + colorSystem into flat map
        var palette: [String: String] = [:]
        if let colorGroups = artBible.designTokens?.colors {
            for (group, colors) in colorGroups {
                for (name, hex) in colors {
                    palette["\(group).\(name)"] = hex
                }
            }
        }
        if let colorSystem = artBible.colorSystem {
            for (name, swatch) in colorSystem {
                palette[name] = swatch.hex
            }
        }

        // Typography: merge designTokens.typography + typographySystem
        var typography: [String: String] = [:]
        if let typoTokens = artBible.designTokens?.typography {
            if let families = typoTokens.fontFamily {
                for (role, family) in families {
                    typography[role] = family
                }
            }
            if let sizes = typoTokens.sizes {
                for (role, size) in sizes {
                    let sizeStr = size.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(size))px" : "\(size)px"
                    if let existing = typography[role] {
                        typography[role] = "\(existing) \(sizeStr)"
                    } else {
                        typography[role] = sizeStr
                    }
                }
            }
        }
        if let typoSystem = artBible.typographySystem {
            for (role, spec) in typoSystem {
                var parts: [String] = []
                if let font = spec.font { parts.append(font) }
                if let weight = spec.weight { parts.append("w\(Int(weight))") }
                let size = spec.sizeDesktop ?? spec.size ?? 0
                if size > 0 {
                    parts.append(size.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(size))px" : "\(size)px")
                }
                if !parts.isEmpty {
                    typography[role] = parts.joined(separator: " ")
                }
            }
        }

        // Spacing & radius: direct from designTokens
        let spacing = artBible.designTokens?.spacing ?? [:]
        let radius = artBible.designTokens?.radius ?? [:]

        // Mood keywords: from verbalMoodboard
        let moodKeywords = artBible.verbalMoodboard?
            .flatMap { $0.keywords ?? [] } ?? []

        // Component token map
        var componentTokenMap: [String: [String]] = [:]
        for component in artBible.allComponents {
            if let tokens = component.tokens, !tokens.isEmpty {
                componentTokenMap[component.name] = tokens
            }
        }

        return DesignContext(
            projectName: artBible.project,
            palette: palette,
            typography: typography,
            spacing: spacing,
            radius: radius,
            moodKeywords: moodKeywords,
            componentTokenMap: componentTokenMap
        )
    }

    // MARK: - Agent Injection

    /// Compact markdown for AGENT.md injection (~800 chars)
    var agentMarkdown: String {
        var lines: [String] = []
        lines.append("## Design Direction (from art-bible.json)")

        if !moodKeywords.isEmpty {
            lines.append("**Mood**: \(moodKeywords.joined(separator: ", "))")
        }

        if !palette.isEmpty {
            let colorEntries = palette.sorted(by: { $0.key < $1.key }).prefix(8)
                .map { "\($0.key)=\($0.value)" }
            lines.append("**Colors**: \(colorEntries.joined(separator: ", "))")
        }

        if !typography.isEmpty {
            let typoEntries = typography.sorted(by: { $0.key < $1.key }).prefix(6)
                .map { "\($0.key)=\($0.value)" }
            lines.append("**Typography**: \(typoEntries.joined(separator: ", "))")
        }

        if !spacing.isEmpty {
            let spacingEntries = spacing.sorted(by: { $0.value < $1.value })
                .map { "\($0.key)=\(Int($0.value))" }
            lines.append("**Spacing**: \(spacingEntries.joined(separator: ", "))")
        }

        if !radius.isEmpty {
            let radiusEntries = radius.sorted(by: { $0.value < $1.value })
                .map { "\($0.key)=\(Int($0.value))" }
            lines.append("**Radius**: \(radiusEntries.joined(separator: ", "))")
        }

        if !componentTokenMap.isEmpty {
            let componentEntries = componentTokenMap.sorted(by: { $0.key < $1.key }).prefix(6)
                .map { "\($0.key)[\($0.value.joined(separator: ", "))]" }
            lines.append("**Components**: \(componentEntries.joined(separator: ", "))")
        }

        lines.append("IMPORTANT: Follow these design tokens. Read art-bible.json for full specs.")

        return lines.joined(separator: "\n")
    }

    /// PRD-compatible dictionary for embedding in prd.json
    var prdSection: [String: Any] {
        var dict: [String: Any] = [:]
        if !palette.isEmpty { dict["palette"] = palette }
        if !typography.isEmpty { dict["typography"] = typography }
        if !spacing.isEmpty { dict["spacing"] = spacing }
        if !radius.isEmpty { dict["radius"] = radius }
        if !moodKeywords.isEmpty { dict["mood"] = moodKeywords }
        return dict
    }

    /// System prompt section for orchestrator awareness
    var systemPromptSection: String {
        var lines: [String] = []
        lines.append("## Visual DNA (from art-bible.json)")
        lines.append("Project: \(projectName)")

        if !moodKeywords.isEmpty {
            lines.append("Mood: \(moodKeywords.joined(separator: ", "))")
        }
        if !palette.isEmpty {
            let topColors = palette.sorted(by: { $0.key < $1.key }).prefix(6)
                .map { "\($0.key): \($0.value)" }
            lines.append("Palette: \(topColors.joined(separator: ", "))")
        }
        if !typography.isEmpty {
            let topTypo = typography.sorted(by: { $0.key < $1.key }).prefix(4)
                .map { "\($0.key): \($0.value)" }
            lines.append("Typography: \(topTypo.joined(separator: ", "))")
        }
        if !spacing.isEmpty {
            lines.append("Spacing tokens: \(spacing.count) defined")
        }
        if !componentTokenMap.isEmpty {
            lines.append("Component specs: \(componentTokenMap.count) components")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - ArtBible Loading Utility

extension DesignContext {
    /// Attempt to load a DesignContext from an art-bible.json file in the given directory
    static func load(from directoryPath: String) -> DesignContext? {
        let fm = FileManager.default
        for name in ["art-bible.json", "art_bible.json"] {
            let url = URL(fileURLWithPath: directoryPath).appendingPathComponent(name)
            guard fm.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url) else { continue }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let bible = try? decoder.decode(ArtBible.self, from: data) else { continue }
            return DesignContext.from(bible)
        }
        return nil
    }
}
