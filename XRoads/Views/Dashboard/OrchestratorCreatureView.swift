//
//  OrchestratorCreatureView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Central orchestrator - Alien Cyberbrain with synaptic connections
//

import SwiftUI

// MARK: - OrchestratorCreatureView

struct OrchestratorCreatureView: View {
    let state: OrchestratorVisualState
    let activeSlotAngles: [Double]

    @State private var brainPulse: Double = 0.0
    @State private var neuralGlow: Double = 0.5
    @State private var synapsePhase: Double = 0.0
    @State private var cortexRotation: Double = 0.0

    private let size: CGFloat = 140

    var body: some View {
        ZStack {
            // Ethereal alien aura
            alienAura

            // Synaptic connections to active slots
            ForEach(Array(activeSlotAngles.enumerated()), id: \.offset) { index, angle in
                SynapticConnection(
                    angle: angle,
                    color: state.color,
                    phase: synapsePhase + Double(index) * 0.3,
                    intensity: state.glowIntensity
                )
            }

            // Neural network background pattern
            neuralNetwork

            // Main cyberbrain structure
            cyberbrainCore

            // Cortex overlay with circuits
            cortexCircuits

            // Central consciousness node
            consciousnessNode

            // Floating neural sparks
            if state.showsParticles {
                NeuralSparks(state: state)
            }

            // Status indicator
            statusLabel
                .offset(y: size / 2 + 25)
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .onAppear { startAnimations() }
        .onChange(of: state) { _, _ in updateAnimations() }
    }

    // MARK: - Alien Aura

    private var alienAura: some View {
        ZStack {
            // Outer ethereal glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            state.color.opacity(neuralGlow * 0.4),
                            state.color.opacity(neuralGlow * 0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 25)

            // Pulsing inner aura
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            state.color.opacity(0.3),
                            state.color.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size * 0.9, height: size * 0.9)
                .scaleEffect(1.0 + brainPulse * 0.15)
                .blur(radius: 10)
        }
    }

    // MARK: - Neural Network Background

    private var neuralNetwork: some View {
        ZStack {
            // Interconnected neural paths
            ForEach(0..<6, id: \.self) { i in
                NeuralPath(
                    index: i,
                    color: state.color,
                    phase: cortexRotation
                )
            }
        }
        .frame(width: size, height: size)
        .opacity(0.4)
    }

    // MARK: - Cyberbrain Core

    private var cyberbrainCore: some View {
        ZStack {
            // Brain hemisphere left
            BrainHemisphere(isLeft: true, color: state.color, pulse: brainPulse)
                .offset(x: -8)

            // Brain hemisphere right
            BrainHemisphere(isLeft: false, color: state.color, pulse: brainPulse)
                .offset(x: 8)

            // Central fissure glow
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            state.color.opacity(0.8),
                            .white.opacity(0.9),
                            state.color.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: size * 0.5)
                .blur(radius: 2)
                .opacity(0.6 + brainPulse * 0.4)
        }
        .frame(width: size * 0.7, height: size * 0.6)
    }

    // MARK: - Cortex Circuits

    private var cortexCircuits: some View {
        ZStack {
            // Circuit pattern overlay
            ForEach(0..<8, id: \.self) { i in
                CortexCircuit(
                    index: i,
                    color: state.color,
                    rotation: cortexRotation,
                    pulse: brainPulse
                )
            }
        }
        .frame(width: size * 0.65, height: size * 0.55)
        .opacity(0.7)
    }

    // MARK: - Consciousness Node

    private var consciousnessNode: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [state.color, .white, state.color, state.color.opacity(0.5), state.color],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(cortexRotation * 2))

            // Inner consciousness
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, state.color, state.color.opacity(0.5)],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 20, height: 20)
                .scaleEffect(1.0 + brainPulse * 0.2)
                .shadow(color: state.color, radius: 10)
                .shadow(color: .white.opacity(0.5), radius: 5)
        }
    }

    // MARK: - Status Label

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.color)
                .frame(width: 6, height: 6)
                .opacity(0.5 + brainPulse * 0.5)

            Text(state.statusMessage)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Brain pulse
        withAnimation(.easeInOut(duration: state.pulseDuration).repeatForever(autoreverses: true)) {
            brainPulse = 1.0
        }

        // Neural glow
        withAnimation(.easeInOut(duration: state.pulseDuration * 1.5).repeatForever(autoreverses: true)) {
            neuralGlow = state.glowIntensity
        }

        // Synapse phase (continuous)
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            synapsePhase = 1.0
        }

        // Cortex rotation
        withAnimation(.linear(duration: 30 / state.rotationSpeed).repeatForever(autoreverses: false)) {
            cortexRotation = 360
        }
    }

    private func updateAnimations() {
        brainPulse = 0.0
        neuralGlow = 0.5

        withAnimation(.easeInOut(duration: state.pulseDuration).repeatForever(autoreverses: true)) {
            brainPulse = 1.0
        }

        withAnimation(.easeInOut(duration: state.pulseDuration * 1.5).repeatForever(autoreverses: true)) {
            neuralGlow = state.glowIntensity
        }
    }
}

