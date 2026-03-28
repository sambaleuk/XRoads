import Foundation
import os

// MARK: - SlotChatViewModel

/// Drives the per-slot chat panel. Loads and streams AgentMessages for a single slot,
/// tracks unread count, and enables user message injection into agent stdin.
///
/// US-004: Cockpit UI — chat panel per slot + Chairman feed display
@MainActor
@Observable
final class SlotChatViewModel {

    // MARK: - Published State

    /// Messages for this slot, ordered by creation time
    var messages: [AgentMessage] = []

    /// Number of unread messages (readAt == nil)
    var unreadCount: Int = 0

    /// Whether the chat panel is expanded
    var isExpanded: Bool = false

    /// User input text for sending to agent stdin
    var inputText: String = ""

    /// Error message (transient)
    var errorMessage: String?

    // MARK: - Identity

    /// The slot this chat panel is bound to
    let slot: AgentSlot

    // MARK: - Dependencies

    private let bus: MessageBusService
    private let ptyRunner: ProcessRunner?
    private let logger = Logger(subsystem: "com.xroads", category: "SlotChat")

    /// Subscription task for real-time updates
    private var subscriptionTask: Task<Void, Never>?

    // MARK: - Init

    init(
        slot: AgentSlot,
        bus: MessageBusService,
        ptyRunner: ProcessRunner? = nil
    ) {
        self.slot = slot
        self.bus = bus
        self.ptyRunner = ptyRunner
    }

    // MARK: - Load Messages

    /// Loads existing messages for this slot from the database.
    func loadMessages() async {
        do {
            let fetched = try await bus.fetchMessages(slotId: slot.id)
            messages = fetched
            unreadCount = fetched.filter { $0.readAt == nil }.count
        } catch {
            let msg = error.localizedDescription
            logger.error("Failed to load messages: \(msg)")
            errorMessage = msg
        }
    }

    // MARK: - Subscribe to Real-Time Updates

    /// Subscribes to the message bus for this slot's session.
    /// Filters incoming messages to only show ones from/to this slot.
    func startListening() async {
        let sessionId = slot.cockpitSessionId
        let stream = await bus.subscribe(toSession: sessionId)
        let slotId = slot.id

        subscriptionTask = Task { [weak self] in
            for await message in stream {
                guard let self else { break }
                guard !Task.isCancelled else { break }
                // Only append messages from or to this slot
                if message.fromSlotId == slotId || message.toSlotId == slotId || message.isBroadcast {
                    await MainActor.run {
                        self.messages.append(message)
                        if message.readAt == nil {
                            self.unreadCount += 1
                        }
                    }
                }
            }
        }
    }

    /// Stops listening for new messages.
    func stopListening() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    // MARK: - Mark as Read

    /// Marks all messages as read, resetting the unread count.
    func markAllAsRead() {
        unreadCount = 0
    }

    // MARK: - Send User Message

    /// Sends the current inputText to the agent's stdin via PTYProcess.
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        // Inject into agent stdin via ProcessRunner
        if let ptyRunner {
            do {
                try await ptyRunner.sendInput(id: slot.id, text: text)
                logger.info("Injected user message to slot \(self.slot.slotIndex)")
            } catch {
                let msg = error.localizedDescription
                logger.error("Failed to send to stdin: \(msg)")
                errorMessage = msg
            }
        }

        // Also publish as a user message on the bus so it shows in chat
        let userMessage = AgentMessage(
            content: text,
            messageType: .status,
            fromSlotId: slot.id,
            isBroadcast: false
        )

        do {
            try await bus.publish(message: userMessage, fromSlot: slot.id)
        } catch {
            let msg = error.localizedDescription
            logger.error("Failed to publish user message: \(msg)")
        }
    }
}
