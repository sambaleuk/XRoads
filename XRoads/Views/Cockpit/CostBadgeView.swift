import SwiftUI

// MARK: - CostBadgeView

/// Compact cost/token display for a slot card or session header.
struct CostBadgeView: View {
    let summary: UsageSummary

    var body: some View {
        guard summary.eventCount > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(costColor)

                Text(summary.formattedCost)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(costColor)

                Text("·")
                    .foregroundStyle(Color.textTertiary)

                Text("\(summary.formattedTokens) tok")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(costColor.opacity(0.08))
            .clipShape(Capsule())
        )
    }

    private var costColor: Color {
        if summary.totalCostCents >= 500 {
            return Color.statusError
        } else if summary.totalCostCents >= 100 {
            return Color.statusWarning
        }
        return Color.statusSuccess
    }
}

// MARK: - SessionCostSummaryView

/// Larger cost summary for the cockpit header, showing session-wide totals.
struct SessionCostSummaryView: View {
    let summary: UsageSummary

    var body: some View {
        guard summary.eventCount > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentPrimary)

                    Text(summary.formattedCost)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                }

                Divider().frame(height: 12)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)

                    Text("\(formatTokens(summary.totalInputTokens)) in")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                }

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)

                    Text("\(formatTokens(summary.totalOutputTokens)) out")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        )
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000.0) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000.0) }
        return "\(count)"
    }
}
