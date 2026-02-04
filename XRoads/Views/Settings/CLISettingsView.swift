//
//  CLISettingsView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-020: CLI Configuration Settings View
//

import SwiftUI

// MARK: - CLISettingsView

/// Complete CLI configuration view with path pickers, default arguments,
/// preference order, validation, and test connection
public struct CLISettingsView: View {

    // MARK: - State

    @State private var settings = AppSettings.shared

    /// Validation results for each CLI
    @State private var claudeValidation: CLIValidationResult?
    @State private var geminiValidation: CLIValidationResult?
    @State private var codexValidation: CLIValidationResult?

    /// Loading states for test connection
    @State private var isTestingClaude = false
    @State private var isTestingGemini = false
    @State private var isTestingCodex = false

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            // Preference Order Section
            preferenceOrderSection

            // Claude CLI Section
            cliSection(
                name: "Claude Code",
                icon: "brain.head.profile",
                iconColor: Color.accentPrimary,
                agentType: .claude,
                path: $settings.claudeCliPath,
                args: $settings.claudeDefaultArgs,
                isEnabled: $settings.claudeEnabled,
                validation: claudeValidation,
                isTesting: isTestingClaude,
                onTest: { testCLI(.claude) }
            )

            // Gemini CLI Section
            cliSection(
                name: "Gemini CLI",
                icon: "sparkles",
                iconColor: Color.statusWarning,
                agentType: .gemini,
                path: $settings.geminiCliPath,
                args: $settings.geminiDefaultArgs,
                isEnabled: $settings.geminiEnabled,
                validation: geminiValidation,
                isTesting: isTestingGemini,
                onTest: { testCLI(.gemini) }
            )

            // Codex CLI Section
            cliSection(
                name: "Codex",
                icon: "terminal",
                iconColor: Color.statusSuccess,
                agentType: .codex,
                path: $settings.codexCliPath,
                args: $settings.codexDefaultArgs,
                isEnabled: $settings.codexEnabled,
                validation: codexValidation,
                isTesting: isTestingCodex,
                onTest: { testCLI(.codex) }
            )

