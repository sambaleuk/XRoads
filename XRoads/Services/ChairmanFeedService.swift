import Foundation
import GRDB
import os

// MARK: - ChairmanFeedError

enum ChairmanFeedError: LocalizedError, Sendable {
    case sessionNotFound(UUID)
    case synthesisSlotMissing
    case synthesisCallFailed(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "CockpitSession not found for Chairman feed: \(id)"
        case .synthesisSlotMissing:
            return "No slot available to emit chairman_brief message"
        case .synthesisCallFailed(let reason):
            return "Chairman synthesis failed: \(reason)"
        }
    }
}

// MARK: - ChairmanSynthesisInput

/// Context sent to cockpit-council for real-time synthesis (not slot assignment).
/// Contains recent messages from all active slots for the Chairman to analyze.
struct ChairmanSynthesisInput: Codable, Hashable, Sendable {
    let sessionId: UUID
    let projectPath: String
    let recentMessages: [MessageSummary]
    let collectedAt: Date

    struct MessageSummary: Codable, Hashable, Sendable {
        let fromSlotId: UUID
        let agentType: String
        let messageType: String
        let content: String
        let createdAt: Date
    }
}

// MARK: - ChairmanSynthesisOutput

/// Output from cockpit-council synthesis mode.
struct ChairmanSynthesisOutput: Codable, Hashable, Sendable {
    let summary: String
    let activeAgentsStatus: String
    let blockers: [String]
    let decisionsRecommended: [String]
    let actionItems: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case activeAgentsStatus = "active_agents_status"
        case blockers
        case decisionsRecommended = "decisions_recommended"
        case actionItems = "action_items"
    }

    /// Formats the synthesis as a single brief string for storage.
    var asBrief: String {
        var parts: [String] = []
        parts.append("## Status\n\(activeAgentsStatus)")
        if !blockers.isEmpty {
            parts.append("## Blockers\n" + blockers.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !decisionsRecommended.isEmpty {
            parts.append("## Decisions Recommended\n" + decisionsRecommended.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !actionItems.isEmpty {
            parts.append("## Action Items\n" + actionItems.map { "- \($0)" }.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - ChairmanSynthesizerProtocol

/// Protocol for Chairman synthesis — enables test injection.
protocol ChairmanSynthesizerProtocol: Sendable {
    func synthesize(input: ChairmanSynthesisInput) async throws -> ChairmanSynthesisOutput
}

// MARK: - ChairmanSynthesizer

/// Calls cockpit-council in synthesis mode via Python subprocess.
actor ChairmanSynthesizer: ChairmanSynthesizerProtocol {

    private let logger = Logger(subsystem: "com.xroads", category: "ChairmanSynth")
    private let pythonPath: String

    init(pythonPath: String? = nil) throws {
        if let path = pythonPath {
            self.pythonPath = path
        } else {
            self.pythonPath = try Self.findPython()
        }
    }

    func synthesize(input: ChairmanSynthesisInput) async throws -> ChairmanSynthesisOutput {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let inputData = try encoder.encode(input)

        logger.info("Sending synthesis input to cockpit-council (\(inputData.count) bytes)")

        let outputData = try await runSynthesis(inputJSON: inputData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(ChairmanSynthesisOutput.self, from: outputData)
        } catch {
            throw ChairmanFeedError.synthesisCallFailed(error.localizedDescription)
        }
    }

    private func runSynthesis(inputJSON: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-m", "cockpit_council", "--synthesize"]

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: stdout)
                } else {
                    let errMsg = String(data: stderr, encoding: .utf8) ?? "unknown error"
                    continuation.resume(throwing: ChairmanFeedError.synthesisCallFailed(errMsg))
                }
            }

            do {
                try process.run()
                stdinPipe.fileHandleForWriting.write(inputJSON)
                stdinPipe.fileHandleForWriting.closeFile()
            } catch {
                continuation.resume(throwing: ChairmanFeedError.synthesisCallFailed(error.localizedDescription))
            }
        }
    }

    private static func findPython() throws -> String {
        let candidates = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        throw CockpitCouncilError.pythonNotFound
    }
}

// MARK: - MockChairmanSynthesizer

/// Mock synthesizer for testing — returns a predetermined output.
final class MockChairmanSynthesizer: ChairmanSynthesizerProtocol, @unchecked Sendable {
    private let output: ChairmanSynthesisOutput?
    private let error: Error?
    private(set) var callCount = 0
    private(set) var lastInput: ChairmanSynthesisInput?

    init(output: ChairmanSynthesisOutput) {
        self.output = output
        self.error = nil
    }

    init(error: Error) {
        self.output = nil
        self.error = error
    }

    func synthesize(input: ChairmanSynthesisInput) async throws -> ChairmanSynthesisOutput {
        callCount += 1
        lastInput = input
        if let error {
            throw error
        }
        return output!
    }
}

// MARK: - ChairmanFeedService

/// Subscribes to the MessageBusService for an active CockpitSession and triggers
/// Chairman synthesis every 5 messages or immediately on a blocker message.
/// Debounces synthesis calls with a 2-second minimum interval.
///
/// US-003: Chairman Feed aggregator — real-time project synthesis
actor ChairmanFeedService {

    private let logger = Logger(subsystem: "com.xroads", category: "ChairmanFeed")
    private let bus: MessageBusService
    private let synthesizer: ChairmanSynthesizerProtocol
    private let repository: CockpitSessionRepository
    private let dbQueue: DatabaseQueue

    /// Number of new messages before triggering synthesis
    private let synthesisThreshold: Int

    /// Minimum interval between synthesis calls (debounce)
    private let debounceInterval: TimeInterval

    /// Accumulated messages since last synthesis
    private var pendingMessages: [AgentMessage] = []

    /// Timestamp of last synthesis call
    private var lastSynthesisTime: Date?

    /// Active feed task (cancelled on stop)
    private var feedTask: Task<Void, Never>?

    /// The session being monitored
    private var activeSessionId: UUID?

    /// The slot ID used to publish chairman_brief messages (first slot in session)
    private var chairmanSlotId: UUID?

    init(
        bus: MessageBusService,
        synthesizer: ChairmanSynthesizerProtocol,
        repository: CockpitSessionRepository,
        dbQueue: DatabaseQueue,
        synthesisThreshold: Int = 5,
        debounceInterval: TimeInterval = 2.0
    ) {
        self.bus = bus
        self.synthesizer = synthesizer
        self.repository = repository
        self.dbQueue = dbQueue
        self.synthesisThreshold = synthesisThreshold
        self.debounceInterval = debounceInterval
    }

    // MARK: - Start / Stop

    /// Start monitoring a session's message bus for synthesis triggers.
    func start(sessionId: UUID) async throws {
        // Cancel any existing feed task to prevent leaks on double-start
        feedTask?.cancel()

        // Validate session exists and is active
        guard let session = try await repository.fetchSession(id: sessionId) else {
            throw ChairmanFeedError.sessionNotFound(sessionId)
        }

        // Get the first slot to use as chairman_brief emitter
        let slots = try await repository.fetchSlots(sessionId: sessionId)
        guard let firstSlot = slots.first else {
            throw ChairmanFeedError.synthesisSlotMissing
        }

        activeSessionId = sessionId
        chairmanSlotId = firstSlot.id
        pendingMessages = []
        lastSynthesisTime = nil

        let stream = await bus.subscribe(toSession: sessionId)
        let projectPath = session.projectPath

        logger.info("Chairman feed started for session \(sessionId)")

        feedTask = Task { [weak self] in
            for await message in stream {
                guard let self else { break }
                guard !Task.isCancelled else { break }
                await self.handleMessage(message, projectPath: projectPath)
            }
        }
    }

    /// Stop monitoring the session.
    func stop() {
        feedTask?.cancel()
        feedTask = nil
        activeSessionId = nil
        chairmanSlotId = nil
        pendingMessages = []
        lastSynthesisTime = nil
        logger.info("Chairman feed stopped")
    }

    // MARK: - Message Handling

    /// Handle a new message from the bus. Accumulates and triggers synthesis as needed.
    private func handleMessage(_ message: AgentMessage, projectPath: String) async {
        // Don't re-trigger on our own chairman_brief messages
        guard message.messageType != .chairmanBrief else { return }

        pendingMessages.append(message)

        let shouldSynthesize: Bool
        if message.messageType == .blocker {
            // Immediate trigger on blocker
            shouldSynthesize = true
        } else if pendingMessages.count >= synthesisThreshold {
            // Trigger every N messages
            shouldSynthesize = true
        } else {
            shouldSynthesize = false
        }

        guard shouldSynthesize else { return }

        // Debounce: skip if last synthesis was too recent
        if let lastTime = lastSynthesisTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < debounceInterval {
                logger.info("Debouncing synthesis — \(elapsed)s since last call")
                return
            }
        }

        await triggerSynthesis(projectPath: projectPath)
    }

    // MARK: - Synthesis

    /// Triggers a Chairman synthesis with accumulated messages.
    private func triggerSynthesis(projectPath: String) async {
        guard let sessionId = activeSessionId else { return }
        guard let slotId = chairmanSlotId else { return }

        let messagesToSynthesize = pendingMessages
        pendingMessages = []
        lastSynthesisTime = Date()

        // Build slot agent type lookup
        let slotAgentTypes = await buildSlotAgentTypes(sessionId: sessionId)

        // Build synthesis input
        let input = ChairmanSynthesisInput(
            sessionId: sessionId,
            projectPath: projectPath,
            recentMessages: messagesToSynthesize.map { msg in
                ChairmanSynthesisInput.MessageSummary(
                    fromSlotId: msg.fromSlotId,
                    agentType: slotAgentTypes[msg.fromSlotId] ?? "unknown",
                    messageType: msg.messageType.rawValue,
                    content: msg.content,
                    createdAt: msg.createdAt
                )
            },
            collectedAt: Date()
        )

        do {
            let output = try await synthesizer.synthesize(input: input)

            // Publish chairman_brief to message bus
            let briefMessage = AgentMessage(
                content: output.asBrief,
                messageType: .chairmanBrief,
                fromSlotId: slotId,
                isBroadcast: true
            )
            try await bus.publish(message: briefMessage, fromSlot: slotId)

            // Update CockpitSession.chairmanBrief in SQLite
            try await updateSessionBrief(sessionId: sessionId, brief: output.asBrief)

            logger.info("Chairman synthesis published for session \(sessionId)")
        } catch {
            let errorMsg = error.localizedDescription
            logger.error("Chairman synthesis failed: \(errorMsg)")
        }
    }

    /// Updates the CockpitSession.chairmanBrief field in the database.
    private func updateSessionBrief(sessionId: UUID, brief: String) async throws {
        guard var session = try await repository.fetchSession(id: sessionId) else {
            throw ChairmanFeedError.sessionNotFound(sessionId)
        }
        session.chairmanBrief = brief
        _ = try await repository.updateSession(session)
    }

    /// Builds a lookup of slotId → agentType for message context enrichment.
    private func buildSlotAgentTypes(sessionId: UUID) async -> [UUID: String] {
        do {
            let slots = try await repository.fetchSlots(sessionId: sessionId)
            return Dictionary(uniqueKeysWithValues: slots.map { ($0.id, $0.agentType) })
        } catch {
            return [:]
        }
    }
}
