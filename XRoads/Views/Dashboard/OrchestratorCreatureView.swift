//
//  OrchestratorCreatureView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Central Neon Brain Orchestrator - wrapper for NeonBrainView with status
//

import SwiftUI

// MARK: - OrchestratorCreatureView

struct OrchestratorCreatureView: View {
    let state: OrchestratorVisualState
    let activeSlotAngles: [Double]

    @State private var energyRotation: Double = 0.0

    // Neon color palette
    private let neonCyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    private let neonMagenta = Color(red: 1.0, green: 0.2, blue: 0.8)
    private let neonPurple = Color(red: 0.6, green: 0.3, blue: 1.0)

    private var isActive: Bool {
        !activeSlotAngles.isEmpty || state == .monitoring || state == .distributing
    }

    var body: some View {
        ZStack {
            // Layer 1: Outer energy rings
            energyRings

            // Layer 2: The animated neon brain
            NeonBrainView(
                isActive: isActive,
                intensity: state.glowIntensity
            )

            // Layer 3: Status indicator
            statusIndicator
                .offset(y: 95)
        }
        .frame(width: 200, height: 220)
        .onAppear { startAnimations() }
    }

    // MARK: - Energy Rings

    private var energyRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                neonCyan.opacity(0.25),
                                neonMagenta.opacity(0.1),
                                neonPurple.opacity(0.25),
                                neonCyan.opacity(0.1)
                            ],
                            center: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(
                        width: 170 + CGFloat(i) * 25,
                        height: 150 + CGFloat(i) * 20
                    )
                    .rotationEffect(.degrees(energyRotation * (i % 2 == 0 ? 1 : -1)))
                    .opacity(isActive ? 0.6 : 0.3)
            }
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            // Animated status dot
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
                .shadow(color: state.color, radius: 4)

            Text(state.statusMessage)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bgSurface.opacity(0.85))
        .cornerRadius(12)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Energy ring rotation
        withAnimation(.linear(duration: 25 / state.rotationSpeed).repeatForever(autoreverses: false)) {
            energyRotation = 360
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OrchestratorCreatureView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()

            VStack(spacing: 40) {
                HStack(spacing: 60) {
                    OrchestratorCreatureView(state: .sleeping, activeSlotAngles: [])
                    OrchestratorCreatureView(state: .idle, activeSlotAngles: [-90])
                }

                HStack(spacing: 60) {
                    OrchestratorCreatureView(state: .monitoring, activeSlotAngles: [-90, -30, 30])
                    OrchestratorCreatureView(state: .celebrating, activeSlotAngles: [-90, -30, 30, 90, 150, 210])
                }
            }
        }
        .frame(width: 700, height: 600)
    }
}
#endif
