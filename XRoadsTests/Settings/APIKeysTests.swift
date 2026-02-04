//
//  APIKeysTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-022: Unit tests for API Keys Settings and validation
//

import XCTest
@testable import XRoadsLib

final class APIKeysTests: XCTestCase {

    // MARK: - APIProvider Tests

    func test_apiProvider_displayName() {
        XCTAssertEqual(APIProvider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(APIProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(APIProvider.google.displayName, "Google")
    }

    func test_apiProvider_iconName() {
        XCTAssertFalse(APIProvider.anthropic.iconName.isEmpty)
        XCTAssertFalse(APIProvider.openai.iconName.isEmpty)
        XCTAssertFalse(APIProvider.google.iconName.isEmpty)
    }

    func test_apiProvider_keyPrefix() {
        XCTAssertEqual(APIProvider.anthropic.keyPrefix, "sk-ant-")
        XCTAssertEqual(APIProvider.openai.keyPrefix, "sk-")
        XCTAssertEqual(APIProvider.google.keyPrefix, "AIza")
    }

    func test_apiProvider_keyPlaceholder() {
        XCTAssertTrue(APIProvider.anthropic.keyPlaceholder.hasPrefix("sk-ant-"))
        XCTAssertTrue(APIProvider.openai.keyPlaceholder.hasPrefix("sk-"))
        XCTAssertTrue(APIProvider.google.keyPlaceholder.hasPrefix("AIza"))
    }

    func test_apiProvider_docsURL() {
        XCTAssertNotNil(APIProvider.anthropic.docsURL)
        XCTAssertNotNil(APIProvider.openai.docsURL)
        XCTAssertNotNil(APIProvider.google.docsURL)

        XCTAssertTrue(APIProvider.anthropic.docsURL?.absoluteString.contains("anthropic") ?? false)
        XCTAssertTrue(APIProvider.openai.docsURL?.absoluteString.contains("openai") ?? false)
        XCTAssertTrue(APIProvider.google.docsURL?.absoluteString.contains("google") ?? false)
    }

    func test_apiProvider_allCases() {
        XCTAssertEqual(APIProvider.allCases.count, 3)
        XCTAssertTrue(APIProvider.allCases.contains(.anthropic))
        XCTAssertTrue(APIProvider.allCases.contains(.openai))
        XCTAssertTrue(APIProvider.allCases.contains(.google))
    }

    // MARK: - API Key Format Validation Tests

    func test_apiKeyValidation_emptyKey() {
        let result = APIProvider.anthropic.validateKeyFormat("")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "API key cannot be empty")
    }

    func test_apiKeyValidation_anthropic_validFormat() {
        let validKey = "sk-ant-api03-1234567890abcdefghij"
        let result = APIProvider.anthropic.validateKeyFormat(validKey)
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func test_apiKeyValidation_anthropic_invalidPrefix() {
        let invalidKey = "sk-1234567890abcdefghij"
        let result = APIProvider.anthropic.validateKeyFormat(invalidKey)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Anthropic keys should start with 'sk-ant-'")
    }

    func test_apiKeyValidation_anthropic_tooShort() {
        let shortKey = "sk-ant-api"
        let result = APIProvider.anthropic.validateKeyFormat(shortKey)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "API key appears too short")
    }

    func test_apiKeyValidation_openai_validFormat() {
        let validKey = "sk-proj-1234567890abcdefghij"
        let result = APIProvider.openai.validateKeyFormat(validKey)
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func test_apiKeyValidation_openai_invalidPrefix() {
        let invalidKey = "api-1234567890abcdefghij"
        let result = APIProvider.openai.validateKeyFormat(invalidKey)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "OpenAI keys should start with 'sk-'")
    }

    func test_apiKeyValidation_openai_tooShort() {
        let shortKey = "sk-short"
        let result = APIProvider.openai.validateKeyFormat(shortKey)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "API key appears too short")
    }

    func test_apiKeyValidation_google_validFormat() {
        let validKey = "AIzaSyDabc123defghij456klmnop789"
        let result = APIProvider.google.validateKeyFormat(validKey)
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func test_apiKeyValidation_google_invalidPrefix() {
        let invalidKey = "AG123456789abcdefghijklmnopqrs"
        let result = APIProvider.google.validateKeyFormat(invalidKey)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Google AI keys should start with 'AIza'")
    }

    func test_apiKeyValidation_google_tooShort() {
        let shortKey = "AIzaSyD123456789"
        let result = APIProvider.google.validateKeyFormat(shortKey)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "API key appears too short")
    }

