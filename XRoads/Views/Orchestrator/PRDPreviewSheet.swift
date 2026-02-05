//
//  PRDPreviewSheet.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Sheet for viewing full PRD content from detected PRD.
//

import SwiftUI

// MARK: - PRDPreviewSheet

/// Sheet displaying the full PRD content
struct PRDPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let prd: DetectedPRD

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(Color.borderDefault)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary section
                    summarySection

                    Divider()
                        .background(Color.borderMuted)

                    // Stories section
                    storiesSection

                    Divider()
                        .background(Color.borderMuted)

                    // Raw JSON section
                    rawJSONSection
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 500)
        .background(Color.bgApp)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("PRD Preview")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.textPrimary)

                Text(prd.title)
                    .font(.system(size: 12))
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            Button("Fermer") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
        }
        .padding(16)
        .background(Color.bgSurface)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Résumé", systemImage: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Titre", value: prd.title)
                infoRow(label: "Description", value: prd.description.isEmpty ? "Non spécifié" : prd.description)
                infoRow(label: "Complexité", value: prd.complexity.displayName)
                infoRow(label: "Stories", value: "\(prd.storyCount)")
                infoRow(label: "Agent suggéré", value: prd.suggestedAgent.displayName)
                infoRow(label: "Branche", value: prd.suggestedBranch)
            }
            .padding(12)
            .background(Color.bgSurface)
            .cornerRadius(8)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.textSecondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(Color.textPrimary)

            Spacer()
        }
    }

    // MARK: - Stories Section

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("User Stories", systemImage: "list.bullet.rectangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.textPrimary)

            if let stories = prd.prdData?.user_stories, !stories.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(stories.enumerated()), id: \.offset) { index, story in
                        storyRow(story, index: index)
                    }
                }
            } else {
                Text("Aucune story définie")
                    .font(.system(size: 12))
                    .foregroundColor(Color.textTertiary)
                    .italic()
            }
        }
    }

    private func storyRow(_ story: DetectedPRD.PRDData.UserStory, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Index
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.textSecondary)
                .frame(width: 24, height: 24)
                .background(Color.bgElevated)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(story.title ?? "Sans titre")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textPrimary)

                // Description
                if let description = story.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(Color.textSecondary)
                        .lineLimit(2)
                }

                // Priority badge
                if let priority = story.priority {
                    Text(priority.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(priorityColor(priority).opacity(0.2))
                        .foregroundColor(priorityColor(priority))
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(Color.bgSurface)
        .cornerRadius(6)
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "critical": return Color.statusError
        case "high": return Color.statusWarning
        case "medium": return Color.accentPrimary
        default: return Color.textTertiary
        }
    }

    // MARK: - Raw JSON Section

    private var rawJSONSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("JSON Source", systemImage: "curlybraces")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.textPrimary)

                Spacer()

                Button(action: copyJSON) {
                    Label("Copier", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.accentPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(formatJSON(prd.rawJSON))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.terminalCyan)
                    .padding(12)
            }
            .frame(maxHeight: 150)
            .background(Color.bgApp)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
        }
    }

    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8)
        else {
            return json
        }
        return prettyString
    }

    private func copyJSON() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formatJSON(prd.rawJSON), forType: .string)
    }
}

// MARK: - Preview

#Preview {
    PRDPreviewSheet(prd: DetectedPRD(
        id: UUID(),
        title: "Share Button Feature",
        description: "Ajouter un bouton de partage sur les articles du blog",
        complexity: .simple,
        storyCount: 2,
        suggestedAgent: .claude,
        suggestedBranch: "feat/share-button",
        rawJSON: """
        {
          "project_name": "Blog",
          "feature_name": "Share Button Feature",
          "description": "Ajouter un bouton de partage",
          "user_stories": [
            {"id": "US-001", "title": "Créer le composant", "priority": "high", "description": "Créer le bouton réutilisable"},
            {"id": "US-002", "title": "Intégrer le partage", "priority": "medium", "description": "Connecter l'API de partage"}
          ]
        }
        """,
        prdData: DetectedPRD.PRDData(
            project_name: "Blog",
            feature_name: "Share Button Feature",
            description: "Ajouter un bouton de partage",
            user_stories: [
                DetectedPRD.PRDData.UserStory(id: "US-001", title: "Créer le composant", priority: "high", description: "Créer le bouton réutilisable"),
                DetectedPRD.PRDData.UserStory(id: "US-002", title: "Intégrer le partage", priority: "medium", description: "Connecter l'API de partage")
            ]
        )
    ))
}
