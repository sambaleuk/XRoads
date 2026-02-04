//
//  MCPSettingsView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-021: MCP Configuration Settings View
//

import SwiftUI

// MARK: - MCPSettingsView

/// MCP configuration view with enable/disable toggles, credential storage, and auto-load rules
public struct MCPSettingsView: View {

    // MARK: - State

    @State private var settings = AppSettings.shared

    /// Validation results for each MCP
    @State private var validationResults: [String: MCPValidationResult] = [:]

    /// Loading states for test connection
    @State private var testingMCPs: Set<String> = []

    /// Currently editing MCP
    @State private var editingMCP: MCPConfiguration?

    /// Show add MCP sheet
    @State private var showAddMCP = false

    /// Show add auto-load rule sheet
    @State private var showAddAutoLoadRule = false

    /// MCP for adding auto-load rule
    @State private var selectedMCPForRule: MCPConfiguration?

    /// Credential being edited
    @State private var editingCredential: (mcpId: String, mcpName: String)?

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            // MCP List Section
            mcpListSection

            // Auto-Load Rules Section
            autoLoadRulesSection

            // Reset Section
            resetSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgSurface)
        .padding()
        .task {
            await validateAllMCPs()
        }
        .sheet(item: $editingMCP) { mcp in
            MCPEditSheet(mcp: mcp) { updatedMCP in
                settings.updateMCPConfiguration(updatedMCP)
            }
        }
        .sheet(isPresented: $showAddMCP) {
            MCPAddSheet { newMCP in
                settings.addMCPConfiguration(newMCP)
            }
        }
        .sheet(item: $selectedMCPForRule) { mcp in
            AutoLoadRuleSheet(mcpId: mcp.id, mcpName: mcp.name) { rule in
                settings.addAutoLoadRule(rule)
            }
        }
        .sheet(item: Binding(
            get: { editingCredential.map { CredentialEdit(mcpId: $0.mcpId, mcpName: $0.mcpName) } },
            set: { editingCredential = $0.map { ($0.mcpId, $0.mcpName) } }
        )) { edit in
            MCPCredentialSheet(mcpId: edit.mcpId, mcpName: edit.mcpName) { _ in
                // Credential saved via KeychainService
                Task {
                    await updateMCPHasCredentials(mcpId: edit.mcpId, hasCredentials: true)
                }
            }
        }
    }

    // MARK: - MCP List Section

    private var mcpListSection: some View {
        Section {
            ForEach(settings.mcpConfigurations) { mcp in
                MCPRowView(
                    mcp: mcp,
                    validation: validationResults[mcp.id],
                    isTesting: testingMCPs.contains(mcp.id),
                    onToggle: { settings.toggleMCPEnabled(id: mcp.id) },
                    onEdit: { editingMCP = mcp },
                    onTest: { testMCP(mcp) },
                    onManageCredential: { editingCredential = (mcp.id, mcp.name) },
                    onAddRule: { selectedMCPForRule = mcp },
                    onDelete: { settings.removeMCPConfiguration(id: mcp.id) }
                )
            }

            // Add MCP Button
            Button(action: { showAddMCP = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentPrimary)
                    Text("Add MCP Server")
                        .foregroundStyle(Color.accentPrimary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            HStack {
                Label("MCP Servers", systemImage: "server.rack")
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("\(settings.enabledMCPs.count) enabled")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        } footer: {
            Text("Model Context Protocol servers provide tools and capabilities to AI agents")
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Auto-Load Rules Section

    private var autoLoadRulesSection: some View {
        Section {
            if settings.mcpAutoLoadRules.isEmpty {
                Text("No auto-load rules configured")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                ForEach(settings.mcpAutoLoadRules) { rule in
                    AutoLoadRuleRow(
                        rule: rule,
                        mcpName: settings.mcpConfiguration(forId: rule.mcpId)?.name ?? "Unknown",
                        onToggle: { toggleAutoLoadRule(rule) },
                        onDelete: { settings.removeAutoLoadRule(id: rule.id) }
                    )
                }
            }
        } header: {
            Label("Auto-Load Rules", systemImage: "wand.and.stars")
                .foregroundStyle(Color.textPrimary)
        } footer: {
            Text("Automatically load MCPs based on project characteristics")
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                settings.resetMCPToDefaults()
                Task {
                    await validateAllMCPs()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset MCP Settings to Defaults")
                }
            }
            .foregroundStyle(Color.statusError)
        }
    }

    // MARK: - Actions

    private func validateAllMCPs() async {
        for mcp in settings.mcpConfigurations {
            let result = MCPPathValidator.validate(path: mcp.path)
            await MainActor.run {
                validationResults[mcp.id] = result
            }
        }
    }

    private func testMCP(_ mcp: MCPConfiguration) {
        testingMCPs.insert(mcp.id)

        Task {
            let result = await MCPPathValidator.testConnection(mcp: mcp)

            await MainActor.run {
                validationResults[mcp.id] = result
                testingMCPs.remove(mcp.id)
            }
        }
    }

    private func toggleAutoLoadRule(_ rule: MCPAutoLoadRule) {
        if let index = settings.mcpAutoLoadRules.firstIndex(where: { $0.id == rule.id }) {
            settings.mcpAutoLoadRules[index].isEnabled.toggle()
        }
    }

    private func updateMCPHasCredentials(mcpId: String, hasCredentials: Bool) async {
        if let index = settings.mcpConfigurations.firstIndex(where: { $0.id == mcpId }) {
            await MainActor.run {
                settings.mcpConfigurations[index].hasCredentials = hasCredentials
            }
        }
    }
}

// MARK: - CredentialEdit Helper

private struct CredentialEdit: Identifiable {
    let mcpId: String
    let mcpName: String
    var id: String { mcpId }
}

// MARK: - MCPRowView

/// Row view for a single MCP configuration
struct MCPRowView: View {
    let mcp: MCPConfiguration
    let validation: MCPValidationResult?
    let isTesting: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onTest: () -> Void
    let onManageCredential: () -> Void
    let onAddRule: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header row with toggle
            HStack {
                Toggle(isOn: Binding(get: { mcp.isEnabled }, set: { _ in onToggle() })) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(mcp.isEnabled ? Color.accentPrimary : Color.textTertiary)
                            .frame(width: 20)

                        Text(mcp.name)
                            .font(.body14)
                            .foregroundStyle(Color.textPrimary)

                        if mcp.hasCredentials {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.statusWarning)
                        }
                    }
                }
                .tint(Color.accentPrimary)

                Spacer()

                // Validation badge
                if let validation = validation {
                    MCPValidationBadge(validation: validation)
                }

                // Expand/collapse button
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Expanded details
            if isExpanded && mcp.isEnabled {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    // Path
                    HStack {
                        Text("Path:")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                        Text(mcp.path)
                            .font(.mono(11))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                    }

                    // Arguments
                    if !mcp.arguments.isEmpty {
                        HStack(alignment: .top) {
                            Text("Args:")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                            Text(mcp.arguments.joined(separator: " "))
                                .font(.mono(11))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(2)
                        }
                    }

                    // Action buttons
                    HStack(spacing: Theme.Spacing.md) {
                        Button(action: onTest) {
                            HStack(spacing: 4) {
                                if isTesting {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text("Test")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTesting)

                        Button(action: onManageCredential) {
                            HStack(spacing: 4) {
                                Image(systemName: "key")
                                Text(mcp.hasCredentials ? "Edit Credential" : "Add Credential")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: onAddRule) {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                Text("Auto-Load")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if mcp.id != "xroads-mcp" { // Prevent deleting built-in MCP
                            Button(role: .destructive, action: onDelete) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.leading, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - MCPValidationBadge

/// Badge showing MCP validation status
struct MCPValidationBadge: View {
    let validation: MCPValidationResult

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var statusColor: Color {
        if validation.connectionTestPassed {
            return .statusSuccess
        } else if validation.isValid {
            return .statusWarning
        } else {
            return .statusError
        }
    }

    private var statusText: String {
        if validation.connectionTestPassed {
            return "Connected"
        } else if validation.isValid {
            return "Available"
        } else {
            return validation.errorMessage ?? "Error"
        }
    }
}

// MARK: - AutoLoadRuleRow

/// Row view for an auto-load rule
struct AutoLoadRuleRow: View {
    let rule: MCPAutoLoadRule
    let mcpName: String
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(get: { rule.isEnabled }, set: { _ in onToggle() })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mcpName)
                        .font(.body14)
                        .foregroundStyle(Color.textPrimary)

                    Text(rule.condition.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .tint(Color.accentPrimary)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.statusError)
        }
    }
}

// MARK: - MCPPathValidator

/// Utility for validating MCP paths and testing connections
public enum MCPPathValidator {

    /// Validate that an MCP path exists
    public static func validate(path: String) -> MCPValidationResult {
        guard !path.isEmpty else {
            return .invalid(error: "Path is empty")
        }

        // Check if it's an npm package reference
        if path.starts(with: "@") {
            return .valid(version: nil, connectionTestPassed: false)
        }

        let fileManager = FileManager.default

        // Resolve relative paths
        var resolvedPath = path
        if !path.hasPrefix("/") {
            // Try relative to current directory
            let currentDir = FileManager.default.currentDirectoryPath
            resolvedPath = (currentDir as NSString).appendingPathComponent(path)
        }

        guard fileManager.fileExists(atPath: resolvedPath) else {
            return .invalid(error: "File not found")
        }

        return .valid(version: nil, connectionTestPassed: false)
    }

    /// Test MCP connection
    public static func testConnection(mcp: MCPConfiguration) async -> MCPValidationResult {
        // First validate the path
        let validation = validate(path: mcp.path)

        // For npm packages, we can't easily test without npm
        if mcp.path.starts(with: "@") {
            return validation
        }

        guard validation.isValid else {
            return validation
        }

        // Try to run the MCP with --version or --help
        var resolvedPath = mcp.path
        if !mcp.path.hasPrefix("/") {
            let currentDir = FileManager.default.currentDirectoryPath
            resolvedPath = (currentDir as NSString).appendingPathComponent(mcp.path)
        }

        // For Node.js scripts, we need to find node
        if resolvedPath.hasSuffix(".js") {
            // Find node path
            let nodePaths = [
                "/usr/local/bin/node",
                "/opt/homebrew/bin/node",
                NSHomeDirectory() + "/.nvm/versions/node/v20.0.0/bin/node"
            ]

            var nodePath: String?
            for path in nodePaths {
                if FileManager.default.isExecutableFile(atPath: path) {
                    nodePath = path
                    break
                }
            }

            guard let node = nodePath else {
                return MCPValidationResult(
                    isValid: true,
                    version: nil,
                    errorMessage: "Node.js not found",
                    connectionTestPassed: false
                )
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: node)
            process.arguments = [resolvedPath, "--help"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                // Give it a short timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode == 0 || exitCode == 143 { // 143 is SIGTERM
                    return .valid(version: nil, connectionTestPassed: true)
                }
            } catch {
                // Process launch failed but file exists
            }
        }

        return MCPValidationResult(
            isValid: true,
            version: nil,
            errorMessage: nil,
            connectionTestPassed: false
        )
    }
}

// MARK: - MCPEditSheet

/// Sheet for editing an MCP configuration
struct MCPEditSheet: View {
    let mcp: MCPConfiguration
    let onSave: (MCPConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var path: String
    @State private var arguments: String
    @State private var envVars: String

    init(mcp: MCPConfiguration, onSave: @escaping (MCPConfiguration) -> Void) {
        self.mcp = mcp
        self.onSave = onSave
        _name = State(initialValue: mcp.name)
        _path = State(initialValue: mcp.path)
        _arguments = State(initialValue: mcp.arguments.joined(separator: " "))
        _envVars = State(initialValue: mcp.environmentVariables.map { "\($0.key)=\($0.value)" }.joined(separator: "\n"))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Edit MCP Server")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Path", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))

                TextField("Arguments (space-separated)", text: $arguments)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))

                VStack(alignment: .leading) {
                    Text("Environment Variables (one per line, KEY=VALUE)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    TextEditor(text: $envVars)
                        .font(.mono(11))
                        .frame(height: 80)
                        .cornerRadius(Theme.Radius.sm)
                }
            }
            .formStyle(.grouped)

            HStack(spacing: Theme.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    let args = arguments.split(separator: " ").map { String($0) }
                    let vars = Dictionary(uniqueKeysWithValues:
                        envVars.split(separator: "\n")
                            .compactMap { line -> (String, String)? in
                                let parts = line.split(separator: "=", maxSplits: 1)
                                guard parts.count == 2 else { return nil }
                                return (String(parts[0]), String(parts[1]))
                            }
                    )

                    let updated = MCPConfiguration(
                        id: mcp.id,
                        name: name,
                        path: path,
                        arguments: args,
                        isEnabled: mcp.isEnabled,
                        hasCredentials: mcp.hasCredentials,
                        environmentVariables: vars
                    )
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || path.isEmpty)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 400, height: 400)
        .background(Color.bgSurface)
    }
}

// MARK: - MCPAddSheet

/// Sheet for adding a new MCP configuration
struct MCPAddSheet: View {
    let onAdd: (MCPConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var path = ""
    @State private var arguments = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Add MCP Server")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Path (executable or npm package)", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))

                TextField("Arguments (space-separated)", text: $arguments)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))
            }
            .formStyle(.grouped)

            // Preset MCPs
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Quick Add")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: Theme.Spacing.sm) {
                    Button("Filesystem") {
                        name = "Filesystem MCP"
                        path = "@modelcontextprotocol/server-filesystem"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Git") {
                        name = "Git MCP"
                        path = "@modelcontextprotocol/server-git"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Memory") {
                        name = "Memory MCP"
                        path = "@modelcontextprotocol/server-memory"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Add") {
                    let args = arguments.split(separator: " ").map { String($0) }
                    let newMCP = MCPConfiguration(
                        name: name,
                        path: path,
                        arguments: args,
                        isEnabled: true
                    )
                    onAdd(newMCP)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || path.isEmpty)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 400, height: 350)
        .background(Color.bgSurface)
    }
}

