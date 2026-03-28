import Foundation
import GRDB

// MARK: - CostEvent

/// Tracks token usage and cost for a single API call or agent iteration.
/// One CostEvent per API response or loop iteration, linked to the AgentSlot.
struct CostEvent: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var agentSlotId: UUID
    var provider: String
    var model: String
    var inputTokens: Int
    var outputTokens: Int
    var costCents: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        agentSlotId: UUID,
        provider: String,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        costCents: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.agentSlotId = agentSlotId
        self.provider = provider
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costCents = costCents
        self.createdAt = createdAt
    }

    /// Estimated cost based on standard pricing (cents).
    /// Pricing as of March 2026 — input/output per 1M tokens.
    static func estimateCostCents(provider: String, model: String, inputTokens: Int, outputTokens: Int) -> Int {
        let (inputRate, outputRate) = pricingPerMillionTokens(provider: provider, model: model)
        let inputCost = Double(inputTokens) / 1_000_000.0 * inputRate
        let outputCost = Double(outputTokens) / 1_000_000.0 * outputRate
        return Int((inputCost + outputCost) * 100) // dollars to cents
    }

    /// Returns (input$/1M, output$/1M) pricing for known models.
    private static func pricingPerMillionTokens(provider: String, model: String) -> (Double, Double) {
        let m = model.lowercased()
        // Anthropic
        if m.contains("opus") { return (15.0, 75.0) }
        if m.contains("sonnet") { return (3.0, 15.0) }
        if m.contains("haiku") { return (0.25, 1.25) }
        // OpenAI
        if m.contains("gpt-4o") { return (2.5, 10.0) }
        if m.contains("gpt-4") { return (10.0, 30.0) }
        if m.contains("o3") || m.contains("o4") { return (10.0, 40.0) }
        // Google
        if m.contains("gemini-2") { return (0.50, 1.50) }
        if m.contains("gemini") { return (0.35, 1.05) }
        // Default fallback
        return (3.0, 15.0)
    }
}

// MARK: - GRDB Conformance

extension CostEvent: FetchableRecord, PersistableRecord {
    static let databaseTableName = "cost_event"

    static let agentSlot = belongsTo(AgentSlot.self)

    var agentSlot: QueryInterfaceRequest<AgentSlot> {
        request(for: CostEvent.agentSlot)
    }

    enum Columns: String, ColumnExpression {
        case id, agentSlotId, provider, model
        case inputTokens, outputTokens, costCents, createdAt
    }
}

// MARK: - Usage Summary

/// Aggregated usage for a slot or session.
struct UsageSummary: Codable, Hashable, Sendable {
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCostCents: Int
    let eventCount: Int

    var totalTokens: Int { totalInputTokens + totalOutputTokens }

    var formattedCost: String {
        if totalCostCents >= 100 {
            return String(format: "$%.2f", Double(totalCostCents) / 100.0)
        }
        return "\(totalCostCents)¢"
    }

    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000.0)
        }
        if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000.0)
        }
        return "\(totalTokens)"
    }

    static let zero = UsageSummary(totalInputTokens: 0, totalOutputTokens: 0, totalCostCents: 0, eventCount: 0)
}
