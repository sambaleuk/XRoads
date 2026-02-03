import SwiftUI

struct OrchestrationHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    private let fileManager: FileManager = .default

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header

            if appState.historyRecords.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(appState.historyRecords) { record in
                            HistoryCard(
                                record: record,
                                canRerun: canRerun(record),
                                onRerun: { rerun(record) }
                            )
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 720, height: 520)
        .background(Color.bgApp)
        .task {
            await appState.loadHistory()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Orchestration History")
                    .font(.title)
                    .foregroundStyle(Color.textPrimary)
                Text("Latest orchestrations with per-agent metrics and quick rerun.")
                    .foregroundStyle(Color.textSecondary)
                    .font(.callout)
            }
            Spacer()
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(Color.textSecondary)
            Text("No orchestration runs recorded yet.")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            Text("Once a merge completes, the orchestrator stores the run summary here.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func canRerun(_ record: OrchestrationRecord) -> Bool {
        guard let path = record.prdPath else { return false }
        return fileManager.fileExists(atPath: path)
    }

    private func rerun(_ record: OrchestrationRecord) {
        guard let path = record.prdPath else { return }
        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: path) else { return }
        appState.pendingPRDURL = url
        dismiss()
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let record: OrchestrationRecord
    let canRerun: Bool
    let onRerun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header
            progressSection
            agentMetricsSection
            conflictSection
            footer
        }
        .padding(Theme.Spacing.lg)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Color.borderDefault.opacity(0.6), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(record.prdName)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            StatusChip(
                text: record.resultSummary,
                color: record.resultSummary == "Merged" ? .green : (record.resultSummary == "Conflicts" ? .red : .yellow)
            )
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Completion")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(record.completedStories)/\(record.totalStories) stories")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            ProgressView(value: record.completionRate, total: 1)
                .tint(Color.accentPrimary)
            HStack(spacing: Theme.Spacing.lg) {
                InfoRow(label: "Duration", value: record.durationSeconds.timeIntervalDescription)
                InfoRow(label: "Branches", value: record.mergedBranches.joined(separator: ", ").ifEmpty("-"))
                InfoRow(label: "Errors", value: record.errors.count.description)
            }
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
        }
    }

    private var agentMetricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Agents")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(record.agentMetrics) { metric in
                    AgentMetricRow(metric: metric)
                }
            }
        }
    }

    private var conflictSection: some View {
        Group {
            if !record.conflicts.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Conflicts")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    ForEach(record.conflicts.prefix(8), id: \.self) { conflict in
                        Text(conflict)
                            .font(.caption2)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.statusWarning.opacity(0.15))
                            .foregroundStyle(Color.statusWarning)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if !record.errors.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Issues")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    ForEach(record.errors.prefix(3), id: \.self) { error in
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(Color.statusWarning)
                    }
                }
            }
            Spacer()
            Button {
                onRerun()
            } label: {
                Label("Rerun", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canRerun)
        }
    }
}

private struct AgentMetricRow: View {
    let metric: AgentRunMetric

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(metric.agentType?.displayName ?? metric.agentId.prefix(6).uppercased())
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                StatusChip(text: metric.state.label, color: metric.state.statusColor)
                Spacer()
                Text(metric.durationSeconds.timeIntervalDescription)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            ProgressView(value: metric.completionRate, total: 1) {
                Text("\(metric.storiesCompleted)/\(metric.storiesTotal) stories")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .progressViewStyle(.linear)
            .tint(Color.accentPrimary)
            if let message = metric.lastMessage, !message.isEmpty {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }
            if !metric.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(metric.errors.prefix(3), id: \.self) { error in
                        Label(error, systemImage: "bolt.trianglebadge.exclamationmark")
                            .font(.caption2)
                            .foregroundStyle(Color.statusWarning)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(Color.textSecondary.opacity(0.8))
            Text(value)
                .font(.caption)
                .foregroundStyle(Color.textPrimary)
        }
    }
}

private struct StatusChip: View {
    let text: String
    let color: StatusColor

    var body: some View {
        Text(text.capitalized)
            .font(.caption2.bold())
            .foregroundStyle(color.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.background.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}

private enum StatusColor {
    case green, yellow, red, purple, blue, orange

    var foreground: Color {
        switch self {
        case .green: return Color.statusSuccess
        case .yellow: return Color.statusWarning
        case .red: return Color.statusError
        case .purple: return Color.accentPrimary
        case .blue: return Color.accentPrimary
        case .orange: return Color.statusWarning
        }
    }

    var background: Color {
        switch self {
        case .green: return Color.statusSuccess
        case .yellow: return Color.statusWarning
        case .red: return Color.statusError
        case .purple: return Color.accentPrimary
        case .blue: return Color.accentPrimary
        case .orange: return Color.statusWarning
        }
    }
}

private extension AgentRunState {
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .needsInput: return "Needs Input"
        case .blocked: return "Blocked"
        case .finished: return "Finished"
        case .error: return "Error"
        }
    }

    var statusColor: StatusColor {
        switch self {
        case .finished: return .green
        case .working: return .blue
        case .needsInput: return .purple
        case .blocked: return .orange
        case .error: return .red
        case .idle: return .yellow
        }
    }
}

private extension String {
    func ifEmpty(_ replacement: String) -> String {
        isEmpty ? replacement : self
    }
}

private extension TimeInterval {
    var timeIntervalDescription: String {
        guard self > 0 else { return "–" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: self) ?? "\(self)s"
    }
}
