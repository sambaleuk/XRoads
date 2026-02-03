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
            ForEach(0..<14, id: \.self) { i in
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

// MARK: - Brain Shape (Top-down view from SVG)

struct BrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Scale from SVG viewBox 1024x1024 to rect
        func s(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x / 1024.0 * w, y: y / 1024.0 * h)
        }

        // Main brain outline extracted from SVG (the dark #333343 path)
        // This is the outer contour of the brain seen from above

        path.move(to: s(494.977, 71.6984))

        // Top center to right side
        path.addCurve(
            to: s(551.466, 82.2766),
            control1: s(514.441, 69.4846),
            control2: s(534.122, 73.17)
        )

        path.addCurve(
            to: s(657.325, 106.525),
            control1: s(560.379, 80.894),
            control2: s(630.659, 85.8886)
        )

        path.addCurve(
            to: s(763.802, 146.071),
            control1: s(693.596, 108.889),
            control2: s(748.556, 133.538)
        )

        path.addCurve(
            to: s(843.369, 224.693),
            control1: s(791.528, 167.303),
            control2: s(831.786, 199.217)
        )

        path.addCurve(
            to: s(889.876, 275.241),
            control1: s(865.527, 237.647),
            control2: s(880.233, 250.819)
        )

        path.addCurve(
            to: s(935.751, 364.707),
            control1: s(895.896, 293.977),
            control2: s(935.268, 330.821)
        )

        path.addCurve(
            to: s(973.99, 461.485),
            control1: s(956.267, 384.788),
            control2: s(977.929, 433.086)
        )

        path.addCurve(
            to: s(977.862, 577.185),
            control1: s(988.931, 495.522),
            control2: s(991.081, 557.147)
        )

        path.addCurve(
            to: s(929.848, 695.414),
            control1: s(982.876, 665.202),
            control2: s(946.343, 691.655)
        )

        path.addCurve(
            to: s(885.137, 807.553),
            control1: s(919.652, 724.763),
            control2: s(916.866, 759.736)
        )

        path.addCurve(
            to: s(781.109, 879.639),
            control1: s(855.886, 836.07),
            control2: s(819.118, 864.147)
        )

        path.addCurve(
            to: s(661.355, 863.249),
            control1: s(742.331, 895.444),
            control2: s(692.715, 893.431)
        )

        // Transition through bottom
        path.addCurve(
            to: s(570.636, 762.296),
            control1: s(636.68, 815.227),
            control2: s(591.973, 773.894)
        )

        path.addCurve(
            to: s(553.855, 774.639),
            control1: s(561.78, 709.71),
            control2: s(576.716, 732.968)
        )

        // Left side going up
        path.addCurve(
            to: s(468.214, 753.5),
            control1: s(524.252, 728.843),
            control2: s(491.071, 739.879)
        )

        path.addCurve(
            to: s(355.497, 724.503),
            control1: s(432.545, 741.587),
            control2: s(396.767, 750.494)
        )

        path.addCurve(
            to: s(260.204, 701.496),
            control1: s(285.932, 718.82),
            control2: s(270.606, 713.163)
        )

        path.addCurve(
            to: s(246, 700.872),
            control1: s(256.08, 717.079),
            control2: s(267.504, 721.678)
        )

        path.addCurve(
            to: s(272.058, 575.66),
            control1: s(239.291, 633.725),
            control2: s(255.667, 606.918)
        )

        path.addCurve(
            to: s(278.414, 657.201),
            control1: s(319.214, 524.588),
            control2: s(295.813, 662.41)
        )

        // Continue left side up
        path.addCurve(
            to: s(142.113, 594.097),
            control1: s(181.252, 617.186),
            control2: s(159.001, 609.315)
        )

        path.addCurve(
            to: s(74.5394, 554.07),
            control1: s(98.624, 584.013),
            control2: s(83.4879, 571.083)
        )

        path.addCurve(
            to: s(37.9109, 473.959),
            control1: s(47.8459, 520.866),
            control2: s(34.3118, 500.602)
        )

        path.addCurve(
            to: s(47.4468, 389.419),
            control1: s(40.8314, 461.885),
            control2: s(36.0346, 430.889)
        )

        path.addCurve(
            to: s(84.3742, 286.448),
            control1: s(56.0464, 354.495),
            control2: s(65.7774, 313.158)
        )

        path.addCurve(
            to: s(158.225, 195.539),
            control1: s(104.764, 256.601),
            control2: s(116.855, 241.854)
        )

        path.addCurve(
            to: s(237.564, 145.348),
            control1: s(183.421, 177.337),
            control2: s(217.828, 154.708)
        )

        path.addCurve(
            to: s(326.793, 102.787),
            control1: s(274.515, 116.504),
            control2: s(302.545, 113.765)
        )

        path.addCurve(
            to: s(380.807, 86.5482),
            control1: s(349.434, 95.9376),
            control2: s(369.46, 91.5947)
        )

        path.addCurve(
            to: s(461.465, 80.4234),
            control1: s(407.09, 76.7136),
            control2: s(434.1, 74.5976)
        )

        // Close back to start
        path.addCurve(
            to: s(494.977, 71.6984),
            control1: s(481.745, 73.0883),
            control2: s(473.503, 75.4925)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Brain Gyri Shape (Internal folds from SVG)

struct BrainGyriShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        func s(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x / 1024.0 * w, y: y / 1024.0 * h)
        }

        // Left hemisphere gyri (extracted from SVG internal paths)

        // Gyrus 1 - upper left
        path.move(to: s(283.209, 150.263))
        path.addCurve(
            to: s(259.519, 208.3),
            control1: s(281.764, 186.479),
            control2: s(273.966, 206.601)
        )

        // Gyrus 2 - mid left
        path.move(to: s(228.756, 439.136))
        path.addCurve(
            to: s(307.84, 488.943),
            control1: s(282.79, 471.939),
            control2: s(293.754, 471.323)
        )

        // Gyrus 3 - lower left
        path.move(to: s(319.645, 350.756))
        path.addCurve(
            to: s(354.387, 458.536),
            control1: s(323.761, 416.317),
            control2: s(342.609, 436.189)
        )

        // Right hemisphere gyri

        // Gyrus 1 - upper right
        path.move(to: s(849.011, 398.061))
        path.addCurve(
            to: s(720.231, 503.264),
            control1: s(830.216, 466.132),
            control2: s(755.739, 483.695)
        )

        // Gyrus 2 - mid right
        path.move(to: s(831.679, 257.403))
        path.addCurve(
            to: s(858.07, 346.469),
            control1: s(858.593, 305.524),
            control2: s(870.998, 346.364)
        )

        // Gyrus 3 - temporal right
        path.move(to: s(664.03, 206.599))
        path.addCurve(
            to: s(719.103, 298.447),
            control1: s(729.386, 253.465),
            control2: s(721.91, 296.596)
        )

        return path
    }
}

