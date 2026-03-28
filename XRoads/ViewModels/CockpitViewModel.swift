import Foundation
import os

// MARK: - CockpitViewModel

/// Drives the Cockpit Mode UI. Manages session lifecycle, slot display state,
/// per-slot chat view models, and Chairman brief observation.
///
/// US-004: Added chatViewModels, chairmanBrief, and chairman feed subscription.
/// US-003: Added pendingGates, approveGate/rejectGate for approval card flow.
@MainActor
@Observable
final class CockpitViewModel {

    // MARK: - Published State

    /// Current cockpit session (nil when no session active)
    var session: CockpitSession?

    /// Slots for the active session, ordered by slotIndex
    var slots: [AgentSlot] = []

    /// Slots that have been revealed by sequential animation
    var revealedSlotIds: Set<UUID> = []

    /// Whether the cockpit is loading (activation in progress)
    var isLoading: Bool = false

    /// Error message to display
    var errorMessage: String?

    /// Per-slot chat view models, keyed by slot ID
    var chatViewModels: [UUID: SlotChatViewModel] = [:]

    /// US-003: Pending ExecutionGates per slot (keyed by slot ID).
    /// Only gates in `awaiting_approval` state are tracked here.
    var pendingGates: [UUID: ExecutionGate] = [:]

    /// US-003: Process IDs for slots with pending gates (keyed by slot ID).
    /// Populated by gate polling or interceptor callbacks.
    var slotProcessIds: [UUID: UUID] = [:]

    /// US-004: Whether the audit trail panel is shown
    var showAuditTrail: Bool = false

    /// Latest chairman brief text, auto-refreshed from session
    var chairmanBrief: String? {
        session?.chairmanBrief
    }

    /// Convenience: session status or .idle when no session
    var sessionStatus: CockpitSessionStatus {
        session?.status ?? .idle
    }

    /// Whether cockpit mode is active (session exists and not idle/closed)
    var isActive: Bool {
        guard let session else { return false }
        return session.status != .idle && session.status != .closed
    }

    // MARK: - Dependencies

    private let lifecycleManager: CockpitLifecycleManager
    private let conductorService: ConductorService
    private let repository: CockpitSessionRepository
    private let bus: MessageBusService
    private let ptyRunner: ProcessRunner?
    /// US-004: Exposed for AuditTrailView sheet creation
    let gateRepo: ExecutionGateRepository?
    private let logger = Logger(subsystem: "com.xroads", category: "CockpitVM")

    /// Task for chairman brief polling
    private var chairmanBriefTask: Task<Void, Never>?
    /// Task for pending gate polling (US-003)
    private var gatePollTask: Task<Void, Never>?

    // MARK: - Init

    init(
        lifecycleManager: CockpitLifecycleManager,
        conductorService: ConductorService,
        repository: CockpitSessionRepository,
        bus: MessageBusService,
        ptyRunner: ProcessRunner? = nil,
        gateRepo: ExecutionGateRepository? = nil
    ) {
        self.lifecycleManager = lifecycleManager
        self.conductorService = conductorService
        self.repository = repository
        self.bus = bus
        self.ptyRunner = ptyRunner
        self.gateRepo = gateRepo
    }

    // MARK: - Activate Cockpit Mode

