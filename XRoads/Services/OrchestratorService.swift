//
//  OrchestratorService.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-013: Orchestrator chat service for AI interactions
//

import Foundation

// MARK: - OrchestratorChatError

/// Errors that can occur during orchestrator chat operations
enum OrchestratorChatError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case rateLimited
    case serverError(Int, String)
    case encodingFailed
    case decodingFailed(Error)
    case terminalNotAvailable
    case processLaunchFailed(Error)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Anthropic API key configured. Please add your API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited. Please wait before sending another message."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .encodingFailed:
            return "Failed to encode request."
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .terminalNotAvailable:
            return "Claude CLI is not available. Please install Claude Code."
        case .processLaunchFailed(let error):
            return "Failed to launch terminal process: \(error.localizedDescription)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - OrchestratorServiceDelegate

/// Protocol for receiving orchestrator events
@MainActor
protocol OrchestratorServiceDelegate: AnyObject {
    func orchestratorDidStartStreaming(_ service: OrchestratorService)
    func orchestratorDidReceiveChunk(_ service: OrchestratorService, chunk: String)
    func orchestratorDidFinishStreaming(_ service: OrchestratorService)
    func orchestratorDidEncounterError(_ service: OrchestratorService, error: OrchestratorChatError)
}

// MARK: - OrchestratorService

