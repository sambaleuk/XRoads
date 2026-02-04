//
//  APIConfig.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-014: Configuration model for Anthropic API
//

import Foundation

// MARK: - APIProvider

/// Supported API providers for the orchestrator
public enum APIProvider: String, Codable, Sendable, CaseIterable {
    case anthropic
    case openai
    case google

    public var displayName: String {
        switch self {
        case .anthropic:
            return "Anthropic"
        case .openai:
            return "OpenAI"
        case .google:
            return "Google"
        }
    }

    public var baseURL: URL {
        switch self {
        case .anthropic:
            return URL(string: "https://api.anthropic.com/v1")!
        case .openai:
            return URL(string: "https://api.openai.com/v1")!
        case .google:
            return URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        }
    }

    public var messagesEndpoint: String {
        switch self {
        case .anthropic:
            return "/messages"
        case .openai:
            return "/chat/completions"
        case .google:
            return "/models/{model}:generateContent"
        }
    }

    public var apiVersionHeader: (key: String, value: String)? {
        switch self {
        case .anthropic:
            return ("anthropic-version", "2023-06-01")
        case .openai, .google:
            return nil
        }
    }

    public var apiKeyHeader: String {
        switch self {
        case .anthropic:
            return "x-api-key"
        case .openai:
            return "Authorization"
        case .google:
            return "x-goog-api-key"
        }
    }

    public var defaultModel: String {
        switch self {
        case .anthropic:
            return "claude-sonnet-4-20250514"
        case .openai:
            return "gpt-4-turbo-preview"
        case .google:
            return "gemini-pro"
        }
    }
}

// MARK: - APIConfig

/// Configuration for API requests to AI providers
public struct APIConfig: Codable, Sendable, Equatable {
    public let provider: APIProvider
    public let model: String
    public let maxTokens: Int
    public let temperature: Double
    public let stream: Bool
    public let timeout: TimeInterval

    // Default configurations
    public static let defaultAnthropic = APIConfig(
        provider: .anthropic,
        model: "claude-sonnet-4-20250514",
        maxTokens: 4096,
        temperature: 0.7,
        stream: true,
        timeout: 60.0
    )

    public static let defaultOpenAI = APIConfig(
        provider: .openai,
        model: "gpt-4-turbo-preview",
        maxTokens: 4096,
        temperature: 0.7,
        stream: true,
        timeout: 60.0
    )

    public static let defaultGoogle = APIConfig(
        provider: .google,
        model: "gemini-pro",
        maxTokens: 4096,
        temperature: 0.7,
        stream: true,
        timeout: 60.0
    )

    public init(
        provider: APIProvider = .anthropic,
        model: String? = nil,
        maxTokens: Int = 4096,
        temperature: Double = 0.7,
        stream: Bool = true,
        timeout: TimeInterval = 60.0
    ) {
        self.provider = provider
        self.model = model ?? provider.defaultModel
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stream = stream
        self.timeout = timeout
    }

    /// Create a copy with modified parameters
    public func with(
        provider: APIProvider? = nil,
        model: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        stream: Bool? = nil,
        timeout: TimeInterval? = nil
    ) -> APIConfig {
        APIConfig(
            provider: provider ?? self.provider,
            model: model ?? self.model,
            maxTokens: maxTokens ?? self.maxTokens,
            temperature: temperature ?? self.temperature,
            stream: stream ?? self.stream,
            timeout: timeout ?? self.timeout
        )
    }
}

// MARK: - APIKeyStorage

/// Enum for API key storage keys in Keychain
public enum APIKeyStorage: String, CaseIterable {
    case anthropic = "com.xroads.apikey.anthropic"
    case openai = "com.xroads.apikey.openai"
    case google = "com.xroads.apikey.google"

    public var provider: APIProvider {
        switch self {
        case .anthropic: return .anthropic
        case .openai: return .openai
        case .google: return .google
        }
    }

    public static func key(for provider: APIProvider) -> APIKeyStorage {
        switch provider {
        case .anthropic: return .anthropic
        case .openai: return .openai
        case .google: return .google
        }
    }
}

// MARK: - StreamEvent

/// Events received during streaming API response
public enum StreamEvent: Sendable {
    case start
    case delta(String)
    case complete(String)
    case error(AnthropicClientError)
}

// MARK: - AnthropicClientError

/// Errors specific to Anthropic API interactions
public enum AnthropicClientError: Error, LocalizedError, Sendable, Equatable {
    case noAPIKey
    case invalidAPIKey
    case invalidRequest(String)
    case rateLimited(retryAfter: Int?)
    case serverError(statusCode: Int, message: String)
    case networkError(String)
    case streamingError(String)
    case decodingError(String)
    case timeout
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Anthropic API key in Settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your Anthropic API key in Settings."
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please retry after \(seconds) seconds."
            }
            return "Rate limited. Please wait before sending another request."
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .timeout:
            return "Request timed out. Please try again."
        case .cancelled:
            return "Request was cancelled."
        }
    }

    /// Whether this error is retryable
    public var isRetryable: Bool {
        switch self {
        case .rateLimited:
            return true
        case .serverError(let statusCode, _) where statusCode >= 500:
            return true
        case .networkError:
            return true
        case .timeout:
            return true
        default:
            return false
        }
    }
}

// MARK: - Anthropic API Response Types

/// Represents a message in the Anthropic API format
public struct AnthropicMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Request body for Anthropic messages API
public struct AnthropicRequest: Codable, Sendable {
    public let model: String
    public let maxTokens: Int
    public let system: String?
    public let messages: [AnthropicMessage]
    public let stream: Bool
    public let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
        case temperature
    }

    public init(
        model: String,
        maxTokens: Int,
        system: String?,
        messages: [AnthropicMessage],
        stream: Bool,
        temperature: Double?
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.messages = messages
        self.stream = stream
        self.temperature = temperature
    }
}

/// Response from Anthropic messages API (non-streaming)
public struct AnthropicResponse: Codable, Sendable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [ContentBlock]
    public let model: String
    public let stopReason: String?
    public let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }

    public struct ContentBlock: Codable, Sendable {
        public let type: String
        public let text: String?
    }

    public struct Usage: Codable, Sendable {
        public let inputTokens: Int
        public let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    /// Extract the text content from the response
    public var textContent: String {
        content.compactMap { $0.text }.joined()
    }
}

/// Error response from Anthropic API
public struct AnthropicErrorResponse: Codable, Sendable {
    public let type: String
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let type: String
        public let message: String
    }
}
