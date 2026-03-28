import XCTest
@testable import XRoadsLib

final class CostEventRepositoryTests: XCTestCase {

    private var dbManager: CockpitDatabaseManager!
    private var repo: CostEventRepository!
    private var sessionRepo: CockpitSessionRepository!

    override func setUp() async throws {
        dbManager = try CockpitDatabaseManager() // in-memory
        let dbQueue = await dbManager.dbQueue
        repo = CostEventRepository(dbQueue: dbQueue)
        sessionRepo = CockpitSessionRepository(dbQueue: dbQueue)
    }

    // MARK: - Helpers

    private func createSlot() async throws -> AgentSlot {
        let session = try await sessionRepo.createSession(
            CockpitSession(projectPath: "/tmp/test-cost")
        )
        return try await sessionRepo.createSlot(
            AgentSlot(cockpitSessionId: session.id, slotIndex: 0, agentType: "claude")
        )
    }

    // MARK: - Tests

    func test_insertThenFetch_roundtrip() async throws {
        let slot = try await createSlot()

        // Insert
        let event = try await repo.recordUsage(
            slotId: slot.id,
            provider: "anthropic",
            model: "sonnet",
            inputTokens: 100,
            outputTokens: 50
        )

        // Verify the slot exists in DB
        let slots = try await sessionRepo.fetchSlots(
            sessionId: slot.cockpitSessionId
        )
        XCTAssertEqual(slots.count, 1, "Slot should exist in DB")

        // Fetch events for this slot
        let events = try await repo.fetchEvents(slotId: slot.id)
        XCTAssertEqual(events.count, 1, "Should find 1 event after insert")
        XCTAssertEqual(events.first?.inputTokens, 100)
        _ = event
    }

    func test_recordUsage_calculatesEstimatedCost() async throws {
        let slot = try await createSlot()

        let event = try await repo.recordUsage(
            slotId: slot.id,
            provider: "anthropic",
            model: "claude-sonnet-4",
            inputTokens: 1000,
            outputTokens: 500
        )

        XCTAssertGreaterThan(event.costCents, 0, "Cost should be estimated")
        XCTAssertEqual(event.inputTokens, 1000)
        XCTAssertEqual(event.outputTokens, 500)
        XCTAssertEqual(event.provider, "anthropic")
    }

    func test_summaryForSlot_aggregatesCorrectly() async throws {
        let slot = try await createSlot()

        // Record 3 events
        try await repo.recordUsage(slotId: slot.id, provider: "anthropic", model: "sonnet", inputTokens: 1000, outputTokens: 500)
        try await repo.recordUsage(slotId: slot.id, provider: "anthropic", model: "sonnet", inputTokens: 2000, outputTokens: 1000)
        try await repo.recordUsage(slotId: slot.id, provider: "anthropic", model: "sonnet", inputTokens: 500, outputTokens: 200)

        let summary = try await repo.summaryForSlot(slotId: slot.id)

        XCTAssertEqual(summary.totalInputTokens, 3500)
        XCTAssertEqual(summary.totalOutputTokens, 1700)
        XCTAssertEqual(summary.eventCount, 3)
        XCTAssertGreaterThan(summary.totalCostCents, 0)
    }

    func test_summaryForSession_aggregatesAcrossSlots() async throws {
        let session = try await sessionRepo.createSession(
            CockpitSession(projectPath: "/tmp/test-session-cost")
        )
        let slot1 = try await sessionRepo.createSlot(
            AgentSlot(cockpitSessionId: session.id, slotIndex: 0, agentType: "claude")
        )
        let slot2 = try await sessionRepo.createSlot(
            AgentSlot(cockpitSessionId: session.id, slotIndex: 1, agentType: "gemini")
        )

        try await repo.recordUsage(slotId: slot1.id, provider: "anthropic", model: "sonnet", inputTokens: 1000, outputTokens: 500)
        try await repo.recordUsage(slotId: slot2.id, provider: "google", model: "gemini-2", inputTokens: 2000, outputTokens: 800)

        let summary = try await repo.summaryForSession(sessionId: session.id)

        XCTAssertEqual(summary.totalInputTokens, 3000)
        XCTAssertEqual(summary.totalOutputTokens, 1300)
        XCTAssertEqual(summary.eventCount, 2)
    }

