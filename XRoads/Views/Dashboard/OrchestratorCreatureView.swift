//
//  OrchestratorCreatureView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Central Neon Brain Orchestrator with dynamic synaptic connections
//

import SwiftUI

// MARK: - OrchestratorCreatureView

struct OrchestratorCreatureView: View {
    let state: OrchestratorVisualState
    let activeSlotAngles: [Double]

    @State private var brainPulse: Double = 0.0
    @State private var glowIntensity: Double = 0.5
    @State private var energyRotation: Double = 0.0

    private let brainSize: CGFloat = 120

    // Neon color palette
    private let neonCyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    private let neonMagenta = Color(red: 1.0, green: 0.2, blue: 0.8)
    private let neonPurple = Color(red: 0.6, green: 0.3, blue: 1.0)
    private let neonBlue = Color(red: 0.3, green: 0.5, blue: 1.0)

    var body: some View {
        ZStack {
            // Layer 1: Outer energy field (rotating rings)
            energyField

            // Layer 2: Brain glow aura (multiple neon layers)
            brainGlowAura

            // Layer 3: Brain core shape with hemispheres
            neonBrainCore

            // Layer 4: Neural activity sparks
            if state.showsParticles {
                NeonNeuralSparks(
                    colors: [neonCyan, neonMagenta, neonPurple],
                    intensity: state.glowIntensity
                )
            }

            // Layer 5: Central consciousness core
            centralConsciousness

            // Status label
            statusIndicator
                .offset(y: brainSize / 2 + 40)
        }
        .frame(width: brainSize * 2, height: brainSize * 2)
        .onAppear { startAnimations() }
        .onChange(of: state) { _, _ in updateAnimations() }
    }

    // MARK: - Energy Field

    private var energyField: some View {
        ZStack {
            // Rotating energy rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                neonCyan.opacity(0.3),
                                neonMagenta.opacity(0.1),
                                neonPurple.opacity(0.3),
                                neonCyan.opacity(0.1)
                            ],
                            center: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(
                        width: brainSize * (1.4 + CGFloat(i) * 0.2),
                        height: brainSize * (1.4 + CGFloat(i) * 0.2)
                    )
                    .rotationEffect(.degrees(energyRotation * (i % 2 == 0 ? 1 : -1)))
                    .opacity(0.4 + brainPulse * 0.3)
            }
        }
    }

    // MARK: - Brain Glow Aura

    private var brainGlowAura: some View {
        ZStack {
            // Outer magenta glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            neonMagenta.opacity(0.4 * glowIntensity),
                            neonMagenta.opacity(0.1 * glowIntensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: brainSize * 0.2,
                        endRadius: brainSize * 0.8
                    )
                )
                .frame(width: brainSize * 1.5, height: brainSize * 1.3)
                .blur(radius: 30)

            // Middle cyan glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            neonCyan.opacity(0.5 * glowIntensity),
                            neonCyan.opacity(0.2 * glowIntensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: brainSize * 0.1,
                        endRadius: brainSize * 0.6
                    )
                )
                .frame(width: brainSize * 1.2, height: brainSize)
                .blur(radius: 20)
                .scaleEffect(1.0 + brainPulse * 0.1)

            // Inner purple core glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            neonPurple.opacity(0.6 * glowIntensity),
                            neonBlue.opacity(0.3 * glowIntensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: brainSize * 0.4
                    )
                )
                .frame(width: brainSize * 0.8, height: brainSize * 0.7)
                .blur(radius: 15)
                .scaleEffect(1.0 + brainPulse * 0.15)
        }
    }

    // MARK: - Neon Brain Core

    private var neonBrainCore: some View {
        ZStack {
            // Left hemisphere
            NeonBrainHemisphere(
                isLeft: true,
                primaryColor: neonCyan,
                secondaryColor: neonMagenta,
                pulse: brainPulse,
                glowIntensity: glowIntensity
            )
            .offset(x: -12)

            // Right hemisphere
            NeonBrainHemisphere(
                isLeft: false,
                primaryColor: neonMagenta,
                secondaryColor: neonCyan,
                pulse: brainPulse,
                glowIntensity: glowIntensity
            )
            .offset(x: 12)

            // Central fissure (glowing line)
            centralFissure

            // Brain stem
            brainStem
        }
        .frame(width: brainSize, height: brainSize * 0.85)
    }

    private var centralFissure: some View {
        ZStack {
            // Glow
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            neonCyan.opacity(0.8),
                            .white.opacity(0.9),
                            neonMagenta.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: brainSize * 0.55)
                .blur(radius: 4)

            // Core line
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [neonCyan, .white, neonMagenta],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: brainSize * 0.5)
        }
        .opacity(0.7 + brainPulse * 0.3)
    }

    private var brainStem: some View {
        ZStack {
            // Stem glow
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            neonPurple.opacity(0.6),
                            neonBlue.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 20, height: 35)
                .blur(radius: 8)

            // Stem core
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [neonPurple, neonBlue.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 12, height: 30)
        }
        .offset(y: brainSize * 0.35)
    }

    // MARK: - Central Consciousness

    private var centralConsciousness: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [neonCyan, neonMagenta, neonPurple, neonCyan],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 35, height: 35)
                .rotationEffect(.degrees(energyRotation * 2))
                .blur(radius: 1)

            // Inner consciousness core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white,
                            neonCyan,
                            neonPurple.opacity(0.5)
                        ],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: 18
                    )
                )
                .frame(width: 25, height: 25)
                .scaleEffect(1.0 + brainPulse * 0.2)

            // Core glow
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .blur(radius: 4)
                .offset(x: -3, y: -3)
        }
        .shadow(color: neonCyan, radius: 15)
        .shadow(color: neonMagenta.opacity(0.5), radius: 25)
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            // Animated status dot
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
                .shadow(color: state.color, radius: 4)
                .scaleEffect(0.8 + brainPulse * 0.4)

            Text(state.statusMessage)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bgSurface.opacity(0.8))
        .cornerRadius(12)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Brain pulse
        withAnimation(.easeInOut(duration: state.pulseDuration).repeatForever(autoreverses: true)) {
            brainPulse = 1.0
        }

        // Glow intensity
        withAnimation(.easeInOut(duration: state.pulseDuration * 1.3).repeatForever(autoreverses: true)) {
            glowIntensity = state.glowIntensity
        }

        // Energy rotation (continuous)
        withAnimation(.linear(duration: 20 / state.rotationSpeed).repeatForever(autoreverses: false)) {
            energyRotation = 360
        }
    }

    private func updateAnimations() {
        brainPulse = 0.0
        glowIntensity = 0.5

        withAnimation(.easeInOut(duration: state.pulseDuration).repeatForever(autoreverses: true)) {
            brainPulse = 1.0
        }

        withAnimation(.easeInOut(duration: state.pulseDuration * 1.3).repeatForever(autoreverses: true)) {
            glowIntensity = state.glowIntensity
        }
    }
}

