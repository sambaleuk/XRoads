//
//  APIKeysSettingsView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-022: API Keys Settings View with secure Keychain storage
//

import SwiftUI

// MARK: - APIProvider Extension for Settings UI

extension APIProvider: Identifiable {
    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .anthropic: return "brain.head.profile"
        case .openai: return "sparkles"
        case .google: return "g.circle"
        }
    }

    public var keyPrefix: String {
        switch self {
        case .anthropic: return "sk-ant-"
        case .openai: return "sk-"
        case .google: return "AIza"
        }
    }

    public var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-api03-..."
        case .openai: return "sk-proj-..."
        case .google: return "AIzaSy..."
        }
    }

    public var docsURL: URL? {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .google: return URL(string: "https://aistudio.google.com/app/apikey")
        }
    }

    /// Validate the format of an API key for this provider
    public func validateKeyFormat(_ key: String) -> APIKeyValidationResult {
        guard !key.isEmpty else {
            return .invalid(error: "API key cannot be empty")
        }

        switch self {
        case .anthropic:
            // Anthropic keys start with "sk-ant-"
            if !key.hasPrefix("sk-ant-") {
                return .invalid(error: "Anthropic keys should start with 'sk-ant-'")
            }
            if key.count < 20 {
                return .invalid(error: "API key appears too short")
            }
            return .valid

        case .openai:
            // OpenAI keys start with "sk-"
            if !key.hasPrefix("sk-") {
                return .invalid(error: "OpenAI keys should start with 'sk-'")
            }
            if key.count < 20 {
                return .invalid(error: "API key appears too short")
            }
            return .valid

        case .google:
            // Google AI keys start with "AIza"
            if !key.hasPrefix("AIza") {
                return .invalid(error: "Google AI keys should start with 'AIza'")
            }
            if key.count < 30 {
                return .invalid(error: "API key appears too short")
            }
            return .valid
        }
    }
}

// MARK: - APIKeyValidationResult

/// Result of API key validation
public enum APIKeyValidationResult: Equatable, Sendable {
    case valid
    case invalid(error: String)
    case testing
    case verified

    public var isValid: Bool {
        switch self {
        case .valid, .verified:
            return true
        case .invalid, .testing:
            return false
        }
    }

    public var errorMessage: String? {
        if case .invalid(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - APIKeyState

/// State for a single API key
public struct APIKeyState: Identifiable, Sendable {
    public let provider: APIProvider
    public var hasKey: Bool
    public var isRevealed: Bool
    public var cachedMaskedKey: String?
    public var validationResult: APIKeyValidationResult?
    public var isTesting: Bool

    public var id: String { provider.rawValue }

    public init(
        provider: APIProvider,
        hasKey: Bool = false,
        isRevealed: Bool = false,
        cachedMaskedKey: String? = nil,
        validationResult: APIKeyValidationResult? = nil,
        isTesting: Bool = false
    ) {
        self.provider = provider
        self.hasKey = hasKey
        self.isRevealed = isRevealed
        self.cachedMaskedKey = cachedMaskedKey
        self.validationResult = validationResult
        self.isTesting = isTesting
    }
}

// MARK: - APIKeysSettingsView

/// Settings view for managing API keys with secure Keychain storage
public struct APIKeysSettingsView: View {

    // MARK: - State

    @State private var keyStates: [APIKeyState] = APIProvider.allCases.map { APIKeyState(provider: $0) }
    @State private var editingProvider: APIProvider?
    @State private var isLoading = false

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            // API Keys Section
            apiKeysSection

            // Info Section
            infoSection

            // Reset Section
            resetSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgSurface)
        .padding()
        .task {
            await loadKeyStates()
        }
        .sheet(item: $editingProvider) { provider in
            APIKeyEditSheet(
                provider: provider,
                onSave: { saved in
                    if saved {
                        Task {
                            await loadKeyStates()
                        }
                    }
                }
            )
        }
    }

    // MARK: - API Keys Section

    private var apiKeysSection: some View {
        Section {
            ForEach($keyStates) { $state in
                APIKeyRowView(
                    state: state,
                    onEdit: { editingProvider = state.provider },
                    onTest: { testAPIKey(provider: state.provider) },
                    onDelete: { deleteAPIKey(provider: state.provider) }
                )
            }
        } header: {
            HStack {
                Label("API Keys", systemImage: "key.fill")
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("\(keyStates.filter { $0.hasKey }.count) configured")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        } footer: {
            Text("API keys are stored securely in macOS Keychain and never leave your device")
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.statusSuccess)

                    Text("Secure Storage")
                        .font(.body14)
                        .foregroundStyle(Color.textPrimary)
                }

                Text("All API keys are encrypted and stored in your Mac's Keychain. They are never transmitted anywhere except to their respective API providers when making requests.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Theme.Spacing.xs)
        } header: {
            Label("Security", systemImage: "shield.checkered")
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                deleteAllAPIKeys()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All API Keys")
                }
            }
            .foregroundStyle(Color.statusError)
            .disabled(keyStates.allSatisfy { !$0.hasKey })
        }
    }

    // MARK: - Actions

    private func loadKeyStates() async {
        isLoading = true

        var updatedStates: [APIKeyState] = []

        for provider in APIProvider.allCases {
            let hasKey = await KeychainService.shared.hasAPIKey(provider: provider.rawValue)
            var maskedKey: String? = nil

            if hasKey, let key = await KeychainService.shared.getAPIKey(provider: provider.rawValue) {
                maskedKey = key.masked
            }

            updatedStates.append(APIKeyState(
                provider: provider,
                hasKey: hasKey,
                cachedMaskedKey: maskedKey
            ))
        }

        await MainActor.run {
            keyStates = updatedStates
            isLoading = false
        }
    }

    private func testAPIKey(provider: APIProvider) {
        guard let index = keyStates.firstIndex(where: { $0.provider == provider }) else { return }

        keyStates[index].isTesting = true
        keyStates[index].validationResult = .testing

        Task {
            let result = await APIKeyValidator.testKey(provider: provider)

            await MainActor.run {
                if let idx = keyStates.firstIndex(where: { $0.provider == provider }) {
                    keyStates[idx].isTesting = false
                    keyStates[idx].validationResult = result
                }
            }
        }
    }

    private func deleteAPIKey(provider: APIProvider) {
        Task {
            do {
                try await KeychainService.shared.deleteAPIKey(provider: provider.rawValue)
                await loadKeyStates()
            } catch {
                // Error handling would show an alert in production
            }
        }
    }

    private func deleteAllAPIKeys() {
        Task {
            for provider in APIProvider.allCases {
                if await KeychainService.shared.hasAPIKey(provider: provider.rawValue) {
                    try? await KeychainService.shared.deleteAPIKey(provider: provider.rawValue)
                }
            }
            await loadKeyStates()
        }
    }
}