    func test_breakdownForSession_returnsPerSlotSummaries() async throws {
        let session = try await sessionRepo.createSession(
            CockpitSession(projectPath: "/tmp/test-breakdown")
        )
        let slot1 = try await sessionRepo.createSlot(
            AgentSlot(cockpitSessionId: session.id, slotIndex: 0, agentType: "claude")
        )
        let slot2 = try await sessionRepo.createSlot(
            AgentSlot(cockpitSessionId: session.id, slotIndex: 1, agentType: "gemini")
        )

        try await repo.recordUsage(slotId: slot1.id, provider: "anthropic", model: "opus", inputTokens: 5000, outputTokens: 2000)
        try await repo.recordUsage(slotId: slot2.id, provider: "google", model: "gemini-2", inputTokens: 3000, outputTokens: 1000)

        let breakdown = try await repo.breakdownForSession(sessionId: session.id)

        XCTAssertEqual(breakdown.count, 2, "Should have 2 slot entries")
        XCTAssertEqual(breakdown[slot1.id]?.totalInputTokens, 5000)
        XCTAssertEqual(breakdown[slot2.id]?.totalInputTokens, 3000)
    }

    func test_cascadeDelete_removesCostEventsWhenSlotDeleted() async throws {
        let session = try await sessionRepo.createSession(
            CockpitSession(projectPath: "/tmp/test-cascade-cost")
        )
        let slot = try await sessionRepo.createSlot(
            AgentSlot(cockpitSessionId: session.id, slotIndex: 0, agentType: "claude")
        )

        try await repo.recordUsage(slotId: slot.id, provider: "anthropic", model: "sonnet", inputTokens: 1000, outputTokens: 500)
        try await repo.recordUsage(slotId: slot.id, provider: "anthropic", model: "sonnet", inputTokens: 2000, outputTokens: 1000)

        let beforeCount = try await repo.fetchEvents(slotId: slot.id).count
        XCTAssertEqual(beforeCount, 2)

        // Delete the session (cascades to slots, then to cost events)
        try await sessionRepo.deleteSession(id: session.id)

        let afterCount = try await repo.fetchEvents(slotId: slot.id).count
        XCTAssertEqual(afterCount, 0, "Cost events should be cascade-deleted with slot")
    }

    func test_estimateCost_anthropicModels() {
        // Opus: $15/$75 per 1M tokens
        let opusCost = CostEvent.estimateCostCents(provider: "anthropic", model: "claude-opus-4", inputTokens: 1_000_000, outputTokens: 1_000_000)
        XCTAssertEqual(opusCost, 9000, "Opus 1M in + 1M out = $15 + $75 = $90 = 9000 cents")

        // Sonnet: $3/$15 per 1M tokens
        let sonnetCost = CostEvent.estimateCostCents(provider: "anthropic", model: "claude-sonnet-4", inputTokens: 1_000_000, outputTokens: 1_000_000)
        XCTAssertEqual(sonnetCost, 1800, "Sonnet 1M in + 1M out = $3 + $15 = $18 = 1800 cents")

        // Haiku: $0.25/$1.25 per 1M tokens
        let haikuCost = CostEvent.estimateCostCents(provider: "anthropic", model: "claude-haiku-4", inputTokens: 1_000_000, outputTokens: 1_000_000)
        XCTAssertEqual(haikuCost, 150, "Haiku 1M in + 1M out = $0.25 + $1.25 = $1.50 = 150 cents")
    }

    func test_usageSummary_formattedCost() {
        let small = UsageSummary(totalInputTokens: 100, totalOutputTokens: 50, totalCostCents: 5, eventCount: 1)
        XCTAssertEqual(small.formattedCost, "5¢")

        let large = UsageSummary(totalInputTokens: 100000, totalOutputTokens: 50000, totalCostCents: 450, eventCount: 10)
        XCTAssertEqual(large.formattedCost, "$4.50")
    }

    func test_usageSummary_formattedTokens() {
        let small = UsageSummary(totalInputTokens: 500, totalOutputTokens: 200, totalCostCents: 0, eventCount: 1)
        XCTAssertEqual(small.formattedTokens, "700")

        let medium = UsageSummary(totalInputTokens: 5000, totalOutputTokens: 3000, totalCostCents: 0, eventCount: 1)
        XCTAssertEqual(medium.formattedTokens, "8.0K")

        let large = UsageSummary(totalInputTokens: 800000, totalOutputTokens: 500000, totalCostCents: 0, eventCount: 1)
        XCTAssertEqual(large.formattedTokens, "1.3M")
    }
}
