import SwiftUI

/// A compact horizontal banner shown when an interrupted orchestration is detected.
/// Displays PRD name, progress, slot summary, and Resume/Dismiss actions.
struct OrchestrationRecoveryBanner: View {
    let recovery: RecoveredOrchestration
    let onResume: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.statusWarning)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(recovery.prdName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(recovery.progressDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)

                    if !recovery.slots.isEmpty {
                        Text("·")
                            .foregroundStyle(Color.textTertiary)
                        Text(slotSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Remaining stories badges
            HStack(spacing: 4) {
                ForEach(recovery.remainingStories.prefix(4)) { story in
                    Text(story.id)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(storyBadgeColor(for: story.status))
                        .foregroundStyle(Color.textPrimary)
                        .cornerRadius(Theme.Radius.xs)
                }
                if recovery.remainingStories.count > 4 {
                    Text("+\(recovery.remainingStories.count - 4)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            // Actions
            Button("Resume Remaining") {
                onResume()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
            .controlSize(.small)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss recovery banner")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Color.statusWarning.opacity(0.08)
        )
        .overlay(
            Rectangle()
                .fill(Color.statusWarning.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Helpers

    private var slotSummary: String {
        let agentNames = recovery.slots.map(\.agentType.shortName)
        let unique = Array(Set(agentNames)).sorted()
        return "\(recovery.slots.count) slots (\(unique.joined(separator: ", ")))"
    }

    private func storyBadgeColor(for status: String) -> Color {
        switch status {
        case "ready":
            return Color.statusSuccess.opacity(0.2)
        case "inProgress":
            return Color.statusWarning.opacity(0.2)
        case "blocked":
            return Color.statusError.opacity(0.15)
        case "failed":
            return Color.statusError.opacity(0.3)
        default:
            return Color.bgElevated
        }
    }
}
