//
//  WorktreeCreateSheet.swift
//  CrossRoads
//
//  Created by Nexus on 2026-02-02.
//  Sheet modal for creating a new git worktree with agent selection.
//

import SwiftUI

// MARK: - WorktreeCreateSheet

/// Modal sheet for creating a new worktree with validation
struct WorktreeCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState

    // MARK: - Form State

    /// Name for the worktree
    @State private var name: String = ""

    /// Path to the git repository
    @State private var repoPath: String = ""

    /// Selected agent type
    @State private var agentType: AgentType = .claude

    /// Branch name (auto-generated from name)
    @State private var branchName: String = ""

    /// Custom branch name enabled
    @State private var useCustomBranch: Bool = false

    // MARK: - UI State

    /// Loading state during creation
    @State private var isCreating: Bool = false

    /// Error message to display
    @State private var errorMessage: String?

    /// Available agent types (checked on appear)
    @State private var availableAgents: [AgentType] = AgentType.allCases

    /// Config checker for validation
    private let configChecker = ConfigChecker()

    // MARK: - Validation

    /// Whether the form is valid for submission
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !repoPath.trimmingCharacters(in: .whitespaces).isEmpty &&
        repoPathExists &&
        !effectiveBranchName.isEmpty
    }

    /// Check if repo path exists
    private var repoPathExists: Bool {
        guard !repoPath.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: repoPath, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    /// The branch name to use (auto or custom)
    private var effectiveBranchName: String {
        if useCustomBranch && !branchName.trimmingCharacters(in: .whitespaces).isEmpty {
            return branchName.trimmingCharacters(in: .whitespaces)
        }
        return generateBranchName(from: name)
    }

    /// Generates a branch name from the worktree name
    private func generateBranchName(from name: String) -> String {
        let sanitized = name
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()

        guard !sanitized.isEmpty else { return "" }
        return "worktree/\(sanitized)"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()
                .background(Color.borderMuted)

            // Form
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    nameSection
                    repoPathSection
                    agentSection
                    branchSection
                }
                .padding(Theme.Spacing.lg)
            }

            Divider()
                .background(Color.borderMuted)

            // Footer with buttons
            sheetFooter
        }
        .frame(width: 480, height: 520)
        .background(Color.bgSurface)
        .preferredColorScheme(.dark)
        .task {
            await checkAvailableAgents()
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("New Worktree")
                    .font(.h1)
                    .foregroundStyle(Color.textPrimary)

                Text("Create an isolated git worktree with an AI agent")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Worktree Name")
                .font(.body14)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)

            TextField("e.g., feature-auth", text: $name)
                .textFieldStyle(DarkProTextFieldStyle())
                .onChange(of: name) { _, _ in
                    // Auto-update branch name when not using custom
                    if !useCustomBranch {
                        branchName = effectiveBranchName
                    }
                }

            Text("A descriptive name for this worktree")
                .font(.small)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Repo Path Section

    private var repoPathSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Repository Path")
                .font(.body14)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Select a git repository...", text: $repoPath)
                    .textFieldStyle(DarkProTextFieldStyle())

                Button("Browse") {
                    browseForRepository()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: Theme.Spacing.xs) {
                if !repoPath.isEmpty {
                    if repoPathExists {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.statusSuccess)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.statusError)
                    }
                }

                Text(repoPath.isEmpty ? "Path to the main git repository" :
                     (repoPathExists ? "Valid repository path" : "Path does not exist"))
                    .font(.small)
                    .foregroundStyle(repoPath.isEmpty || repoPathExists ? Color.textTertiary : Color.statusError)
            }
        }
    }

    // MARK: - Agent Section

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Agent Type")
                .font(.body14)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)

            Picker("Agent", selection: $agentType) {
                ForEach(AgentType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.iconName)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: Theme.Spacing.xs) {
                if availableAgents.contains(agentType) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.statusSuccess)
                    Text("\(agentType.displayName) is available")
                        .font(.small)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.statusWarning)
                    Text("\(agentType.displayName) not found - install it first")
                        .font(.small)
                        .foregroundStyle(Color.statusWarning)
                }
            }
        }
    }

    // MARK: - Branch Section

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Branch Name")
                    .font(.body14)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Toggle("Custom", isOn: $useCustomBranch)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.8)

                Text("Custom")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
            }

            if useCustomBranch {
                TextField("e.g., feature/my-branch", text: $branchName)
                    .textFieldStyle(DarkProTextFieldStyle())
            } else {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(Color.textTertiary)
                    Text(effectiveBranchName.isEmpty ? "Enter a name above" : effectiveBranchName)
                        .font(.code)
                        .foregroundStyle(effectiveBranchName.isEmpty ? Color.textTertiary : Color.textSecondary)
                }
                .padding(Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }

            Text("Branch will be created in the new worktree")
                .font(.small)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            // Error message
            if let error = errorMessage {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.statusError)
                    Text(error)
                        .font(.small)
                        .foregroundStyle(Color.statusError)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Cancel button
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            // Create button
            Button {
                Task {
                    await createWorktree()
                }
            } label: {
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 60)
                } else {
                    Text("Create")
                        .frame(width: 60)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
            .disabled(!isValid || isCreating)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Actions

    /// Opens NSOpenPanel to select a git repository
    private func browseForRepository() {
        let panel = NSOpenPanel()
        panel.title = "Select Git Repository"
        panel.message = "Choose the root folder of a git repository"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        // Set initial directory
        if !repoPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: repoPath)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
        }
    }

    /// Checks which agent CLIs are available
    private func checkAvailableAgents() async {
        let status = await configChecker.checkAll()
        await MainActor.run {
            availableAgents = status.availableAgentTypes
            // Default to first available agent if current selection is unavailable
            if !availableAgents.contains(agentType), let first = availableAgents.first {
                agentType = first
            }
        }
    }

    /// Creates the worktree using SessionViewModel
    private func createWorktree() async {
        guard isValid else { return }

        isCreating = true
        errorMessage = nil

        // Create a SessionViewModel to handle the creation
        let viewModel = SessionViewModel(services: appState.services)

        await viewModel.createWorktree(
            name: name.trimmingCharacters(in: .whitespaces),
            repoPath: repoPath.trimmingCharacters(in: .whitespaces),
            agentType: agentType
        )

        // Check for errors
        if let error = viewModel.error {
            errorMessage = error.localizedDescription
            isCreating = false
            return
        }

        // Transfer the created worktree and agent to AppState
        if let newWorktree = viewModel.worktrees.last {
            appState.addWorktree(newWorktree)

            // Transfer agent
            for (path, agent) in viewModel.agents {
                if path == newWorktree.path {
                    appState.setAgent(agent)
                }
            }

            // Select the new worktree
            appState.selectWorktree(newWorktree)
        }

        isCreating = false
        dismiss()
    }
}

// MARK: - DarkProTextFieldStyle

/// Custom text field style matching Dark Pro theme
struct DarkProTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(Theme.Spacing.sm)
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Color.borderMuted, lineWidth: 1)
            )
            .font(.body14)
    }
}

// MARK: - Preview

#if DEBUG
struct WorktreeCreateSheet_Previews: PreviewProvider {
    static var previews: some View {
        WorktreeCreateSheet()
            .environment(\.appState, AppState(services: MockServiceContainer()))
    }
}
#endif
