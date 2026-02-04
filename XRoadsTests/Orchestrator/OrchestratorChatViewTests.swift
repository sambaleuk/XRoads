//
//  OrchestratorChatViewTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-013: Unit tests for Orchestrator Chat View
//

import XCTest
@testable import XRoadsLib

// MARK: - ChatMessage Tests

final class ChatMessageTests: XCTestCase {

    // MARK: - User Message Tests

    func test_user_message_creation() {
        let message = ChatMessage.user("Hello, orchestrator!")

        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello, orchestrator!")
        XCTAssertEqual(message.status, .complete)
        XCTAssertNil(message.actions)
    }

    func test_assistant_message_creation() {
        let message = ChatMessage.assistant("I can help you with that.")

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "I can help you with that.")
        XCTAssertEqual(message.status, .complete)
    }

    func test_system_message_creation() {
        let message = ChatMessage.system("Connected to MCP server")

        XCTAssertEqual(message.role, .system)
        XCTAssertEqual(message.content, "Connected to MCP server")
    }

    func test_streaming_placeholder_creation() {
        let message = ChatMessage.streamingPlaceholder()

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "")
        XCTAssertEqual(message.status, .streaming)
    }

    // MARK: - Status Tests

    func test_status_isLoading_pending() {
        let status = ChatMessageStatus.pending
        XCTAssertTrue(status.isLoading)
    }

    func test_status_isLoading_streaming() {
        let status = ChatMessageStatus.streaming
        XCTAssertTrue(status.isLoading)
    }

    func test_status_isLoading_complete() {
        let status = ChatMessageStatus.complete
        XCTAssertFalse(status.isLoading)
    }

    func test_status_isLoading_error() {
        let status = ChatMessageStatus.error("Network failed")
        XCTAssertFalse(status.isLoading)
    }

    // MARK: - Message with Actions

    func test_message_with_actions() {
        let actions = [
            ChatAction(type: .createPRD, label: "Create PRD"),
            ChatAction(type: .launchLoop, label: "Start Loop")
        ]

        let message = ChatMessage(
            role: .assistant,
            content: "Ready to create your feature.",
            actions: actions
        )

        XCTAssertEqual(message.actions?.count, 2)
        XCTAssertEqual(message.actions?[0].type, .createPRD)
        XCTAssertEqual(message.actions?[1].type, .launchLoop)
    }

    // MARK: - Timestamp Formatting

    func test_formatted_timestamp() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let date = formatter.date(from: "2026-02-04 14:30")!

        let message = ChatMessage(
            role: .user,
            content: "Test",
            timestamp: date
        )

        XCTAssertEqual(message.formattedTimestamp, "14:30")
    }

    // MARK: - Equality

    func test_message_equality_by_id() {
        let id = UUID()
        let message1 = ChatMessage(id: id, role: .user, content: "Hello")
        let message2 = ChatMessage(id: id, role: .user, content: "Different content")

        XCTAssertEqual(message1, message2)
    }

    func test_message_inequality_different_ids() {
        let message1 = ChatMessage.user("Hello")
        let message2 = ChatMessage.user("Hello")

        XCTAssertNotEqual(message1, message2)
    }
}

// MARK: - ChatRole Tests

final class ChatRoleTests: XCTestCase {

    func test_role_display_names() {
        XCTAssertEqual(ChatRole.user.displayName, "You")
        XCTAssertEqual(ChatRole.assistant.displayName, "Orchestrator")
        XCTAssertEqual(ChatRole.system.displayName, "System")
    }

    func test_role_icon_names() {
        XCTAssertEqual(ChatRole.user.iconName, "person.fill")
        XCTAssertEqual(ChatRole.assistant.iconName, "brain.head.profile")
        XCTAssertEqual(ChatRole.system.iconName, "gearshape.fill")
    }
}

// MARK: - OrchestratorMode Tests

final class OrchestratorModeTests: XCTestCase {

    func test_mode_display_names() {
        XCTAssertEqual(OrchestratorMode.api.displayName, "API")
        XCTAssertEqual(OrchestratorMode.terminal.displayName, "Terminal")
    }

    func test_mode_icon_names() {
        XCTAssertEqual(OrchestratorMode.api.iconName, "bolt.fill")
        XCTAssertEqual(OrchestratorMode.terminal.iconName, "terminal.fill")
    }

