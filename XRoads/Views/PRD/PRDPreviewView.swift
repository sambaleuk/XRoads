//
//  PRDPreviewView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-023: Real-time PRD preview panel
//

import SwiftUI

// MARK: - PRD Preview View

struct PRDPreviewView: View {
    let document: PRDDocument

    @State private var selectedTab: PreviewTab = .summary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header

            Picker("Preview", selection: $selectedTab) {
                ForEach(PreviewTab.allCases, id: \.self) { tab in
                    Text(tab.displayName)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch selectedTab {
            case .summary:
                summaryView
            case .json:
                jsonView
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PRD Preview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text("Updates live as you edit the wizard")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.featureName.isEmpty ? "Untitled Feature" : document.featureName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(document.description.isEmpty ? "Add a feature description to see it here." : document.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                HStack(spacing: Theme.Spacing.lg) {
                    summaryStat(label: "Template", value: document.templateType.displayName)
                    summaryStat(label: "Stories", value: "\(document.userStories.count)")
                    summaryStat(label: "Progress", value: String(format: "%.0f%%", document.progress * 100))
                }
                .padding(Theme.Spacing.md)
                .background(Color.bgElevated)
                .cornerRadius(Theme.Radius.md)

                if !document.userStories.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Stories")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        ForEach(document.userStories.prefix(6)) { story in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(story.id) · \(story.title)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.textPrimary)
                                    Text(story.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Text(story.priority.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.accentPrimary)
                            }
                            .padding(Theme.Spacing.sm)
                            .background(Color.bgSurface)
                            .cornerRadius(Theme.Radius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(Color.borderMuted, lineWidth: 1)
                            )
                        }

                        if document.userStories.count > 6 {
                            Text("+ \(document.userStories.count - 6) more stories")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private var jsonView: some View {
        let json = (try? document.toJSON()) ?? "{}"
        return ScrollView {
            Text(json)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.sm)
        }
        .background(Color.bgCanvas)
        .cornerRadius(Theme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color.borderMuted, lineWidth: 1)
        )
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum PreviewTab: String, CaseIterable {
    case summary
    case json

    var displayName: String {
        switch self {
        case .summary: return "Summary"
        case .json: return "JSON"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PRDPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        PRDPreviewView(document: sampleDocument)
            .frame(width: 360, height: 500)
            .padding()
            .background(Color.bgApp)
    }

    static var sampleDocument: PRDDocument {
        let stories = [
            PRDUserStory(
                id: "US-001",
                title: "Create onboarding flow",
                description: "Guide users through key setup steps",
                priority: .high,
                acceptanceCriteria: ["Shows 3 steps", "Supports skip"],
                estimatedComplexity: 3
            ),
            PRDUserStory(
                id: "US-002",
                title: "Persist onboarding state",
                description: "Save onboarding completion to disk",
                priority: .medium,
                acceptanceCriteria: ["Uses UserDefaults"],
                estimatedComplexity: 2
            )
        ]

        return PRDDocument(
            featureName: "Onboarding",
            description: "Add a guided onboarding experience",
            templateType: .feature,
            userStories: stories,
            vision: PRDVision(summary: "Reduce time to first value", keyConcepts: ["Guided", "Fast"]) 
        )
    }
}
#endif
