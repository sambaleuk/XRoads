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
            // SVG-based detail folds
            BrainDetailShape()
                .stroke(
                    LinearGradient(
                        colors: [neonCyan.opacity(0.6), neonMagenta.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .blur(radius: 1)

            // Left hemisphere folds
            ForEach(0..<4, id: \.self) { i in
                GyrusPath(index: i, isLeft: true)
                    .stroke(neonCyan.opacity(0.4 + glowOpacity * 0.3), lineWidth: 1.5)
                    .blur(radius: 1)
            }

            // Right hemisphere folds
            ForEach(0..<4, id: \.self) { i in
                GyrusPath(index: i, isLeft: false)
                    .stroke(neonMagenta.opacity(0.4 + glowOpacity * 0.3), lineWidth: 1.5)
                    .blur(radius: 1)
            }

            // Central fissure
            CentralFissure()
                .stroke(
                    LinearGradient(
                        colors: [neonCyan, .white.opacity(0.8), neonMagenta],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .blur(radius: 1)
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

// MARK: - Brain Shape (Realistic SVG-based)

struct BrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Scale factors from original SVG viewBox (1280x1024) to target rect
        // The brain in the SVG is roughly centered around x:400-900, y:100-700
        // We'll normalize to 0-1 range and scale to rect

        let scaleX = w / 700.0  // Approximate brain width in SVG
        let scaleY = h / 600.0  // Approximate brain height in SVG
        let offsetX = w * 0.05  // Small offset for centering
        let offsetY = h * 0.05

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: (x - 200) * scaleX + offsetX, y: (y - 50) * scaleY + offsetY)
        }

        // Outer brain contour - traced from SVG main path
        // Starting from top-left frontal lobe area
        path.move(to: p(606.528, 19.0672))

        // Top curve - frontal lobe
        path.addCurve(
            to: p(677.602, 21.7344),
            control1: p(628.385, 18.006),
            control2: p(655.496, 19.721)
        )

        // Right frontal lobe bulge
        path.addCurve(
            to: p(931.972, 108.816),
            control1: p(763.538, 29.5617),
            control2: p(863.562, 54.4886)
        )

        // Right parietal area
        path.addCurve(
            to: p(1022, 301.709),
            control1: p(993.604, 157.762),
            control2: p(1003.34, 230.477)
        )

        // Right temporal lobe
        path.addCurve(
            to: p(1042.45, 380.991),
            control1: p(1028.89, 328.019),
            control2: p(1041.35, 352.536)
        )

        // Right occipital curve
        path.addCurve(
            to: p(1030.87, 456.961),
            control1: p(1044.1, 409.955),
            control2: p(1018.02, 427.569)
        )

        // Back of head curve
        path.addCurve(
            to: p(1112.01, 552.681),
            control1: p(1048.56, 497.418),
            control2: p(1082.05, 522.343)
        )

        // Lower back curve
        path.addCurve(
            to: p(1057.51, 621.394),
            control1: p(1119.01, 559.773),
            control2: p(1103.06, 602.118)
        )

        // Continuing down the back
        path.addCurve(
            to: p(1050.57, 698.599),
            control1: p(1051.3, 634.887),
            control2: p(1080.59, 665.368)
        )

        // Lower back - cerebellum area
        path.addCurve(
            to: p(1031.55, 763.533),
            control1: p(1073.8, 727.339),
            control2: p(1033.35, 738.712)
        )

        // Brain stem area
        path.addCurve(
            to: p(1019.02, 854.658),
            control1: p(1030.3, 780.838),
            control2: p(1041.33, 792.331)
        )

        // Bottom right
        path.addCurve(
            to: p(860.391, 862.222),
            control1: p(971.629, 871.21),
            control2: p(905.045, 860.573)
        )

        // Bottom center - transition to left
        path.addCurve(
            to: p(661.088, 756.215),
            control1: p(781.651, 831.096),
            control2: p(680.751, 778.811)
        )

        // Left temporal lobe
        path.addCurve(
            to: p(615.428, 671.395),
            control1: p(658.461, 771.413),
            control2: p(638.375, 696.175)
        )

        // Left side inward curve
        path.addCurve(
            to: p(527.743, 588.76),
            control1: p(580.56, 656.995),
            control2: p(552.466, 622.144)
        )

        // Left bottom
        path.addCurve(
            to: p(253.211, 532.517),
            control1: p(521.777, 657.084),
            control2: p(251.449, 574.162)
        )

        // Left lower curve
        path.addCurve(
            to: p(203.099, 431.635),
            control1: p(212.431, 520.889),
            control2: p(194.444, 470.009)
        )

        // Left mid section
        path.addCurve(
            to: p(241.038, 310.375),
            control1: p(204.951, 423.424),
            control2: p(198.082, 367.225)
        )

        // Left upper curve
        path.addCurve(
            to: p(290.314, 225.576),
            control1: p(237.464, 272.435),
            control2: p(259.161, 244.206)
        )

        // Left frontal lobe
        path.addCurve(
            to: p(330.156, 176.429),
            control1: p(292.596, 197.378),
            control2: p(306.089, 186.955)
        )

        // Upper left
        path.addCurve(
            to: p(394.65, 124.47),
            control1: p(344.146, 146.769),
            control2: p(357.795, 124.828)
        )

        // Top left frontal
        path.addCurve(
            to: p(465.5, 85.7151),
            control1: p(413.177, 100.054),
            control2: p(433.181, 83.7954)
        )

        // Back to top center
        path.addCurve(
            to: p(551.363, 75.4167),
            control1: p(492.683, 67.6758),
            control2: p(522.081, 69.5268)
        )

        // Close the top
        path.addCurve(
            to: p(606.528, 19.0672),
            control1: p(575.537, 63.7993),
            control2: p(598.496, 64.8301)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Brain Detail Shape (Inner folds - gyri)

struct BrainDetailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let scaleX = w / 700.0
        let scaleY = h / 600.0
        let offsetX = w * 0.05
        let offsetY = h * 0.05

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: (x - 200) * scaleX + offsetX, y: (y - 50) * scaleY + offsetY)
        }

        // Inner fold 1 - left frontal gyrus
        path.move(to: p(392.042, 258.797))
        path.addCurve(
            to: p(378.69, 281.048),
            control1: p(385.328, 264.05),
            control2: p(377.08, 270.641)
        )
        path.addCurve(
            to: p(454.814, 313.672),
            control1: p(384.134, 316.252),
            control2: p(431.347, 301.069)
        )

        // Inner fold 2 - temporal area
        path.move(to: p(323.989, 235.014))
        path.addCurve(
            to: p(357.17, 355.596),
            control1: p(337.453, 239.391),
            control2: p(337.894, 325.423)
        )

        // Inner fold 3 - parietal
        path.move(to: p(540.591, 106.881))
        path.addCurve(
            to: p(574.387, 191.745),
            control1: p(519.04, 159.745),
            control2: p(541.465, 177.936)
        )

        // Inner fold 4 - occipital
        path.move(to: p(603.457, 167.12))
        path.addCurve(
            to: p(653.599, 241.45),
            control1: p(642.288, 183.708),
            control2: p(655.753, 221.935)
        )

        return path
    }
}

