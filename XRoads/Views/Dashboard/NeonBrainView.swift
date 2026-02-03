//
//  NeonBrainView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Animated neon brain with traveling filaments for the orchestrator
//

import SwiftUI

// MARK: - NeonBrainView

struct NeonBrainView: View {
    let isActive: Bool
    let intensity: Double

    // Neon colors
    private let neonCyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    private let neonMagenta = Color(red: 1.0, green: 0.2, blue: 0.8)
    private let neonPurple = Color(red: 0.6, green: 0.3, blue: 1.0)

    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5

    var body: some View {
        ZStack {
            // Layer 1: Outer glow aura
            brainGlowAura

            // Layer 2: Brain base shape with gradient fill
            brainBaseShape

            // Layer 3: Brain outline glow
            brainOutlineGlow

            // Layer 4: Internal gyri (folds)
            brainGyri

            // Layer 5: Animated filaments
            if isActive {
                filamentLayer
            }

            // Layer 6: Neural sparks
            if isActive {
                neuralSparksLayer
            }
        }
        .frame(width: 160, height: 140)
        .onAppear { startAnimations() }
    }

    // MARK: - Glow Aura

    private var brainGlowAura: some View {
        ZStack {
            // Magenta outer glow
            BrainShape()
                .fill(neonMagenta.opacity(0.3 * glowOpacity))
                .blur(radius: 30)
                .scaleEffect(1.3)

            // Cyan middle glow
            BrainShape()
                .fill(neonCyan.opacity(0.4 * glowOpacity))
                .blur(radius: 20)
                .scaleEffect(1.15)

            // Purple inner glow
            BrainShape()
                .fill(neonPurple.opacity(0.5 * glowOpacity))
                .blur(radius: 12)
                .scaleEffect(pulseScale)
        }
    }

    // MARK: - Brain Base Shape

