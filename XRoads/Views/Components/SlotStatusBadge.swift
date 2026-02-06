//
//  SlotStatusBadge.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  Reusable status badge component with consistent styling
//

import SwiftUI

// MARK: - SlotStatusBadge

/// A reusable badge that displays status with consistent styling
struct SlotStatusBadge: View {
    let status: TerminalSlotStatus
    var showDot: Bool = true
    var compact: Bool = false

    @State private var isPulsing: Bool = false

    private var statusColor: Color {
        Theme.Status.color(for: status.rawValue)
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            if showDot {
                // Status dot with optional pulse animation
                ZStack {
                    if status.isWaitingForInput || status == .starting {
                        // Pulsing outer ring for attention states
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: compact ? 10 : 14, height: compact ? 10 : 14)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                    }

                    Circle()
                        .fill(statusColor)
                        .frame(width: compact ? 5 : 6, height: compact ? 5 : 6)
                        .shadow(color: statusColor.opacity(0.6), radius: 3)
                }
            }

            Text(status.displayName)
                .font(.system(size: compact ? 9 : 10, weight: .medium, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Theme.Status.backgroundColor(for: status.rawValue))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.Status.borderColor(for: status.rawValue), lineWidth: 1)
        )
        .onAppear {
            if status.isWaitingForInput || status == .starting {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus.isWaitingForInput || newStatus == .starting {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}

// MARK: - SlotStatusIndicator

/// A minimal status indicator (just the dot) for tight spaces
struct SlotStatusIndicator: View {
    let status: TerminalSlotStatus
    var size: CGFloat = 8

    @State private var isPulsing: Bool = false

    private var statusColor: Color {
        Theme.Status.color(for: status.rawValue)
    }

    var body: some View {
        ZStack {
            // Outer glow for active states
            if status.isActive {
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: size * 2, height: size * 2)
                    .blur(radius: 4)
            }

            // Pulsing ring for attention states
            if status.isWaitingForInput {
                Circle()
                    .stroke(statusColor.opacity(0.5), lineWidth: 2)
                    .frame(width: size * 1.8, height: size * 1.8)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            }

            // Main dot
            Circle()
                .fill(statusColor)
                .frame(width: size, height: size)
                .shadow(color: statusColor.opacity(0.8), radius: status.isActive ? 4 : 2)
        }
        .frame(width: size * 2.5, height: size * 2.5)
        .onAppear {
            if status.isWaitingForInput {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus.isWaitingForInput {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}

// MARK: - NeedsInputOverlay

/// An overlay to show when a slot needs user input
struct NeedsInputOverlay: View {
    let isVisible: Bool

    @State private var opacity: Double = 0.0

    var body: some View {
        if isVisible {
            ZStack {
                // Gradient border effect
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.terminalMagenta.opacity(opacity),
                                Color.terminalMagenta.opacity(opacity * 0.5),
                                Color.terminalMagenta.opacity(opacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )

                // Corner badge
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 9))
                            Text("INPUT")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.terminalMagenta)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                    }
                    Spacer()
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.8
                }
            }
        }
    }
}

// MARK: - ErrorOverlay

/// An overlay to show when a slot is in error state
struct ErrorOverlay: View {
    let isVisible: Bool
    let errorMessage: String?

    @State private var shimmer: Double = 0.0

    var body: some View {
        if isVisible {
            ZStack {
                // Error border
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Color.statusError.opacity(0.6), lineWidth: 2)

                // Corner badge
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("ERROR")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.statusError)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - CompletedOverlay

/// A subtle overlay for completed state
struct CompletedOverlay: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            // Corner badge
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                        Text("DONE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SlotStatusBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // All status badges - Row 1
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Status Badges")
                    .font(.h3)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    SlotStatusBadge(status: .empty)
                    SlotStatusBadge(status: .configuring)
                    SlotStatusBadge(status: .ready)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    SlotStatusBadge(status: .starting)
                    SlotStatusBadge(status: .running)
                    SlotStatusBadge(status: .paused)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    SlotStatusBadge(status: .completed)
                    SlotStatusBadge(status: .error)
                    SlotStatusBadge(status: .needsInput)
                }
            }

            Divider()

            // Compact badges
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Compact Badges")
                    .font(.h3)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    SlotStatusBadge(status: .running, compact: true)
                    SlotStatusBadge(status: .needsInput, compact: true)
                    SlotStatusBadge(status: .error, compact: true)
                }
            }

            Divider()

            // Status indicators
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Status Indicators")
                    .font(.h3)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: Theme.Spacing.lg) {
                    SlotStatusIndicator(status: .empty)
                    SlotStatusIndicator(status: .ready)
                    SlotStatusIndicator(status: .running)
                    SlotStatusIndicator(status: .needsInput)
                    SlotStatusIndicator(status: .error)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Color.bgApp)
    }
}
#endif
