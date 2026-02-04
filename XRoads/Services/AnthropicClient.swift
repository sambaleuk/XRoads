//
//  AnthropicClient.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-014: Anthropic API client actor for chat interactions
//

import Foundation

// MARK: - AnthropicClient

/// Actor-based client for Anthropic API interactions
/// Handles API authentication, request formation, and streaming responses
public actor AnthropicClient {
    // MARK: - Properties

    private var apiKey: String?
    private var config: APIConfig
    private var currentTask: Task<Void, Never>?

    private let urlSession: URLSession

    // MARK: - Constants

    private static let apiVersion = "2023-06-01"

    // MARK: - Initialization

    public init(config: APIConfig = .defaultAnthropic) {
        self.config = config

        // Configure URLSession with appropriate timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 2
        configuration.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - Configuration

    /// Set the API key for authentication
    public func setAPIKey(_ key: String?) {
        self.apiKey = key
    }

    /// Get the current API key (masked for display)
    public func getMaskedAPIKey() -> String? {
        guard let key = apiKey, key.count > 8 else { return nil }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    /// Check if an API key is configured
    public func hasAPIKey() -> Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    /// Update the API configuration
    public func setConfig(_ config: APIConfig) {
        self.config = config
    }

    /// Get the current configuration
    public func getConfig() -> APIConfig {
        return config
    }

    // MARK: - API Key Validation

    /// Validate the API key format (basic check)
    public func validateAPIKeyFormat(_ key: String) -> Bool {
        // Anthropic keys typically start with "sk-ant-" and are alphanumeric
        guard key.hasPrefix("sk-ant-") else { return false }
        guard key.count > 20 else { return false }
        return true
    }

    /// Test the API key by making a minimal request
    public func testAPIKey() async throws -> Bool {
        guard let key = apiKey, !key.isEmpty else {
            throw AnthropicClientError.noAPIKey
        }

        // Make a minimal request to verify the key
        let messages = [AnthropicMessage(role: "user", content: "Hello")]
        let request = try buildRequest(messages: messages, systemPrompt: nil)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnthropicClientError.networkError("Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                return true
            case 401:
                throw AnthropicClientError.invalidAPIKey
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
                throw AnthropicClientError.rateLimited(retryAfter: retryAfter)
            default:
                if let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
                    throw AnthropicClientError.serverError(
                        statusCode: httpResponse.statusCode,
                        message: errorResponse.error.message
                    )
                }
                throw AnthropicClientError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: "Unknown error"
                )
            }
        } catch let error as AnthropicClientError {
            throw error
        } catch {
            throw AnthropicClientError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Send Message (Non-Streaming)

    /// Send a message and receive the complete response
    public func sendMessage(
        messages: [AnthropicMessage],
        systemPrompt: String?
    ) async throws -> AnthropicResponse {
        guard let key = apiKey, !key.isEmpty else {
            throw AnthropicClientError.noAPIKey
        }

        var request = try buildRequest(messages: messages, systemPrompt: systemPrompt)
        // Override stream to false for non-streaming
        let nonStreamConfig = config.with(stream: false)
        request = try buildRequest(messages: messages, systemPrompt: systemPrompt, config: nonStreamConfig)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnthropicClientError.networkError("Invalid response")
            }

            try handleHTTPStatus(httpResponse, data: data)

            do {
                let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
                return anthropicResponse
            } catch {
                throw AnthropicClientError.decodingError(error.localizedDescription)
            }
        } catch let error as AnthropicClientError {
            throw error
        } catch is CancellationError {
            throw AnthropicClientError.cancelled
        } catch {
            throw AnthropicClientError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Send Message (Streaming)

    /// Send a message and receive streaming response chunks
    public func sendMessageStreaming(
        messages: [AnthropicMessage],
        systemPrompt: String?
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        // Pre-build request and capture values while inside actor context
        let requestResult: Result<URLRequest, Error>
        do {
            let request = try self.buildRequest(messages: messages, systemPrompt: systemPrompt)
            requestResult = .success(request)
        } catch {
            requestResult = .failure(error)
        }

        let capturedUrlSession = self.urlSession

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Get the pre-built request
                    let request: URLRequest
                    switch requestResult {
                    case .success(let req):
                        request = req
                    case .failure(let error):
                        if let clientError = error as? AnthropicClientError {
                            continuation.yield(.error(clientError))
                            continuation.finish(throwing: clientError)
                        } else {
                            let clientError = AnthropicClientError.invalidRequest(error.localizedDescription)
                            continuation.yield(.error(clientError))
                            continuation.finish(throwing: clientError)
                        }
                        return
                    }

                    let (bytes, response) = try await capturedUrlSession.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AnthropicClientError.networkError("Invalid response")
                    }

                    // Check status before streaming
                    guard httpResponse.statusCode == 200 else {
                        let error = Self.parseStreamingError(httpResponse)
                        continuation.yield(.error(error))
                        continuation.finish(throwing: error)
                        return
                    }

                    continuation.yield(.start)

                    var fullContent = ""

                    // Process Server-Sent Events (SSE)
                    for try await line in bytes.lines {
                        // Check for cancellation
                        try Task.checkCancellation()

                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))

                        // Skip [DONE] marker
                        if jsonString == "[DONE]" {
                            break
                        }

                        guard let data = jsonString.data(using: .utf8) else { continue }

                        // Parse the SSE event
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let eventType = json["type"] as? String {

                            switch eventType {
                            case "content_block_delta":
                                if let delta = json["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    fullContent += text
                                    continuation.yield(.delta(text))
                                }

                            case "message_stop":
                                break

                            case "error":
                                if let error = json["error"] as? [String: Any],
                                   let message = error["message"] as? String {
                                    throw AnthropicClientError.streamingError(message)
                                }

                            default:
                                break
                            }
                        }
                    }

                    continuation.yield(.complete(fullContent))
                    continuation.finish()

                } catch is CancellationError {
                    continuation.yield(.error(.cancelled))
                    continuation.finish(throwing: AnthropicClientError.cancelled)
                } catch let error as AnthropicClientError {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                } catch {
                    let clientError = AnthropicClientError.networkError(error.localizedDescription)
                    continuation.yield(.error(clientError))
                    continuation.finish(throwing: clientError)
                }
            }

            self.currentTask = task

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Cancel any ongoing streaming request
    public func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Static helper to parse streaming errors (used outside actor context)
    private static func parseStreamingError(_ response: HTTPURLResponse) -> AnthropicClientError {
        switch response.statusCode {
        case 401:
            return .invalidAPIKey
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            return .rateLimited(retryAfter: retryAfter)
        default:
            return .serverError(statusCode: response.statusCode, message: "Request failed")
        }
    }

    // MARK: - Request Building

    private func buildRequest(
        messages: [AnthropicMessage],
        systemPrompt: String?,
        config: APIConfig? = nil
    ) throws -> URLRequest {
        let cfg = config ?? self.config

        guard let apiKey = apiKey else {
            throw AnthropicClientError.noAPIKey
        }

        let url = cfg.provider.baseURL.appendingPathComponent(cfg.provider.messagesEndpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: cfg.provider.apiKeyHeader)

        if let versionHeader = cfg.provider.apiVersionHeader {
            request.setValue(versionHeader.value, forHTTPHeaderField: versionHeader.key)
        }

        let requestBody = AnthropicRequest(
            model: cfg.model,
            maxTokens: cfg.maxTokens,
            system: systemPrompt,
            messages: messages,
            stream: cfg.stream,
            temperature: cfg.temperature
        )

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            throw AnthropicClientError.invalidRequest("Failed to encode request: \(error.localizedDescription)")
        }

        return request
    }

    // MARK: - Error Handling

    private func handleHTTPStatus(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200..<300:
            return // Success
        case 401:
            throw AnthropicClientError.invalidAPIKey
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw AnthropicClientError.rateLimited(retryAfter: retryAfter)
        case 400..<500:
            if let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
                throw AnthropicClientError.invalidRequest(errorResponse.error.message)
            }
            throw AnthropicClientError.invalidRequest("Client error: \(response.statusCode)")
        case 500..<600:
            if let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
                throw AnthropicClientError.serverError(
                    statusCode: response.statusCode,
                    message: errorResponse.error.message
                )
            }
            throw AnthropicClientError.serverError(
                statusCode: response.statusCode,
                message: "Internal server error"
            )
        default:
            throw AnthropicClientError.serverError(
                statusCode: response.statusCode,
                message: "Unexpected status code"
            )
        }
    }

    private func handleStreamingError(_ response: HTTPURLResponse) -> AnthropicClientError {
        switch response.statusCode {
        case 401:
            return .invalidAPIKey
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            return .rateLimited(retryAfter: retryAfter)
        default:
            return .serverError(statusCode: response.statusCode, message: "Request failed")
        }
    }

    // MARK: - XRoads System Prompt

    /// Build the system prompt with XRoads context
    public static func buildSystemPrompt(
        basePrompt: String? = nil,
        context: ChatContext?
    ) -> String {
        var prompt = basePrompt ?? defaultSystemPrompt

        if let ctx = context {
            prompt += "\n\n" + ctx.systemPromptSection
        }

        return prompt
    }

    /// Default system prompt for XRoads orchestrator
    public static let defaultSystemPrompt = """
    You are the XRoads Orchestrator, an intelligent assistant that helps developers manage multi-agent coding workflows.

    ## Your Capabilities
    - Create PRDs (Product Requirements Documents) for features
    - Launch and manage nexus loops for parallel development
    - Provide guidance on using XRoads features
    - Help with git operations and worktree management
    - Coordinate between multiple AI coding agents (Claude, Gemini, Codex)

    ## Communication Style
    - Be concise and actionable
    - Use markdown formatting for clarity
    - When suggesting actions, be specific about what will happen
    - Proactively offer to create PRDs when users describe features

    ## Available Actions
    When you determine the user wants to perform an action, respond with a structured suggestion:
    - For PRD creation: Offer to generate a prd.json with user stories
    - For loop launching: Suggest starting a nexus-loop with specific parameters
    - For worktree operations: Recommend git worktree commands

    ## Important Rules
    - Never make up information about the codebase without checking
    - Always confirm before making destructive changes
    - Suggest the appropriate mode (API for quick tasks, Terminal for complex operations)
    """
}

// MARK: - Convenience Extensions

public extension AnthropicClient {
    /// Convert ChatMessage array to AnthropicMessage array
    static func toAnthropicMessages(_ messages: [ChatMessage]) -> [AnthropicMessage] {
        messages
            .filter { $0.role != .system } // System messages go in system prompt
            .map { message in
                AnthropicMessage(
                    role: message.role == .user ? "user" : "assistant",
                    content: message.content
                )
            }
    }

    /// Simple send message helper that takes ChatMessage array
    func send(
        messages: [ChatMessage],
        systemPrompt: String? = nil
    ) async throws -> String {
        let anthropicMessages = Self.toAnthropicMessages(messages)
        let response = try await sendMessage(messages: anthropicMessages, systemPrompt: systemPrompt)
        return response.textContent
    }

    /// Simple streaming helper that takes ChatMessage array
    func sendStreaming(
        messages: [ChatMessage],
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let anthropicMessages = Self.toAnthropicMessages(messages)
        return sendMessageStreaming(messages: anthropicMessages, systemPrompt: systemPrompt)
    }
}