/// Actor-based service for orchestrator chat functionality
/// Supports both API mode (Anthropic API) and Terminal mode (Claude CLI)
actor OrchestratorService {
    // MARK: - Properties

    private var mode: OrchestratorMode = .api
    private var apiKey: String?
    private var systemPrompt: String = OrchestratorService.defaultSystemPrompt
    private var context: ChatContext?
    private var conversationHistory: [ChatMessage] = []
    private weak var delegate: OrchestratorServiceDelegate?

    private let processRunner: ProcessRunner
    private var terminalProcessId: UUID?

    // MARK: - Constants

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let defaultModel = "claude-sonnet-4-20250514"
    private static let maxTokens = 4096

    static let defaultSystemPrompt = """
    You are the XRoads Orchestrator, an intelligent assistant that helps users (including non-technical users) implement features through AI coding agents.

    ## Your Primary Role
    When a user describes ANY feature, modification, or improvement they want:
    1. Understand their need in plain language
    2. Ask 2-4 clarifying questions to refine scope, constraints, and priorities
    3. ONLY AFTER the user answers, generate a structured PRD (Product Requirements Document)
    4. The PRD will be auto-detected and the user can launch implementation with one click

    ## Phase 1: Clarification (MANDATORY before any PRD)
    When a user describes a feature, you MUST first ask clarifying questions. Examples:
    - What is the expected behavior / user flow?
    - Are there specific constraints (tech stack, performance, compatibility)?
    - What is the priority and desired scope (MVP vs full)?
    - Are there existing components or patterns to reuse?

    Do NOT generate a PRD until the user has answered your questions.
    If the user explicitly says "just do it" or "skip questions", you may proceed directly.

    ## Phase 2: PRD Generation (Nexus Format)
    ALWAYS wrap your PRD in a ```prd code block using this EXACT Nexus JSON structure:

    ```prd
    {
      "version": "1.0",
      "feature_name": "Feature Title",
      "description": "Brief description of what this feature does",
      "author": "Nexus",
      "user_stories": [
        {
          "id": "US-001",
          "title": "Story title",
          "description": "What needs to be done",
          "priority": "critical|high|medium|low",
          "status": "pending",
          "acceptance_criteria": ["Criterion 1", "Criterion 2"],
          "depends_on": [],
          "estimated_complexity": 3,
          "unit_test": {
            "file": "tests/us_001_test.swift",
            "name": "test_us_001",
            "description": "Verify story implementation",
            "assertions": ["Assert: criterion 1 is met"],
            "status": "pending"
          }
        }
      ]
    }
    ```

    ### PRD Rules (CRITICAL)
    - Every story MUST have a `unit_test` field - tests are mandatory for the Nexus loop
    - Every story MUST have `status: "pending"`
    - Use `acceptance_criteria` to define what "done" means
    - Use `depends_on` to reference story IDs (e.g. ["US-001"]) when ordering matters
    - `estimated_complexity` is 1-5 (1=trivial, 5=very complex)

    ## Complexity Guidelines
    - 1 story = Trivial (quick fix, single change)
    - 2 stories = Simple (small feature)
    - 3-5 stories = Moderate (standard feature)
    - 6+ stories = Complex (multi-agent recommended)

    ## Communication Style
    - Use simple, non-technical language
    - Explain what will happen in plain terms
    - Be encouraging and supportive
    - After generating a PRD, briefly explain what it contains

    ## Example Conversation

    User: "Je veux ajouter un bouton de partage"

    You: "Super idée ! Avant de créer le plan, j'ai quelques questions :

    1. **Quel contenu** doit être partageable ? (texte, lien, fichier...)
    2. **Quelles plateformes** de partage ? (système natif, copier le lien, réseaux sociaux...)
    3. **Où** le bouton doit-il apparaître ? (barre d'outils, menu contextuel, les deux...)
    4. Y a-t-il des **composants existants** à réutiliser ?"

    User: "Partage de lien via le système natif, dans la toolbar"

    You: "Parfait ! Voici le plan :

    ```prd
    {
      "version": "1.0",
      "feature_name": "Bouton de Partage",
      "description": "Ajouter un bouton de partage natif dans la toolbar pour partager des liens",
      "author": "Nexus",
      "user_stories": [
        {
          "id": "US-001",
          "title": "Créer le composant ShareButton",
          "description": "Créer un bouton réutilisable avec icône de partage dans la toolbar",
          "priority": "high",
          "status": "pending",
          "acceptance_criteria": ["Le bouton apparaît dans la toolbar", "Icône SF Symbol square.and.arrow.up"],
          "depends_on": [],
          "estimated_complexity": 2,
          "unit_test": {
            "file": "tests/us_001_test.swift",
            "name": "test_share_button_creation",
            "description": "Verify ShareButton component renders correctly",
            "assertions": ["Assert: button is visible in toolbar", "Assert: correct icon is displayed"],
            "status": "pending"
          }
        },
        {
          "id": "US-002",
          "title": "Intégrer NSSharingServicePicker",
          "description": "Connecter le bouton au service de partage natif macOS",
          "priority": "high",
          "status": "pending",
          "acceptance_criteria": ["Le picker natif s'ouvre au clic", "Le lien est partagé correctement"],
          "depends_on": ["US-001"],
          "estimated_complexity": 3,
          "unit_test": {
            "file": "tests/us_002_test.swift",
            "name": "test_sharing_integration",
            "description": "Verify native sharing service integration",
            "assertions": ["Assert: sharing picker opens", "Assert: link content is passed correctly"],
            "status": "pending"
          }
        }
      ]
    }
    ```

    Ce PRD contient 2 stories avec tests unitaires. Vous pouvez lancer l'implémentation !"

    ## Important
    - ALWAYS ask clarifying questions FIRST (unless user says to skip)
    - NEVER skip the `unit_test` field - the Nexus loop requires it
    - Keep PRDs focused and achievable
    - Suggest breaking large features (6+ stories) into smaller PRDs or use multi-agent mode
    """

    // MARK: - Initialization

    init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    // MARK: - Configuration

    /// Set the operating mode
    func setMode(_ mode: OrchestratorMode) {
        self.mode = mode
    }

    /// Get the current mode
    func getMode() -> OrchestratorMode {
        return mode
    }

    /// Set the API key for API mode
    func setAPIKey(_ key: String?) {
        self.apiKey = key
    }

    /// Set the chat context
    func setContext(_ context: ChatContext) {
        self.context = context
    }

    /// Set the delegate for receiving events
    func setDelegate(_ delegate: OrchestratorServiceDelegate?) {
        self.delegate = delegate
    }

    /// Update system prompt with context
    func updateSystemPrompt(_ customPrompt: String? = nil) {
        var prompt = customPrompt ?? Self.defaultSystemPrompt
        if let ctx = context {
            prompt += "\n\n" + ctx.systemPromptSection
        }
        self.systemPrompt = prompt
    }

    // MARK: - Conversation Management

    /// Add a message to the conversation history
    func addMessage(_ message: ChatMessage) {
        conversationHistory.append(message)
    }

    /// Get all messages in the conversation
    func getMessages() -> [ChatMessage] {
        return conversationHistory
    }

    /// Clear the conversation history
    func clearConversation() {
        conversationHistory.removeAll()
    }

    /// Update a message in the conversation (e.g., for streaming)
    func updateMessage(id: UUID, content: String? = nil, status: ChatMessageStatus? = nil) {
        guard let index = conversationHistory.firstIndex(where: { $0.id == id }) else { return }
        if let content = content {
            conversationHistory[index] = ChatMessage(
                id: conversationHistory[index].id,
                role: conversationHistory[index].role,
                content: content,
                timestamp: conversationHistory[index].timestamp,
                status: status ?? conversationHistory[index].status,
                actions: conversationHistory[index].actions,
                metadata: conversationHistory[index].metadata
            )
        } else if let status = status {
            conversationHistory[index] = ChatMessage(
                id: conversationHistory[index].id,
                role: conversationHistory[index].role,
                content: conversationHistory[index].content,
                timestamp: conversationHistory[index].timestamp,
                status: status,
                actions: conversationHistory[index].actions,
                metadata: conversationHistory[index].metadata
            )
        }
    }

    // MARK: - Send Message

    /// Send a message and get a response
    /// In API mode, makes an API call. In Terminal mode, runs Claude CLI.
    func sendMessage(_ content: String) async throws -> ChatMessage {
        // Add user message
        let userMessage = ChatMessage.user(content)
        addMessage(userMessage)

        switch mode {
        case .api:
            return try await sendAPIMessage(content)
        case .terminal:
            return try await sendTerminalMessage(content)
        }
    }

    // MARK: - API Mode

    private func sendAPIMessage(_ content: String) async throws -> ChatMessage {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw OrchestratorChatError.noAPIKey
        }

        // Create placeholder for streaming response
        let responseMessage = ChatMessage.streamingPlaceholder()
        addMessage(responseMessage)

        await delegate?.orchestratorDidStartStreaming(self)

        // Build request
        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Build messages array (excluding system messages and the placeholder)
        let apiMessages: [[String: Any]] = conversationHistory
            .filter { $0.role != .system && $0.id != responseMessage.id }
            .map { message in
                [
                    "role": message.role == .user ? "user" : "assistant",
                    "content": message.content
                ]
            }

        let body: [String: Any] = [
            "model": Self.defaultModel,
            "max_tokens": Self.maxTokens,
            "system": systemPrompt,
            "messages": apiMessages,
            "stream": true
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw OrchestratorChatError.encodingFailed
        }
        request.httpBody = jsonData

        // Make streaming request
        var responseContent = ""

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OrchestratorChatError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    throw OrchestratorChatError.rateLimited
                }
                throw OrchestratorChatError.serverError(httpResponse.statusCode, "API request failed")
            }

            // Process SSE stream
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" {
                        break
                    }

                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String {

                        if type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            responseContent += text
                            await delegate?.orchestratorDidReceiveChunk(self, chunk: text)
                            updateMessage(id: responseMessage.id, content: responseContent)
                        }
                    }
                }
            }

            // Finalize message
            updateMessage(id: responseMessage.id, content: responseContent, status: .complete)
            await delegate?.orchestratorDidFinishStreaming(self)

            return ChatMessage(
                id: responseMessage.id,
                role: .assistant,
                content: responseContent,
                timestamp: responseMessage.timestamp,
                status: .complete
            )

        } catch let error as OrchestratorChatError {
            updateMessage(id: responseMessage.id, status: .error(error.localizedDescription ?? "Unknown error"))
            await delegate?.orchestratorDidEncounterError(self, error: error)
            throw error
        } catch {
            let orchestratorError = OrchestratorChatError.networkError(error)
            updateMessage(id: responseMessage.id, status: .error(orchestratorError.localizedDescription ?? "Network error"))
            await delegate?.orchestratorDidEncounterError(self, error: orchestratorError)
            throw orchestratorError
        }
    }

    // MARK: - Terminal Mode

    private func sendTerminalMessage(_ content: String) async throws -> ChatMessage {
        // Create placeholder for response
        let responseMessage = ChatMessage.streamingPlaceholder()
        addMessage(responseMessage)

        await delegate?.orchestratorDidStartStreaming(self)

        // Find Claude CLI
        guard let claudePath = findClaudeCLI() else {
            throw OrchestratorChatError.terminalNotAvailable
        }

        var responseContent = ""
        let workingDirectory = context?.projectPath ?? FileManager.default.currentDirectoryPath

        // Build arguments for Claude CLI in print mode
        // --dangerously-skip-permissions: Required for non-interactive mode
        // --output-format text: Get plain text output (not JSON)
        // -p: Print mode - execute prompt and exit
        let arguments = [
            "--dangerously-skip-permissions",
            "--output-format", "text",
            "-p", content
        ]

        // Debug logging to file
        let logFile = "/tmp/xroads_orchestrator.log"
        let logMsg = """
        [\(Date())] Launching Claude CLI
        Path: \(claudePath)
        Arguments: \(arguments)
        Working directory: \(workingDirectory)

        """
        try? logMsg.write(toFile: logFile, atomically: false, encoding: .utf8)
        Log.orchestrator.info("Launching Claude CLI at: \(claudePath)")

        // Launch Claude CLI with the message
        do {
            let processId = try await processRunner.launch(
                executable: claudePath,
                arguments: arguments,
                workingDirectory: workingDirectory,
                closeStdinImmediately: true  // Claude -p mode needs EOF on stdin
            ) { [weak self] output in
                guard let self = self else { return }
                Log.orchestrator.debug("Received output chunk: \(output.prefix(100))...")
                Task {
                    responseContent += output
                    await self.delegate?.orchestratorDidReceiveChunk(self, chunk: output)
                    await self.updateMessage(id: responseMessage.id, content: responseContent)
                }
            }

            terminalProcessId = processId
            Log.orchestrator.info("Process launched with ID: \(processId)")

            // Wait for process to complete with timeout (5 minutes max)
            let timeoutSeconds = 300
            var elapsedSeconds = 0
            Log.orchestrator.info("Waiting for process to complete...")
            while await processRunner.isRunning(id: processId) {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                elapsedSeconds += 1
                if elapsedSeconds % 50 == 0 { // Log every 5 seconds
                    Log.orchestrator.debug("Still waiting... elapsed: \(elapsedSeconds / 10)s, isRunning: true")
                }
                if elapsedSeconds >= timeoutSeconds * 10 { // 100ms intervals
                    // Timeout - terminate the process
                    try? await processRunner.terminate(id: processId)
                    terminalProcessId = nil
                    updateMessage(id: responseMessage.id, content: responseContent + "\n\n[Timeout: Process terminated after 5 minutes]", status: .complete)
                    await delegate?.orchestratorDidFinishStreaming(self)
                    return ChatMessage(
                        id: responseMessage.id,
                        role: .assistant,
                        content: responseContent + "\n\n[Timeout: Process terminated after 5 minutes]",
                        timestamp: responseMessage.timestamp,
                        status: .complete
                    )
                }
            }

            terminalProcessId = nil

            // Finalize message
            updateMessage(id: responseMessage.id, content: responseContent, status: .complete)
            await delegate?.orchestratorDidFinishStreaming(self)

            return ChatMessage(
                id: responseMessage.id,
                role: .assistant,
                content: responseContent,
                timestamp: responseMessage.timestamp,
                status: .complete
            )

        } catch {
            let orchestratorError = OrchestratorChatError.processLaunchFailed(error)
            updateMessage(id: responseMessage.id, status: .error(orchestratorError.localizedDescription ?? "Process failed"))
            await delegate?.orchestratorDidEncounterError(self, error: orchestratorError)
            throw orchestratorError
        }
    }

    /// Stop the current terminal process if running
    func stopTerminalProcess() async {
        guard let processId = terminalProcessId else { return }
        try? await processRunner.terminate(id: processId)
        terminalProcessId = nil
    }

    // MARK: - Helpers

    private func findClaudeCLI() -> String? {
        let home = NSHomeDirectory()
        var possiblePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.local/bin/claude",
            "\(home)/.npm-global/bin/claude"
        ]

        // Check nvm directories for node-installed CLI
        let nvmDir = "\(home)/.nvm/versions/node"
        if let nodeVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for version in nodeVersions {
                possiblePaths.append("\(nvmDir)/\(version)/bin/claude")
            }
        }

        // Also check volta if installed
        let voltaDir = "\(home)/.volta/bin"
        possiblePaths.append("\(voltaDir)/claude")

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}
