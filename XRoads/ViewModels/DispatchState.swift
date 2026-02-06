import Foundation

// MARK: - DispatchState

/// Manages LayeredDispatcher progress state: phase, progress, messages,
/// global logs, and current layer tracking.
/// Extracted from AppState (CR-301) to reduce God Object complexity.
@MainActor
@Observable
final class DispatchState {

    // MARK: - Dispatch Phase

    /// Current dispatch phase
    var dispatchPhase: DispatchPhase = .idle

    /// Dispatch progress info
    var dispatchProgress: DispatchProgress?

    /// Current dispatch message
    var dispatchMessage: String = ""

    // MARK: - Logs

    /// Global logs from all dispatch sources (CR-001: bounded at 5000 with FIFO eviction)
    var globalLogs = BoundedBuffer<LogEntry>(capacity: 5000)

    // MARK: - Layer Tracking

    /// PRD being dispatched
    var currentPRD: PRDDocument?

    /// Current layer being executed
    var currentDispatchLayer: Int = 0

    /// Total layers in dispatch
    var totalDispatchLayers: Int = 0

    // MARK: - Computed Properties

    /// Whether a layered dispatch is active
    var isDispatching: Bool {
        switch dispatchPhase {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
}
