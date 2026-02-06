import XCTest
@testable import XRoadsLib

/// CR-001: Verifies BoundedBuffer FIFO eviction, capacity enforcement,
/// and integration with AppState/sub-state bounded collections.
final class BoundedBufferTests: XCTestCase {

    // MARK: - BoundedBuffer Core Tests

    func test_append_enforcesCapacity() {
        var buffer = BoundedBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4) // should evict 1
        XCTAssertEqual(buffer.count, 3, "Buffer should not exceed capacity")
        XCTAssertEqual(buffer.elements, [2, 3, 4], "Oldest element should be evicted (FIFO)")
    }

    func test_evictsOldestElements_FIFO() {
        var buffer = BoundedBuffer<Int>(capacity: 2)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30) // evicts 10
        buffer.append(40) // evicts 20
        XCTAssertEqual(buffer.elements, [30, 40], "Should keep only the newest elements")
    }

    func test_appendContentsOf_respectsCapacity() {
        var buffer = BoundedBuffer<Int>(capacity: 3)
        buffer.append(contentsOf: [1, 2, 3, 4, 5])
        XCTAssertEqual(buffer.count, 3, "Buffer should cap at capacity after bulk append")
        XCTAssertEqual(buffer.elements, [3, 4, 5], "Should keep last 3 elements")
    }

    func test_insertAt_respectsCapacity() {
        var buffer = BoundedBuffer<Int>(capacity: 3)
        buffer.append(contentsOf: [1, 2, 3])
        buffer.insert(99, at: 0) // inserts at front, evicts oldest (element at index 0 after shift)
        XCTAssertEqual(buffer.count, 3, "Buffer should not exceed capacity after insert")
        // After insert [99, 1, 2, 3] -> evict first -> [1, 2, 3]
        // Actually: insert at 0 gives [99, 1, 2, 3], then evictIfNeeded removes first -> [1, 2, 3]
        XCTAssertEqual(buffer.elements, [1, 2, 3], "Insert + eviction should remove from front")
    }

    func test_removeAll_clearsAllElements() {
        var buffer = BoundedBuffer<Int>(capacity: 5)
        buffer.append(contentsOf: [1, 2, 3])
        buffer.removeAll()
        XCTAssertTrue(buffer.isEmpty, "Buffer should be empty after removeAll")
        XCTAssertEqual(buffer.count, 0, "Count should be 0 after removeAll")
    }

    func test_initWithElements_truncatesToCapacity() {
        let buffer = BoundedBuffer<Int>(capacity: 3, elements: [10, 20, 30, 40, 50])
        XCTAssertEqual(buffer.count, 3, "Should truncate to capacity on init")
        XCTAssertEqual(buffer.elements, [30, 40, 50], "Should keep the last (newest) elements")
    }

    func test_initWithElements_underCapacity() {
        let buffer = BoundedBuffer<Int>(capacity: 10, elements: [1, 2, 3])
        XCTAssertEqual(buffer.count, 3, "Should retain all elements when under capacity")
        XCTAssertEqual(buffer.elements, [1, 2, 3])
    }

    func test_lastAndFirst() {
        var buffer = BoundedBuffer<Int>(capacity: 5)
        XCTAssertNil(buffer.first, "Empty buffer should have nil first")
        XCTAssertNil(buffer.last, "Empty buffer should have nil last")
        buffer.append(contentsOf: [10, 20, 30])
        XCTAssertEqual(buffer.first, 10)
        XCTAssertEqual(buffer.last, 30)
    }

    func test_removeLast() {
        var buffer = BoundedBuffer<Int>(capacity: 5)
        buffer.append(contentsOf: [1, 2, 3, 4, 5])
        buffer.removeLast(2)
        XCTAssertEqual(buffer.elements, [1, 2, 3])
    }

    // MARK: - Integration: AppState.logs bounded at 5000

    @MainActor
    func test_appStateLogs_usesBoundedBuffer_capacity5000() {
        let appState = AppState(services: MockServiceContainer())
        XCTAssertEqual(appState.logs.capacity, 5000, "AppState.logs should use BoundedBuffer with capacity 5000")
    }

    // MARK: - Integration: DispatchState.globalLogs bounded at 5000

    @MainActor
    func test_dispatchStateGlobalLogs_usesBoundedBuffer_capacity5000() {
        let dispatch = DispatchState()
        XCTAssertEqual(dispatch.globalLogs.capacity, 5000, "DispatchState.globalLogs should use BoundedBuffer with capacity 5000")
    }

    // MARK: - Integration: OrchestrationSubState.agentTimelineEvents bounded at 1000

    @MainActor
    func test_orchestrationAgentTimelineEvents_usesBoundedBuffer_capacity1000() {
        let orch = OrchestrationSubState()
        XCTAssertEqual(orch.agentTimelineEvents.capacity, 1000, "OrchestrationSubState.agentTimelineEvents should use BoundedBuffer with capacity 1000")
    }

    // MARK: - Integration: TerminalSlot.addLog caps at 50

    func test_terminalSlotAddLog_capsAt50() {
        var slot = TerminalSlot(slotNumber: 1)
        for i in 0..<60 {
            slot.addLog(LogEntry(level: .info, source: "test", message: "log \(i)"))
        }
        XCTAssertEqual(slot.logs.count, 50, "TerminalSlot.logs should cap at 50")
        XCTAssertEqual(slot.logs.first?.message, "log 10", "Oldest logs should be evicted")
        XCTAssertEqual(slot.logs.last?.message, "log 59", "Newest logs should be retained")
    }

    // MARK: - Integration: AppState.addLog no inline eviction

    @MainActor
    func test_appStateAddLog_delegatesToBoundedBuffer() {
        let appState = AppState(services: MockServiceContainer())
        // Add a log entry and verify it goes through BoundedBuffer
        let entry = LogEntry(level: .info, source: "test", message: "test log")
        appState.addLog(entry)
        XCTAssertEqual(appState.logs.count, 1)
        XCTAssertEqual(appState.logs.last?.message, "test log")
    }

    // MARK: - Source file verification: no inline eviction for agentTimelineEvents

    func test_noInlineEviction_agentTimelineEvents_inAppState() throws {
        // #filePath = .../XRoadsTests/Models/BoundedBufferTests.swift
        // Go up 3 levels: file -> Models -> XRoadsTests -> project root
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Models/
            .deletingLastPathComponent() // XRoadsTests/
            .deletingLastPathComponent() // project root
        let appStatePath = projectRoot
            .appendingPathComponent("XRoads")
            .appendingPathComponent("ViewModels")
            .appendingPathComponent("AppState.swift")
        let content = try String(contentsOf: appStatePath, encoding: .utf8)

        // The old pattern was: agentTimelineEvents.count > 100 followed by removeLast
        // With BoundedBuffer, this inline eviction should be removed
        let hasInlineEviction = content.contains("agentTimelineEvents.count > 100")
        XCTAssertFalse(hasInlineEviction, "AppState should not have inline eviction for agentTimelineEvents (BoundedBuffer handles it)")
    }

    func test_noInlineEviction_logs_inAppState() throws {
        // #filePath = .../XRoadsTests/Models/BoundedBufferTests.swift
        // Go up 3 levels: file -> Models -> XRoadsTests -> project root
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Models/
            .deletingLastPathComponent() // XRoadsTests/
            .deletingLastPathComponent() // project root
        let appStatePath = projectRoot
            .appendingPathComponent("XRoads")
            .appendingPathComponent("ViewModels")
            .appendingPathComponent("AppState.swift")
        let content = try String(contentsOf: appStatePath, encoding: .utf8)

        // The old pattern was: logs.count > 500 followed by removeFirst
        let hasInlineEviction = content.contains("logs.count > 500")
        XCTAssertFalse(hasInlineEviction, "AppState should not have inline eviction for logs (BoundedBuffer handles it)")
    }
}
