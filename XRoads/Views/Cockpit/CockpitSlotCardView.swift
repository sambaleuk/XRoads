import SwiftUI

// MARK: - CockpitSlotCardView

/// Displays a single agent slot card within the Cockpit Mode panel.
/// Shows: skill name, agent type, status badge, unread message count, and expandable chat panel.
///
/// US-004: Added expandable chat panel and unread badge.
/// US-003: Added approval card overlay when slot is in waiting_approval state.
struct CockpitSlotCardView: View {
    let slot: AgentSlot
    let skillName: String
    let isRevealed: Bool
    @Bindable var chatViewModel: SlotChatViewModel
    /// Pending gate to display approval card (nil when no gate awaiting approval)
    /// Cost summary for this slot
    var costSummary: UsageSummary?
    var pendingGate: ExecutionGate?
    /// Callback when user approves the pending gate
    var onApproveGate: ((ExecutionGate) -> Void)?
    /// Callback when user rejects the pending gate
    var onRejectGate: ((ExecutionGate) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header (clickable to toggle chat)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    chatViewModel.isExpanded.toggle()
                    if chatViewModel.isExpanded {
                        chatViewModel.markAllAsRead()
                    }
                }
            } label: {
                cardContent
            }
            .buttonStyle(.plain)

            // Expandable chat panel
            if chatViewModel.isExpanded {
                SlotChatPanelView(viewModel: chatViewModel)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // US-003: Approval card overlay when gate is awaiting approval
            if let gate = pendingGate, slot.status == .waitingApproval {
                ApprovalCardView(
                    gate: gate,
                    onApprove: { onApproveGate?(gate) },
                    onReject: { onRejectGate?(gate) }
                )
                .padding(Theme.Spacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pendingGate?.id)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(statusBorderColor.opacity(0.4), lineWidth: 1)
        )
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRevealed)
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header: slot index + agent type + status + unread badge
            HStack {
                // Slot index badge
                Text("#\(slot.slotIndex)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgApp)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))

                // Skill name
                Text(skillName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Unread badge
                if chatViewModel.unreadCount > 0 && !chatViewModel.isExpanded {
                    Text("\(chatViewModel.unreadCount)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentPrimary)
                        .clipShape(Capsule())
                }

                // Status badge
                cockpitStatusBadge

                // Expand indicator
                Image(systemName: chatViewModel.isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }

            // Agent type
            HStack(spacing: 4) {
                Image(systemName: agentIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentPrimary)
                Text(slot.agentType)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            // Cost badge
            if let cost = costSummary {
                CostBadgeView(summary: cost)
            }

            // Branch name (if assigned)
            if let branch = slot.branchName {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                    Text(branch)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var cockpitStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.6), radius: 3)

            Text(statusLabel)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var agentIcon: String {
        switch slot.agentType.lowercased() {
        case "claude": return "brain.head.profile"
        case "gemini": return "sparkles"
        case "codex": return "terminal"
        default: return "cpu"
        }
    }

    private var statusColor: Color {
        switch slot.status {
        case .empty: return Color.textTertiary
        case .provisioning: return Color.statusInfo
        case .running: return Color.statusSuccess
        case .waitingApproval: return Color.statusWarning
        case .paused: return Color.terminalYellow
        case .done: return Color.accentPrimary
        case .error: return Color.statusError
        }
    }

    private var statusBorderColor: Color {
        switch slot.status {
        case .running: return Color.statusSuccess
        case .error: return Color.statusError
        case .waitingApproval: return Color.statusWarning
        default: return Color.borderMuted
        }
    }

    private var statusLabel: String {
        switch slot.status {
        case .empty: return "EMPTY"
        case .provisioning: return "PROVISIONING"
        case .running: return "RUNNING"
        case .waitingApproval: return "APPROVAL"
        case .paused: return "PAUSED"
        case .done: return "DONE"
        case .error: return "ERROR"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CockpitSlotCardView_Previews: PreviewProvider {
    static var previews: some View {
        Text("CockpitSlotCardView requires DI setup for preview")
            .foregroundStyle(Color.textTertiary)
            .frame(width: 300, height: 200)
            .background(Color.bgApp)
    }
}
#endif
