//
//  OrchestratorChatView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-013: Main orchestrator chat view with messages and input
//

import SwiftUI

// MARK: - OrchestratorChatView

/// Main chat view for interacting with the orchestrator AI
struct OrchestratorChatView: View {
    @Environment(\.appState) private var appState
    @Environment(\.services) private var services
    @StateObject private var viewModel = OrchestratorChatViewModel()
    @State private var showPRDFullView = false
    @State private var selectedPRDForView: DetectedPRD?
    @State private var showSlotAssignment = false
    @State private var prdDocumentForSlotAssignment: PRDDocument?

    // Phase 2: Chat dispatch integration
    private let dispatchParser = ChatDispatchParser()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                chatHeader

                Divider()
                    .background(Color.borderMuted)

                // Messages area
                messagesArea

                // Context bar
                ChatContextBar(
                    projectPath: appState.projectPath,
                    branch: viewModel.currentBranch,
                    mode: appState.dashboardMode,
                    onOpenProject: openProjectPicker
                )

                // Input bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    mode: $viewModel.mode,
                    isLoading: viewModel.isLoading,
                    onSend: sendMessage,
                    onStop: stopGeneration
                )
            }

            // PRD Proposal Overlay
            PRDProposalOverlay(
                detectedPRD: viewModel.detectedPRD,
                onDismiss: {
                    withAnimation { viewModel.dismissPRDProposal() }
                },
                onViewPRD: { prd in
                    selectedPRDForView = prd
                    showPRDFullView = true
                },
                onLaunch: { prd, agent, branch in
                    launchImplementation(prd: prd, agent: agent, branch: branch)
                },
                onConfigureMultiAgent: { prd in
                    openSlotAssignment(for: prd)
                }
            )
        }
        .background(Color.bgApp)
        .task {
            await viewModel.loadContext(from: appState)
        }
        .sheet(isPresented: $showPRDFullView) {
            if let prd = selectedPRDForView {
                PRDPreviewSheet(prd: prd)
            }
        }
        .sheet(isPresented: $showSlotAssignment) {
            if let doc = prdDocumentForSlotAssignment,
               let projectPath = appState.projectPath {
                SlotAssignmentSheet(prd: doc, repoPath: URL(fileURLWithPath: projectPath)) {
                    showSlotAssignment = false
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var chatHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16))
                .foregroundStyle(Color.statusSuccess)

            Text("Orchestrator")
                .font(.h2)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            // Mode indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.mode == .api ? Color.accentPrimary : Color.terminalCyan)
                    .frame(width: 6, height: 6)
                Text(viewModel.mode.displayName)
                    .font(.xs)
                    .foregroundStyle(Color.textSecondary)
            }

            // Clear chat button
            Button {
                viewModel.clearChat()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Clear chat history")
            .disabled(viewModel.messages.isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.bgSurface)
    }

    // MARK: - Messages Area

    @ViewBuilder
    private var messagesArea: some View {
        if viewModel.messages.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            ChatMessageView(message: message) { action in
                                handleAction(action)
                            }
                            .id(message.id)
                        }
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.lastMessageContent) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            .background(Color.bgApp)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation(.easeOut(duration: Theme.Animation.fast)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.statusSuccess.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.statusSuccess)
            }

            // Title
            Text("XRoads Orchestrator")
                .font(.h1)
                .foregroundStyle(Color.textPrimary)

            // Description
            Text("Your AI assistant for multi-agent development workflows")
                .font(.body14)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            // Quick actions
            VStack(spacing: Theme.Spacing.sm) {
                Text("Try asking:")
                    .font(.small)
                    .foregroundStyle(Color.textTertiary)

                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        viewModel.inputText = prompt
                    } label: {
                        Text(prompt)
                            .font(.small)
                            .foregroundStyle(Color.accentPrimary)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Color.accentPrimary.opacity(0.1))
                            .cornerRadius(Theme.Radius.md)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgApp)
    }

    private var quickPrompts: [String] {
        [
            "Create a PRD for a user authentication feature",
            "Help me set up a new worktree for my feature branch",
            "What skills are available for this project?"
        ]
    }

    // MARK: - Actions

    private func sendMessage() {
        Task {
            await viewModel.sendMessage()
        }
    }

    private func stopGeneration() {
        Task {
            await viewModel.stopGeneration()
        }
    }

    private func handleAction(_ action: ChatAction) {
        switch action.type {
        case .createPRD:
            // Open PRD assistant with context from action
            NotificationCenter.default.post(name: .openPRDAssistant, object: action.payload)
        case .launchLoop:
            // Launch nexus loop with PRD via UnifiedDispatcher
            if let prdPath = action.payload?["prdPath"] {
                Task {
                    appState.pendingPRDURL = URL(fileURLWithPath: prdPath)
                }
            }
        case .openFile:
            // Open file in default editor
            if let filePath = action.payload?["path"] {
                NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
            }
        case .createWorktree:
            // Trigger worktree creation sheet
            NotificationCenter.default.post(name: .openWorktreeCreator, object: action.payload)
        case .runCommand:
            // Execute command (switch to terminal mode)
            if let command = action.payload?["command"] {
                viewModel.inputText = command
                viewModel.mode = .terminal
            }
        case .viewArtBible:
            // Open art direction view
            NotificationCenter.default.post(name: .openArtDirection, object: nil)
        case .viewSkills:
            // Open skills browser
            NotificationCenter.default.post(name: .openSkillsBrowser, object: nil)

        // Phase 2: Dispatch-related actions via UnifiedDispatcher
        case .launchSlot:
            handleLaunchSlotAction(action)
        case .startAllSlots:
            handleStartAllAction()
        case .stopSlot:
            handleStopSlotAction(action)
        case .stopAllSlots:
            handleStopAllAction()
        case .configureSlot:
            handleConfigureSlotAction(action)
        }
    }

    // MARK: - Phase 2: Dispatch Action Handlers

    private func handleLaunchSlotAction(_ action: ChatAction) {
        Task {
            guard let slotNumberStr = action.payload?["slotNumber"],
                  let slotNumber = Int(slotNumberStr) else {
                viewModel.addSystemMessage("Missing slot number for launch action")
                return
            }

            // Parse agent type from payload
            var agentType: AgentType = .claude
            if let agentTypeStr = action.payload?["agentType"],
               let parsed = AgentType(rawValue: agentTypeStr) {
                agentType = parsed
            }

            let worktreePath = action.payload?["worktreePath"] ?? appState.projectPath ?? ""

            let request = DispatchRequest.single(
                slotNumber: slotNumber,
                agentType: agentType,
                worktreePath: worktreePath,
                source: .chat
            )

            await dispatchViaUnified(request)
        }
    }

    private func handleStartAllAction() {
        Task {
            let request = DispatchRequest(
                mode: .chat,
                source: .chat,
                chatIntent: "start_all"
            )
            await dispatchViaUnified(request)
        }
    }

    private func handleStopSlotAction(_ action: ChatAction) {
        Task {
            let slotNumber = action.payload?["slotNumber"].flatMap { Int($0) }
            let request = DispatchRequest(
                mode: .chat,
                source: .chat,
                slotNumber: slotNumber,
                chatIntent: "stop_slot"
            )
            await dispatchViaUnified(request)
        }
    }

    private func handleStopAllAction() {
        Task {
            let request = DispatchRequest(
                mode: .chat,
                source: .chat,
                chatIntent: "stop_all"
            )
            await dispatchViaUnified(request)
        }
    }

    private func handleConfigureSlotAction(_ action: ChatAction) {
        // Configuration triggers UI, not dispatch
        NotificationCenter.default.post(name: .openSlotConfiguration, object: action.payload)
    }

    /// Dispatch via UnifiedDispatcher with callbacks
    private func dispatchViaUnified(_ request: DispatchRequest) async {
        let callbacks = DispatchCallbacks(
            onProgress: { progress in
                Task { @MainActor in
                    self.appState.dispatchProgress = progress
                }
            },
            onSlotUpdate: { slotInfo in
                Task { @MainActor in
                    // Update slot in appState
                    if let index = self.appState.terminalSlots.firstIndex(where: { $0.slotNumber == slotInfo.slotNumber }) {
                        self.appState.terminalSlots[index].processId = slotInfo.processId
                    }
                }
            },
            onSlotOutput: { slotNumber, output in
                Task { @MainActor in
                    // Route to terminal slot
                    self.appState.appendSlotOutput(slotNumber: slotNumber, output: output)
                }
            },
            onSlotTermination: { slotNumber, exitCode in
                Task { @MainActor in
                    // Update slot status on termination
                    self.appState.handleSlotTermination(slotNumber: slotNumber, exitCode: exitCode)
                }
            },
            onLog: { log in
                Task { @MainActor in
                    self.appState.globalLogs.append(log)
                }
            },
            onComplete: {
                Task { @MainActor in
                    self.viewModel.addSystemMessage("Dispatch completed successfully")
                }
            },
            onError: { error in
                Task { @MainActor in
                    self.viewModel.addSystemMessage("Dispatch error: \(error.localizedDescription)")
                }
            }
        )

        do {
            _ = try await services.unifiedDispatcher.dispatch(request, callbacks: callbacks)
        } catch {
            viewModel.addSystemMessage("Failed to dispatch: \(error.localizedDescription)")
        }
    }

    private func openProjectPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the project directory"

        if panel.runModal() == .OK, let url = panel.url {
            appState.projectPath = url.path
            Task {
                await viewModel.loadContext(from: appState)
            }
        }
    }

    private func openSlotAssignment(for prd: DetectedPRD) {
        guard appState.projectPath != nil else {
            viewModel.addSystemMessage("Veuillez d'abord sélectionner un projet.")
            return
        }

        // Convert DetectedPRD → PRDDocument for SlotAssignmentSheet
        let stories: [PRDUserStory] = (prd.prdData?.user_stories ?? []).enumerated().map { index, story in
            var prdStory = PRDUserStory(
                id: story.id ?? "US-\(String(format: "%03d", index + 1))",
                title: story.title ?? "Story \(index + 1)",
                description: story.description ?? "",
                priority: PRDPriority(rawValue: story.priority ?? "medium") ?? .medium,
                status: PRDStoryStatus(rawValue: story.status ?? "pending") ?? .pending,
                acceptanceCriteria: story.acceptance_criteria ?? [],
                dependsOn: story.depends_on ?? [],
                estimatedComplexity: story.estimated_complexity ?? 3
            )

            // Map unit_test if present
            if let ut = story.unit_test {
                prdStory.unitTest = PRDUnitTest(
                    file: ut.file ?? "tests/\(prdStory.id.lowercased().replacingOccurrences(of: "-", with: "_"))_test.swift",
                    name: ut.name ?? "test_\(prdStory.id.lowercased().replacingOccurrences(of: "-", with: "_"))",
                    description: ut.description ?? "Test for \(prdStory.title)",
                    assertions: ut.assertions ?? [],
                    status: PRDTestStatus(rawValue: ut.status ?? "pending") ?? .pending
                )
            } else {
                prdStory.generateDefaultUnitTest()
            }

            return prdStory
        }

        let document = PRDDocument(
            featureName: prd.prdData?.feature_name ?? prd.title,
            description: prd.prdData?.description ?? prd.description,
            userStories: stories
        )

        withAnimation { viewModel.dismissPRDProposal() }
        prdDocumentForSlotAssignment = document
        showSlotAssignment = true
    }

    private func launchImplementation(prd: DetectedPRD, agent: AgentType, branch: String) {
        Task {
            // Dismiss the proposal
            await MainActor.run {
                withAnimation { viewModel.dismissPRDProposal() }
            }

            // Save PRD to file
            guard let projectPath = appState.projectPath else {
                viewModel.addSystemMessage("Veuillez d'abord sélectionner un projet.")
                return
            }

            let prdPath = "\(projectPath)/prd.json"
            do {
                try prd.rawJSON.write(toFile: prdPath, atomically: true, encoding: .utf8)
            } catch {
                viewModel.addSystemMessage("Erreur lors de la sauvegarde du PRD: \(error.localizedDescription)")
                return
            }

            // Create branch if needed
            let gitService = GitService()
            do {
                // Try to checkout existing branch first
                try await gitService.checkout(branch: branch, repoPath: projectPath)
            } catch {
                // Branch doesn't exist, create it
                do {
                    // Create and checkout new branch
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    process.arguments = ["checkout", "-b", branch]
                    process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    // Continue anyway, branch creation is not critical
                }
            }

            // Notify about launch
            viewModel.addSystemMessage("""
                🚀 Lancement de l'implémentation...

                **PRD:** \(prd.title)
                **Agent:** \(agent.displayName)
                **Branche:** \(branch)

                La loop démarre dans le terminal.
                """)

            // Launch the loop
            NotificationCenter.default.post(
                name: .launchAgentLoop,
                object: nil,
                userInfo: [
                    "agent": agent,
                    "prdPath": prdPath,
                    "branch": branch,
                    "projectPath": projectPath
                ]
            )
        }
    }
}