// MARK: - Brain Hemisphere

private struct BrainHemisphere: View {
    let isLeft: Bool
    let color: Color
    let pulse: Double

    var body: some View {
        ZStack {
            // Main hemisphere shape
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.4),
                            color.opacity(0.2),
                            color.opacity(0.1)
                        ],
                        startPoint: isLeft ? .topLeading : .topTrailing,
                        endPoint: isLeft ? .bottomTrailing : .bottomLeading
                    )
                )
                .frame(width: 45, height: 55)

            // Gyri (brain folds) pattern
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .stroke(color.opacity(0.3 + pulse * 0.2), lineWidth: 1)
                    .frame(width: 30 - CGFloat(i * 5), height: 8)
                    .offset(y: CGFloat(i * 12) - 18)
                    .rotationEffect(.degrees(isLeft ? -10 : 10))
            }

            // Highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.3), .clear],
                        center: .init(x: isLeft ? 0.3 : 0.7, y: 0.2),
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 45, height: 55)
        }
        .scaleEffect(1.0 + pulse * 0.05)
    }
}

// MARK: - Neural Path

private struct NeuralPath: View {
    let index: Int
    let color: Color
    let phase: Double

    var body: some View {
        let angle = Double(index) * 60.0

        Path { path in
            let center = CGPoint(x: 70, y: 70)
            let endRadius: CGFloat = 55

            // Curved neural path
            path.move(to: center)

            let controlPoint = CGPoint(
                x: center.x + 20 * CGFloat(Darwin.cos((angle + 30) * .pi / 180)),
                y: center.y + 20 * CGFloat(Darwin.sin((angle + 30) * .pi / 180))
            )
            let endPoint = CGPoint(
                x: center.x + endRadius * CGFloat(Darwin.cos(angle * .pi / 180)),
                y: center.y + endRadius * CGFloat(Darwin.sin(angle * .pi / 180))
            )

            path.addQuadCurve(to: endPoint, control: controlPoint)
        }
        .stroke(
            color.opacity(0.3),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3], dashPhase: CGFloat(phase))
        )
    }
}

// MARK: - Cortex Circuit

private struct CortexCircuit: View {
    let index: Int
    let color: Color
    let rotation: Double
    let pulse: Double

    var body: some View {
        let angle = Double(index) * 45.0
        let radius: CGFloat = 20 + CGFloat(index % 3) * 8

        Circle()
            .fill(color.opacity(0.3 + pulse * 0.3))
            .frame(width: 3 + CGFloat(index % 2) * 2, height: 3 + CGFloat(index % 2) * 2)
            .offset(
                x: radius * CGFloat(Darwin.cos((angle + rotation * 0.1) * .pi / 180)),
                y: radius * CGFloat(Darwin.sin((angle + rotation * 0.1) * .pi / 180))
            )
            .blur(radius: 0.5)
    }
}

// MARK: - Synaptic Connection

private struct SynapticConnection: View {
    let angle: Double
    let color: Color
    let phase: Double
    let intensity: Double

    @State private var impulsePosition: CGFloat = 0
    @State private var isAnimating: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let length: CGFloat = 100

