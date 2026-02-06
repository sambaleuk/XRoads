//
//  PRDProposalView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-05.
//  Popup view shown when a PRD is detected in chat, proposing implementation.
//

import SwiftUI

// MARK: - PRDProposalView

/// Floating card that appears when a PRD is detected in chat
struct PRDProposalView: View {
    let detectedPRD: DetectedPRD
    let onDismiss: () -> Void
    let onViewPRD: () -> Void
    let onLaunch: (AgentType, String) -> Void
    let onConfigureMultiAgent: () -> Void

    @State private var selectedAgent: AgentType
    @State private var branchName: String
    @State private var isExpanded = false

    init(
        detectedPRD: DetectedPRD,
        onDismiss: @escaping () -> Void,
        onViewPRD: @escaping () -> Void,
        onLaunch: @escaping (AgentType, String) -> Void,
        onConfigureMultiAgent: @escaping () -> Void = {}
    ) {
        self.detectedPRD = detectedPRD
        self.onDismiss = onDismiss
        self.onViewPRD = onViewPRD
        self.onLaunch = onLaunch
        self.onConfigureMultiAgent = onConfigureMultiAgent
        self._selectedAgent = State(initialValue: detectedPRD.suggestedAgent)
        self._branchName = State(initialValue: detectedPRD.suggestedBranch)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header

            Divider()
                .background(Color.borderDefault)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                // PRD Info
                prdInfoSection

                // Complexity Badge
                complexityBadge

                // Agent Selection (expandable for complex)
                if detectedPRD.complexity.recommendsMultiAgent || isExpanded {
                    agentSelectionSection
                }

                // Branch Name
                branchSection

                // Actions
                actionButtons
            }
            .padding(16)
        }
        .background(Color.bgElevated)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentPrimary.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 20))
                .foregroundColor(Color.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("PRD Détecté")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.textPrimary)

                Text(detectedPRD.title)
                    .font(.system(size: 12))
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Dismiss button
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

    // MARK: - PRD Info Section

    private var prdInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !detectedPRD.description.isEmpty {
                Text(detectedPRD.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                // Story count
                Label {
                    Text("\(detectedPRD.storyCount) story\(detectedPRD.storyCount > 1 ? "s" : "")")
                        .font(.system(size: 11))
                } icon: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color.textTertiary)

                // Suggested agent
                Label {
                    Text(detectedPRD.suggestedAgent.displayName)
                        .font(.system(size: 11))
                } icon: {
                    Image(systemName: detectedPRD.suggestedAgent.iconName)
                        .font(.system(size: 10))
                }
                .foregroundColor(detectedPRD.suggestedAgent.color)
            }
        }
    }

    // MARK: - Complexity Badge

    private var complexityBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: detectedPRD.complexity.icon)
                .font(.system(size: 12))

            Text("Complexité: \(detectedPRD.complexity.displayName)")
                .font(.system(size: 11, weight: .medium))

            if detectedPRD.complexity.recommendsMultiAgent {
                Text("Multi-agent recommandé")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentPrimary.opacity(0.2))
                    .cornerRadius(4)
            }

            Spacer()

            // Expand button for options
            if !detectedPRD.complexity.recommendsMultiAgent {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(complexityBackgroundColor.opacity(0.15))
        .cornerRadius(8)
        .foregroundColor(complexityBackgroundColor)
    }

    private var complexityBackgroundColor: Color {
        switch detectedPRD.complexity {
        case .trivial: return Color.statusSuccess
        case .simple: return Color.accentPrimary
        case .moderate: return Color.statusWarning
        case .complex: return Color.statusError
        }
    }

    // MARK: - Agent Selection

    private var agentSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.textSecondary)

            HStack(spacing: 8) {
                ForEach(AgentType.allCases, id: \.self) { agent in
                    agentButton(agent)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func agentButton(_ agent: AgentType) -> some View {
        Button(action: { selectedAgent = agent }) {
            HStack(spacing: 6) {
                Image(systemName: agent.iconName)
                    .font(.system(size: 12))

                Text(agent.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedAgent == agent ? agent.color.opacity(0.2) : Color.bgSurface)
            .foregroundColor(selectedAgent == agent ? agent.color : Color.textSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedAgent == agent ? agent.color : Color.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Branch Section

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Branche")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.textSecondary)

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12))
                    .foregroundColor(Color.textTertiary)

                TextField("feat/feature-name", text: $branchName)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.bgSurface)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // View PRD
                Button(action: onViewPRD) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("Voir PRD")
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

                // Single-agent launch button
                Button(action: { onLaunch(selectedAgent, branchName) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Lancer l'implémentation")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            // Multi-agent configure button (only when complexity recommends it)
            if detectedPRD.complexity.recommendsMultiAgent {
                Button(action: onConfigureMultiAgent) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Configurer Multi-Agent")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.statusWarning.opacity(0.15))
                    .foregroundColor(Color.statusWarning)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.statusWarning.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - PRDProposalOverlay

/// Overlay container that positions the proposal view
struct PRDProposalOverlay: View {
    let detectedPRD: DetectedPRD?
    let onDismiss: () -> Void
    let onViewPRD: (DetectedPRD) -> Void
    let onLaunch: (DetectedPRD, AgentType, String) -> Void
    let onConfigureMultiAgent: (DetectedPRD) -> Void

    init(
        detectedPRD: DetectedPRD?,
        onDismiss: @escaping () -> Void,
        onViewPRD: @escaping (DetectedPRD) -> Void,
        onLaunch: @escaping (DetectedPRD, AgentType, String) -> Void,
        onConfigureMultiAgent: @escaping (DetectedPRD) -> Void = { _ in }
    ) {
        self.detectedPRD = detectedPRD
        self.onDismiss = onDismiss
        self.onViewPRD = onViewPRD
        self.onLaunch = onLaunch
        self.onConfigureMultiAgent = onConfigureMultiAgent
    }

    var body: some View {
        if let prd = detectedPRD {
            VStack {
                Spacer()

                PRDProposalView(
                    detectedPRD: prd,
                    onDismiss: onDismiss,
                    onViewPRD: { onViewPRD(prd) },
                    onLaunch: { agent, branch in onLaunch(prd, agent, branch) },
                    onConfigureMultiAgent: { onConfigureMultiAgent(prd) }
                )
                .padding(24)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: detectedPRD?.id)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.bgApp
            .ignoresSafeArea()

        PRDProposalView(
            detectedPRD: DetectedPRD(
                id: UUID(),
                title: "Share Button Feature",
                description: "Ajouter un bouton de partage sur les articles du blog",
                complexity: .complex,
                storyCount: 8,
                suggestedAgent: .claude,
                suggestedBranch: "feat/share-button",
                rawJSON: "{}",
                prdData: nil
            ),
            onDismiss: {},
            onViewPRD: {},
            onLaunch: { _, _ in },
            onConfigureMultiAgent: {}
        )
        .padding(40)
    }
    .frame(width: 500, height: 500)
}
