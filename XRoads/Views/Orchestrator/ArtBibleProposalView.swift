//
//  ArtBibleProposalView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-10.
//  Floating card shown when an art-bible JSON block is detected in chat.
//

import SwiftUI

// MARK: - ArtBibleSummary

/// Parsed summary from a detected art-bible JSON for display purposes
struct ArtBibleSummary {
    let projectName: String
    let colorCount: Int
    let typographyCount: Int
    let componentCount: Int
    let moodKeywords: [String]
    let spacingCount: Int

    /// Parse from raw JSON string
    static func parse(from json: String) -> ArtBibleSummary? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let project = dict["project"] as? String ?? "Untitled"

        // Count colors from designTokens.colors + colorSystem
        var colorCount = 0
        if let tokens = dict["designTokens"] as? [String: Any],
           let colors = tokens["colors"] as? [String: Any] {
            for (_, group) in colors {
                if let g = group as? [String: Any] {
                    colorCount += g.count
                }
            }
        }
        if let colorSystem = dict["colorSystem"] as? [String: Any] {
            colorCount += colorSystem.count
        }

        // Count typography entries
        var typoCount = 0
        if let typoSystem = dict["typographySystem"] as? [String: Any] {
            typoCount = typoSystem.count
        }

        // Count components
        var compCount = 0
        if let comps = dict["uiComponents"] as? [[String: Any]] {
            compCount += comps.count
        }
        if let comps = dict["components"] as? [[String: Any]] {
            compCount += comps.count
        }

        // Mood keywords
        var mood: [String] = []
        if let moodboard = dict["verbalMoodboard"] as? [[String: Any]] {
            for entry in moodboard {
                if let keywords = entry["keywords"] as? [String] {
                    mood.append(contentsOf: keywords)
                }
            }
        }

        // Spacing tokens count
        var spacingCount = 0
        if let tokens = dict["designTokens"] as? [String: Any],
           let spacing = tokens["spacing"] as? [String: Any] {
            spacingCount = spacing.count
        }

        return ArtBibleSummary(
            projectName: project,
            colorCount: colorCount,
            typographyCount: typoCount,
            componentCount: compCount,
            moodKeywords: mood,
            spacingCount: spacingCount
        )
    }
}

// MARK: - ArtBibleProposalView

/// Floating card that appears when an art-bible is detected in chat
struct ArtBibleProposalView: View {
    let rawJSON: String
    let summary: ArtBibleSummary
    let onDismiss: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header

            Divider()
                .background(Color.borderDefault)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Mood keywords
                if !summary.moodKeywords.isEmpty {
                    moodSection
                }

                // Stats grid
                statsGrid

                // Actions
                actionButtons
            }
            .padding(16)
        }
        .background(Color.bgElevated)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6), .orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .purple.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Art Bible Detected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.textPrimary)

                Text(summary.projectName)
                    .font(.system(size: 12))
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(Color.bgSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mood")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.textSecondary)

            FlowLayout(spacing: 6) {
                ForEach(summary.moodKeywords.prefix(8), id: \.self) { keyword in
                    Text(keyword)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(Color.purple)
                        .cornerRadius(4)
                }
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statBadge(icon: "paintpalette.fill", count: summary.colorCount, label: "Colors", color: .orange)
            statBadge(icon: "textformat", count: summary.typographyCount, label: "Typo", color: .blue)
            statBadge(icon: "square.stack.fill", count: summary.componentCount, label: "Components", color: .green)
            if summary.spacingCount > 0 {
                statBadge(icon: "ruler.fill", count: summary.spacingCount, label: "Spacing", color: .indigo)
            }
        }
    }

    private func statBadge(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Dismiss
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Ignorer")
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.bgSurface)
                .foregroundColor(Color.textSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Save button
            Button(action: onSave) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Sauvegarder art-bible.json")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - ArtBibleProposalOverlay

/// Overlay container that positions the art-bible proposal view
struct ArtBibleProposalOverlay: View {
    let detectedArtBible: String?
    let projectPath: String?
    let onDismiss: () -> Void
    let onSaved: () -> Void

    @State private var saveError: String?

    var body: some View {
        if let json = detectedArtBible,
           let summary = ArtBibleSummary.parse(from: json) {
            VStack {
                Spacer()

                ArtBibleProposalView(
                    rawJSON: json,
                    summary: summary,
                    onDismiss: onDismiss,
                    onSave: { saveArtBible(json: json) }
                )
                .padding(24)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: detectedArtBible != nil)
        }
    }

    private func saveArtBible(json: String) {
        guard let path = projectPath else {
            saveError = "No project selected"
            return
        }

        let filePath = URL(fileURLWithPath: path).appendingPathComponent("art-bible.json")

        do {
            // Pretty-print the JSON before saving
            if let data = json.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
                try pretty.write(to: filePath)
            } else {
                try json.write(to: filePath, atomically: true, encoding: .utf8)
            }

            onSaved()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color.bgApp
            .ignoresSafeArea()

        ArtBibleProposalView(
            rawJSON: "{}",
            summary: ArtBibleSummary(
                projectName: "MyApp",
                colorCount: 12,
                typographyCount: 6,
                componentCount: 8,
                moodKeywords: ["minimal", "dark", "professional", "modern"],
                spacingCount: 5
            ),
            onDismiss: {},
            onSave: {}
        )
        .padding(40)
    }
    .frame(width: 500, height: 500)
}
#endif