    func test_mode_descriptions() {
        XCTAssertTrue(OrchestratorMode.api.description.contains("Fast"))
        XCTAssertTrue(OrchestratorMode.terminal.description.contains("Full"))
    }
}

// MARK: - ChatContext Tests

final class ChatContextTests: XCTestCase {

    func test_context_system_prompt_section() {
        let context = ChatContext(
            projectPath: "/Users/dev/Projects/MyApp",
            currentBranch: "main",
            worktrees: ["feature-auth", "feature-api"],
            availableSkills: ["nexus", "prd"],
            mcpServers: ["xroads-mcp"],
            dashboardMode: "agentic"
        )

        let section = context.systemPromptSection

        XCTAssertTrue(section.contains("MyApp"))
        XCTAssertTrue(section.contains("main"))
        XCTAssertTrue(section.contains("feature-auth"))
        XCTAssertTrue(section.contains("nexus"))
        XCTAssertTrue(section.contains("xroads-mcp"))
        XCTAssertTrue(section.contains("agentic"))
    }

    func test_context_empty_values() {
        let context = ChatContext()

        let section = context.systemPromptSection

        XCTAssertTrue(section.contains("XRoads Context"))
        XCTAssertFalse(section.contains("Project:"))
        XCTAssertFalse(section.contains("Branch:"))
    }
}

// MARK: - ChatAction Tests

final class ChatActionTests: XCTestCase {

    func test_action_creation() {
        let action = ChatAction(
            type: .createPRD,
            label: "Create PRD",
            payload: ["feature": "auth"]
        )

        XCTAssertEqual(action.type, .createPRD)
        XCTAssertEqual(action.label, "Create PRD")
        XCTAssertEqual(action.payload?["feature"], "auth")
    }

    func test_action_types() {
        let types: [ChatActionType] = [
            .createPRD,
            .launchLoop,
            .openFile,
            .createWorktree,
            .runCommand,
            .viewArtBible,
            .viewSkills
        ]

        XCTAssertEqual(types.count, 7)
    }
}

// MARK: - OrchestratorService Tests

final class OrchestratorServiceTests: XCTestCase {

    func test_service_mode_default() async {
        let service = OrchestratorService()
        let mode = await service.getMode()

        XCTAssertEqual(mode, .api)
    }

    func test_service_set_mode() async {
        let service = OrchestratorService()

        await service.setMode(.terminal)
        let mode = await service.getMode()

        XCTAssertEqual(mode, .terminal)
    }

    func test_service_message_management() async {
        let service = OrchestratorService()

        await service.addMessage(.user("Hello"))
        await service.addMessage(.assistant("Hi there"))

        let messages = await service.getMessages()

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[1].role, .assistant)
    }

    func test_service_clear_conversation() async {
        let service = OrchestratorService()

        await service.addMessage(.user("Hello"))
        await service.addMessage(.assistant("Hi"))
        await service.clearConversation()

        let messages = await service.getMessages()

        XCTAssertTrue(messages.isEmpty)
    }

    func test_service_context_update() async {
        let service = OrchestratorService()

        let context = ChatContext(
            projectPath: "/test/path",
            currentBranch: "main"
        )

        await service.setContext(context)
        await service.updateSystemPrompt()

        // Context should be set without throwing
        // Full validation would require inspecting internal state
    }

    func test_service_send_without_api_key_throws() async {
        let service = OrchestratorService()
        await service.setMode(.api)
        await service.setAPIKey(nil)

        do {
            _ = try await service.sendMessage("Hello")
            XCTFail("Expected error to be thrown")
        } catch let error as OrchestratorChatError {
            if case .noAPIKey = error {
                // Expected
            } else {
                XCTFail("Expected noAPIKey error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - OrchestratorChatError Tests

final class OrchestratorChatErrorTests: XCTestCase {

    func test_error_descriptions() {
        let errors: [OrchestratorChatError] = [
            .noAPIKey,
            .invalidResponse,
            .rateLimited,
            .terminalNotAvailable,
            .encodingFailed
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func test_network_error_description() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        let error = OrchestratorChatError.networkError(underlyingError)

        XCTAssertTrue(error.errorDescription!.contains("Network"))
    }

    func test_server_error_description() {
        let error = OrchestratorChatError.serverError(500, "Internal Server Error")

        XCTAssertTrue(error.errorDescription!.contains("500"))
        XCTAssertTrue(error.errorDescription!.contains("Internal Server Error"))
    }
}
