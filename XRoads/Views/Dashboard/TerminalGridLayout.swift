//
//  TerminalGridLayout.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Hexagonal layout for 6 terminal slots with central orchestrator
//

import SwiftUI

// MARK: - TerminalGridLayout

struct TerminalGridLayout: View {
    @Binding var slots: [TerminalSlot]
    let orchestratorState: OrchestratorVisualState
    let onStartSlot: (Int) -> Void
    let onStopSlot: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = calculateRadius(for: geometry.size)

            ZStack {
                // Background connection lines
                ConnectionLinesCanvas(
                    slots: slots,
                    center: center,
                    radius: radius,
                    orchestratorState: orchestratorState
                )

                // Terminal slots arranged in hexagon
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    let angle = Angle(degrees: slot.positionAngle)
                    let position = slotPosition(center: center, radius: radius, angle: angle)

                    TerminalSlotView(
                        slot: $slots[index],
                        onStart: { onStartSlot(slot.slotNumber) },
                        onStop: { onStopSlot(slot.slotNumber) }
                    )
                    .position(position)
                }

                // Central orchestrator creature
                OrchestratorCreatureView(
                    state: orchestratorState,
                    activeSlotAngles: activeSlotAngles
                )
                .position(center)
            }
        }
    }

    // MARK: - Calculations

    private func calculateRadius(for size: CGSize) -> CGFloat {
        let minDimension = min(size.width, size.height)
        // Leave room for slots (200pt wide) and padding
        return (minDimension / 2) - 130
    }

    private func slotPosition(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(Darwin.cos(angle.radians)),
            y: center.y + radius * CGFloat(Darwin.sin(angle.radians))
        )
    }

    private var activeSlotAngles: [Double] {
        slots
            .filter { $0.status.isActive }
            .map { $0.positionAngle }
    }
}

// MARK: - Connection Lines Canvas

struct ConnectionLinesCanvas: View {
    let slots: [TerminalSlot]
    let center: CGPoint
    let radius: CGFloat
    let orchestratorState: OrchestratorVisualState

    var body: some View {
        Canvas { context, size in
            // Draw connection lines from center to each slot
            for slot in slots {
                let angle = Angle(degrees: slot.positionAngle)
                let endPoint = CGPoint(
                    x: center.x + radius * CGFloat(Darwin.cos(angle.radians)),
                    y: center.y + radius * CGFloat(Darwin.sin(angle.radians))
                )

                let isActive = slot.status.isActive
                let lineColor = isActive ? Color.connectionLineActive : Color.connectionLineDefault

                var path = Path()
                path.move(to: center)
                path.addLine(to: endPoint)

                context.stroke(
                    path,
                    with: .color(lineColor.opacity(isActive ? 0.6 : 0.2)),
                    style: StrokeStyle(
                        lineWidth: isActive ? 2 : 1,
                        lineCap: .round,
                        dash: isActive ? [] : [5, 5]
                    )
                )

                // Draw small circles at connection points
                if slot.isConfigured {
                    let dotSize: CGFloat = isActive ? 6 : 4
                    let dotRect = CGRect(
                        x: endPoint.x - dotSize / 2,
                        y: endPoint.y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Circle().path(in: dotRect),
                        with: .color(slot.agentType?.slotBorderColor ?? .slotBorderEmpty)
                    )
                }
            }

            // Draw hexagon outline
            drawHexagonOutline(context: context, center: center, radius: radius)
        }
    }