    private var brainBaseShape: some View {
        BrainShape()
            .fill(
                RadialGradient(
                    colors: [
                        neonPurple.opacity(0.4),
                        neonCyan.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                )
            )
            .scaleEffect(pulseScale)
    }

    // MARK: - Brain Outline Glow

    private var brainOutlineGlow: some View {
        ZStack {
            // Outer stroke glow
            BrainShape()
                .stroke(neonCyan.opacity(0.6), lineWidth: 4)
                .blur(radius: 6)

            // Middle stroke
            BrainShape()
                .stroke(
                    LinearGradient(
                        colors: [neonCyan, neonMagenta, neonPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .blur(radius: 2)

            // Core stroke
            BrainShape()
                .stroke(
                    LinearGradient(
                        colors: [neonCyan.opacity(0.8), neonMagenta.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .scaleEffect(pulseScale)
    }

    // MARK: - Brain Gyri (Folds)

    private var brainGyri: some View {
        ZStack {
            // Main gyri pattern
            BrainGyriShape()
                .stroke(
                    LinearGradient(
                        colors: [neonCyan.opacity(0.5), neonMagenta.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .blur(radius: 1)

            // Central fissure (divides hemispheres)
            CentralFissure()
                .stroke(
                    LinearGradient(
                        colors: [neonCyan, .white.opacity(0.9), neonMagenta],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .blur(radius: 1.5)
        }
        .scaleEffect(pulseScale)
    }

    // MARK: - Filament Layer

    private var filamentLayer: some View {
        ZStack {
            // Multiple animated filaments
            ForEach(0..<12, id: \.self) { i in
                AnimatedFilament(
                    index: i,
                    color: filamentColor(for: i),
                    delay: Double(i) * 0.15
                )
            }
        }
    }

    // MARK: - Neural Sparks

    private var neuralSparksLayer: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                NeuralSpark(
                    index: i,
                    color: i % 2 == 0 ? neonCyan : neonMagenta
                )
            }
        }
    }

    // MARK: - Helpers

    private func filamentColor(for index: Int) -> Color {
        let colors = [neonCyan, neonMagenta, neonPurple, .white]
        return colors[index % colors.count]
    }

    // MARK: - Animations

    private func startAnimations() {
        // Pulse animation
        withAnimation(.easeInOut(duration: isActive ? 1.5 : 3.0).repeatForever(autoreverses: true)) {
            pulseScale = isActive ? 1.05 : 1.02
        }

        // Glow animation
        withAnimation(.easeInOut(duration: isActive ? 1.2 : 2.5).repeatForever(autoreverses: true)) {
            glowOpacity = isActive ? intensity : 0.4
        }
    }
}

// MARK: - Brain Shape (Pure brain - no head silhouette)

struct BrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Pure brain shape - cerebrum only, stylized for neon effect
        // Centered in rect with proper proportions

        // Start at top center
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.02))

        // === LEFT HEMISPHERE ===

        // Top left curve (frontal lobe)
        path.addCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.25),
            control1: CGPoint(x: w * 0.35, y: h * 0.0),
            control2: CGPoint(x: w * 0.18, y: h * 0.08)
        )

        // Left frontal bulge
        path.addCurve(
            to: CGPoint(x: w * 0.05, y: h * 0.45),
            control1: CGPoint(x: w * 0.06, y: h * 0.32),
            control2: CGPoint(x: w * 0.03, y: h * 0.38)
        )

        // Left temporal lobe (lower bulge)
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.72),
            control1: CGPoint(x: w * 0.02, y: h * 0.55),
            control2: CGPoint(x: w * 0.05, y: h * 0.68)
        )

        // Left occipital area
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.88),
            control1: CGPoint(x: w * 0.22, y: h * 0.78),
            control2: CGPoint(x: w * 0.28, y: h * 0.85)
        )

        // === BRAIN STEM (bottom center) ===

        // To brain stem
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.98),
            control1: CGPoint(x: w * 0.40, y: h * 0.92),
            control2: CGPoint(x: w * 0.45, y: h * 0.96)
        )

        // === RIGHT HEMISPHERE ===

        // From brain stem to right occipital
        path.addCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.88),
            control1: CGPoint(x: w * 0.55, y: h * 0.96),
            control2: CGPoint(x: w * 0.60, y: h * 0.92)
        )

        // Right temporal lobe
        path.addCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.72),
            control1: CGPoint(x: w * 0.72, y: h * 0.85),
            control2: CGPoint(x: w * 0.78, y: h * 0.78)
        )

        // Right side going up
        path.addCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.45),
            control1: CGPoint(x: w * 0.95, y: h * 0.68),
            control2: CGPoint(x: w * 0.98, y: h * 0.55)
        )

        // Right frontal bulge
        path.addCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.25),
            control1: CGPoint(x: w * 0.97, y: h * 0.38),
            control2: CGPoint(x: w * 0.94, y: h * 0.32)
        )

        // Top right back to center
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.02),
            control1: CGPoint(x: w * 0.82, y: h * 0.08),
            control2: CGPoint(x: w * 0.65, y: h * 0.0)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Brain Gyri Shape (Internal folds)

struct BrainGyriShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // === LEFT HEMISPHERE GYRI ===

        // Frontal gyrus 1
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.38, y: h * 0.22),
            control: CGPoint(x: w * 0.25, y: h * 0.18)
        )

        // Frontal gyrus 2
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.38))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.40, y: h * 0.35),
            control: CGPoint(x: w * 0.26, y: h * 0.30)
        )

        // Parietal gyrus
        path.move(to: CGPoint(x: w * 0.10, y: h * 0.50))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.42, y: h * 0.48),
            control: CGPoint(x: w * 0.28, y: h * 0.42)
        )

        // Temporal gyrus
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.65))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.40, y: h * 0.62),
            control: CGPoint(x: w * 0.28, y: h * 0.56)
        )

        // === RIGHT HEMISPHERE GYRI ===

        // Frontal gyrus 1
        path.move(to: CGPoint(x: w * 0.85, y: h * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.22),
            control: CGPoint(x: w * 0.75, y: h * 0.18)
        )

        // Frontal gyrus 2
        path.move(to: CGPoint(x: w * 0.88, y: h * 0.38))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.60, y: h * 0.35),
            control: CGPoint(x: w * 0.74, y: h * 0.30)
        )

        // Parietal gyrus
        path.move(to: CGPoint(x: w * 0.90, y: h * 0.50))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.48),
            control: CGPoint(x: w * 0.72, y: h * 0.42)
        )

        // Temporal gyrus
        path.move(to: CGPoint(x: w * 0.85, y: h * 0.65))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.60, y: h * 0.62),
            control: CGPoint(x: w * 0.72, y: h * 0.56)
        )

        return path
    }
}

