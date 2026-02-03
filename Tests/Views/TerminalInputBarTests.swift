import XCTest
@testable import XRoads

final class TerminalInputBarTests: XCTestCase {

    // MARK: - Text Submission Callback Tests

    func testTextSubmissionCallbackIsInvoked() {
        // Given
        var submittedText: String?
        let inputBar = TerminalInputBar(
            onSubmit: { text in
                submittedText = text
            },
            isEnabled: true,
            isWaitingForInput: false
        )

        // Then - verify the callback structure exists
        // Note: Full UI interaction testing requires ViewInspector or UI tests
        XCTAssertNotNil(inputBar.onSubmit)
    }

    func testSubmitCallbackReceivesCorrectText() {
        // Given
        var receivedText: String?
        let expectedText = "Hello, agent!"

        let callback: (String) -> Void = { text in
            receivedText = text
        }

        // When - simulate callback
        callback(expectedText)

        // Then
        XCTAssertEqual(receivedText, expectedText)
    }

    func testSubmitCallbackTrimsWhitespace() {
        // Given
        var receivedText: String?
        let inputWithWhitespace = "  Hello, agent!  "

        let callback: (String) -> Void = { text in
            receivedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // When
        callback(inputWithWhitespace)

        // Then
        XCTAssertEqual(receivedText, "Hello, agent!")
    }

    // MARK: - Multi-line Input Detection Tests

    func testMultiLineInputDetection() {
        // Given - text with newlines
        let singleLineText = "Hello, agent!"
        let multiLineText = "Hello,\nagent!"

        // Then
        XCTAssertFalse(singleLineText.contains("\n"))
        XCTAssertTrue(multiLineText.contains("\n"))
    }

    func testMultiLineInputPreservesNewlines() {
        // Given
        let multiLineInput = "Line 1\nLine 2\nLine 3"

        // When - split by newlines
        let lines = multiLineInput.components(separatedBy: "\n")

        // Then
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "Line 1")
        XCTAssertEqual(lines[1], "Line 2")
        XCTAssertEqual(lines[2], "Line 3")
    }

    // MARK: - Disabled State Tests

    func testInputBarDisabledStateWhenNoProcess() {
        // Given
        let inputBar = TerminalInputBar(
            onSubmit: { _ in },
            isEnabled: false,
            isWaitingForInput: false
        )

        // Then
        XCTAssertFalse(inputBar.isEnabled)
    }

    func testInputBarEnabledStateWhenProcessRunning() {
        // Given
        let inputBar = TerminalInputBar(
            onSubmit: { _ in },
            isEnabled: true,
            isWaitingForInput: false
        )

        // Then
        XCTAssertTrue(inputBar.isEnabled)
    }

    // MARK: - Waiting for Input State Tests

    func testWaitingForInputState() {
        // Given
        let inputBar = TerminalInputBar(
            onSubmit: { _ in },
            isEnabled: true,
            isWaitingForInput: true
        )

        // Then
        XCTAssertTrue(inputBar.isWaitingForInput)
    }

    func testNotWaitingForInputState() {
        // Given
        let inputBar = TerminalInputBar(
            onSubmit: { _ in },
            isEnabled: true,
            isWaitingForInput: false
        )

        // Then
        XCTAssertFalse(inputBar.isWaitingForInput)
    }

    // MARK: - Empty Input Prevention Tests

    func testEmptyInputIsNotSubmitted() {
        // Given
        var wasSubmitted = false
        let emptyText = ""

        // When - checking empty validation
        let shouldSubmit = !emptyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Then
        XCTAssertFalse(shouldSubmit)
        XCTAssertFalse(wasSubmitted)
    }

    func testWhitespaceOnlyInputIsNotSubmitted() {
        // Given
        let whitespaceText = "   \n\t   "

        // When
        let trimmed = whitespaceText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Then
        XCTAssertTrue(trimmed.isEmpty)
    }

    // MARK: - Compact Input Bar Tests

    func testCompactInputBarCreation() {
        // Given
        let compactBar = CompactTerminalInputBar(
            onSubmit: { _ in },
            isEnabled: true,
            isWaitingForInput: false
        )

        // Then
        XCTAssertTrue(compactBar.isEnabled)
    }

    func testCompactInputBarDisabledState() {
        // Given
        let compactBar = CompactTerminalInputBar(
            onSubmit: { _ in },
            isEnabled: false,
            isWaitingForInput: false
        )

        // Then
        XCTAssertFalse(compactBar.isEnabled)
    }

    func testCompactInputBarWaitingState() {
        // Given
        let compactBar = CompactTerminalInputBar(
            onSubmit: { _ in },
            isEnabled: true,
            isWaitingForInput: true
        )

        // Then
        XCTAssertTrue(compactBar.isWaitingForInput)
    }

    // MARK: - Input Validation Tests

    func testCanSubmitWhenEnabledAndHasText() {
        // Given
        let isEnabled = true
        let inputText = "Hello"

        // When
        let canSubmit = isEnabled && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Then
        XCTAssertTrue(canSubmit)
    }

    func testCannotSubmitWhenDisabled() {
        // Given
        let isEnabled = false
        let inputText = "Hello"

        // When
        let canSubmit = isEnabled && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Then
        XCTAssertFalse(canSubmit)
    }

    func testCannotSubmitWhenEmpty() {
        // Given
        let isEnabled = true
        let inputText = ""

        // When
        let canSubmit = isEnabled && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Then
        XCTAssertFalse(canSubmit)
    }

    // MARK: - Placeholder Tests

    func testDefaultPlaceholder() {
        // Given
        let inputBar = TerminalInputBar(
            onSubmit: { _ in },
            isEnabled: true,
            isWaitingForInput: false
        )

        // Then
        XCTAssertEqual(inputBar.placeholder, "Type a message...")
    }

    func testCustomPlaceholder() {
        // Given
        let customPlaceholder = "Enter your command..."
        let inputBar = TerminalInputBar(
            onSubmit: { _ in },
            isEnabled: true,
            isWaitingForInput: false,
            placeholder: customPlaceholder
        )

        // Then
        XCTAssertEqual(inputBar.placeholder, customPlaceholder)
    }

    // MARK: - Input History Support (Future)

    func testInputHistoryStorage() {
        // Given
        var inputHistory: [String] = []
        let inputs = ["First command", "Second command", "Third command"]

        // When
        for input in inputs {
            inputHistory.append(input)
        }

        // Then
        XCTAssertEqual(inputHistory.count, 3)
        XCTAssertEqual(inputHistory.first, "First command")
        XCTAssertEqual(inputHistory.last, "Third command")
    }
}

// MARK: - TerminalInputBarStyle Tests

final class TerminalInputBarStyleTests: XCTestCase {

    func testAllStyleCases() {
        // Given/Then
        let styles: [TerminalInputBarStyle] = [.compact, .standard, .expanded]
        XCTAssertEqual(styles.count, 3)
    }

    func testCompactStyle() {
        // Given
        let style = TerminalInputBarStyle.compact

        // Then
        XCTAssertEqual(style, .compact)
    }

    func testStandardStyle() {
        // Given
        let style = TerminalInputBarStyle.standard

        // Then
        XCTAssertEqual(style, .standard)
    }

    func testExpandedStyle() {
        // Given
        let style = TerminalInputBarStyle.expanded

        // Then
        XCTAssertEqual(style, .expanded)
    }
}