    private func drawHexagonOutline(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var path = Path()
        for i in 0..<6 {
            let angle = Angle(degrees: Double(i) * 60 - 90)
            let point = CGPoint(
                x: center.x + radius * CGFloat(Darwin.cos(angle.radians)),
                y: center.y + radius * CGFloat(Darwin.sin(angle.radians))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        context.stroke(
            path,
            with: .color(Color.borderMuted.opacity(0.3)),
            style: StrokeStyle(lineWidth: 1, dash: [10, 10])
        )
    }
}

// MARK: - Single Terminal Layout

/// Layout for single mode - one large terminal
struct SingleTerminalLayout: View {
    @Binding var slot: TerminalSlot
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        LargeTerminalSlotView(
            slot: $slot,
            onStart: onStart,
            onStop: onStop
        )
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - Large Terminal Slot View

/// Larger terminal view for single mode
struct LargeTerminalSlotView: View {
    @Environment(\.appState) private var appState
    @Binding var slot: TerminalSlot

    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(borderColor.opacity(0.5))

            // Terminal output
            terminalOutput

            // Footer with controls
            footer
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(borderColor, lineWidth: slot.status.isActive ? 2 : 1)
        )
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            // Agent picker
            if let agent = slot.agentType {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: agent.iconName)
                    Text(agent.displayName)
                }
                .font(.h3)
                .foregroundStyle(agent.slotBorderColor)
            } else {
                Menu {
                    ForEach(AgentType.allCases, id: \.self) { agent in
                        Button {
                            slot.agentType = agent
                        } label: {
                            Label(agent.displayName, systemImage: agent.iconName)
                        }
                    }
                } label: {
                    Label("Select Agent", systemImage: "plus.circle")
                        .font(.h3)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            // Worktree info
            if let worktree = slot.worktree {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(worktree.branch)
                }
                .font(.body14)
                .foregroundStyle(Color.textSecondary)
            } else {
                Menu {
                    ForEach(appState.worktrees) { worktree in
                        Button {
                            slot.worktree = worktree
                            if slot.agentType != nil {
                                slot.status = .ready
                            }
                        } label: {
                            Text(worktree.branch)
                        }
                    }
                } label: {
                    Label("Select Worktree", systemImage: "folder")
                        .font(.body14)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            // Status badge
            Text(slot.status.displayName)
                .font(.small)
                .foregroundStyle(statusColor)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(statusColor.opacity(0.15))
                .cornerRadius(Theme.Radius.sm)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(height: Theme.Component.headerHeight)
    }

    private var terminalOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(slot.logs) { log in
                        LogLine(log: log)
                            .id(log.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.sm)
            }
            .background(Color.bgCanvas)
            .onChange(of: slot.logs.count) { _, _ in
                if let lastLog = slot.logs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Current task
            if let task = slot.currentTask {
                Text(task)
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Progress
            if slot.status.isActive && slot.progress > 0 {
                ProgressView(value: slot.progress)
                    .progressViewStyle(.linear)
                    .tint(borderColor)
                    .frame(width: 100)

                Text("\(Int(slot.progress * 100))%")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
            }

            // Action buttons
            if slot.status.canStart {
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.statusSuccess)
            }

            if slot.status.canStop {
                Button(action: onStop) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(height: Theme.Component.inputBarHeight)
        .background(Color.bgElevated)
    }

    private var borderColor: Color {
        slot.agentType?.slotBorderColor ?? .slotBorderEmpty
    }

    private var statusColor: Color {
        switch slot.status {
        case .empty, .configuring: return .textTertiary
        case .ready: return .statusInfo
        case .starting, .running: return .statusSuccess
        case .paused: return .statusWarning
        case .completed: return .accentPrimary
        case .error: return .statusError
        case .needsInput: return .statusWarning
        }
    }
}

// MARK: - Log Line

private struct LogLine: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text(log.formattedTimestamp)
                .font(.terminal)
                .foregroundStyle(Color.textTertiary)

            Text("[\(log.source)]")
                .font(.terminal)
                .foregroundStyle(sourceColor)

            Text(log.message)
                .font(.terminal)
                .foregroundStyle(levelColor)
        }
    }

    private var sourceColor: Color {
        switch log.source.lowercased() {
        case "claude": return .slotBorderClaude
        case "gemini": return .slotBorderGemini
        case "codex": return .slotBorderCodex
        default: return .textSecondary
        }
    }

    private var levelColor: Color {
        switch log.level {
        case .error: return .terminalRed
        case .warn: return .terminalYellow
        case .info: return .terminalCyan
        case .debug: return .textSecondary
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TerminalGridLayout_Previews: PreviewProvider {
    static var previews: some View {
        TerminalGridLayout(
            slots: .constant(previewSlots),
            orchestratorState: .monitoring,
            onStartSlot: { _ in },
            onStopSlot: { _ in }
        )
        .frame(width: 1000, height: 800)
        .background(Color.bgApp)
    }

    static var previewSlots: [TerminalSlot] {
        [
            TerminalSlot(slotNumber: 1, agentType: .claude, status: .running, currentTask: "Implementing auth..."),
            TerminalSlot(slotNumber: 2, agentType: .gemini, status: .ready),
            TerminalSlot(slotNumber: 3, agentType: .codex, status: .completed),
            TerminalSlot(slotNumber: 4, status: .empty),
            TerminalSlot(slotNumber: 5, status: .empty),
            TerminalSlot(slotNumber: 6, agentType: .claude, status: .error)
        ]
    }
}
#endif
