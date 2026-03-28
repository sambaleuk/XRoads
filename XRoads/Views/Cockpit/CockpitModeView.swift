import SwiftUI

// MARK: - CockpitModeView

/// Main Cockpit Mode panel. Shows session status, slot cards with sequential
/// reveal animation, Chairman Feed sidebar, and Pause/Resume/Close controls.
///
/// US-004: Added Chairman Feed panel and per-slot chat integration.
struct CockpitModeView: View {
    @Bindable var viewModel: CockpitViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header with session status and controls
            cockpitHeader
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)

            Divider()

            // Main content: slots + chairman feed
            if viewModel.slots.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 0) {
                    // Slot cards (main area)
                    slotsList
                        .frame(maxWidth: .infinity)

                    Divider()

                    // Chairman Feed sidebar
                    ChairmanFeedPanelView(chairmanBrief: viewModel.chairmanBrief)
                        .frame(width: 280)
                        .padding(Theme.Spacing.sm)
                }
            }
        }
        .background(Color.bgCanvas)
    }

    // MARK: - Header

    @ViewBuilder
    private var cockpitHeader: some View {
        HStack {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(sessionStatusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: sessionStatusColor.opacity(0.6), radius: 3)

                Text("COCKPIT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)

                Text(viewModel.sessionStatus.rawValue.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(sessionStatusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sessionStatusColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()

            // Session controls
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, Theme.Spacing.sm)
            }

            sessionControls
        }
    }

    @ViewBuilder
    private var sessionControls: some View {
        HStack(spacing: Theme.Spacing.sm) {
            switch viewModel.sessionStatus {
            case .active:
                Button {
                    Task { await viewModel.pause() }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task { await viewModel.close() }
                } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)

            case .paused:
                Button {
                    Task { await viewModel.resume() }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.green)

                Button {
                    Task { await viewModel.close() }
                } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Slot Cards

    @ViewBuilder
    private var slotsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.slots, id: \.id) { slot in
                    if let chatVM = viewModel.chatViewModels[slot.id] {
                        CockpitSlotCardView(
                            slot: slot,
                            skillName: skillName(for: slot),
                            isRevealed: viewModel.revealedSlotIds.contains(slot.id),
                            chatViewModel: chatVM,
                            pendingGate: viewModel.pendingGates[slot.id],
                            onApproveGate: { gate in
                                Task { await viewModel.approveGate(gate) }
                            },
                            onRejectGate: { gate in
                                Task { await viewModel.rejectGate(gate) }
                            }
                        )
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "cpu")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)
            Text("No active cockpit session")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.statusError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var sessionStatusColor: Color {
        switch viewModel.sessionStatus {
        case .idle: return Color.textTertiary
        case .initializing: return Color.statusInfo
        case .active: return Color.statusSuccess
        case .paused: return Color.terminalYellow
        case .closed: return Color.textTertiary
        }
    }

    private func skillName(for slot: AgentSlot) -> String {
        slot.branchName?.components(separatedBy: "/").last ?? "slot-\(slot.slotIndex)"
    }
}

// MARK: - Preview

#if DEBUG
struct CockpitModeView_Previews: PreviewProvider {
    static var previews: some View {
        Text("CockpitModeView requires DI setup for preview")
            .foregroundStyle(Color.textTertiary)
            .frame(width: 300, height: 400)
            .background(Color.bgApp)
    }
}
#endif
