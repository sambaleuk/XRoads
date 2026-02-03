import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.appState) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 260), spacing: Theme.Spacing.xl, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                DashboardSummary(progress: appState.globalDashboardProgress, totalAgents: appState.dashboardEntries.count)

                if appState.dashboardEntries.isEmpty {
                    DashboardEmptyState()
                } else {
                    AgentCardsGrid(entries: appState.dashboardEntries)
                }

                TimelineSection(events: appState.agentTimelineEvents)
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Color.bgApp)
        .task {
            appState.startAgentEventStream()
        }
    }
}

// MARK: - Summary

private struct DashboardSummary: View {
    let progress: Double
    let totalAgents: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Full Agentic Mode")
                        .font(.h1)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(totalAgents) agents active")
                        .font(.body)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentPrimary)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.accentPrimary)
        }
        .padding()
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - Agent Cards

private struct AgentCardsGrid: View {
    let entries: [AgentDashboardEntry]
    private let columns = [
        GridItem(.adaptive(minimum: 260), spacing: Theme.Spacing.lg, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
            ForEach(entries) { entry in
                AgentCard(entry: entry)
            }
        }
    }
}

private struct AgentCard: View {
    let entry: AgentDashboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Circle()
                    .fill(entry.statusColor.foreground.color)
                    .frame(width: 10, height: 10)
                Text(entry.stateLabel)
                    .font(.caption)
                    .foregroundStyle(entry.statusColor.foreground.color)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(entry.statusColor.background.color.opacity(0.6))
                    .clipShape(Capsule())
                Spacer()
                Text(entry.lastUpdate.relativeFormat)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Text(entry.displayName)
                .font(.h2)
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: Theme.Spacing.md) {
                Label("Avg \(entry.formattedAverageStoryTime)", systemImage: "clock")
                Spacer()
                Label("Success \(entry.formattedSuccessRate)", systemImage: "checkmark.seal")
            }
            .font(.caption2)
            .foregroundStyle(Color.textSecondary)

            if !entry.stories.isEmpty {
                Text("Stories: \(entry.stories.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if let current = entry.currentStoryId {
                Label(current, systemImage: "list.number")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            ProgressView(value: entry.progress)
                .progressViewStyle(.linear)
                .tint(entry.statusColor.foreground.color)

            Text(entry.message)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(3)

            if let issue = entry.activeHealthIssue {
                HealthBadge(issue: issue)
            }
        }
        .padding()
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color.borderAccent.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct DashboardEmptyState: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(Color.textSecondary)
            Text("No agent data yet")
                .font(.h2)
                .foregroundStyle(Color.textPrimary)
            Text("Start an orchestration to see live agent progress, statuses, and events.")
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

// MARK: - Timeline

private struct TimelineSection: View {
    let events: [AgentTimelineEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recent Activity")
                .font(.h2)
                .foregroundStyle(Color.textPrimary)

            if events.isEmpty {
                Text("No events yet")
                    .foregroundStyle(Color.textSecondary)
                    .font(.callout)
            } else {
                ForEach(events.prefix(12)) { event in
                    TimelineRow(event: event)
                }
            }
        }
    }
}

private struct TimelineRow: View {
    let event: AgentTimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Circle()
                .fill(event.state.color.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(event.agentType?.displayName ?? event.agentId.prefix(6).uppercased())
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(event.timestamp.relativeFormat)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Text(event.message)
                    .foregroundStyle(Color.textSecondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct HealthBadge: View {
    let issue: AgentHealthIssue

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.statusWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(issueTitle)
                    .font(.caption.bold())
                    .foregroundStyle(Color.statusWarning)
                Text(issue.message)
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Color.statusWarning.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private var issueTitle: String {
        switch issue.type {
        case .nonResponsive:
            return "Non-Responsive"
        case .repeatedMessage:
            return "Loop Detected"
        }
    }
}

// MARK: - Extensions

private extension AgentDashboardEntry {
    var stateLabel: String {
        switch state {
        case .idle: return "Idle"
        case .working: return "Working"
        case .needsInput: return "Needs Input"
        case .blocked: return "Blocked"
        case .finished: return "Finished"
        case .error: return "Error"
        }
    }
}

private extension AgentRunState {
    var color: AgentStatusColor.ColorToken {
        switch self {
        case .idle: return .blueBright
        case .working: return .purpleBright
        case .needsInput: return .yellowBright
        case .blocked: return .orangeBright
        case .finished: return .greenBright
        case .error: return .redBright
        }
    }
}

private extension Date {
    var relativeFormat: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
