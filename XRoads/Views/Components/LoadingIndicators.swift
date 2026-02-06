//
//  LoadingIndicators.swift
//  XRoads
//
//  Created by Nexus on 2026-02-06.
//  Polished loading indicators and skeleton components
//

import SwiftUI

// MARK: - Neon Spinner

/// A neon-styled spinning indicator
struct NeonSpinner: View {
    let color: Color
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Spinning arc
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.3), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            // Glow effect
            Circle()
                .trim(from: 0, to: 0.1)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth + 1, lineCap: .round))
                .rotationEffect(.degrees(rotation))
                .blur(radius: 2)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Pulse Dot

/// A pulsing dot indicator
struct PulseDot: View {
    let color: Color
    var size: CGFloat = 8

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Pulse ring
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(scale)
                .opacity(opacity)

            // Core dot
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.6), radius: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                scale = 2.0
                opacity = 0
            }
        }
    }
}

// MARK: - Typing Indicator

/// Three dots typing animation
struct TypingIndicator: View {
    let color: Color

    @State private var dot1Opacity: Double = 0.3
    @State private var dot2Opacity: Double = 0.3
    @State private var dot3Opacity: Double = 0.3

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(dot1Opacity)

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(dot2Opacity)

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(dot3Opacity)
        }
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
            dot1Opacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                dot2Opacity = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                dot3Opacity = 1.0
            }
        }
    }
}

// MARK: - Shimmer Effect

/// A shimmer loading effect modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: -geo.size.width * 0.25 + phase * geo.size.width * 1.5)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Line

/// A skeleton placeholder line
struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.bgElevated)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Starting State View

/// A view shown when a slot is in "starting" state
struct StartingStateView: View {
    let agentColor: Color
    let agentName: String?

    @State private var dots: String = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Spinner
            NeonSpinner(color: agentColor, size: 32, lineWidth: 3)

            // Text
            VStack(spacing: Theme.Spacing.xs) {
                Text("Starting\(dots)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)

                if let name = agentName {
                    Text(name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(agentColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.SlotCard.terminalBackground)
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
    }
}

// MARK: - Empty Terminal Placeholder

/// A placeholder view for empty terminal output
struct EmptyTerminalPlaceholder: View {
    let isConfigured: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if isConfigured {
                Image(systemName: "terminal")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textTertiary.opacity(0.4))

                Text("Ready to run")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)

                Text("Press play to start")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary.opacity(0.6))
            } else {
                Image(systemName: "square.dashed")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textTertiary.opacity(0.3))

                Text("No output yet")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.textTertiary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Animated Progress Bar

/// A progress bar with smooth animation and glow
struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 3
    var showGlow: Bool = true

    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.borderMuted.opacity(0.3))
                    .frame(height: height)

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * animatedProgress, height: height)
                    .shadow(color: showGlow ? color.opacity(0.5) : .clear, radius: 4)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingIndicators_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Spinners
            HStack(spacing: Theme.Spacing.lg) {
                NeonSpinner(color: .accentPrimary)
                NeonSpinner(color: .statusSuccess)
                NeonSpinner(color: .statusWarning)
            }

            // Pulse dots
            HStack(spacing: Theme.Spacing.lg) {
                PulseDot(color: .accentPrimary)
                PulseDot(color: .statusSuccess)
                PulseDot(color: .terminalMagenta)
            }

            // Typing indicator
            TypingIndicator(color: .textSecondary)

            // Skeleton lines
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SkeletonLine(width: 150)
                SkeletonLine(width: 100)
                SkeletonLine(width: 180)
            }

            // Progress bars
            VStack(spacing: Theme.Spacing.md) {
                AnimatedProgressBar(progress: 0.3, color: .accentPrimary)
                AnimatedProgressBar(progress: 0.7, color: .statusSuccess)
                AnimatedProgressBar(progress: 1.0, color: .terminalMagenta)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.xl)
        .background(Color.bgApp)
    }
}
#endif
