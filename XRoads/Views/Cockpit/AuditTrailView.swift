import SwiftUI

// MARK: - AuditTrailView

/// Panel/sheet displaying the full audit trail of ExecutionGates for the active
/// CockpitSession. Each row shows slot_index, operation_type, risk_level, status,
/// approved_by, and duration. Expandable rows reveal full audit_entry JSON.
///
/// US-004: Audit trail display in Cockpit.
struct AuditTrailView: View {
    @Bindable var viewModel: AuditTrailViewModel

    /// Slot lookup: maps agentSlotId -> slotIndex for display
    let slotIndexMap: [UUID: Int]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.isLoading {
                loadingState
            } else if viewModel.gates.isEmpty {
                emptyState
            } else {
                gateList
            }
        }
        .frame(minWidth: 480, minHeight: 300)
        .background(Color.bgCanvas)
        .task {
            await viewModel.loadGates()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.terminalCyan)

                Text("AUDIT TRAIL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            Text("\(viewModel.gates.count) gates")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Gate List

    @ViewBuilder
    private var gateList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.gates, id: \.id) { gate in
                    AuditTrailRowView(
                        gate: gate,
                        slotIndex: slotIndexMap[gate.agentSlotId],
                        isExpanded: viewModel.isExpanded(gateId: gate.id),
                        duration: viewModel.durationString(for: gate),
                        auditJSON: viewModel.prettyAuditJSON(for: gate),
                        onToggle: { viewModel.toggleExpanded(gateId: gate.id) }
                    )
                }
            }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("Loading audit trail...")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 28))
                .foregroundStyle(Color.textTertiary)
            Text("No execution gates recorded")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            Text("Gates will appear here as agents request sensitive operations")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AuditTrailRowView

/// Single row in the audit trail list. Shows gate summary with expandable audit_entry JSON.
struct AuditTrailRowView: View {
    let gate: ExecutionGate
    let slotIndex: Int?
    let isExpanded: Bool
    let duration: String?
    let auditJSON: String?
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary row (always visible)
            Button(action: onToggle) {
                summaryRow
            }
            .buttonStyle(.plain)

            // Expanded audit_entry JSON
            if isExpanded, let json = auditJSON {
                expandedContent(json: json)
            }
        }
        .background(Color.bgSurface)
    }

    // MARK: - Summary Row

    @ViewBuilder
    private var summaryRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Expand indicator
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 12)

            // Slot index badge
            Text("S\(slotIndex ?? 0)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.bgApp)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Operation type
            Text(gate.operationType)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer()

            // Risk level badge
            riskBadge

            // Status badge
            statusBadge

            // Approved by
            if let approver = gate.approvedBy {
                Text(approver)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
            }

            // Duration
            if let dur = duration {
                Text(dur)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 50, alignment: .trailing)
            }

            // Timestamp
            Text(formattedTime)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private func expandedContent(json: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(Color.borderMuted)

            Text(json)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.terminalCyan)
                .textSelection(.enabled)
                .padding(Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgApp)
        }
        .padding(.leading, 24)
    }

    // MARK: - Badges

    @ViewBuilder
    private var riskBadge: some View {
        let parsed = RiskLevel(rawValue: gate.riskLevel.lowercased())
        let color = riskColor(for: parsed)

        Text(gate.riskLevel.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var statusBadge: some View {
        let color = statusColor(for: gate.status)

        Text(gate.status.rawValue.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: gate.createdAt)
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

    private func statusColor(for status: ExecutionGateStatus) -> Color {
        switch status {
        case .completed: return Color.statusSuccess
        case .rejected: return Color.statusError
        case .rolledBack: return Color.statusWarning
        case .executing: return Color.statusInfo
        case .awaitingApproval: return Color.terminalYellow
        case .pending: return Color.textTertiary
        case .dryRun: return Color.terminalCyan
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AuditTrailView_Previews: PreviewProvider {
    static var previews: some View {
        Text("AuditTrailView requires DI setup for preview")
            .foregroundStyle(Color.textTertiary)
            .frame(width: 500, height: 300)
            .background(Color.bgApp)
    }
}
#endif
