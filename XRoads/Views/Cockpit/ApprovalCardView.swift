import SwiftUI

// MARK: - ApprovalCardView

/// Overlay card displayed on a CockpitSlotCardView when an ExecutionGate
/// is in `awaiting_approval` state. Shows operation details, risk level badge,
/// dry_run summary, estimated impact, and one-click approve / reject buttons.
///
/// US-003: Approval Card UI per slot.
struct ApprovalCardView: View {
    let gate: ExecutionGate
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header: title + risk badge
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.statusWarning)

                Text("APPROVAL REQUIRED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                riskBadge
            }

            Divider()
                .background(Color.borderMuted)

            // Operation type
            labeledRow(label: "Operation", value: gate.operationType)

            // Raw intent (the command)
            VStack(alignment: .leading, spacing: 2) {
                Text("Intent")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)

                Text(gate.operationPayload)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.terminalCyan)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.xs)
                    .background(Color.bgApp)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))
            }

            // Estimated impact (if present)
            if let impact = gate.estimatedImpact, !impact.isEmpty {
                labeledRow(label: "Impact", value: impact)
            }

            Divider()
                .background(Color.borderMuted)

            // Action buttons
            HStack(spacing: Theme.Spacing.sm) {
                // Reject button
                Button(action: onReject) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Reject")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.statusError)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)

                // Approve button
                Button(action: onApprove) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Approve")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.statusSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(riskBorderColor, lineWidth: 1.5)
        )
        .shadow(color: riskBorderColor.opacity(0.3), radius: 8, y: 2)
    }

    // MARK: - Risk Badge

    @ViewBuilder
    private var riskBadge: some View {
        let parsed = RiskLevel(rawValue: gate.riskLevel.lowercased())
        let color = riskColor(for: parsed)
        let label = gate.riskLevel.uppercased()

        Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    @ViewBuilder
    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 60, alignment: .trailing)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
        }
    }

    private func riskColor(for level: RiskLevel?) -> Color {
        switch level {
        case .low: return Color.statusSuccess
        case .medium: return Color.terminalYellow
        case .high: return Color.statusWarning
        case .critical: return Color.statusError
        case .none: return Color.textTertiary
        }
    }

    private var riskBorderColor: Color {
        riskColor(for: RiskLevel(rawValue: gate.riskLevel.lowercased()))
    }
}

// MARK: - Preview

#if DEBUG
struct ApprovalCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleGate = ExecutionGate(
            agentSlotId: UUID(),
            status: .awaitingApproval,
            operationType: "git_push",
            operationPayload: "git push origin main --force",
            riskLevel: "critical",
            estimatedImpact: "Force push to main branch — may overwrite remote history"
        )

        VStack(spacing: 20) {
            ApprovalCardView(gate: sampleGate, onApprove: {}, onReject: {})
                .frame(width: 320)
        }
        .padding()
        .background(Color.bgCanvas)
    }
}
#endif