            // Reset Section
            resetSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgSurface)
        .padding()
        .task {
            // Validate all paths on appear
            await validateAllPaths()
        }
    }

    // MARK: - Preference Order Section

    private var preferenceOrderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("When auto-detecting, CLIs are tried in this order:")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(settings.cliPreferenceOrder.enumerated()), id: \.element) { index, agentType in
                        PreferenceOrderBadge(
                            agentType: agentType,
                            position: index + 1,
                            canMoveUp: index > 0,
                            canMoveDown: index < settings.cliPreferenceOrder.count - 1,
                            onMoveUp: { movePreference(at: index, direction: -1) },
                            onMoveDown: { movePreference(at: index, direction: 1) }
                        )
                    }
                }
            }
        } header: {
            Label("Auto-Detection Preference", systemImage: "arrow.up.arrow.down")
                .foregroundStyle(Color.textPrimary)
        } footer: {
            Text("First enabled and available CLI wins")
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - CLI Section

    @ViewBuilder
    private func cliSection(
        name: String,
        icon: String,
        iconColor: Color,
        agentType: AgentType,
        path: Binding<String>,
        args: Binding<[String]>,
        isEnabled: Binding<Bool>,
        validation: CLIValidationResult?,
        isTesting: Bool,
        onTest: @escaping () -> Void
    ) -> some View {
        Section {
            // Enable/Disable Toggle
            Toggle(isOn: isEnabled) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 24)

                    Text(name)
                        .font(.body14)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .tint(iconColor)

            if isEnabled.wrappedValue {
                // Path Row
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Executable Path")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    HStack {
                        TextField("Path", text: path)
                            .textFieldStyle(DarkProTextFieldStyle())
                            .font(.mono(12))
                            .onChange(of: path.wrappedValue) { _, _ in
                                validatePath(agentType)
                            }

                        Button("Browse...") {
                            browseForExecutable(name: name, currentPath: path.wrappedValue) { newPath in
                                path.wrappedValue = newPath
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Validation Status
                if let validation = validation {
                    CLIValidationStatusView(validation: validation)
                }

                // Default Arguments
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Default Arguments")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    CLIArgumentsEditor(arguments: args)
                }

                // Test Connection Button
                HStack {
                    Button(action: onTest) {
                        HStack(spacing: Theme.Spacing.xs) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text("Test Connection")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting || !(validation?.isValid ?? false))

                    Spacer()

                    if let validation = validation, validation.connectionTestPassed {
                        Label("Connection OK", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.statusSuccess)
                    }
                }
            }
        } header: {
            HStack {
                Label(name, systemImage: icon)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if isEnabled.wrappedValue {
                    ValidationBadge(validation: validation)
                }
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                settings.resetAllCLIToDefaults()
                Task {
                    await validateAllPaths()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All CLI Settings to Defaults")
                }
            }
            .foregroundStyle(Color.statusError)
        }
    }

    // MARK: - Actions

    private func movePreference(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0, newIndex < settings.cliPreferenceOrder.count else { return }

        var order = settings.cliPreferenceOrder
        order.swapAt(index, newIndex)
        settings.cliPreferenceOrder = order
    }

    private func browseForExecutable(name: String, currentPath: String, onSelect: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select \(name) executable"
        panel.prompt = "Select"

        if !currentPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        }

        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url.path)
        }
    }

    private func validatePath(_ agentType: AgentType) {
        let path = settings.cliPath(for: agentType)
        let result = CLIPathValidator.validate(path: path)

        switch agentType {
        case .claude: claudeValidation = result
        case .gemini: geminiValidation = result
        case .codex: codexValidation = result
        }
    }

    private func validateAllPaths() async {
        claudeValidation = CLIPathValidator.validate(path: settings.claudeCliPath)
        geminiValidation = CLIPathValidator.validate(path: settings.geminiCliPath)
        codexValidation = CLIPathValidator.validate(path: settings.codexCliPath)
    }

    private func testCLI(_ agentType: AgentType) {
        switch agentType {
        case .claude: isTestingClaude = true
        case .gemini: isTestingGemini = true
        case .codex: isTestingCodex = true
        }

        Task {
            let result = await CLIPathValidator.testConnection(
                path: settings.cliPath(for: agentType),
                agentType: agentType
            )

            await MainActor.run {
                switch agentType {
                case .claude:
                    claudeValidation = result
                    isTestingClaude = false
                case .gemini:
                    geminiValidation = result
                    isTestingGemini = false
                case .codex:
                    codexValidation = result
                    isTestingCodex = false
                }
            }
        }
    }
}

// MARK: - CLIPathValidator

/// Utility for validating CLI paths and testing connections
public enum CLIPathValidator {

    /// Validate that a path exists and is executable
    public static func validate(path: String) -> CLIValidationResult {
        guard !path.isEmpty else {
            return .invalid(error: "Path is empty")
        }

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            return .invalid(error: "File not found")
        }

        guard fileManager.isExecutableFile(atPath: path) else {
            return .invalid(error: "Not executable")
        }

        // Try to get version
        let version = getVersion(path: path)