    /// Starts the full cockpit activation flow: idle -> initializing -> active.
    /// Sequential slot reveal animation is driven by `revealedSlotIds`.
    func activate(projectPath: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            // Step 1: Create session in idle state
            let newSession = try await repository.createSession(
                CockpitSession(projectPath: projectPath)
            )
            session = newSession

            // Step 2: Activate (idle -> initializing) with context reading
            let (initializing, chairmanInput) = try await lifecycleManager.activate(session: newSession)
            session = initializing

            // Step 3: Conductor deliberation (initializing -> active)
            let (activeSession, assignedSlots) = try await conductorService.conductSlotAssignment(
                session: initializing,
                chairmanInput: chairmanInput
            )
            session = activeSession
            slots = assignedSlots

            // Step 4: Create chat view models for each slot
            buildChatViewModels(for: assignedSlots)

            // Step 5: Sequential slot reveal animation (500ms between each)
            await revealSlotsSequentially(assignedSlots)

            // Step 6: Start chairman brief refresh loop
            startChairmanBriefRefresh()

            // Step 7: Start gate polling for approval cards (US-003)
            startGatePolling()

            isLoading = false
            logger.info("Cockpit activated with \(assignedSlots.count) slots")
        } catch {
            isLoading = false
            let msg = error.localizedDescription
            errorMessage = msg
            logger.error("Cockpit activation failed: \(msg)")
        }
    }

    // MARK: - Pause (active -> paused)

    /// Pauses the cockpit session and all agent slots.
    func pause() async {
        guard let current = session, current.status == .active else { return }

        do {
            let paused = try await lifecycleManager.pause(session: current)
            session = paused

            // Transition all running slots to paused
            var updatedSlots: [AgentSlot] = []
            for var slot in slots {
                if slot.status == .running {
                    slot.status = .paused
                    slot.updatedAt = Date()
                    let persisted = try await repository.updateSlot(slot)
                    updatedSlots.append(persisted)
                } else {
                    updatedSlots.append(slot)
                }
            }
            slots = updatedSlots

            logger.info("Cockpit paused: all running slots suspended")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Pause failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Resume (paused -> active)

    /// Resumes the cockpit session and all paused agent slots.
    func resume() async {
        guard let current = session, current.status == .paused else { return }

        do {
            let active = try await lifecycleManager.resume(session: current)
            session = active

            // Transition all paused slots back to running
            var updatedSlots: [AgentSlot] = []
            for var slot in slots {
                if slot.status == .paused {
                    slot.status = .running
                    slot.updatedAt = Date()
                    let persisted = try await repository.updateSlot(slot)
                    updatedSlots.append(persisted)
                } else {
                    updatedSlots.append(slot)
                }
            }
            slots = updatedSlots

            logger.info("Cockpit resumed: all paused slots restarted")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Resume failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Close (active|paused -> closed)

    /// Closes the cockpit session and terminates all slots.
    func close() async {
        guard let current = session,
              current.status == .active || current.status == .paused else { return }

        do {
            let closed = try await lifecycleManager.close(
                session: current,
                hasPendingGates: !pendingGates.isEmpty
            )
            session = closed
            slots = []
            revealedSlotIds = []

            // Cleanup chat view models and chairman refresh
            for (_, chatVM) in chatViewModels {
                chatVM.stopListening()
            }
            chatViewModels = [:]
            chairmanBriefTask?.cancel()
            chairmanBriefTask = nil
            gatePollTask?.cancel()
            gatePollTask = nil
            pendingGates = [:]
            slotProcessIds = [:]

            logger.info("Cockpit session closed")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Close failed: \(error.localizedDescription)")
        }
    }

    // MARK: - US-003: Approve Gate

    /// Approves a pending ExecutionGate:
    /// 1. Transitions gate from awaiting_approval -> executing via state machine (guard: approved_by_human)
    /// 2. Resumes the suspended agent process (SIGCONT)
    /// 3. Transitions AgentSlot from waiting_approval -> running (gate_approved event)
    func approveGate(_ gate: ExecutionGate) async {
        guard let gateRepo else {
            logger.error("Cannot approve gate: gateRepo not available")
            return
        }

        do {
            // 1. Transition gate: awaiting_approval -> executing
            let context = ExecutionGateGuardContext(approvedByHuman: true)
            let updated = try await gateRepo.updateStatus(
                gateId: gate.id,
                event: .approve,
                context: context,
                approvedBy: "board_user"
            )

            // 2. Resume agent process via SIGCONT
            if let slot = slots.first(where: { $0.id == gate.agentSlotId }) {
                await resumeAgentProcess(for: slot)
            }

            // 3. Transition slot: waiting_approval -> running
            try await transitionSlot(id: gate.agentSlotId, to: .running)

            // 4. Remove from pending gates
            pendingGates.removeValue(forKey: gate.agentSlotId)

            logger.info("Gate \(gate.id) approved, slot \(gate.agentSlotId) resumed -> running")
            _ = updated // silence unused warning
        } catch {
            let msg = error.localizedDescription
            errorMessage = msg
            logger.error("Approve gate failed: \(msg)")
        }
    }

    // MARK: - US-003: Reject Gate

    /// Rejects a pending ExecutionGate:
    /// 1. Transitions gate from awaiting_approval -> rejected
    /// 2. Notifies agent via stdin that the operation was rejected
    /// 3. Resumes the agent process (SIGCONT) so it can continue with rejection
    /// 4. Transitions AgentSlot from waiting_approval -> running (gate_rejected event)
    func rejectGate(_ gate: ExecutionGate) async {
        guard let gateRepo else {
            logger.error("Cannot reject gate: gateRepo not available")
            return
        }

        do {
            // 1. Transition gate: awaiting_approval -> rejected
            let updated = try await gateRepo.updateStatus(
                gateId: gate.id,
                event: .reject,
                deniedReason: "Rejected by board user"
            )

            // 2. Notify agent and resume process
            if let slot = slots.first(where: { $0.id == gate.agentSlotId }) {
                // Send rejection message via stdin before resuming
                if let processId = slotProcessIds[slot.id],
                   let runner = ptyRunner as? PTYProcessRunner {
                    try? await runner.sendInput(id: processId, text: "[SAFEEXEC_REJECTED]\n")
                }
                await resumeAgentProcess(for: slot)
            }

            // 3. Transition slot: waiting_approval -> running
            try await transitionSlot(id: gate.agentSlotId, to: .running)

            // 4. Remove from pending gates
            pendingGates.removeValue(forKey: gate.agentSlotId)

            logger.info("Gate \(gate.id) rejected, slot \(gate.agentSlotId) resumed -> running")
            _ = updated
        } catch {
            let msg = error.localizedDescription
            errorMessage = msg
            logger.error("Reject gate failed: \(msg)")
        }
    }

    // MARK: - US-003: Gate Polling

    /// Starts polling for pending gates on waiting_approval slots.
    /// Called when cockpit activates or when loading existing sessions.
    func startGatePolling() {
        gatePollTask?.cancel()
        gatePollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await self?.refreshPendingGates()
            }
        }
    }

    /// Fetches the latest awaiting_approval gate for each slot that is in waiting_approval state.
    private func refreshPendingGates() async {
        guard let gateRepo else { return }

        for slot in slots where slot.status == .waitingApproval {
            do {
                let gates = try await gateRepo.fetchGates(slotId: slot.id)
                if let pending = gates.first(where: { $0.status == .awaitingApproval }) {
                    pendingGates[slot.id] = pending
                }
            } catch {
                // Non-fatal: gate fetch failure
            }
        }

        // Remove stale pending gates for slots no longer in waiting_approval
        for slotId in pendingGates.keys {
            if !slots.contains(where: { $0.id == slotId && $0.status == .waitingApproval }) {
                pendingGates.removeValue(forKey: slotId)
            }
        }
    }

    // MARK: - US-003: Private Helpers

    /// Resume an agent process by sending SIGCONT via the PTY runner.
    private func resumeAgentProcess(for slot: AgentSlot) async {
        guard let runner = ptyRunner as? PTYProcessRunner,
              let processId = slotProcessIds[slot.id] else {
            logger.warning("No process ID found for slot \(slot.id) — cannot resume")
            return
        }

        if let info = await runner.getProcessInfo(id: processId) {
            let pid = info.pid
            if pid > 0 {
                kill(pid, SIGCONT)
                logger.info("SIGCONT sent to pid \(pid) for slot \(slot.id)")
            }
        }
    }

    /// Persist a slot status transition in the database and update local state.
    private func transitionSlot(id: UUID, to newStatus: AgentSlotStatus) async throws {
        if let index = slots.firstIndex(where: { $0.id == id }) {
            slots[index].status = newStatus
            slots[index].updatedAt = Date()
            _ = try await repository.updateSlot(slots[index])
        }
    }

    // MARK: - Load Existing Session

    /// Loads an existing non-closed session for a project path (e.g., on app restart).
    func loadExistingSession(projectPath: String) async {
        do {
            if let existing = try await repository.activeSession(for: projectPath) {
                session = existing
                slots = try await repository.fetchSlots(sessionId: existing.id)
                // All existing slots are already revealed
                revealedSlotIds = Set(slots.map(\.id))
                // Build chat view models for loaded slots
                buildChatViewModels(for: slots)
                // Start chairman brief refresh
                startChairmanBriefRefresh()
                // Start gate polling (US-003)
                startGatePolling()
            }
        } catch {
            logger.error("Failed to load existing session: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: Chat View Models

    /// Creates a SlotChatViewModel for each slot and stores in chatViewModels.
    private func buildChatViewModels(for assignedSlots: [AgentSlot]) {
        for slot in assignedSlots {
            let chatVM = SlotChatViewModel(
                slot: slot,
                bus: bus,
                ptyRunner: ptyRunner
            )
            chatViewModels[slot.id] = chatVM
        }
    }

    // MARK: - Private: Chairman Brief Refresh

    /// Polls CockpitSession.chairmanBrief from the database every 3 seconds
    /// to detect updates from ChairmanFeedService.
    private func startChairmanBriefRefresh() {
        chairmanBriefTask?.cancel()
        chairmanBriefTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, let sessionId = self.session?.id else { break }
                do {
                    if let refreshed = try await self.repository.fetchSession(id: sessionId) {
                        if refreshed.chairmanBrief != self.session?.chairmanBrief {
                            self.session?.chairmanBrief = refreshed.chairmanBrief
                        }
                    }
                } catch {
                    // Non-fatal: chairman brief refresh failure
                }
            }
        }
    }

    // MARK: - Private: Slot Reveal

    /// Reveals slots one by one with a spring animation delay.
    private func revealSlotsSequentially(_ slotsToReveal: [AgentSlot]) async {
        for slot in slotsToReveal {
            try? await Task.sleep(for: .milliseconds(500))
            revealedSlotIds.insert(slot.id)
        }
    }
}
