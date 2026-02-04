//
//  KeychainService.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-021: Secure credential storage via macOS Keychain
//

import Foundation
import Security

// MARK: - KeychainError

/// Errors that can occur during Keychain operations
public enum KeychainError: Error, LocalizedError, Sendable, Equatable {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in Keychain"
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .invalidData:
            return "Invalid data format"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .encodingFailed:
            return "Failed to encode data for storage"
        case .decodingFailed:
            return "Failed to decode stored data"
        }
    }
}

// MARK: - KeychainItem

/// Represents an item stored in the Keychain
public struct KeychainItem: Codable, Sendable, Equatable {
    public let key: String
    public let value: String
    public let service: String
    public let accessGroup: String?

    public init(key: String, value: String, service: String = "com.xroads.credentials", accessGroup: String? = nil) {
        self.key = key
        self.value = value
        self.service = service
        self.accessGroup = accessGroup
    }
}

// MARK: - KeychainService

/// Actor for thread-safe Keychain operations
/// Provides secure storage for MCP credentials and API keys
public actor KeychainService {

    // MARK: - Singleton

    public static let shared = KeychainService()

    // MARK: - Constants

    private let defaultService = "com.xroads.credentials"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Save a string value to the Keychain
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The unique key identifier
    ///   - service: Optional service name (defaults to com.xroads.credentials)
    /// - Throws: KeychainError if the operation fails
    public func save(_ value: String, forKey key: String, service: String? = nil) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let serviceToUse = service ?? defaultService

        // Build query for checking existing item
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceToUse,
            kSecAttrAccount as String: key
        ]

        // Check if item already exists
        let existingStatus = SecItemCopyMatching(query as CFDictionary, nil)

        if existingStatus == errSecSuccess {
            // Update existing item
            let updateQuery: [String: Any] = [
                kSecValueData as String: data
            ]

            let updateStatus = SecItemUpdate(query as CFDictionary, updateQuery as CFDictionary)

            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if existingStatus == errSecItemNotFound {
            // Add new item
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(query as CFDictionary, nil)

            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else {
            throw KeychainError.unexpectedStatus(existingStatus)
        }
    }

    /// Retrieve a string value from the Keychain
    /// - Parameters:
    ///   - key: The unique key identifier
    ///   - service: Optional service name (defaults to com.xroads.credentials)
    /// - Returns: The stored string value
    /// - Throws: KeychainError if the operation fails
    public func retrieve(forKey key: String, service: String? = nil) throws -> String {
        let serviceToUse = service ?? defaultService

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceToUse,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return value
    }

    /// Delete a value from the Keychain
    /// - Parameters:
    ///   - key: The unique key identifier
    ///   - service: Optional service name (defaults to com.xroads.credentials)
    /// - Throws: KeychainError if the operation fails
    public func delete(forKey key: String, service: String? = nil) throws {
        let serviceToUse = service ?? defaultService

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceToUse,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Check if a key exists in the Keychain
    /// - Parameters:
    ///   - key: The unique key identifier
    ///   - service: Optional service name (defaults to com.xroads.credentials)
    /// - Returns: True if the key exists
    public func exists(forKey key: String, service: String? = nil) -> Bool {
        let serviceToUse = service ?? defaultService

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceToUse,
            kSecAttrAccount as String: key
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete all items for a service
    /// - Parameter service: Optional service name (defaults to com.xroads.credentials)
    /// - Throws: KeychainError if the operation fails
    public func deleteAll(service: String? = nil) throws {
        let serviceToUse = service ?? defaultService

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceToUse
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - MCP Credential Helpers

    /// MCP credential key prefix
    private let mcpCredentialPrefix = "mcp.credential."

    /// Save an MCP credential
    /// - Parameters:
    ///   - mcpId: The MCP identifier
    ///   - credential: The credential value
    public func saveMCPCredential(mcpId: String, credential: String) async throws {
        try save(credential, forKey: "\(mcpCredentialPrefix)\(mcpId)")
    }

    /// Retrieve an MCP credential
    /// - Parameter mcpId: The MCP identifier
    /// - Returns: The credential value, or nil if not found
    public func getMCPCredential(mcpId: String) async -> String? {
        try? retrieve(forKey: "\(mcpCredentialPrefix)\(mcpId)")
    }

    /// Delete an MCP credential
    /// - Parameter mcpId: The MCP identifier
    public func deleteMCPCredential(mcpId: String) async throws {
        try delete(forKey: "\(mcpCredentialPrefix)\(mcpId)")
    }

    /// Check if an MCP has stored credentials
    /// - Parameter mcpId: The MCP identifier
    /// - Returns: True if credentials exist
    public func hasMCPCredential(mcpId: String) async -> Bool {
        exists(forKey: "\(mcpCredentialPrefix)\(mcpId)")
    }

    // MARK: - API Key Helpers

    /// API key prefix
    private let apiKeyPrefix = "api.key."

    /// Save an API key
    /// - Parameters:
    ///   - provider: The API provider (e.g., "anthropic", "openai", "google")
    ///   - key: The API key value
    public func saveAPIKey(provider: String, key: String) async throws {
        try save(key, forKey: "\(apiKeyPrefix)\(provider)")
    }

    /// Retrieve an API key
    /// - Parameter provider: The API provider
    /// - Returns: The API key value, or nil if not found
    public func getAPIKey(provider: String) async -> String? {
        try? retrieve(forKey: "\(apiKeyPrefix)\(provider)")
    }

    /// Delete an API key
    /// - Parameter provider: The API provider
    public func deleteAPIKey(provider: String) async throws {
        try delete(forKey: "\(apiKeyPrefix)\(provider)")
    }

    /// Check if an API key exists for a provider
    /// - Parameter provider: The API provider
    /// - Returns: True if an API key exists
    public func hasAPIKey(provider: String) async -> Bool {
        exists(forKey: "\(apiKeyPrefix)\(provider)")
    }
}

// MARK: - Credential Masking

extension String {
    /// Returns a masked version of the string for display
    /// Shows first 4 and last 4 characters with dots in between
    public var masked: String {
        guard count > 8 else {
            return String(repeating: "•", count: count)
        }
        let prefix = String(self.prefix(4))
        let suffix = String(self.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }

    /// Returns a fully masked version (all dots)
    public var fullyMasked: String {
        String(repeating: "•", count: min(count, 32))
    }
}