        return .valid(version: version, connectionTestPassed: false)
    }

    /// Get version string from CLI
    private static func getVersion(path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract version from output (first line, first token that looks like a version)
            if let firstLine = output?.split(separator: "\n").first {
                return String(firstLine)
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Test connection by running a simple command
    static func testConnection(path: String, agentType: AgentType) async -> CLIValidationResult {
        // First validate the path
        let validation = validate(path: path)
        guard validation.isValid else {
            return validation
        }

        // Run a simple test command
        let testArgs: [String]
        switch agentType {
        case .claude:
            testArgs = ["--help"]
        case .gemini:
            testArgs = ["--help"]
        case .codex:
            testArgs = ["--help"]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = testArgs

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            if exitCode == 0 {
                return .valid(version: validation.version, connectionTestPassed: true)
            } else {
                return CLIValidationResult(
                    isValid: true,
                    version: validation.version,
                    errorMessage: "Exit code: \(exitCode)",
                    connectionTestPassed: false
                )
            }
        } catch {
            return CLIValidationResult(
                isValid: true,
                version: validation.version,
                errorMessage: error.localizedDescription,
                connectionTestPassed: false
            )
        }
    }
}

// MARK: - PreferenceOrderBadge

/// Badge showing CLI in preference order with reorder buttons
struct PreferenceOrderBadge: View {
    let agentType: AgentType
    let position: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            // Position number
            Text("\(position)")
                .font(.caption2.bold())
                .foregroundStyle(Color.textTertiary)
                .frame(width: 12)

            // Agent icon
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)

            Text(agentType.displayName)
                .font(.caption)
                .foregroundStyle(Color.textPrimary)

            // Reorder buttons
            VStack(spacing: 0) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .opacity(canMoveUp ? 1 : 0.3)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .opacity(canMoveDown ? 1 : 0.3)
            }
            .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.bgElevated)
        .cornerRadius(Theme.Radius.sm)
    }

    private var iconName: String {
        switch agentType {
        case .claude: return "brain.head.profile"
        case .gemini: return "sparkles"
        case .codex: return "terminal"
        }
    }

    private var iconColor: Color {
        switch agentType {
        case .claude: return .accentPrimary
        case .gemini: return .statusWarning
        case .codex: return .statusSuccess
        }
    }
}

// MARK: - ValidationBadge

/// Small badge showing validation status
struct ValidationBadge: View {
    let validation: CLIValidationResult?

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var statusColor: Color {
        guard let validation = validation else {
            return .statusWarning
        }
        return validation.isValid ? .statusSuccess : .statusError
    }

    private var statusText: String {
        guard let validation = validation else {
            return "Checking..."
        }
        return validation.isValid ? "Available" : "Not found"
    }
}

// MARK: - CLIValidationStatusView

/// Detailed validation status display
struct CLIValidationStatusView: View {
    let validation: CLIValidationResult

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: validation.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(validation.isValid ? Color.statusSuccess : Color.statusError)

            VStack(alignment: .leading, spacing: 2) {
                if validation.isValid {
                    if let version = validation.version {
                        Text(version)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Executable found")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                } else if let error = validation.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.statusError)
                }
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - CLIArgumentsEditor

/// Editor for CLI default arguments
struct CLIArgumentsEditor: View {
    @Binding var arguments: [String]
    @State private var newArgument = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Current arguments
            FlowLayout(spacing: Theme.Spacing.xs) {
                ForEach(Array(arguments.enumerated()), id: \.offset) { index, arg in
                    ArgumentTag(argument: arg) {
                        arguments.remove(at: index)
                    }
                }
            }

            // Add new argument
            HStack {
                TextField("Add argument...", text: $newArgument)
                    .textFieldStyle(DarkProTextFieldStyle())
                    .font(.mono(11))
                    .onSubmit {
                        addArgument()
                    }

                Button(action: addArgument) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentPrimary)
                .disabled(newArgument.isEmpty)
            }
        }
    }

    private func addArgument() {
        let trimmed = newArgument.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        arguments.append(trimmed)
        newArgument = ""
    }
}

// MARK: - ArgumentTag

/// Tag displaying a single argument with remove button
struct ArgumentTag: View {
    let argument: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(argument)
                .font(.mono(11))
                .foregroundStyle(Color.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(Color.bgElevated)
        .cornerRadius(Theme.Radius.sm)
    }
}

// Note: FlowLayout and DarkProTextFieldStyle are defined in other files
// - FlowLayout: Views/Orchestrator/ChatMessageView.swift
// - DarkProTextFieldStyle: Views/WorktreeCreateSheet.swift

// MARK: - Preview

#if DEBUG
struct CLISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CLISettingsView()
            .frame(width: 550, height: 700)
    }
}
#endif