// MARK: - ViewModel

/// View model for OrchestratorChatView managing chat state and service communication
@MainActor
final class OrchestratorChatViewModel: ObservableObject, OrchestratorServiceDelegate {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var mode: OrchestratorMode = .api
    @Published var isLoading: Bool = false
    @Published var currentBranch: String?
    @Published var lastMessageContent: String = ""
    @Published var detectedPRD: DetectedPRD?

    private let orchestratorService = OrchestratorService()
    private var context: ChatContext?
    private var streamingMessageId: UUID?

    // MARK: - Context Loading

    func loadContext(from appState: AppState) async {
        let worktreeNames = appState.worktrees.map { $0.name }

        // Get current branch if project path is set
        var branch: String?
        if let projectPath = appState.projectPath {
            let gitService = GitService()
            branch = try? await gitService.getCurrentBranch(path: projectPath)
        }

        // Load available skills from registry
        let registry = SkillRegistry.shared
        await registry.initialize()
        let allSkillIds = await registry.allSkillIDs()

        // Combine with universal skills (always available in Claude)
        var skillIds = Set(allSkillIds)
        skillIds.formUnion(ActionType.universalSkills)

        context = ChatContext(
            projectPath: appState.projectPath,
            currentBranch: branch,
            worktrees: worktreeNames,
            availableSkills: Array(skillIds).sorted(),
            mcpServers: ["xroads-mcp"],
            dashboardMode: appState.dashboardMode == .single ? "single" : "agentic"
        )

        currentBranch = branch

        await orchestratorService.setContext(context!)
        await orchestratorService.updateSystemPrompt()
        await orchestratorService.setDelegate(self)

        // Load API key from Keychain (secure storage)
        if let apiKey = await KeychainService.shared.getAPIKey(provider: "anthropic") {
            await orchestratorService.setAPIKey(apiKey)
        }
    }