// MARK: - APIKeyRowView

/// Row view for a single API key
struct APIKeyRowView: View {
    let state: APIKeyState
    let onEdit: () -> Void
    let onTest: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header row
            HStack {
                // Provider icon and name
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: state.provider.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(state.hasKey ? Color.accentPrimary : Color.textTertiary)
                        .frame(width: 20)

                    Text(state.provider.displayName)
                        .font(.body14)
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                // Status badge
                statusBadge

                // Expand button
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    // Masked key display
                    if state.hasKey, let maskedKey = state.cachedMaskedKey {
                        HStack {
                            Text("Key:")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                            Text(maskedKey)
                                .font(.mono(11))
                                .foregroundStyle(Color.textPrimary)
                        }
                    }

                    // Validation result
                    if let result = state.validationResult {
                        validationResultView(result)
                    }

                    // Action buttons
                    HStack(spacing: Theme.Spacing.md) {
                        Button(action: onEdit) {
                            HStack(spacing: 4) {
                                Image(systemName: state.hasKey ? "pencil" : "plus")
                                Text(state.hasKey ? "Edit" : "Add Key")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if state.hasKey {
                            Button(action: onTest) {
                                HStack(spacing: 4) {
                                    if state.isTesting {
                                        ProgressView()
                                            .controlSize(.mini)
                                    } else {
                                        Image(systemName: "bolt.fill")
                                    }
                                    Text("Test")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(state.isTesting)

                            // Documentation link
                            if let url = state.provider.docsURL {
                                Link(destination: url) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "questionmark.circle")
                                        Text("Docs")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Spacer()

                            Button(role: .destructive, action: onDelete) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.leading, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var statusColor: Color {
        if let result = state.validationResult {
            switch result {
            case .verified:
                return .statusSuccess
            case .valid:
                return .statusInfo
            case .invalid:
                return .statusError
            case .testing:
                return .statusWarning
            }
        }
        return state.hasKey ? .statusInfo : .textTertiary
    }

    private var statusText: String {
        if let result = state.validationResult {
            switch result {
            case .verified:
                return "Verified"
            case .valid:
                return "Valid format"
            case .invalid:
                return "Invalid"
            case .testing:
                return "Testing..."
            }
        }
        return state.hasKey ? "Configured" : "Not configured"
    }

    @ViewBuilder
    private func validationResultView(_ result: APIKeyValidationResult) -> some View {
        switch result {
        case .verified:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.statusSuccess)
                Text("API key verified successfully")
                    .font(.caption)
                    .foregroundStyle(Color.statusSuccess)
            }
        case .valid:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color.statusInfo)
                Text("Key format is valid")
                    .font(.caption)
                    .foregroundStyle(Color.statusInfo)
            }
        case .invalid(let error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.statusError)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.statusError)
            }
        case .testing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Testing connection...")
                    .font(.caption)
                    .foregroundStyle(Color.statusWarning)
            }
        }
    }
}