// MARK: - Neon Brain Hemisphere

private struct NeonBrainHemisphere: View {
    let isLeft: Bool
    let primaryColor: Color
    let secondaryColor: Color
    let pulse: Double
    let glowIntensity: Double

    var body: some View {
        ZStack {
            // Main hemisphere shape with gradient
            hemisphereShape
                .fill(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(0.5 * glowIntensity),
                            secondaryColor.opacity(0.3 * glowIntensity),
                            primaryColor.opacity(0.2 * glowIntensity)
                        ],
                        startPoint: isLeft ? .topLeading : .topTrailing,
                        endPoint: isLeft ? .bottomTrailing : .bottomLeading
                    )
                )
                .frame(width: 55, height: 70)

            // Gyri (brain folds) - glowing lines
            ForEach(0..<5, id: \.self) { i in
                gyrusLine(index: i)
            }

            // Highlight reflection
            hemisphereShape
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.4),
                            .clear
                        ],
                        center: .init(x: isLeft ? 0.3 : 0.7, y: 0.25),
                        startRadius: 0,
                        endRadius: 25
                    )
                )
                .frame(width: 55, height: 70)
        }
        .scaleEffect(1.0 + pulse * 0.03)
    }

    private var hemisphereShape: some Shape {
        RoundedRectangle(cornerRadius: 25)
    }

    private func gyrusLine(index: Int) -> some View {
        let yOffset = CGFloat(index) * 14 - 28

        return Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        primaryColor.opacity(0.6 + pulse * 0.3),
                        secondaryColor.opacity(0.3 + pulse * 0.2)
                    ],
                    startPoint: isLeft ? .leading : .trailing,
                    endPoint: isLeft ? .trailing : .leading
                )
            )
            .frame(width: 35 - CGFloat(abs(index - 2)) * 5, height: 3)
            .blur(radius: 1)
            .offset(y: yOffset)
            .rotationEffect(.degrees(isLeft ? -8 : 8))
    }
}

// MARK: - Neon Neural Sparks

private struct NeonNeuralSparks: View {
    let colors: [Color]
    let intensity: Double

    @State private var sparks: [NeonSpark] = []

    var body: some View {
        ZStack {
            ForEach(sparks) { spark in
                Circle()
                    .fill(spark.color)
                    .frame(width: spark.size, height: spark.size)
                    .blur(radius: spark.size > 3 ? 2 : 0)
                    .offset(x: spark.x, y: spark.y)
                    .opacity(spark.opacity * intensity)
            }
        }
        .onAppear { initializeSparks() }
    }

    private func initializeSparks() {
        sparks = (0..<20).map { _ in
            NeonSpark(
                x: CGFloat.random(in: -60...60),
                y: CGFloat.random(in: -50...50),
                size: CGFloat.random(in: 2...5),
                opacity: Double.random(in: 0.4...1.0),
                color: colors.randomElement() ?? .white
            )
        }

        // Animate sparks with jittery movement
        Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                for i in sparks.indices {
                    sparks[i].x += CGFloat.random(in: -4...4)
                    sparks[i].y += CGFloat.random(in: -4...4)
                    sparks[i].x = max(-65, min(65, sparks[i].x))
                    sparks[i].y = max(-55, min(55, sparks[i].y))
                    sparks[i].opacity = Double.random(in: 0.3...1.0)
                }
            }
        }
    }
}

private struct NeonSpark: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var color: Color
}

// MARK: - Preview

#if DEBUG
struct OrchestratorCreatureView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()

            VStack(spacing: 60) {
                HStack(spacing: 80) {
                    OrchestratorCreatureView(state: .sleeping, activeSlotAngles: [])
                    OrchestratorCreatureView(state: .idle, activeSlotAngles: [-90])
                }

                HStack(spacing: 80) {
                    OrchestratorCreatureView(state: .monitoring, activeSlotAngles: [-90, -30, 30])
                    OrchestratorCreatureView(state: .celebrating, activeSlotAngles: [-90, -30, 30, 90, 150, 210])
                }
            }
        }
        .frame(width: 800, height: 700)
    }
}
#endif
