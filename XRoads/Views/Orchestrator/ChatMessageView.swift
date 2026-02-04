//
//  ChatMessageView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-013: Individual chat message display component
//

import SwiftUI

// MARK: - ChatMessageView

/// Displays a single chat message with role-appropriate styling
struct ChatMessageView: View {
    let message: ChatMessage
    var onActionTap: ((ChatAction) -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Avatar
            avatarView

            // Message content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Header with role and timestamp
                headerView

                // Message content
                contentView

                // Actions (if any)
                if let actions = message.actions, !actions.isEmpty {
                    actionsView(actions)
                }
            }
            .frame(maxWidth: Theme.Layout.chatMaxWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.md)
        .background(isHovered ? Color.bgElevated.opacity(0.5) : .clear)
        .cornerRadius(Theme.Radius.sm)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Theme.Animation.fast)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarBackgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: message.role.iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(avatarForegroundColor)
        }
    }

    private var avatarBackgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentPrimary.opacity(0.2)
        case .assistant:
            return Color.statusSuccess.opacity(0.2)
        case .system:
            return Color.textSecondary.opacity(0.2)
        }
    }

    private var avatarForegroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentPrimary
        case .assistant:
            return Color.statusSuccess
        case .system:
            return Color.textSecondary
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(message.role.displayName)
                .font(.small)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)

            Text(message.formattedTimestamp)
                .font(.xs)
                .foregroundStyle(Color.textTertiary)

            // Status indicator
            if message.status.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            }

            if case .error(let errorMessage) = message.status {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Error")
                        .font(.xs)
                }
                .foregroundStyle(Color.statusError)
                .help(errorMessage)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if message.content.isEmpty && message.status == .streaming {
            // Streaming placeholder with typing indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.textTertiary)
                        .frame(width: 6, height: 6)
                        .opacity(animationOpacity(for: index))
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: message.status
                        )
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        } else {
            Text(message.content)
                .font(.body14)
                .foregroundStyle(message.role == .system ? Color.textSecondary : Color.textPrimary)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func animationOpacity(for index: Int) -> Double {
        // Simple opacity animation for typing indicator
        return 0.3 + (Double(index) * 0.2)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionsView(_ actions: [ChatAction]) -> some View {
        FlowLayout(spacing: Theme.Spacing.xs) {
            ForEach(actions) { action in
                Button {
                    onActionTap?(action)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: actionIcon(for: action.type))
                            .font(.system(size: 10))
                        Text(action.label)
                            .font(.xs)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.accentPrimary.opacity(0.1))
                    .foregroundStyle(Color.accentPrimary)
                    .cornerRadius(Theme.Radius.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private func actionIcon(for type: ChatActionType) -> String {
        switch type {
        case .createPRD:
            return "doc.badge.plus"
        case .launchLoop:
            return "play.circle.fill"
        case .openFile:
            return "doc.text"
        case .createWorktree:
            return "arrow.triangle.branch"
        case .runCommand:
            return "terminal"
        case .viewArtBible:
            return "paintpalette"
        case .viewSkills:
            return "list.bullet.rectangle"
        }
    }
}

// MARK: - FlowLayout Helper

/// Simple flow layout for action buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)

                if currentX + viewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, viewSize.height)
                currentX += viewSize.width + spacing
                size.width = max(size.width, currentX)
            }

            size.height = currentY + lineHeight
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ChatMessageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            ChatMessageView(message: .user("Create a login feature with OAuth support for Google and GitHub"))

            ChatMessageView(message: .assistant("I'll help you create a login feature with OAuth support. Here's what we'll need:\n\n1. **OAuth Configuration** - Set up Google and GitHub OAuth apps\n2. **Backend Endpoints** - Handle the OAuth callbacks\n3. **UI Components** - Login buttons and user session display\n\nWould you like me to create a PRD for this feature?"))

            ChatMessageView(message: ChatMessage(
                role: .assistant,
                content: "Here's the PRD for the OAuth login feature.",
                actions: [
                    ChatAction(type: .createPRD, label: "View PRD"),
                    ChatAction(type: .launchLoop, label: "Start Loop")
                ]
            ))

            ChatMessageView(message: .system("Connected to XRoads MCP server"))

            ChatMessageView(message: ChatMessage.streamingPlaceholder())
        }
        .padding()
        .background(Color.bgApp)
        .frame(width: 600)
    }
}
#endif