    // MARK: - Message Handling

    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let content = inputText
        inputText = ""
        isLoading = true

        await orchestratorService.setMode(mode)

        do {
            // Add user message immediately to UI
            let userMessage = ChatMessage.user(content)
            messages.append(userMessage)
            // Note: orchestratorService.sendMessage() adds user message internally,
            // so we do NOT call orchestratorService.addMessage() here to avoid duplicates.

            // Create streaming placeholder for UI
            let placeholder = ChatMessage.streamingPlaceholder()
            messages.append(placeholder)
            streamingMessageId = placeholder.id

            // Send and stream response -- delegate callbacks update UI during streaming
            let response = try await orchestratorService.sendMessage(content)

            // Finalize: ensure placeholder has the complete response
            if let index = messages.firstIndex(where: { $0.id == placeholder.id }) {
                messages[index] = ChatMessage(
                    id: placeholder.id,
                    role: .assistant,
                    content: response.content,
                    timestamp: placeholder.timestamp,
                    status: .complete
                )
            }
            streamingMessageId = nil
            lastMessageContent = response.content

            // Detect PRD in response
            if let prd = PRDDetector.detect(in: response.content) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    detectedPRD = prd
                }
            }

        } catch {
            streamingMessageId = nil
            // Update last message with error
            if let lastIndex = messages.indices.last,
               messages[lastIndex].role == .assistant {
                messages[lastIndex] = ChatMessage(
                    id: messages[lastIndex].id,
                    role: .assistant,
                    content: messages[lastIndex].content.isEmpty
                        ? "An error occurred. Please try again."
                        : messages[lastIndex].content,
                    timestamp: messages[lastIndex].timestamp,
                    status: .error(error.localizedDescription)
                )
            } else {
                messages.append(ChatMessage(
                    role: .assistant,
                    content: "An error occurred: \(error.localizedDescription)",
                    status: .error(error.localizedDescription)
                ))
            }
        }

        isLoading = false
    }

    func stopGeneration() async {
        await orchestratorService.stopTerminalProcess()
        isLoading = false

        // Mark current streaming message as complete
        if let lastIndex = messages.indices.last,
           messages[lastIndex].status == .streaming {
            messages[lastIndex] = ChatMessage(
                id: messages[lastIndex].id,
                role: messages[lastIndex].role,
                content: messages[lastIndex].content + "\n\n*[Generation stopped]*",
                timestamp: messages[lastIndex].timestamp,
                status: .complete
            )
        }
    }

    // MARK: - OrchestratorServiceDelegate

    func orchestratorDidStartStreaming(_ service: OrchestratorService) {
        // Placeholder already added in sendMessage
    }

    func orchestratorDidReceiveChunk(_ service: OrchestratorService, chunk: String) {
        guard let messageId = streamingMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let updatedContent = messages[index].content + chunk
        messages[index] = ChatMessage(
            id: messageId,
            role: .assistant,
            content: updatedContent,
            timestamp: messages[index].timestamp,
            status: .streaming
        )
        lastMessageContent = updatedContent
    }

    func orchestratorDidFinishStreaming(_ service: OrchestratorService) {
        // Final update happens in sendMessage when it returns
    }

    func orchestratorDidEncounterError(_ service: OrchestratorService, error: OrchestratorChatError) {
        guard let messageId = streamingMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        messages[index] = ChatMessage(
            id: messageId,
            role: .assistant,
            content: messages[index].content.isEmpty
                ? "An error occurred. Please try again."
                : messages[index].content,
            timestamp: messages[index].timestamp,
            status: .error(error.localizedDescription)
        )
        streamingMessageId = nil
    }

    func clearChat() {
        messages.removeAll()
        detectedPRD = nil
        Task {
            await orchestratorService.clearConversation()
        }
    }

    func dismissPRDProposal() {
        detectedPRD = nil
    }

    func addSystemMessage(_ content: String) {
        let systemMessage = ChatMessage(
            role: .assistant,
            content: content,
            status: .complete,
            metadata: ["type": "system"]
        )
        messages.append(systemMessage)
    }
}

// MARK: - Preview

#if DEBUG
struct OrchestratorChatView_Previews: PreviewProvider {
    static var previews: some View {
        OrchestratorChatView()
            .environment(\.appState, previewAppState())
            .frame(width: 400, height: 700)
    }

    static func previewAppState() -> AppState {
        let state = AppState()
        state.projectPath = "/Users/dev/Projects/MyApp"
        state.dashboardMode = .agentic
        return state
    }
}
#endif