    // MARK: - APIKeyValidationResult Tests

    func test_apiKeyValidationResult_valid() {
        let result = APIKeyValidationResult.valid
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func test_apiKeyValidationResult_verified() {
        let result = APIKeyValidationResult.verified
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func test_apiKeyValidationResult_invalid() {
        let result = APIKeyValidationResult.invalid(error: "Test error")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Test error")
    }

    func test_apiKeyValidationResult_testing() {
        let result = APIKeyValidationResult.testing
        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func test_apiKeyValidationResult_equality() {
        XCTAssertEqual(APIKeyValidationResult.valid, APIKeyValidationResult.valid)
        XCTAssertEqual(APIKeyValidationResult.verified, APIKeyValidationResult.verified)
        XCTAssertEqual(APIKeyValidationResult.testing, APIKeyValidationResult.testing)
        XCTAssertEqual(
            APIKeyValidationResult.invalid(error: "Same"),
            APIKeyValidationResult.invalid(error: "Same")
        )
        XCTAssertNotEqual(
            APIKeyValidationResult.invalid(error: "One"),
            APIKeyValidationResult.invalid(error: "Two")
        )
        XCTAssertNotEqual(APIKeyValidationResult.valid, APIKeyValidationResult.verified)
    }

    // MARK: - APIKeyState Tests

    func test_apiKeyState_creation() {
        let state = APIKeyState(
            provider: .anthropic,
            hasKey: true,
            isRevealed: false,
            cachedMaskedKey: "sk-a••••••••cdef",
            validationResult: .valid,
            isTesting: false
        )

        XCTAssertEqual(state.provider, .anthropic)
        XCTAssertTrue(state.hasKey)
        XCTAssertFalse(state.isRevealed)
        XCTAssertEqual(state.cachedMaskedKey, "sk-a••••••••cdef")
        XCTAssertEqual(state.validationResult, .valid)
        XCTAssertFalse(state.isTesting)
    }

    func test_apiKeyState_id() {
        let state = APIKeyState(provider: .openai)
        XCTAssertEqual(state.id, "openai")
    }

    func test_apiKeyState_defaults() {
        let state = APIKeyState(provider: .google)
        XCTAssertFalse(state.hasKey)
        XCTAssertFalse(state.isRevealed)
        XCTAssertNil(state.cachedMaskedKey)
        XCTAssertNil(state.validationResult)
        XCTAssertFalse(state.isTesting)
    }

    // MARK: - String Masking Tests (API Key Display)

    func test_apiKey_masked_displayShortKey() {
        let shortKey = "sk-abc"
        let masked = shortKey.masked
        // Keys <= 8 chars are fully masked
        XCTAssertEqual(masked, "••••••")
    }

    func test_apiKey_masked_displayLongKey() {
        let apiKey = "sk-ant-api03-1234567890"
        let masked = apiKey.masked

        // Should show first 4 and last 4 characters
        XCTAssertTrue(masked.hasPrefix("sk-a"))
        XCTAssertTrue(masked.hasSuffix("7890"))
        XCTAssertTrue(masked.contains("••••"))
    }

    func test_apiKey_masked_preservesLengthInfo() {
        let key1 = "sk-ant-api03-abc"
        let key2 = "sk-ant-api03-abcdefghijklmnop"

        // Both should have the same masking pattern (4 + dots + 4)
        // but the dots count shouldn't reveal exact length
        XCTAssertTrue(key1.masked.contains("••••••••"))
        XCTAssertTrue(key2.masked.contains("••••••••"))
    }

    func test_apiKey_fullyMasked() {
        let apiKey = "sk-ant-api03-1234567890abcdef"
        let masked = apiKey.fullyMasked

        // Should be all dots
        XCTAssertTrue(masked.allSatisfy { $0 == "•" })
        // Should not contain any original characters
        XCTAssertFalse(masked.contains("s"))
        XCTAssertFalse(masked.contains("k"))
    }

    func test_apiKey_fullyMasked_maxLength() {
        let veryLongKey = String(repeating: "a", count: 100)
        let masked = veryLongKey.fullyMasked

        // fullyMasked has max length of 32
        XCTAssertEqual(masked.count, 32)
    }

    // MARK: - KeychainService API Key Tests

    func test_keychainService_apiKey_saveAndRetrieve() async {
        let service = KeychainService.shared
        let testProvider = "test-api-\(UUID().uuidString)"
        let testKey = "sk-ant-api03-test1234567890"

        // Save API key
        do {
            try await service.saveAPIKey(provider: testProvider, key: testKey)
        } catch {
            XCTFail("Failed to save API key: \(error)")
            return
        }

        // Retrieve and verify
        let retrieved = await service.getAPIKey(provider: testProvider)
        XCTAssertEqual(retrieved, testKey)

        // Cleanup
        try? await service.deleteAPIKey(provider: testProvider)
    }

    func test_keychainService_apiKey_update() async {
        let service = KeychainService.shared
        let testProvider = "test-api-update-\(UUID().uuidString)"
        let firstKey = "sk-first-key-1234567890"
        let secondKey = "sk-second-key-0987654321"

        do {
            // Save first key
            try await service.saveAPIKey(provider: testProvider, key: firstKey)
            var retrieved = await service.getAPIKey(provider: testProvider)
            XCTAssertEqual(retrieved, firstKey)

            // Update with second key
            try await service.saveAPIKey(provider: testProvider, key: secondKey)
            retrieved = await service.getAPIKey(provider: testProvider)
            XCTAssertEqual(retrieved, secondKey)

            // Cleanup
            try await service.deleteAPIKey(provider: testProvider)
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }

    func test_keychainService_apiKey_delete() async {
        let service = KeychainService.shared
        let testProvider = "test-api-delete-\(UUID().uuidString)"
        let testKey = "sk-delete-me-1234567890"

        do {
            // Save key
            try await service.saveAPIKey(provider: testProvider, key: testKey)
            let hasAfterSave = await service.hasAPIKey(provider: testProvider)
            XCTAssertTrue(hasAfterSave)

            // Delete key
            try await service.deleteAPIKey(provider: testProvider)
            let hasAfterDelete = await service.hasAPIKey(provider: testProvider)
            XCTAssertFalse(hasAfterDelete)

            // Verify retrieval returns nil
            let retrieved = await service.getAPIKey(provider: testProvider)
            XCTAssertNil(retrieved)
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }

    func test_keychainService_apiKey_hasKey() async {
        let service = KeychainService.shared
        let testProvider = "test-api-has-\(UUID().uuidString)"

        // Initially no key
        let initialHas = await service.hasAPIKey(provider: testProvider)
        XCTAssertFalse(initialHas)

        // Save key
        try? await service.saveAPIKey(provider: testProvider, key: "sk-test-key-1234567890")

        // Now has key
        let nowHas = await service.hasAPIKey(provider: testProvider)
        XCTAssertTrue(nowHas)

        // Cleanup
        try? await service.deleteAPIKey(provider: testProvider)
    }

    func test_keychainService_apiKey_nonExistent() async {
        let service = KeychainService.shared
        let nonExistentProvider = "non-existent-provider-\(UUID().uuidString)"

        let result = await service.getAPIKey(provider: nonExistentProvider)
        XCTAssertNil(result)
    }

    // MARK: - API Key Secure Storage Tests

    func test_apiKey_notStoredInPlaintext() async {
        let service = KeychainService.shared
        let testProvider = "test-plaintext-\(UUID().uuidString)"
        let sensitiveKey = "sk-ant-api03-sensitive-secret-key-12345"

        do {
            try await service.saveAPIKey(provider: testProvider, key: sensitiveKey)

            // The key should be stored in Keychain, not in UserDefaults
            // Check that UserDefaults doesn't contain the key
            let userDefaultsValue = UserDefaults.standard.string(forKey: "api.key.\(testProvider)")
            XCTAssertNil(userDefaultsValue, "API key should not be stored in UserDefaults")

            // But we can still retrieve it from Keychain
            let retrieved = await service.getAPIKey(provider: testProvider)
            XCTAssertEqual(retrieved, sensitiveKey)

            // Cleanup
            try await service.deleteAPIKey(provider: testProvider)
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }
}