// MARK: - Gyrus Path (Brain Folds)

struct GyrusPath: Shape {
    let index: Int
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let yOffset = CGFloat(index) * (h * 0.15) + h * 0.2
        let xStart = isLeft ? w * 0.15 : w * 0.55
        let xEnd = isLeft ? w * 0.45 : w * 0.85
        let xControl = isLeft ? w * 0.25 : w * 0.75

        path.move(to: CGPoint(x: xStart, y: yOffset))
        path.addQuadCurve(
            to: CGPoint(x: xEnd, y: yOffset + h * 0.05),
            control: CGPoint(x: xControl, y: yOffset - h * 0.08)
        )

        return path
    }
}

// MARK: - Central Fissure

struct CentralFissure: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.75),
            control1: CGPoint(x: w * 0.48, y: h * 0.4),
            control2: CGPoint(x: w * 0.52, y: h * 0.55)
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

// MARK: - Filament Path

struct FilamentPath: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Center point
        let center = CGPoint(x: w * 0.5, y: h * 0.45)

        // Calculate angle based on index (spread around the brain)
        let baseAngle = Double(index) * 30.0 - 150.0
        let angleRad = baseAngle * .pi / 180

        // Random-ish endpoint based on index
        let radius = w * 0.35 + CGFloat(index % 3) * w * 0.05
        let endX = center.x + radius * CGFloat(cos(angleRad))
        let endY = center.y + radius * CGFloat(sin(angleRad)) * 0.8

        // Control point for curve
        let ctrlAngle = angleRad + (index % 2 == 0 ? 0.3 : -0.3)
        let ctrlRadius = radius * 0.6
        let ctrlX = center.x + ctrlRadius * CGFloat(cos(ctrlAngle))
        let ctrlY = center.y + ctrlRadius * CGFloat(sin(ctrlAngle)) * 0.8

        path.move(to: center)
        path.addQuadCurve(
            to: CGPoint(x: endX, y: endY),
            control: CGPoint(x: ctrlX, y: ctrlY)
        )

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