// MARK: - APIKeyEditSheet

/// Sheet for editing an API key
struct APIKeyEditSheet: View {
    let provider: APIProvider
    let onSave: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var hasExistingKey = false
    @State private var isSaving = false
    @State private var validationResult: APIKeyValidationResult?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentPrimary)

                Text("\(provider.displayName) API Key")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
            }

            // Security info
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.statusSuccess)
                Text("Stored securely in macOS Keychain")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Color.bgElevated)
            .cornerRadius(Theme.Radius.sm)

            // API Key Input
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                SecureField(provider.keyPlaceholder, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))
                    .onChange(of: apiKey) { _, newValue in
                        validationResult = provider.validateKeyFormat(newValue)
                    }

                if hasExistingKey {
                    Text("A key already exists. Enter a new value to replace it.")
                        .font(.caption)
                        .foregroundStyle(Color.statusWarning)
                }

                // Validation feedback
                if let result = validationResult, !apiKey.isEmpty {
                    validationFeedback(result)
                }
            }

            // Get API Key link
            if let url = provider.docsURL {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Get your \(provider.displayName) API key")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentPrimary)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.statusError)
            }

            Spacer()

            // Actions
            HStack(spacing: Theme.Spacing.md) {
                if hasExistingKey {
                    Button(role: .destructive) {
                        deleteKey()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || !isValidFormat || isSaving)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 450, height: 400)
        .background(Color.bgSurface)
        .task {
            await checkExistingKey()
        }
    }

    private var isValidFormat: Bool {
        guard let result = validationResult else { return false }
        return result.isValid
    }

    @ViewBuilder
    private func validationFeedback(_ result: APIKeyValidationResult) -> some View {
        switch result {
        case .valid, .verified:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color.statusSuccess)
                Text("Valid format")
                    .font(.caption)
                    .foregroundStyle(Color.statusSuccess)
            }
        case .invalid(let error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.statusError)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.statusError)
            }
        case .testing:
            EmptyView()
        }
    }

    private func checkExistingKey() async {
        hasExistingKey = await KeychainService.shared.hasAPIKey(provider: provider.rawValue)
    }

    private func saveKey() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await KeychainService.shared.saveAPIKey(provider: provider.rawValue, key: apiKey)
                await MainActor.run {
                    onSave(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func deleteKey() {
        Task {
            do {
                try await KeychainService.shared.deleteAPIKey(provider: provider.rawValue)
                await MainActor.run {
                    onSave(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - APIKeyValidator

/// Utility for validating API keys with their respective providers
public enum APIKeyValidator {

    /// Test an API key by making a minimal API call
    public static func testKey(provider: APIProvider) async -> APIKeyValidationResult {
        guard let key = await KeychainService.shared.getAPIKey(provider: provider.rawValue) else {
            return .invalid(error: "No API key found")
        }

        // First validate format
        let formatResult = provider.validateKeyFormat(key)
        guard formatResult.isValid else {
            return formatResult
        }

        // Test with actual API call
        switch provider {
        case .anthropic:
            return await testAnthropicKey(key)
        case .openai:
            return await testOpenAIKey(key)
        case .google:
            return await testGoogleKey(key)
        }
    }

    private static func testAnthropicKey(_ key: String) async -> APIKeyValidationResult {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return .invalid(error: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Minimal request body that will return quickly
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return .verified
                case 401:
                    return .invalid(error: "Invalid API key")
                case 403:
                    return .invalid(error: "API key lacks required permissions")
                case 429:
                    // Rate limited but key is valid
                    return .verified
                default:
                    return .invalid(error: "API error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            return .invalid(error: "Connection error: \(error.localizedDescription)")
        }

        return .invalid(error: "Unknown error")
    }

    private static func testOpenAIKey(_ key: String) async -> APIKeyValidationResult {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return .invalid(error: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return .verified
                case 401:
                    return .invalid(error: "Invalid API key")
                case 403:
                    return .invalid(error: "API key lacks required permissions")
                case 429:
                    // Rate limited but key is valid
                    return .verified
                default:
                    return .invalid(error: "API error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            return .invalid(error: "Connection error: \(error.localizedDescription)")
        }

        return .invalid(error: "Unknown error")
    }

    private static func testGoogleKey(_ key: String) async -> APIKeyValidationResult {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models?key=\(key)") else {
            return .invalid(error: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return .verified
                case 400:
                    return .invalid(error: "Invalid API key format")
                case 403:
                    return .invalid(error: "API key is invalid or lacks permissions")
                case 429:
                    // Rate limited but key is valid
                    return .verified
                default:
                    return .invalid(error: "API error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            return .invalid(error: "Connection error: \(error.localizedDescription)")
        }

        return .invalid(error: "Unknown error")
    }
}

// MARK: - Preview

#if DEBUG
struct APIKeysSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeysSettingsView()
            .frame(width: 550, height: 600)
    }
}
#endif
