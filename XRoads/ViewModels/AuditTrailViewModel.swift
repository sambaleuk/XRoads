import Foundation
import os

// MARK: - AuditTrailViewModel

/// Drives the Audit Trail panel for US-004.
/// Loads all ExecutionGates for the active CockpitSession, sorted by created_at desc.
/// Supports expanding rows to reveal full audit_entry JSON.
@MainActor
@Observable
final class AuditTrailViewModel {

    // MARK: - Published State

    /// All gates for the active session, sorted by created_at desc
    var gates: [ExecutionGate] = []

    /// Set of gate IDs whose audit_entry row is expanded
    var expandedGateIds: Set<UUID> = []

    /// Whether data is loading
    var isLoading: Bool = false

    /// Error message to display
    var errorMessage: String?

    // MARK: - Dependencies

    private let gateRepo: ExecutionGateRepository
    private let sessionId: UUID
    private let logger = Logger(subsystem: "com.xroads", category: "AuditTrailVM")

    // MARK: - Init

    init(gateRepo: ExecutionGateRepository, sessionId: UUID) {
        self.gateRepo = gateRepo
        self.sessionId = sessionId
    }

    // MARK: - Load

    /// Fetches all gates for the session, sorted by created_at desc.
    func loadGates() async {
        isLoading = true
        errorMessage = nil

        do {
            gates = try await gateRepo.fetchGatesForSession(sessionId: sessionId)
            logger.info("Loaded \(self.gates.count) gates for session \(self.sessionId)")
        } catch {
            let msg = error.localizedDescription
            errorMessage = msg
            logger.error("Failed to load audit trail: \(msg)")
        }

        isLoading = false
    }

    // MARK: - Expand / Collapse

    /// Toggle expanded state for a gate row.
    func toggleExpanded(gateId: UUID) {
        if expandedGateIds.contains(gateId) {
            expandedGateIds.remove(gateId)
        } else {
            expandedGateIds.insert(gateId)
        }
    }

    /// Whether a gate row is expanded.
    func isExpanded(gateId: UUID) -> Bool {
        expandedGateIds.contains(gateId)
    }

    // MARK: - Decoded Audit Entry

    /// Decode and pretty-print the audit_entry JSON for a gate.
    func prettyAuditJSON(for gate: ExecutionGate) -> String? {
        guard let jsonString = gate.auditEntry,
              let data = jsonString.data(using: .utf8) else { return nil }

        // Pretty-print the JSON
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let pretty = String(data: prettyData, encoding: .utf8) {
            return pretty
        }

        // Fallback: return raw JSON string
        return jsonString
    }

    // MARK: - Computed Helpers

    /// Duration string from audit_entry, or nil if not available.
    func durationString(for gate: ExecutionGate) -> String? {
        guard let jsonString = gate.auditEntry,
              let data = jsonString.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(AuditEntry.self, from: data) else { return nil }

        if let ms = entry.durationMs {
            if ms < 1000 {
                return "\(ms)ms"
            } else {
                let seconds = Double(ms) / 1000.0
                return String(format: "%.1fs", seconds)
            }
        }
        return nil
    }
}
