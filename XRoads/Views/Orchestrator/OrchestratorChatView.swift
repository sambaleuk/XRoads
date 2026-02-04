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
    @StateObject private var viewModel = OrchestratorChatViewModel()

    var body: some View {
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
        .background(Color.bgApp)
        .task {
            await viewModel.loadContext(from: appState)
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
            // Launch nexus loop with PRD
            if let prdPath = action.payload?["prdPath"] {
                Task {
                    // Load PRD and start orchestration
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
}

// MARK: - ViewModel

/// View model for OrchestratorChatView managing chat state and service communication
@MainActor
final class OrchestratorChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var mode: OrchestratorMode = .api
    @Published var isLoading: Bool = false
    @Published var currentBranch: String?
    @Published var lastMessageContent: String = ""

    private let orchestratorService = OrchestratorService()
    private var context: ChatContext?

    // MARK: - Context Loading

    func loadContext(from appState: AppState) async {
        let worktreeNames = appState.worktrees.map { $0.name }

        // Get current branch if project path is set
        var branch: String?
        if let projectPath = appState.projectPath {
            let gitService = GitService()
            branch = try? await gitService.getCurrentBranch(path: projectPath)
        }

        context = ChatContext(
            projectPath: appState.projectPath,
            currentBranch: branch,
            worktrees: worktreeNames,
            availableSkills: [], // TODO: Load from SkillRegistry
            mcpServers: ["xroads-mcp"],
            dashboardMode: appState.dashboardMode == .single ? "single" : "agentic"
        )

        currentBranch = branch

        await orchestratorService.setContext(context!)
        await orchestratorService.updateSystemPrompt()

        // Load API key from settings if available
        if let apiKey = UserDefaults.standard.string(forKey: "anthropicAPIKey") {
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
            // Add user message immediately
            let userMessage = ChatMessage.user(content)
            messages.append(userMessage)
            await orchestratorService.addMessage(userMessage)

            // Create streaming placeholder
            let placeholder = ChatMessage.streamingPlaceholder()
            messages.append(placeholder)

            // Send and stream response
            let response = try await orchestratorService.sendMessage(content)

            // Update placeholder with final response
            if let index = messages.firstIndex(where: { $0.id == placeholder.id }) {
                messages[index] = response
            }
            lastMessageContent = response.content

        } catch {
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

    func clearChat() {
        messages.removeAll()
        Task {
            await orchestratorService.clearConversation()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openPRDAssistant = Notification.Name("openPRDAssistant")
    static let openWorktreeCreator = Notification.Name("openWorktreeCreator")
    static let openArtDirection = Notification.Name("openArtDirection")
    static let openSkillsBrowser = Notification.Name("openSkillsBrowser")
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