// MARK: - Central Fissure (Longitudinal fissure - top-down view)

struct CentralFissure: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Longitudinal fissure dividing left and right hemispheres
        // Runs from frontal (top) to occipital (bottom) in top-down view
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.08))

        // Slight S-curve for realism
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.88),
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

// MARK: - Filament Path (Adapted to SVG brain shape - top-down view)

struct FilamentPath: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Center of brain (from SVG - approximately center of the shape)
        let center = CGPoint(x: w * 0.5, y: h * 0.45)

        // Filament endpoints matching the SVG brain contours (top-down view)
        // Coordinates normalized from SVG 1024x1024 viewBox
        let endpoints: [(x: CGFloat, y: CGFloat, ctrlX: CGFloat, ctrlY: CGFloat)] = [
            // Top (frontal) - both hemispheres
            (0.48, 0.08, 0.48, 0.25),   // 0 - top center-left
            (0.52, 0.08, 0.52, 0.25),   // 1 - top center-right

            // Upper right hemisphere
            (0.75, 0.12, 0.62, 0.28),   // 2 - upper right frontal
            (0.88, 0.25, 0.70, 0.35),   // 3 - right frontal
            (0.93, 0.45, 0.72, 0.45),   // 4 - right parietal

            // Lower right hemisphere
            (0.90, 0.60, 0.70, 0.55),   // 5 - right temporal
            (0.78, 0.82, 0.65, 0.65),   // 6 - right occipital

            // Bottom (occipital)
            (0.55, 0.88, 0.52, 0.68),   // 7 - bottom right
            (0.45, 0.88, 0.48, 0.68),   // 8 - bottom left

            // Lower left hemisphere
            (0.22, 0.82, 0.35, 0.65),   // 9 - left occipital
            (0.10, 0.60, 0.30, 0.55),   // 10 - left temporal

            // Upper left hemisphere
            (0.07, 0.45, 0.28, 0.45),   // 11 - left parietal
            (0.12, 0.25, 0.30, 0.35),   // 12 - left frontal
            (0.25, 0.12, 0.38, 0.28),   // 13 - upper left frontal
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
