//
//  Theme.swift
//  CrossRoads
//
//  Created by Nexus on 2026-02-02.
//  Dark Pro theme system inspired by GitHub Dark / VS Code Pro
//

import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Initialize Color from hex string
    /// Supports formats: "#RRGGBB", "RRGGBB", "#RGB", "RGB"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RRGGBB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }

    // MARK: - Background Colors

    /// App background - deepest layer (#0d1117)
    static let bgApp = Color(hex: "#0d1117")

    /// Canvas background - for terminals and logs (#010409)
    static let bgCanvas = Color(hex: "#010409")

    /// Surface background - cards, panels, chat (#161b22)
    static let bgSurface = Color(hex: "#161b22")

    /// Elevated background - hover states, elevated UI (#1c2128)
    static let bgElevated = Color(hex: "#1c2128")

    // MARK: - Text Colors

    /// Primary text - titles, main content (#e6edf3)
    static let textPrimary = Color(hex: "#e6edf3")

    /// Secondary text - labels, metadata (#7d8590)
    static let textSecondary = Color(hex: "#7d8590")

    /// Tertiary text - placeholders, disabled (#484f58)
    static let textTertiary = Color(hex: "#484f58")

    /// Inverse text - on light backgrounds (#0d1117)
    static let textInverse = Color(hex: "#0d1117")

    // MARK: - Border Colors

    /// Default border - subtle borders (#30363d)
    static let borderDefault = Color(hex: "#30363d")

    /// Muted border - very discrete borders (#21262d)
    static let borderMuted = Color(hex: "#21262d")

    /// Accent border - active/focus states (#388bfd)
    static let borderAccent = Color(hex: "#388bfd")

    // MARK: - Accent Colors

    /// Primary accent - Claude AI blue (#388bfd)
    static let accentPrimary = Color(hex: "#388bfd")

    /// Primary accent hover (#4493ff)
    static let accentPrimaryHover = Color(hex: "#4493ff")

    // MARK: - Status Colors

    /// Success status - running, active (#3fb950)
    static let statusSuccess = Color(hex: "#3fb950")

    /// Warning status - pending, processing (#d29922)
    static let statusWarning = Color(hex: "#d29922")

    /// Error status - failed, stopped (#f85149)
    static let statusError = Color(hex: "#f85149")

    /// Info status - idle, informational (#79c0ff)
    static let statusInfo = Color(hex: "#79c0ff")

    // MARK: - Terminal Colors

    /// Terminal green - successful commands (#58a6ff)
    static let terminalGreen = Color(hex: "#58a6ff")

    /// Terminal cyan - info logs (#79c0ff)
    static let terminalCyan = Color(hex: "#79c0ff")

    /// Terminal yellow - warnings (#d29922)
    static let terminalYellow = Color(hex: "#d29922")

    /// Terminal red - errors (#ff7b72)
    static let terminalRed = Color(hex: "#ff7b72")

    // MARK: - Glow Colors (with opacity)

    /// Primary accent glow - 15% opacity
    static let accentPrimaryGlow = Color(hex: "#388bfd").opacity(0.15)

    /// Success glow - 15% opacity
    static let statusSuccessGlow = Color(hex: "#3fb950").opacity(0.15)

    /// Warning glow - 15% opacity
    static let statusWarningGlow = Color(hex: "#d29922").opacity(0.15)

    /// Error glow - 15% opacity
    static let statusErrorGlow = Color(hex: "#f85149").opacity(0.15)

    /// Info glow - 15% opacity
    static let statusInfoGlow = Color(hex: "#79c0ff").opacity(0.15)
}

// MARK: - Font Extensions

extension Font {
    // MARK: - Font Families

    /// Monospace font for code-related content
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// System font for UI labels
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: - Display Sizes

    /// Display text - 24px semibold mono
    static let display = Font.mono(24, weight: .semibold)

    /// Heading 1 - 20px semibold mono
    static let h1 = Font.mono(20, weight: .semibold)

