//
//  StartSessionSheet.swift
//  XRoads
//
//  Simplified session start flow - replaces WorktreeCreateSheet
//  Single Agent: Works in main directory with branch
//  Multi Agent: Creates worktrees automatically
//

import SwiftUI

// MARK: - SessionMode

enum SessionMode: String, CaseIterable {
    case single = "single"
    case multi = "multi"

    var displayName: String {
        switch self {
        case .single: return "Single Agent"
        case .multi: return "Multi-Agent (Parallel)"
        }
    }

    var description: String {
        switch self {
        case .single: return "One agent works in the main directory"
        case .multi: return "Multiple agents work in parallel worktrees"
        }
    }

    var iconName: String {
        switch self {
        case .single: return "person.fill"
        case .multi: return "person.3.fill"
        }
    }
}

// MARK: - StartSessionSheet

struct StartSessionSheet: View {
    @Environment(\.dismiss) private var envDismiss
    @Environment(\.appState) private var appState

    var onDismiss: (() -> Void)? = nil

    private func dismiss() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            envDismiss()
        }
    }

    // MARK: - Form State

    @State private var projectPath: String = ""
    @State private var featureName: String = ""
    @State private var sessionMode: SessionMode = .single
    @State private var selectedAgents: Set<AgentType> = [.claude]

    // MARK: - UI State

    @State private var isStarting: Bool = false
    @State private var errorMessage: String?
    @State private var availableAgents: [AgentType] = AgentType.allCases
    @State private var gitInfo: GitRepoInfo?

    private let configChecker = ConfigChecker()

    // MARK: - Computed

    private var isValid: Bool {
        !projectPath.isEmpty &&
        isValidGitRepo &&
        !featureName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedAgents.isEmpty
    }

    private var isValidGitRepo: Bool {
        guard !projectPath.isEmpty else { return false }
        let gitPath = (projectPath as NSString).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath)
    }

    private var branchName: String {
        let sanitized = featureName
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        return sanitized.isEmpty ? "" : "feat/\(sanitized)"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider().background(Color.borderMuted)

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    projectSection
                    featureSection
                    modeSection
                    agentSection
                    summarySection
                }
                .padding(Theme.Spacing.lg)
            }

            Divider().background(Color.borderMuted)
            sheetFooter
        }
        .frame(width: 520, height: 600)
        .background(Color.bgSurface)
        .preferredColorScheme(.dark)
        .onAppear {
            activateWindow()
            // Pre-fill with current directory if it's a git repo
            let cwd = FileManager.default.currentDirectoryPath
            if FileManager.default.fileExists(atPath: (cwd as NSString).appendingPathComponent(".git")) {
                projectPath = cwd
                loadGitInfo()
            }
        }
        .task {
            await checkAvailableAgents()
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Start Session")
                    .font(.h1)
                    .foregroundStyle(Color.textPrimary)

                Text("Configure and launch an AI development session")
                    .font(.small)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Project Section

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("1", "Project")

            HStack(spacing: Theme.Spacing.sm) {
                MacTextField(
                    placeholder: "Select a git repository...",
                    text: $projectPath
                )
                .frame(height: 24)
                .onChange(of: projectPath) { _, _ in
                    loadGitInfo()
                }

                Button("Browse") {
                    browseForRepository()
                }
                .buttonStyle(.bordered)
            }

            // Git info display
            if let info = gitInfo {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.statusSuccess)

                    Text("Git repo")
                        .foregroundStyle(Color.textSecondary)

                    Text("•")
                        .foregroundStyle(Color.textTertiary)

                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(Color.textTertiary)
                    Text(info.currentBranch)
                        .foregroundStyle(Color.accentPrimary)

                    if info.uncommittedChanges > 0 {
                        Text("•")
                            .foregroundStyle(Color.textTertiary)
                        Text("\(info.uncommittedChanges) changes")
                            .foregroundStyle(Color.statusWarning)
                    }
                }
                .font(.small)
            } else if !projectPath.isEmpty && !isValidGitRepo {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.statusError)
                    Text("Not a git repository")
                        .foregroundStyle(Color.statusError)
                }
                .font(.small)
            }
        }
    }

    // MARK: - Feature Section

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("2", "Feature")

            MacTextField(
                placeholder: "e.g., user-authentication, dark-mode, api-refactor",
                text: $featureName,
                isFirstResponder: projectPath.isEmpty ? false : true
            )
            .frame(height: 24)

            if !branchName.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(Color.textTertiary)
                    Text("Branch:")
                        .foregroundStyle(Color.textTertiary)
                    Text(branchName)
                        .foregroundStyle(Color.accentPrimary)
                        .font(.system(.body, design: .monospaced))
                }
                .font(.small)
            }
        }
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("3", "Mode")

            HStack(spacing: Theme.Spacing.md) {
                ForEach(SessionMode.allCases, id: \.self) { mode in
                    modeCard(mode)
                }
            }
        }
    }

    private func modeCard(_ mode: SessionMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                sessionMode = mode
                // Reset agent selection based on mode
                if mode == .single {
                    selectedAgents = [selectedAgents.first ?? .claude]
                }
            }
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(sessionMode == mode ? Color.accentPrimary : Color.textTertiary)

                Text(mode.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(sessionMode == mode ? Color.textPrimary : Color.textSecondary)

                Text(mode.description)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(sessionMode == mode ? Color.accentPrimary.opacity(0.15) : Color.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(sessionMode == mode ? Color.accentPrimary : Color.borderMuted, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Agent Section

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("4", sessionMode == .single ? "Agent" : "Agents")

            HStack(spacing: Theme.Spacing.md) {
                ForEach(AgentType.allCases, id: \.self) { agent in
                    agentCard(agent)
                }
            }

            // Warning if agent not available
            let unavailable = selectedAgents.filter { !availableAgents.contains($0) }
            if !unavailable.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.statusWarning)
                    Text("\(unavailable.map(\.displayName).joined(separator: ", ")) not installed")
                        .foregroundStyle(Color.statusWarning)
                }
                .font(.small)
            }
        }
    }

    private func agentCard(_ agent: AgentType) -> some View {
        let isSelected = selectedAgents.contains(agent)
        let isAvailable = availableAgents.contains(agent)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if sessionMode == .single {
                    // Single mode: only one agent
                    selectedAgents = [agent]
                } else {
                    // Multi mode: toggle selection
                    if isSelected {
                        selectedAgents.remove(agent)
                    } else {
                        selectedAgents.insert(agent)
                    }
                }
            }
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? agent.color.opacity(0.2) : Color.bgElevated)
                        .frame(width: 48, height: 48)

                    Image(systemName: agent.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? agent.color : Color.textTertiary)

                    // Checkmark for multi-select
                    if sessionMode == .multi && isSelected {
                        Circle()
                            .fill(Color.statusSuccess)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 16, y: -16)
                    }
                }

                Text(agent.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)

                // Availability indicator
                HStack(spacing: 2) {
                    Circle()
                        .fill(isAvailable ? Color.statusSuccess : Color.statusError)
                        .frame(width: 6, height: 6)
                    Text(isAvailable ? "Ready" : "Missing")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.sm)
            .background(isSelected ? agent.color.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(isSelected ? agent.color : Color.borderMuted, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .opacity(isAvailable ? 1 : 0.6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Divider().background(Color.borderMuted)

            HStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    if sessionMode == .single {
                        Text("Single Agent Mode")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("Agent will work in the main project directory on branch \(branchName.isEmpty ? "feat/<name>" : branchName)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Multi-Agent Mode")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(selectedAgents.count) agents will work in parallel worktrees, each on their own branch")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Color.accentPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
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

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])

            Button {
                Task { await startSession() }
            } label: {
                if isStarting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 100)
                } else {
                    Text("Start Session")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
            .disabled(!isValid || isStarting)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Helpers

    private func sectionHeader(_ number: String, _ title: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 20, height: 20)
                .background(Color.accentPrimary.opacity(0.2))
                .clipShape(Circle())

            Text(title)
                .font(.body14)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func activateWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                window.makeKey()
            }
        }
    }

    private func browseForRepository() {
        let panel = NSOpenPanel()
        panel.title = "Select Project"
        panel.message = "Choose the root folder of a git repository"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if !projectPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: projectPath)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        if panel.runModal() == .OK, let url = panel.url {
            projectPath = url.path
        }
    }

    private func loadGitInfo() {
        guard isValidGitRepo else {
            gitInfo = nil
            return
        }

        Task {
            let info = await getGitRepoInfo(path: projectPath)
            await MainActor.run {
                gitInfo = info
            }
        }
    }

    private func getGitRepoInfo(path: String) async -> GitRepoInfo? {
        // Get current branch
        let branchResult = try? await runGitCommand(["branch", "--show-current"], in: path)
        let branch = branchResult?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        // Get uncommitted changes count
        let statusResult = try? await runGitCommand(["status", "--porcelain"], in: path)
        let changes = statusResult?.components(separatedBy: .newlines).filter { !$0.isEmpty }.count ?? 0

        return GitRepoInfo(currentBranch: branch, uncommittedChanges: changes)
    }

    private func runGitCommand(_ args: [String], in path: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func checkAvailableAgents() async {
        let status = await configChecker.checkAll()
        await MainActor.run {
            availableAgents = status.availableAgentTypes
        }
    }

    // MARK: - Start Session

    private func startSession() async {
        guard isValid else { return }

        isStarting = true
        errorMessage = nil

        do {
            if sessionMode == .single {
                try await startSingleAgentSession()
            } else {
                try await startMultiAgentSession()
            }
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isStarting = false
            }
        }
    }

    private func startSingleAgentSession() async throws {
        guard let agent = selectedAgents.first else { return }

        // 1. Create/checkout branch
        let branchExists = try await checkBranchExists(branchName, in: projectPath)
        if branchExists {
            _ = try await runGitCommand(["checkout", branchName], in: projectPath)
        } else {
            _ = try await runGitCommand(["checkout", "-b", branchName], in: projectPath)
        }

        // 2. Run nexus-init if prd.json doesn't exist
        let prdPath = (projectPath as NSString).appendingPathComponent("prd.json")
        if !FileManager.default.fileExists(atPath: prdPath) {
            try await runNexusInit(featureName: featureName, in: projectPath)
        }

        // 3. Create session in AppState
        let worktree = Worktree(
            path: projectPath,
            branch: branchName
        )

        let agentModel = Agent(
            type: agent,
            status: .idle,
            worktreePath: projectPath
        )

        await MainActor.run {
            appState.addWorktree(worktree)
            appState.selectWorktree(worktree)
            appState.setAgent(agentModel)
        }

        // 4. Optionally start the loop (or let user do it manually)
        // For now, we just set up - user can click "Start" in the UI
    }

    private func startMultiAgentSession() async throws {
        // Multi-agent mode: create worktrees for each agent
        let baseWorktreePath = (projectPath as NSString).deletingLastPathComponent

        for agent in selectedAgents {
            let worktreeName = "\(featureName)-\(agent.rawValue)"
            let worktreePath = (baseWorktreePath as NSString).appendingPathComponent(worktreeName)
            let agentBranch = "feat/\(featureName)-\(agent.rawValue)"

            // Create worktree
            _ = try await runGitCommand(
                ["worktree", "add", "-b", agentBranch, worktreePath],
                in: projectPath
            )

            // Run nexus-init in worktree
            try await runNexusInit(featureName: featureName, in: worktreePath)

            // Add to AppState
            let worktree = Worktree(
                path: worktreePath,
                branch: agentBranch
            )

            let agentModel = Agent(
                type: agent,
                status: .idle,
                worktreePath: worktreePath
            )

            await MainActor.run {
                appState.addWorktree(worktree)
                appState.setAgent(agentModel)
            }
        }

        // Select the first worktree
        if let first = appState.worktrees.first {
            await MainActor.run {
                appState.selectWorktree(first)
            }
        }
    }

    private func checkBranchExists(_ branch: String, in path: String) async throws -> Bool {
        let result = try await runGitCommand(["branch", "--list", branch], in: path)
        return !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func runNexusInit(featureName: String, in path: String) async throws {
        // Find nexus-init script
        guard let initScript = LoopScriptLocator.findScript(.nexusInit) else {
            // Create minimal prd.json if script not found
            let prd = """
            {
              "feature_name": "\(featureName)",
              "branch": "feat/\(featureName)",
              "created_at": "\(ISO8601DateFormatter().string(from: Date()))",
              "status": "in_progress",
              "user_stories": []
            }
            """
            let prdPath = (path as NSString).appendingPathComponent("prd.json")
            try prd.write(toFile: prdPath, atomically: true, encoding: .utf8)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [initScript, featureName]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // Set up environment for non-interactive mode
        var env = ProcessInfo.processInfo.environment
        env["NEXUS_NON_INTERACTIVE"] = "1"
        process.environment = env

        try process.run()
        process.waitUntilExit()
    }
}

// MARK: - GitRepoInfo

struct GitRepoInfo {
    let currentBranch: String
    let uncommittedChanges: Int
}

// MARK: - AgentType Color Extension

extension AgentType {
    var color: Color {
        switch self {
        case .claude: return Color.slotBorderClaude
        case .gemini: return Color.slotBorderGemini
        case .codex: return Color.slotBorderCodex
        }
    }
}

// MARK: - Preview

#if DEBUG
struct StartSessionSheet_Previews: PreviewProvider {
    static var previews: some View {
        StartSessionSheet()
            .environment(\.appState, AppState(services: MockServiceContainer()))
    }
}
#endif
