import XCTest

/// Tests that DispatchQueue.main.asyncAfter has been replaced with Task.sleep
/// in SwiftUI/@MainActor contexts, and is documented with "AppKit timing" comments
/// where intentionally retained for AppKit focus workarounds.
final class AsyncAfterMigrationTests: XCTestCase {

    // MARK: - Helpers

    private func projectRoot() -> String {
        // Navigate from test file location to project root
        let testFile = #filePath
        var url = URL(fileURLWithPath: testFile)
        // Go up: Views/ -> XRoadsTests/ -> project root
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url.path
    }

    private func readSource(_ relativePath: String) throws -> String {
        let path = projectRoot() + "/" + relativePath
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    private func lines(of source: String, matching pattern: String) -> [String] {
        source.components(separatedBy: .newlines).filter { $0.contains(pattern) }
    }

    // MARK: - SwiftUI files must NOT use DispatchQueue.main.asyncAfter

    func testLoadingIndicatorsNoDispatchQueue() throws {
        let source = try readSource("XRoads/Views/Components/LoadingIndicators.swift")
        let matches = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertEqual(matches.count, 0, "LoadingIndicators.swift should have no DispatchQueue.main.asyncAfter calls, found: \(matches)")
    }

    func testQuickActionBarNoDispatchQueue() throws {
        let source = try readSource("XRoads/Views/Components/QuickActionBar.swift")
        let matches = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertEqual(matches.count, 0, "QuickActionBar.swift should have no DispatchQueue.main.asyncAfter calls, found: \(matches)")
    }

    func testArtDirectionViewNoDispatchQueue() throws {
        let source = try readSource("XRoads/Views/ArtDirection/ArtDirectionView.swift")
        let matches = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertEqual(matches.count, 0, "ArtDirectionView.swift should have no DispatchQueue.main.asyncAfter calls, found: \(matches)")
    }

    func testNeonBrainViewNoDispatchQueue() throws {
        let source = try readSource("XRoads/Views/Dashboard/NeonBrainView.swift")
        let matches = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertEqual(matches.count, 0, "NeonBrainView.swift should have no DispatchQueue.main.asyncAfter calls, found: \(matches)")
    }

    func testAppStateNoDispatchQueue() throws {
        let source = try readSource("XRoads/ViewModels/AppState.swift")
        let matches = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertEqual(matches.count, 0, "AppState.swift should have no DispatchQueue.main.asyncAfter calls, found: \(matches)")
    }

    // MARK: - SwiftUI files must use Task.sleep

    func testLoadingIndicatorsUsesTaskSleep() throws {
        let source = try readSource("XRoads/Views/Components/LoadingIndicators.swift")
        let matches = lines(of: source, matching: "Task.sleep")
        XCTAssertGreaterThanOrEqual(matches.count, 2, "LoadingIndicators.swift should use Task.sleep for staggered dots animation")
    }

    func testQuickActionBarUsesTaskSleep() throws {
        let source = try readSource("XRoads/Views/Components/QuickActionBar.swift")
        let matches = lines(of: source, matching: "Task.sleep")
        XCTAssertGreaterThanOrEqual(matches.count, 1, "QuickActionBar.swift should use Task.sleep for loading feedback delay")
    }

    func testArtDirectionViewUsesTaskSleep() throws {
        let source = try readSource("XRoads/Views/ArtDirection/ArtDirectionView.swift")
        let matches = lines(of: source, matching: "Task.sleep")
        XCTAssertGreaterThanOrEqual(matches.count, 1, "ArtDirectionView.swift should use Task.sleep for auto-clear message")
    }

    func testNeonBrainViewUsesTaskSleep() throws {
        let source = try readSource("XRoads/Views/Dashboard/NeonBrainView.swift")
        let matches = lines(of: source, matching: "Task.sleep")
        XCTAssertGreaterThanOrEqual(matches.count, 2, "NeonBrainView.swift should use Task.sleep for staggered animations")
    }

    // MARK: - AppKit files retain DispatchQueue with documented "AppKit timing" comment

    func testFloatingInputWindowRetainsDocumentedDispatchQueue() throws {
        let source = try readSource("XRoads/Views/Components/FloatingInputWindow.swift")
        let dispatchLines = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertGreaterThanOrEqual(dispatchLines.count, 2, "FloatingInputWindow.swift should retain DispatchQueue for AppKit focus timing")

        let commentLines = lines(of: source, matching: "AppKit timing")
        XCTAssertGreaterThanOrEqual(commentLines.count, 2, "FloatingInputWindow.swift should document retained DispatchQueue with 'AppKit timing' comment")
    }

    func testMacTextFieldRetainsDocumentedDispatchQueue() throws {
        let source = try readSource("XRoads/Views/Components/MacTextField.swift")
        let dispatchLines = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertGreaterThanOrEqual(dispatchLines.count, 2, "MacTextField.swift should retain DispatchQueue for AppKit focus timing")

        let commentLines = lines(of: source, matching: "AppKit timing")
        XCTAssertGreaterThanOrEqual(commentLines.count, 2, "MacTextField.swift should document retained DispatchQueue with 'AppKit timing' comment")
    }

    func testModalPanelRetainsDocumentedDispatchQueue() throws {
        let source = try readSource("XRoads/Views/Components/ModalPanel.swift")
        let dispatchLines = lines(of: source, matching: "DispatchQueue.main.asyncAfter")
        XCTAssertGreaterThanOrEqual(dispatchLines.count, 2, "ModalPanel.swift should retain DispatchQueue for AppKit focus timing")

        let commentLines = lines(of: source, matching: "AppKit timing")
        XCTAssertGreaterThanOrEqual(commentLines.count, 2, "ModalPanel.swift should document retained DispatchQueue with 'AppKit timing' comment")
    }
}