    /// Heading 2 - 16px medium mono
    static let h2 = Font.mono(16, weight: .medium)

    // MARK: - Body Sizes

    /// Body text - 14px normal mono
    static let body14 = Font.mono(14, weight: .regular)

    /// Small text - 12px normal mono
    static let small = Font.mono(12, weight: .regular)

    /// Extra small text - 11px normal system
    static let xs = Font.ui(11, weight: .regular)

    // MARK: - Terminal Sizes

    /// Terminal text - 13px normal mono
    static let terminal = Font.mono(13, weight: .regular)

    /// Code text - 13px normal mono
    static let code = Font.mono(13, weight: .regular)
}

// MARK: - Theme Constants

enum Theme {
    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Border Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    // MARK: - Layout

    enum Layout {
        static let sidebarWidth: CGFloat = 240
        static let inspectorWidth: CGFloat = 320
        static let minWindowWidth: CGFloat = 1280
        static let minWindowHeight: CGFloat = 800
        static let defaultWindowWidth: CGFloat = 1440
        static let defaultWindowHeight: CGFloat = 900
        static let chatMaxWidth: CGFloat = 800
        static let processLogsHeight: CGFloat = 200
    }

    // MARK: - Animation

    enum Animation {
        static let fast: Double = 0.1
        static let normal: Double = 0.15
        static let slow: Double = 0.2
        static let modal: Double = 0.25
        static let pulse: Double = 2.0
    }

    // MARK: - Component Sizes

    enum Component {
        static let headerHeight: CGFloat = 48
        static let inputBarHeight: CGFloat = 56
        static let logHeaderHeight: CGFloat = 36
        static let buttonHeight: CGFloat = 36
        static let statusBadgeHeight: CGFloat = 20
        static let statusDotSize: CGFloat = 8
        static let sessionCardMinHeight: CGFloat = 96
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply Dark Pro background
    func darkProBackground(_ color: Color = .bgApp) -> some View {
        self.background(color)
    }

    /// Apply card styling
    func cardStyle() -> some View {
        self
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
    }

    /// Apply elevated card styling (with shadow)
    func elevatedCardStyle() -> some View {
        self
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
    }

    /// Apply terminal panel styling
    func terminalStyle() -> some View {
        self
            .background(Color.bgCanvas)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Color.borderMuted, lineWidth: 1)
            )
    }
}

// MARK: - Preview Provider

#if DEBUG
struct Theme_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Background colors
            HStack(spacing: Theme.Spacing.sm) {
                colorSwatch(.bgApp, label: "bgApp")
                colorSwatch(.bgCanvas, label: "bgCanvas")
                colorSwatch(.bgSurface, label: "bgSurface")
                colorSwatch(.bgElevated, label: "bgElevated")
            }

            // Text colors
            HStack(spacing: Theme.Spacing.sm) {
                Text("Primary")
                    .font(.body14)
                    .foregroundStyle(Color.textPrimary)
                Text("Secondary")
                    .font(.body14)
                    .foregroundStyle(Color.textSecondary)
                Text("Tertiary")
                    .font(.body14)
                    .foregroundStyle(Color.textTertiary)
            }

            // Status colors
            HStack(spacing: Theme.Spacing.sm) {
                colorSwatch(.statusSuccess, label: "Success")
                colorSwatch(.statusWarning, label: "Warning")
                colorSwatch(.statusError, label: "Error")
                colorSwatch(.statusInfo, label: "Info")
            }

            // Typography
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Display Text").font(.display)
                Text("Heading 1").font(.h1)
                Text("Heading 2").font(.h2)
                Text("Body Text").font(.body14)
                Text("Small Text").font(.small)
                Text("Terminal Text").font(.terminal)
            }
            .foregroundStyle(Color.textPrimary)
        }
        .padding(Theme.Spacing.lg)
        .darkProBackground()
    }

    static func colorSwatch(_ color: Color, label: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            Text(label)
                .font(.xs)
                .foregroundStyle(Color.textTertiary)
        }
    }
}
#endif
