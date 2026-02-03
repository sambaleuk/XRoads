import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.appState) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                AgenticOrchestratorScene()

                DashboardSummary(
                    progress: appState.globalDashboardProgress,
                    totalAgents: appState.dashboardEntries.count
                )

                if appState.dashboardEntries.isEmpty {
                    DashboardEmptyState()
                } else {
                    AgentCardsGrid(entries: appState.dashboardEntries)
                }

                TimelineSection(events: appState.agentTimelineEvents)
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Color.bgApp.ignoresSafeArea())
        .task {
            appState.startAgentEventStream()
        }
    }
}

// MARK: - Agentic Scene

private struct AgenticOrchestratorScene: View {
    @Environment(\.appState) private var appState

    private let slotAngles: [Double] = [-90, -30, 30, 90, 150, -150]
    private let slotColors: [Color] = [
        Color(red: 0.45, green: 0.84, blue: 1.0),
        Color(red: 0.96, green: 0.50, blue: 1.0),
        Color(red: 0.48, green: 0.65, blue: 1.0),
        Color(red: 0.43, green: 0.93, blue: 0.76),
        Color(red: 1.0, green: 0.52, blue: 0.82),
        Color(red: 0.62, green: 0.59, blue: 1.0)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.35
            let entries = Array(appState.dashboardEntries.prefix(slotAngles.count))

            let slots: [AgenticSlot] = slotAngles.enumerated().map { index, angle in
                let angleRadians = angle * .pi / 180
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angleRadians)) * radius,
                    y: center.y + CGFloat(sin(angleRadians)) * radius
                )
                let entry = index < entries.count ? entries[index] : nil
                let accent = entry?.agentType?.neonColor ?? slotColors[index % slotColors.count]
                return AgenticSlot(
                    index: index,
                    point: point,
                    color: accent,
                    entry: entry,
                    iconName: entry?.agentType?.iconName,
                    agentType: entry?.agentType
                )
            }

            ZStack {
                SynapseConnections(
                    center: center,
                    slots: slots,
                    isActive: appState.isAgenticPulseActive
                )

                ForEach(slots) { slot in
                    NeonSlotCard(slot: slot)
                        .frame(width: 220, height: 140)
                        .position(slot.point)
                }

                OrchestratorBrainView(
                    isActive: appState.isAgenticPulseActive,
                    state: appState.orchestrationState
                )
                .frame(width: 240, height: 200)
                .position(center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                AgenticStatusPanel(
                    branchName: appState.activeWorktreeAssignments.first?.branchName
                        ?? appState.orchestrationRepoPath?.lastPathComponent
                        ?? "feat/crossroads-v1",
                    prdName: appState.activePRDName ?? "No PRD Loaded",
                    agentCount: appState.dashboardEntries.count,
                    progress: appState.globalDashboardProgress
                )
                .padding()
            }
            .overlay(alignment: .topTrailing) {
                LogStatusPanel(
                    isStreaming: appState.isStreamingLogs,
                    logs: Array(appState.logs.suffix(6).reversed())
                )
                .padding()
            }
        }
        .frame(height: 520)
        .padding(.top, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.07, blue: 0.12),
                            Color(red: 0.11, green: 0.13, blue: 0.20),
                            Color(red: 0.07, green: 0.07, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(Color.accentPrimary.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: Color.accentPrimary.opacity(0.35), radius: 30, x: 0, y: 25)
    }
}

private struct OrchestratorBrainView: View {
    var isActive: Bool
    var state: OrchestratorState
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.25),
                            Color.blue.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 140
                    )
                )
                .scaleEffect(isActive ? 1.2 : 1.0)
                .blur(radius: 40)
            BrainShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.84, green: 0.46, blue: 1.0),
                            Color(red: 0.45, green: 0.84, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.purple.opacity(0.7), radius: 25)
                .overlay(
                    BrainShape()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                        .blur(radius: 1)
                )
                .scaleEffect(1 + 0.03 * sin(phase))
            VStack(spacing: 4) {
                Text("Claude Orchestrator")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.8))
                Text(stateLabel)
                    .font(.title3.bold())
                    .foregroundStyle(Color.white)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                phase = 2 * .pi
            }
        }
    }

    private var stateLabel: String {
        switch state {
        case .idle: return "Idle"
        case .analyzing: return "Analyzing PRD"
        case .distributing: return "Distributing Tasks"
        case .monitoring: return "Monitoring Agents"
        case .merging: return "Coordinating Merge"
        case .complete: return "Complete"
        case .error(let message):
            return message ?? "Error"
        }
    }
}

private struct BrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.insetBy(dx: rect.width * 0.15, dy: rect.height * 0.2)
        path.addRoundedRect(
            in: inset,
            cornerSize: CGSize(width: inset.width * 0.45, height: inset.height * 0.45)
        )
        return path
    }
}

private struct SynapseConnections: View {
    let center: CGPoint
    let slots: [AgenticSlot]
    let isActive: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let progress = isActive ? (time.truncatingRemainder(dividingBy: 2.5) / 2.5) : 0