// MARK: - Central Fissure (Longitudinal fissure dividing hemispheres)

struct CentralFissure: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Starts from top of brain, curves down to brain stem
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.05))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.85),
            control1: CGPoint(x: w * 0.48, y: h * 0.35),
            control2: CGPoint(x: w * 0.52, y: h * 0.60)
        )

        return path
    }
}

// MARK: - Animated Filament

struct AnimatedFilament: View {
    let index: Int
    let color: Color
    let delay: Double

    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        FilamentPath(index: index)
            .trim(from: max(0, progress - 0.3), to: progress)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .blur(radius: 2)
            .opacity(opacity)
            .onAppear {
                startAnimation()
            }
    }

    private func startAnimation() {
        // Staggered start
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                progress = 1.3
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                opacity = 0.8
            }
        }
    }
}

// MARK: - Filament Path (Adapted to brain shape)

struct FilamentPath: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Center of brain (slightly above center for anatomical accuracy)
        let center = CGPoint(x: w * 0.5, y: h * 0.45)

        // Pre-defined filament endpoints that follow brain contours
        let endpoints: [(x: CGFloat, y: CGFloat, ctrlX: CGFloat, ctrlY: CGFloat)] = [
            // Top filaments (frontal lobe)
            (0.30, 0.12, 0.38, 0.25),  // 0 - top left
            (0.50, 0.05, 0.50, 0.22),  // 1 - top center
            (0.70, 0.12, 0.62, 0.25),  // 2 - top right

            // Left side filaments
            (0.10, 0.30, 0.28, 0.35),  // 3 - left frontal
            (0.08, 0.50, 0.26, 0.48),  // 4 - left parietal
            (0.15, 0.70, 0.30, 0.58),  // 5 - left temporal

            // Right side filaments
            (0.90, 0.30, 0.72, 0.35),  // 6 - right frontal
            (0.92, 0.50, 0.74, 0.48),  // 7 - right parietal
            (0.85, 0.70, 0.70, 0.58),  // 8 - right temporal

            // Bottom filaments (occipital/brain stem)
            (0.30, 0.85, 0.38, 0.65),  // 9 - bottom left
            (0.50, 0.92, 0.50, 0.70),  // 10 - bottom center (brain stem)
            (0.70, 0.85, 0.62, 0.65),  // 11 - bottom right
        ]

        let safeIndex = index % endpoints.count
        let endpoint = endpoints[safeIndex]

        let endPoint = CGPoint(x: w * endpoint.x, y: h * endpoint.y)
        let controlPoint = CGPoint(x: w * endpoint.ctrlX, y: h * endpoint.ctrlY)

        path.move(to: center)
        path.addQuadCurve(to: endPoint, control: controlPoint)

        return path
    }
}

// MARK: - Neural Spark

struct NeuralSpark: View {
    let index: Int
    let color: Color

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .blur(radius: 3)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: position.x, y: position.y)
            .onAppear {
                initializePosition()
                startAnimation()
            }
    }

    private func initializePosition() {
        // Distribute sparks within brain area
        let angle = Double(index) * 45.0 * .pi / 180
        let radius = CGFloat.random(in: 20...50)
        position = CGPoint(
            x: radius * CGFloat(cos(angle)),
            y: radius * CGFloat(sin(angle)) * 0.7
        )
    }

    private func startAnimation() {
        // Delay based on index
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
            // Flicker animation
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                opacity = Double.random(in: 0.5...1.0)
                scale = CGFloat.random(in: 0.8...1.2)
            }

            // Drift animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                position.x += CGFloat.random(in: -10...10)
                position.y += CGFloat.random(in: -8...8)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NeonBrainView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                NeonBrainView(isActive: false, intensity: 0.5)
                NeonBrainView(isActive: true, intensity: 1.0)
            }
        }
        .frame(width: 400, height: 500)
    }
}
#endif
