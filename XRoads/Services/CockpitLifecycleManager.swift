import Foundation
import os

// MARK: - CockpitLifecycleError

enum CockpitLifecycleError: LocalizedError, Sendable {
    case guardViolation(guard: String, event: String)
    case invalidTransition(from: CockpitSessionStatus, event: String)

    var errorDescription: String? {
        switch self {
        case .guardViolation(let guardName, let event):
            return "Guard '\(guardName)' blocked event '\(event)'"
        case .invalidTransition(let from, let event):
            return "No transition for event '\(event)' from state '\(from.rawValue)'"
        }
    }
}

// MARK: - CockpitLifecycleManager

/// Manages CockpitLifecycle state transitions as defined in states.json.
/// Enforces guards and triggers actions on transitions.
actor CockpitLifecycleManager {

    private let logger = Logger(subsystem: "com.xroads", category: "CockpitLifecycle")
    private let contextReader: ProjectContextReader
    private let repository: CockpitSessionRepository

    init(contextReader: ProjectContextReader, repository: CockpitSessionRepository) {
        self.contextReader = contextReader
        self.repository = repository
    }

    // MARK: - Activate (idle → initializing)

    /// Activates a CockpitSession: validates the has_valid_project guard,
    /// reads project context, and transitions from idle to initializing.
    ///
    /// CockpitLifecycle: idle → activate [guard: has_valid_project] → initializing
    /// Action: read_project_context
    ///
    /// - Parameter session: The session to activate (must be in idle state)
    /// - Returns: Tuple of (updated session, chairman input context)
    /// - Throws: CockpitLifecycleError on guard violation or invalid state
    func activate(session: CockpitSession) async throws -> (CockpitSession, ChairmanInput) {
        // Verify current state allows this transition
        guard session.status == .idle else {
            throw CockpitLifecycleError.invalidTransition(from: session.status, event: "activate")
        }

        let path = session.projectPath

        // Guard: has_valid_project
        guard await contextReader.hasValidProject(at: path) else {
            logger.warning("Guard has_valid_project failed for \(path, privacy: .public)")
            throw CockpitLifecycleError.guardViolation(guard: "has_valid_project", event: "activate")
        }

        // Action: read_project_context
        let chairmanInput = try await contextReader.readContext(projectPath: path)

        // Transition: idle → initializing
        var updated = session
        updated.status = .initializing
        updated.updatedAt = Date()
        let persisted = try await repository.updateSession(updated)

        logger.info("CockpitSession \(session.id) activated: idle → initializing")

        return (persisted, chairmanInput)
    }
}