            ZStack {
                // Base axon (nerve fiber)
                axonPath(center: center, length: length)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.2)],
                            startPoint: .center,
                            endPoint: endPoint(center: center, length: length)
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )

                // Myelin sheath segments
                ForEach(0..<5, id: \.self) { i in
                    let segmentPos = CGFloat(i) / 5.0
                    myelinSegment(center: center, length: length, position: segmentPos)
                }

                // Traveling neural impulse
                neuralImpulse(center: center, length: length)

                // Synaptic terminal (end bulb)
                synapticTerminal(center: center, length: length)
            }
        }
        .onAppear {
            startImpulseAnimation()
        }
    }

    private func axonPath(center: CGPoint, length: CGFloat) -> Path {
        Path { path in
            path.move(to: center)
            let end = CGPoint(
                x: center.x + length * CGFloat(Darwin.cos(angle * .pi / 180)),
                y: center.y + length * CGFloat(Darwin.sin(angle * .pi / 180))
            )
            path.addLine(to: end)
        }
    }

    private func endPoint(center: CGPoint, length: CGFloat) -> UnitPoint {
        UnitPoint(
            x: 0.5 + 0.5 * Darwin.cos(angle * .pi / 180),
            y: 0.5 + 0.5 * Darwin.sin(angle * .pi / 180)
        )
    }

    private func myelinSegment(center: CGPoint, length: CGFloat, position: CGFloat) -> some View {
        let distance = length * (0.2 + position * 0.6)
        let x = center.x + distance * CGFloat(Darwin.cos(angle * .pi / 180))
        let y = center.y + distance * CGFloat(Darwin.sin(angle * .pi / 180))

        return Capsule()
            .fill(color.opacity(0.15))
            .frame(width: 8, height: 4)
            .rotationEffect(.degrees(angle))
            .position(x: x, y: y)
    }

    private func neuralImpulse(center: CGPoint, length: CGFloat) -> some View {
        let distance = length * impulsePosition
        let x = center.x + distance * CGFloat(Darwin.cos(angle * .pi / 180))
        let y = center.y + distance * CGFloat(Darwin.sin(angle * .pi / 180))

        return ZStack {
            // Glow
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .blur(radius: 6)

            // Core
            Circle()
                .fill(.white)
                .frame(width: 5, height: 5)
        }
        .position(x: x, y: y)
        .opacity(isAnimating ? intensity : 0)
    }

    private func synapticTerminal(center: CGPoint, length: CGFloat) -> some View {
        let x = center.x + length * CGFloat(Darwin.cos(angle * .pi / 180))
        let y = center.y + length * CGFloat(Darwin.sin(angle * .pi / 180))

        return ZStack {
            // Terminal bulb glow
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: 14, height: 14)
                .blur(radius: 4)

            // Terminal bulb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color, color.opacity(0.5)],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: 6
                    )
                )
                .frame(width: 8, height: 8)
        }
        .position(x: x, y: y)
    }

    private func startImpulseAnimation() {
        isAnimating = true

        // Staggered impulse animation based on phase
        let delay = phase.truncatingRemainder(dividingBy: 1.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.6).repeatForever(autoreverses: false)) {
                impulsePosition = 1.0
            }
        }
    }
}

// MARK: - Neural Sparks

private struct NeuralSparks: View {
    let state: OrchestratorVisualState

    @State private var sparks: [NeuralSpark] = []

    var body: some View {
        ZStack {
            ForEach(sparks) { spark in
                Circle()
                    .fill(spark.isWhite ? .white : state.color)
                    .frame(width: spark.size, height: spark.size)
                    .offset(x: spark.x, y: spark.y)
                    .opacity(spark.opacity)
                    .blur(radius: spark.size > 3 ? 1 : 0)
            }
        }
        .onAppear { generateSparks() }
    }

    private func generateSparks() {
        sparks = (0..<15).map { _ in
            NeuralSpark(
                x: CGFloat.random(in: -50...50),
                y: CGFloat.random(in: -40...40),
                size: CGFloat.random(in: 1.5...4),
                opacity: Double.random(in: 0.3...0.8),
                isWhite: Bool.random()
            )
        }

        // Animate sparks
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                for i in sparks.indices {
                    // Jittery neural activity
                    sparks[i].x += CGFloat.random(in: -3...3)
                    sparks[i].y += CGFloat.random(in: -3...3)

                    // Keep within bounds
                    sparks[i].x = max(-55, min(55, sparks[i].x))
                    sparks[i].y = max(-45, min(45, sparks[i].y))

                    // Flicker
                    sparks[i].opacity = Double.random(in: 0.2...0.9)
                }
            }
        }
    }
}

private struct NeuralSpark: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var isWhite: Bool
}

// MARK: - Preview

#if DEBUG
struct OrchestratorCreatureView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.xl) {
            HStack(spacing: Theme.Spacing.xl) {
                OrchestratorCreatureView(state: .idle, activeSlotAngles: [])
                OrchestratorCreatureView(state: .monitoring, activeSlotAngles: [-90, -30, 30])
            }

            HStack(spacing: Theme.Spacing.xl) {
                OrchestratorCreatureView(state: .distributing, activeSlotAngles: [-90, -30, 30, 90, 150])
                OrchestratorCreatureView(state: .celebrating, activeSlotAngles: [-90, -30, 30, 90, 150, 210])
            }
        }
        .padding(Theme.Spacing.xl)
        .background(Color.bgApp)
    }
}
#endif
