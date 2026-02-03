//
//  WorktreeCard.swift
//  XRoads
//
//  Created by Nexus on 2026-02-02.
//  Worktree card component with status badge for sidebar display.
//

import SwiftUI

// MARK: - StatusBadge

/// A visual status indicator with colored dot and optional pulse animation
struct StatusBadge: View {
    let status: AgentStatus

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            // Status dot with optional pulse
            Circle()
                .fill(statusColor)
                .frame(width: Theme.Component.statusDotSize, height: Theme.Component.statusDotSize)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: isPulsing ? 4 : 0)
                        .scaleEffect(isPulsing ? 1.5 : 1)
                        .opacity(isPulsing ? 0 : 1)
                )
                .animation(
                    status.isActive
                        ? .easeInOut(duration: Theme.Animation.pulse).repeatForever(autoreverses: false)
                        : .default,
                    value: isPulsing
                )

            // Status label
            Text(status.displayName)
                .font(.xs)
                .foregroundStyle(statusColor)
        }
        .onAppear {
            isPulsing = status.isActive
        }
        .onChange(of: status) { _, newStatus in
            isPulsing = newStatus.isActive
        }
    }

    private var statusColor: Color {
        switch status {
        case .running:
            return .statusSuccess
        case .idle:
            return .statusInfo
        case .error:
            return .statusError
        case .planning:
            return .statusWarning
        case .complete:
            return .statusSuccess
        }
    }
}

// MARK: - WorktreeCard

/// A card component displaying worktree information with agent status
struct WorktreeCard: View {
    let worktree: Worktree
    let agentType: AgentType?
    let status: AgentStatus
    let isSelected: Bool

    @State private var isHovered = false

    init(
        worktree: Worktree,
        agentType: AgentType? = nil,
        status: AgentStatus = .idle,
        isSelected: Bool = false
    ) {
        self.worktree = worktree
        self.agentType = agentType
        self.status = status
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Agent type icon
            agentIcon
                .frame(width: 32, height: 32)
                .background(agentIconBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))

            // Worktree info
            VStack(alignment: .leading, spacing: 2) {
                // Name
                Text(worktree.name)
                    .font(.body14)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                // Branch
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text(worktree.branch)
                        .font(.small)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.textSecondary)

                // Path (truncated)
                Text(truncatedPath)
                    .font(.xs)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Status badge
            StatusBadge(status: status)
        }
        .padding(Theme.Spacing.sm)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Theme.Animation.fast)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var agentIcon: some View {
        if let agentType {
            Image(systemName: agentType.iconName)
                .font(.system(size: 14))
                .foregroundStyle(agentIconColor)
        } else {
            Image(systemName: "questionmark")
                .font(.system(size: 14))
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        if isSelected {
            return .bgElevated
        } else if isHovered {
            return .bgElevated.opacity(0.6)
        } else {
            return .bgSurface
        }
    }

    private var borderColor: Color {
        if isSelected {
            return .borderAccent
        } else {
            return .borderMuted
        }
    }

    private var agentIconBackground: Color {
        switch agentType {
        case .claude:
            return Color.accentPrimary.opacity(0.15)
        case .gemini:
            return Color.statusWarning.opacity(0.15)
        case .codex:
            return Color.statusSuccess.opacity(0.15)
        case nil:
            return Color.textTertiary.opacity(0.15)
        }
    }

    private var agentIconColor: Color {
        switch agentType {
        case .claude:
            return .accentPrimary
        case .gemini:
            return .statusWarning
        case .codex:
            return .statusSuccess
        case nil:
            return .textTertiary
        }
    }

    private var truncatedPath: String {
        let path = worktree.path
        let components = path.split(separator: "/")
        if components.count > 3 {
            let last3 = components.suffix(3).joined(separator: "/")
            return ".../" + last3
        }
        return path
    }
}

// MARK: - Preview

#if DEBUG
struct WorktreeCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Running state with Claude
            WorktreeCard(
                worktree: Worktree(
                    path: "/Users/dev/Projects/MyApp/worktrees/feature-auth",
                    branch: "feature/auth-system"
                ),
                agentType: .claude,
                status: .running,
                isSelected: true
            )

            // Idle state with Gemini
            WorktreeCard(
                worktree: Worktree(
                    path: "/Users/dev/Projects/MyApp/worktrees/feature-ui",
                    branch: "feature/ui-redesign"
                ),
                agentType: .gemini,
                status: .idle,
                isSelected: false
            )

            // Planning state with Codex
            WorktreeCard(
                worktree: Worktree(
                    path: "/Users/dev/Projects/MyApp/worktrees/bugfix",
                    branch: "fix/memory-leak"
                ),
                agentType: .codex,
                status: .planning,
                isSelected: false
            )

            // Error state
            WorktreeCard(
                worktree: Worktree(
                    path: "/Users/dev/Projects/MyApp/worktrees/test",
                    branch: "test/integration"
                ),
                agentType: .claude,
                status: .error,
                isSelected: false
            )

            // No agent assigned
            WorktreeCard(
                worktree: Worktree(
                    path: "/Users/dev/Projects/MyApp/worktrees/orphan",
                    branch: "orphan-branch"
                ),
                agentType: nil,
                status: .idle,
                isSelected: false
            )

            // Status badges standalone
            HStack(spacing: Theme.Spacing.lg) {
                StatusBadge(status: .running)
                StatusBadge(status: .idle)
                StatusBadge(status: .planning)
                StatusBadge(status: .error)
                StatusBadge(status: .complete)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 300)
        .background(Color.bgApp)
    }
}
#endif
