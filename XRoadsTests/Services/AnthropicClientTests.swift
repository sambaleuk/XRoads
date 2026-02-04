//
//  AnthropicClientTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-014: Unit tests for AnthropicClient API request formation
//

import XCTest
@testable import XRoadsLib

final class AnthropicClientTests: XCTestCase {

    // MARK: - Test Properties

    var client: AnthropicClient!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        client = AnthropicClient()
    }

    override func tearDown() async throws {
        client = nil
        try await super.tearDown()
    }

    // MARK: - Test: API Key Management

    func test_hasAPIKey_returnsFalse_whenNoKeySet() async {
        // Given: A new client with no API key

        // When: Checking if API key exists
        let hasKey = await client.hasAPIKey()

        // Then: Should return false
        XCTAssertFalse(hasKey, "Client should not have API key when none is set")
    }

    func test_hasAPIKey_returnsTrue_whenKeyIsSet() async {
        // Given: A client with an API key set
        await client.setAPIKey("sk-ant-test-key-12345")

        // When: Checking if API key exists
        let hasKey = await client.hasAPIKey()

        // Then: Should return true
        XCTAssertTrue(hasKey, "Client should have API key after setting one")
    }

    func test_hasAPIKey_returnsFalse_whenKeyIsEmpty() async {
        // Given: A client with an empty API key
        await client.setAPIKey("")

        // When: Checking if API key exists
        let hasKey = await client.hasAPIKey()

        // Then: Should return false
        XCTAssertFalse(hasKey, "Client should not have API key when empty string is set")
    }

    func test_getMaskedAPIKey_returnsNil_whenNoKey() async {
        // Given: A new client with no API key

        // When: Getting masked API key
        let maskedKey = await client.getMaskedAPIKey()

        // Then: Should return nil
        XCTAssertNil(maskedKey, "Masked key should be nil when no key is set")
    }

    func test_getMaskedAPIKey_returnsMaskedFormat() async {
        // Given: A client with a valid API key
        await client.setAPIKey("sk-ant-api3-abcdef123456")

        // When: Getting masked API key
        let maskedKey = await client.getMaskedAPIKey()

        // Then: Should return masked format (first 4 + ... + last 4)
        XCTAssertNotNil(maskedKey, "Masked key should not be nil")
        XCTAssertEqual(maskedKey, "sk-a...3456", "Masked key should show first 4 and last 4 characters")
    }

    // MARK: - Test: API Key Validation

    func test_validateAPIKeyFormat_validKey_returnsTrue() async {
        // Given: A properly formatted Anthropic API key
        let validKey = "sk-ant-api03-validkey1234567890"

        // When: Validating the key format
        let isValid = await client.validateAPIKeyFormat(validKey)

        // Then: Should return true
        XCTAssertTrue(isValid, "Valid API key format should be accepted")
    }

    func test_validateAPIKeyFormat_invalidPrefix_returnsFalse() async {
        // Given: An API key with wrong prefix
        let invalidKey = "sk-openai-wrong-prefix"

        // When: Validating the key format
        let isValid = await client.validateAPIKeyFormat(invalidKey)

        // Then: Should return false
        XCTAssertFalse(isValid, "API key with invalid prefix should be rejected")
    }

    func test_validateAPIKeyFormat_tooShort_returnsFalse() async {
        // Given: An API key that's too short
        let shortKey = "sk-ant-short"

        // When: Validating the key format
        let isValid = await client.validateAPIKeyFormat(shortKey)

        // Then: Should return false
        XCTAssertFalse(isValid, "API key that's too short should be rejected")
    }

    // MARK: - Test: Configuration

    func test_defaultConfig_usesAnthropic() async {
        // Given: A new client with default config

        // When: Getting the config
        let config = await client.getConfig()

        // Then: Should use Anthropic provider
        XCTAssertEqual(config.provider, .anthropic, "Default provider should be Anthropic")
        XCTAssertEqual(config.model, "claude-sonnet-4-20250514", "Default model should be claude-sonnet-4")
        XCTAssertTrue(config.stream, "Default should enable streaming")
        XCTAssertEqual(config.maxTokens, 4096, "Default max tokens should be 4096")
    }

    func test_setConfig_updatesConfiguration() async {
        // Given: A custom config
        let customConfig = APIConfig(
            provider: .anthropic,
            model: "claude-3-opus-20240229",
            maxTokens: 8192,
            temperature: 0.5,
            stream: false,
            timeout: 120.0
        )

        // When: Setting the custom config
        await client.setConfig(customConfig)
        let config = await client.getConfig()

        // Then: Should reflect the custom values
        XCTAssertEqual(config.model, "claude-3-opus-20240229", "Model should be updated")
        XCTAssertEqual(config.maxTokens, 8192, "Max tokens should be updated")
        XCTAssertEqual(config.temperature, 0.5, "Temperature should be updated")
        XCTAssertFalse(config.stream, "Streaming should be disabled")
        XCTAssertEqual(config.timeout, 120.0, "Timeout should be updated")
    }

    // MARK: - Test: Message Conversion

    func test_toAnthropicMessages_convertsUserMessage() {
        // Given: A user ChatMessage
        let chatMessage = ChatMessage.user("Hello, how are you?")

        // When: Converting to Anthropic messages
        let anthropicMessages = AnthropicClient.toAnthropicMessages([chatMessage])

        // Then: Should convert correctly
        XCTAssertEqual(anthropicMessages.count, 1, "Should have one message")
        XCTAssertEqual(anthropicMessages[0].role, "user", "Role should be 'user'")
        XCTAssertEqual(anthropicMessages[0].content, "Hello, how are you?", "Content should match")
    }

    func test_toAnthropicMessages_convertsAssistantMessage() {
        // Given: An assistant ChatMessage
        let chatMessage = ChatMessage.assistant("I'm doing well, thank you!")

        // When: Converting to Anthropic messages
        let anthropicMessages = AnthropicClient.toAnthropicMessages([chatMessage])

        // Then: Should convert correctly
        XCTAssertEqual(anthropicMessages.count, 1, "Should have one message")
        XCTAssertEqual(anthropicMessages[0].role, "assistant", "Role should be 'assistant'")
        XCTAssertEqual(anthropicMessages[0].content, "I'm doing well, thank you!", "Content should match")
    }

    func test_toAnthropicMessages_excludesSystemMessages() {
        // Given: Messages including a system message
        let messages = [
            ChatMessage.system("You are a helpful assistant"),
            ChatMessage.user("Hello"),
            ChatMessage.assistant("Hi there!")
        ]

        // When: Converting to Anthropic messages
        let anthropicMessages = AnthropicClient.toAnthropicMessages(messages)

        // Then: Should exclude system messages
        XCTAssertEqual(anthropicMessages.count, 2, "Should have two messages (system excluded)")
        XCTAssertEqual(anthropicMessages[0].role, "user", "First message should be user")
        XCTAssertEqual(anthropicMessages[1].role, "assistant", "Second message should be assistant")
    }

    func test_toAnthropicMessages_preservesConversationOrder() {
        // Given: A conversation with multiple messages
        let messages = [
            ChatMessage.user("What's the weather?"),
            ChatMessage.assistant("I don't have access to weather data."),
            ChatMessage.user("Can you help with coding?"),
            ChatMessage.assistant("Yes, I can help with that!")
        ]

        // When: Converting to Anthropic messages
        let anthropicMessages = AnthropicClient.toAnthropicMessages(messages)

        // Then: Should preserve order
        XCTAssertEqual(anthropicMessages.count, 4, "Should have four messages")
        XCTAssertEqual(anthropicMessages[0].content, "What's the weather?")
        XCTAssertEqual(anthropicMessages[1].content, "I don't have access to weather data.")
        XCTAssertEqual(anthropicMessages[2].content, "Can you help with coding?")
        XCTAssertEqual(anthropicMessages[3].content, "Yes, I can help with that!")
    }

    // MARK: - Test: System Prompt Building

    func test_buildSystemPrompt_withoutContext_returnsDefaultPrompt() {
        // Given: No context

        // When: Building system prompt
        let prompt = AnthropicClient.buildSystemPrompt(context: nil)

        // Then: Should contain default prompt elements
        XCTAssertTrue(prompt.contains("XRoads Orchestrator"), "Should mention XRoads Orchestrator")
        XCTAssertTrue(prompt.contains("PRDs"), "Should mention PRDs capability")
        XCTAssertTrue(prompt.contains("nexus loops"), "Should mention nexus loops")
    }

    func test_buildSystemPrompt_withContext_includesContextSection() {
        // Given: A context with project information
        let context = ChatContext(
            projectPath: "/Users/test/MyProject",
            currentBranch: "feat/new-feature",
            worktrees: ["worktree-1", "worktree-2"],
            availableSkills: ["prd", "commit"],
            mcpServers: ["xroads-mcp"],
            dashboardMode: "multi"
        )

        // When: Building system prompt with context
        let prompt = AnthropicClient.buildSystemPrompt(context: context)

        // Then: Should include context information
        XCTAssertTrue(prompt.contains("/Users/test/MyProject"), "Should include project path")
        XCTAssertTrue(prompt.contains("feat/new-feature"), "Should include branch name")
        XCTAssertTrue(prompt.contains("worktree-1"), "Should include worktrees")
        XCTAssertTrue(prompt.contains("prd"), "Should include skills")
        XCTAssertTrue(prompt.contains("xroads-mcp"), "Should include MCP servers")
    }

    func test_buildSystemPrompt_withCustomBase_usesCustomPrompt() {
        // Given: A custom base prompt
        let customPrompt = "You are a custom assistant for testing."

        // When: Building system prompt with custom base
        let prompt = AnthropicClient.buildSystemPrompt(basePrompt: customPrompt, context: nil)

        // Then: Should use custom prompt
        XCTAssertTrue(prompt.contains("custom assistant for testing"), "Should use custom base prompt")
        XCTAssertFalse(prompt.contains("XRoads Orchestrator"), "Should not include default prompt")
    }

    // MARK: - Test: Error Cases

    func test_sendMessage_withoutAPIKey_throwsNoAPIKeyError() async {
        // Given: A client without an API key

        // When/Then: Attempting to send a message should throw
        do {
            let messages = [AnthropicMessage(role: "user", content: "Hello")]
            _ = try await client.sendMessage(messages: messages, systemPrompt: nil)
            XCTFail("Should have thrown an error")
        } catch let error as AnthropicClientError {
            XCTAssertEqual(error, .noAPIKey, "Should throw noAPIKey error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Test: Error Types

    func test_anthropicClientError_isRetryable_rateLimited() {
        // Given: A rate limited error
        let error = AnthropicClientError.rateLimited(retryAfter: 30)

        // Then: Should be retryable
        XCTAssertTrue(error.isRetryable, "Rate limited errors should be retryable")
    }

    func test_anthropicClientError_isRetryable_serverError500() {
        // Given: A 500 server error
        let error = AnthropicClientError.serverError(statusCode: 500, message: "Internal error")

        // Then: Should be retryable
        XCTAssertTrue(error.isRetryable, "5xx server errors should be retryable")
    }

    func test_anthropicClientError_isNotRetryable_invalidAPIKey() {
        // Given: An invalid API key error
        let error = AnthropicClientError.invalidAPIKey

        // Then: Should not be retryable
        XCTAssertFalse(error.isRetryable, "Invalid API key errors should not be retryable")
    }

    func test_anthropicClientError_isNotRetryable_invalidRequest() {
        // Given: An invalid request error
        let error = AnthropicClientError.invalidRequest("Bad format")

        // Then: Should not be retryable
        XCTAssertFalse(error.isRetryable, "Invalid request errors should not be retryable")
    }

    // MARK: - Test: APIConfig

    func test_apiConfig_withModifier_createsNewInstance() {
        // Given: A default config
        let original = APIConfig.defaultAnthropic

        // When: Creating modified version
        let modified = original.with(maxTokens: 8192, temperature: 0.3)

        // Then: Original should be unchanged, modified should have new values
        XCTAssertEqual(original.maxTokens, 4096, "Original should be unchanged")
        XCTAssertEqual(modified.maxTokens, 8192, "Modified should have new max tokens")
        XCTAssertEqual(modified.temperature, 0.3, "Modified should have new temperature")
        XCTAssertEqual(modified.model, original.model, "Unmodified fields should be preserved")
    }

    func test_apiProvider_baseURL_correct() {
        // Then: Each provider should have correct base URL
        XCTAssertEqual(
            APIProvider.anthropic.baseURL.absoluteString,
            "https://api.anthropic.com/v1",
            "Anthropic base URL should be correct"
        )
    }

    func test_apiProvider_apiKeyHeader_correct() {
        // Then: Each provider should have correct API key header
        XCTAssertEqual(APIProvider.anthropic.apiKeyHeader, "x-api-key", "Anthropic should use x-api-key header")
        XCTAssertEqual(APIProvider.openai.apiKeyHeader, "Authorization", "OpenAI should use Authorization header")
    }

    // MARK: - Test: AnthropicRequest Encoding

    func test_anthropicRequest_encodesCorrectly() throws {
        // Given: A request object
        let request = AnthropicRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 4096,
            system: "You are helpful",
            messages: [AnthropicMessage(role: "user", content: "Hello")],
            stream: true,
            temperature: 0.7
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then: Should have correct structure
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-20250514")
        XCTAssertEqual(json["max_tokens"] as? Int, 4096)
        XCTAssertEqual(json["system"] as? String, "You are helpful")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["temperature"] as? Double, 0.7)

        let messages = json["messages"] as! [[String: Any]]
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        XCTAssertEqual(messages[0]["content"] as? String, "Hello")
    }

    // MARK: - Test: AnthropicResponse Decoding

    func test_anthropicResponse_decodesCorrectly() throws {
        // Given: A JSON response from Anthropic API
        let jsonString = """
        {
            "id": "msg_123",
            "type": "message",
            "role": "assistant",
            "content": [{"type": "text", "text": "Hello! How can I help?"}],
            "model": "claude-sonnet-4-20250514",
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 10, "output_tokens": 8}
        }
        """

        // When: Decoding the response
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        // Then: Should parse correctly
        XCTAssertEqual(response.id, "msg_123")
        XCTAssertEqual(response.role, "assistant")
        XCTAssertEqual(response.textContent, "Hello! How can I help?")
        XCTAssertEqual(response.usage.inputTokens, 10)
        XCTAssertEqual(response.usage.outputTokens, 8)
    }

    // MARK: - Test: StreamEvent

    func test_streamEvent_cases() {
        // Given: Different stream events

        // Then: Each case should be distinguishable
        let start = StreamEvent.start
        let delta = StreamEvent.delta("chunk")
        let complete = StreamEvent.complete("full content")
        let error = StreamEvent.error(.timeout)

        // Verify they can be pattern matched
        switch start {
        case .start: break
        default: XCTFail("Should be start event")
        }

        switch delta {
        case .delta(let text):
            XCTAssertEqual(text, "chunk")
        default: XCTFail("Should be delta event")
        }

        switch complete {
        case .complete(let content):
            XCTAssertEqual(content, "full content")
        default: XCTFail("Should be complete event")
        }

        switch error {
        case .error(let err):
            XCTAssertEqual(err, .timeout)
        default: XCTFail("Should be error event")
        }
    }
}