// MARK: - AutoLoadRuleSheet

/// Sheet for adding an auto-load rule
struct AutoLoadRuleSheet: View {
    let mcpId: String
    let mcpName: String
    let onAdd: (MCPAutoLoadRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCondition: AutoLoadCondition = .always

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Add Auto-Load Rule")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Text("Automatically load \(mcpName) when:")
                .font(.body14)
                .foregroundStyle(Color.textSecondary)

            Form {
                Picker("Condition", selection: $selectedCondition) {
                    ForEach(AutoLoadCondition.allCases.filter { $0 != .custom }, id: \.self) { condition in
                        VStack(alignment: .leading) {
                            Text(condition.displayName)
                            Text(condition.description)
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .tag(condition)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            .formStyle(.grouped)

            HStack(spacing: Theme.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Add Rule") {
                    let rule = MCPAutoLoadRule(
                        mcpId: mcpId,
                        condition: selectedCondition,
                        isEnabled: true
                    )
                    onAdd(rule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 400, height: 350)
        .background(Color.bgSurface)
    }
}

// MARK: - MCPCredentialSheet

/// Sheet for managing MCP credentials securely via Keychain
struct MCPCredentialSheet: View {
    let mcpId: String
    let mcpName: String
    let onSave: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var credential = ""
    @State private var hasExistingCredential = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.statusWarning)

                Text("MCP Credential")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(mcpName)
                    .font(.body14)
                    .foregroundStyle(Color.textSecondary)
            }

            // Info
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.statusSuccess)
                Text("Credentials are stored securely in macOS Keychain")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Color.bgElevated)
            .cornerRadius(Theme.Radius.sm)

            // Credential Input
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("API Key or Token")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                SecureField("Enter credential...", text: $credential)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))

                if hasExistingCredential {
                    Text("A credential already exists. Enter a new value to replace it.")
                        .font(.caption)
                        .foregroundStyle(Color.statusWarning)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.statusError)
            }

            Spacer()

            // Actions
            HStack(spacing: Theme.Spacing.md) {
                if hasExistingCredential {
                    Button(role: .destructive) {
                        deleteCredential()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveCredential()
                }
                .buttonStyle(.borderedProminent)
                .disabled(credential.isEmpty || isSaving)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 400, height: 350)
        .background(Color.bgSurface)
        .task {
            await checkExistingCredential()
        }
    }

    private func checkExistingCredential() async {
        hasExistingCredential = await KeychainService.shared.hasMCPCredential(mcpId: mcpId)
    }

    private func saveCredential() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await KeychainService.shared.saveMCPCredential(mcpId: mcpId, credential: credential)
                await MainActor.run {
                    onSave(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func deleteCredential() {
        Task {
            do {
                try await KeychainService.shared.deleteMCPCredential(mcpId: mcpId)
                await MainActor.run {
                    onSave(false)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MCPSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MCPSettingsView()
            .frame(width: 550, height: 700)
    }
}
#endif