            Canvas { context, size in
                for slot in slots {
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: slot.point)

                    let dash: [CGFloat] = slot.entry == nil ? [6, 10] : []
                    let gradient = Gradient(colors: [
                        Color.white.opacity(0.05),
                        slot.color.opacity(slot.entry == nil ? 0.15 : 0.9)
                    ])

                    context.stroke(
                        path,
                        with: .linearGradient(
                            gradient,
                            startPoint: center,
                            endPoint: slot.point
                        ),
                        style: StrokeStyle(
                            lineWidth: slot.lineWidth,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: dash,
                            dashPhase: 0
                        )
                    )

                    guard slot.isActive && isActive else { continue }
                    let offset = (progress + Double(slot.index) * 0.12)
                        .truncatingRemainder(dividingBy: 1)
                    let dx = slot.point.x - center.x
                    let dy = slot.point.y - center.y
                    let dot = CGPoint(
                        x: center.x + dx * offset,
                        y: center.y + dy * offset
                    )
                    let rect = CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(slot.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct NeonSlotCard: View {
    let slot: AgenticSlot

    private var accent: Color {
        slot.entry?.agentType?.neonColor
            ?? slot.entry?.statusColor.foreground.color
            ?? slot.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                if let iconName = slot.iconName {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.25))
                            .frame(width: 32, height: 32)
                            .shadow(color: accent.opacity(0.4), radius: 8)
                        Image(systemName: iconName)
                            .foregroundStyle(accent)
                    }
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.entry?.agentType?.displayName ?? "No Agent")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                    Text("Slot \(slot.index + 1)")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                Text(slot.entry?.stateLabel ?? "Idle")
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.15))
                    .clipShape(Capsule(style: .continuous))
            }

            if let entry = slot.entry {
                Text(entry.message)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(2)

                ProgressView(value: entry.progress)
                    .progressViewStyle(.linear)
                    .tint(accent)

                HStack(spacing: Theme.Spacing.md) {
                    Label(entry.formattedAverageStoryTime, systemImage: "clock")
                    Spacer()
                    Label(entry.formattedSuccessRate, systemImage: "checkmark.seal")
                }
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.7))
            } else {
                Text("Select an agent to begin.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.65))
                Spacer()
                Text("Awaiting assignment…")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(accent.opacity(0.5), lineWidth: 1.2)
                        .shadow(color: accent.opacity(0.35), radius: 8)
                )
        )
    }
}

private struct AgenticStatusPanel: View {
    let branchName: String
    let prdName: String
    let agentCount: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(branchName.uppercased())
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            Text(prdName)
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: Theme.Spacing.md) {
                Label("\(agentCount) agents", systemImage: "bolt.horizontal.circle")
                Label("\(Int(progress * 100))% complete", systemImage: "chart.bar.xaxis")
            }
            .font(.caption)
            .foregroundStyle(Color.textSecondary)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.accentPrimary)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.bgSurface.opacity(0.95))
        )
    }
}

private struct LogStatusPanel: View {
    let isStreaming: Bool
    let logs: [LogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label(
                    isStreaming ? "Streaming Logs" : "Logs Paused",
                    systemImage: isStreaming ? "waveform.path.ecg" : "waveform.path"
                )
                Spacer()
                Circle()
                    .fill(isStreaming ? Color.statusSuccess : Color.statusWarning)
                    .frame(width: 8, height: 8)
            }
            .font(.caption)
            .foregroundStyle(Color.textSecondary)

            Divider()
                .background(Color.white.opacity(0.1))

            if logs.isEmpty {
                Text("Awaiting new events…")
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(logs.prefix(5)) { log in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Text(log.formattedTimestamp)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Text(log.level.displayName)
                            .font(.caption2.bold())
                            .foregroundStyle(log.level.accentColor)
                            .frame(width: 42, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.message)
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.9))
                                .lineLimit(2)
                            if let worktree = log.worktree, !worktree.isEmpty {
                                Text(worktree)
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct AgenticSlot: Identifiable {
    let id = UUID()
    let index: Int
    let point: CGPoint
    let color: Color
    let entry: AgentDashboardEntry?
    let iconName: String?
    let agentType: AgentType?

    var lineWidth: CGFloat {
        entry == nil ? 1.2 : (isActive ? 4 : 2.4)
    }

    var isActive: Bool {
        guard let state = entry?.state else { return false }
        return state == .working || state == .needsInput
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

private extension AgentType {
    var neonColor: Color {
        switch self {
        case .claude:
            return Color(red: 0.95, green: 0.50, blue: 1.0)
        case .gemini:
            return Color(red: 0.35, green: 0.78, blue: 1.0)
        case .codex:
            return Color(red: 0.46, green: 0.96, blue: 0.79)
        }
    }
}

private extension LogLevel {
    var accentColor: Color {
        switch self {
        case .debug: return Color.terminalCyan
        case .info: return Color.accentPrimary
        case .warn: return Color.statusWarning
        case .error: return Color.statusError
        }
    }
}
